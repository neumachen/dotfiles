"""Tests for dot_local/bin/executable_macos-preferences.

Run from the repository root (nothing here reads or writes this Mac's real
preferences: the tool is pointed at tests/fake_defaults, a model of `defaults`
backed by a temporary directory):

    python3 -m unittest discover -s private_dot_config/macos-preferences/tests -v
"""

import datetime
import hashlib
import importlib.machinery
import importlib.util
import io
import json
import os
import plistlib
import random
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.dont_write_bytecode = True   # never leave __pycache__ next to the tool in the source tree

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
# MACOS_PREFERENCES_TOOL lets the mutation check run this suite against a deliberately broken copy.
TOOL = os.environ.get('MACOS_PREFERENCES_TOOL') or os.path.join(REPO, 'dot_local', 'bin', 'executable_macos-preferences')
FAKE = os.path.join(HERE, 'fake_defaults')
SHIPPED_PROFILE = os.path.join(REPO, 'private_dot_config', 'macos-preferences', 'profile.json')


def load_tool():
    loader = importlib.machinery.SourceFileLoader('macos_preferences', TOOL)
    spec = importlib.util.spec_from_loader('macos_preferences', loader)
    module = importlib.util.module_from_spec(spec)
    sys.modules['macos_preferences'] = module
    loader.exec_module(module)
    return module


mp = load_tool()


def read_bytes(path):
    with open(path, 'rb') as handle:
        return handle.read()


def setUpModule():
    os.chmod(FAKE, 0o755)


# --- fixtures ---------------------------------------------------------------

HOTKEYS = {
    '9': {'enabled': True, 'value': {'parameters': [65535, 48, 262144], 'type': 'standard'}},
    '10': {'enabled': False, 'value': {'parameters': [65535, 49, 262144], 'type': 'standard'}},
    '16': {'enabled': False},  # record with no "value" at all
    '34': {'enabled': True, 'value': {'parameters': [65535, 232, 131072], 'type': 'standard'}},
    '64': {'enabled': False, 'value': {'parameters': [32, 49, 1048576], 'type': 'standard'}},
    '100': {'enabled': True, 'value': {'parameters': [65535, 1, 0], 'type': 'standard'}},
    '176': {'enabled': False, 'value': {'type': 'SAE1.0'}},  # nonstandard record type
}
HOTKEYS_DOMAIN = 'com.apple.symbolichotkeys'


def group(domain, scope, keys=None, absent=()):
    return {'domain': domain, 'scope': scope, 'keys': dict(keys or {}), 'absent': sorted(absent)}


def profile_text(*groups):
    return mp.dump_document({'schema': 1, 'description': mp.PROFILE_DESCRIPTION, 'preferences': list(groups)})


class MemoryBackend(object):
    """In-process stand-in used where argv-level behaviour is not under test."""

    def __init__(self, data=None, domain_order=None):
        self.data = data or {}
        self.domain_order = domain_order
        self.writes = []

    def export(self, domain, scope):
        return dict(self.data.get((domain, scope), {}))

    def domains(self):
        names = [d for (d, s) in self.data if s == mp.USER]
        return self.domain_order(names) if self.domain_order else names

    def set_key(self, domain, scope, key, value):
        self.writes.append(('set_key', domain, scope, key))
        self.data.setdefault((domain, scope), {})[key] = value

    def set_entry(self, domain, scope, key, entry, value):
        self.writes.append(('set_entry', domain, scope, key, entry))
        self.data.setdefault((domain, scope), {}).setdefault(key, {})[entry] = value

    def delete_key(self, domain, scope, key):
        self.writes.append(('delete_key', domain, scope, key))
        self.data.get((domain, scope), {}).pop(key, None)


class Sandbox(object):
    """A temporary fake-defaults world plus everything a CLI run needs."""

    def __init__(self, test):
        self.dir = tempfile.mkdtemp(prefix='macos-prefs-test-', dir=os.environ.get('TMPDIR'))
        test.addCleanup(shutil.rmtree, self.dir, True)
        self.root = os.path.join(self.dir, 'defaults')
        self.home = os.path.join(self.dir, 'home')
        os.makedirs(self.home)
        self.backups = os.path.join(self.dir, 'backups')
        self.profile = os.path.join(self.dir, 'profile.json')
        patcher = mock.patch.dict(os.environ, {'FAKE_DEFAULTS_ROOT': self.root})
        patcher.start()
        test.addCleanup(patcher.stop)

    def _path(self, scope, domain):
        return os.path.join(self.root, scope, domain + '.plist')

    def seed(self, domain, data, scope='user'):
        os.makedirs(os.path.join(self.root, scope), exist_ok=True)
        with open(self._path(scope, domain), 'wb') as handle:
            plistlib.dump(data, handle)

    def read(self, domain, scope='user'):
        try:
            with open(self._path(scope, domain), 'rb') as handle:
                return plistlib.load(handle)
        except FileNotFoundError:
            return {}

    def everything(self):
        """All non-empty domains, for whole-state comparisons."""
        state = {}
        for scope in mp.SCOPES:
            directory = os.path.join(self.root, scope)
            if os.path.isdir(directory):
                for name in os.listdir(directory):
                    data = self.read(name[:-6], scope)
                    if data:
                        state[(scope, name[:-6])] = data
        return state

    def digest(self):
        out = {}
        for base, _dirs, files in os.walk(self.root):
            for name in files:
                if name != 'calls.jsonl':
                    with open(os.path.join(base, name), 'rb') as handle:
                        out[os.path.relpath(os.path.join(base, name), self.root)] = hashlib.sha256(handle.read()).hexdigest()
        return out

    def calls(self):
        try:
            with open(os.path.join(self.root, 'calls.jsonl')) as handle:
                return [json.loads(line) for line in handle]
        except FileNotFoundError:
            return []

    def writes(self):
        return [c for c in self.calls() if c['argv'][0] in ('write', 'delete')]

    def backend(self):
        return mp.DefaultsBackend(FAKE)

    def env(self, **extra):
        env = {
            'PATH': os.environ.get('PATH', '/usr/bin:/bin'),
            'HOME': self.home,
            'XDG_STATE_HOME': os.path.join(self.dir, 'state'),
            'XDG_CONFIG_HOME': os.path.join(self.dir, 'config'),
            'TMPDIR': self.dir,
            'NO_COLOR': '1',
            'PYTHONDONTWRITEBYTECODE': '1',
            'MACOS_PREFERENCES_DEFAULTS_BIN': FAKE,
            'MACOS_PREFERENCES_BACKUP_DIR': self.backups,
            'FAKE_DEFAULTS_ROOT': self.root,
        }
        env.update(extra)
        return env

    def run(self, *args, **extra):
        stdin = extra.pop('stdin', subprocess.DEVNULL)
        return subprocess.run([sys.executable, TOOL] + list(args), env=self.env(**extra), stdin=stdin,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)

    def write_profile(self, *groups):
        with open(self.profile, 'w', encoding='utf-8') as handle:
            handle.write(profile_text(*groups))

    def backup_dirs(self):
        return sorted(os.listdir(self.backups)) if os.path.isdir(self.backups) else []


def silent_log():
    return mp.Log(io.StringIO())


# --- value model ------------------------------------------------------------


class ValueModelTests(unittest.TestCase):
    ALL_TYPES = {
        'false': False, 'true': True, 'zero': 0, 'one': 1, 'neg': -3, 'int64max': 2 ** 63, 'uint64max': 2 ** 64 - 1,
        'real_zero': 0.0, 'real_whole': 1000.0, 'real_frac': 0.5, 'real_tiny': 1e-07, 'real_big': 1e16,
        'str_num': '1', 'str_true': 'true', 'str_empty': '', 'str_unicode': 'Ünï “q” & <x>',
        'data': b'\x00\x01\xff', 'data_empty': b'', 'date': datetime.datetime(2026, 1, 2, 3, 4, 5),
        'array_empty': [], 'dict_empty': {}, 'nested': {'a': [1, 1.0, True, {'b': b'x'}]},
    }

    def test_strict_eq_distinguishes_plist_types(self):
        self.assertFalse(mp.strict_eq(True, 1))
        self.assertFalse(mp.strict_eq(False, 0))
        self.assertFalse(mp.strict_eq(1, 1.0))
        self.assertFalse(mp.strict_eq('1', 1))
        self.assertFalse(mp.strict_eq({'a': False}, {'a': 0}))
        self.assertFalse(mp.strict_eq([1], [1.0]))
        self.assertTrue(mp.strict_eq({'a': [1, 2.5, 'x', b'y']}, {'a': [1, 2.5, 'x', b'y']}))

    def test_codec_round_trips_every_plist_type_through_json_text(self):
        for name, value in self.ALL_TYPES.items():
            errors = []
            text = json.dumps(mp.to_jsonable(value))
            back = mp.from_jsonable(json.loads(text), name, errors)
            self.assertEqual([], errors, name)
            self.assertTrue(mp.strict_eq(value, back), '%s: %r came back as %r' % (name, value, back))

    def test_document_round_trip_preserves_types_and_absent_keys(self):
        keys = {
            'autohide': False, 'largesize': 0, 'tilesize': 64.0, 'magnification': True, 'mineffect': '1',
            'orientation': b'\x00\xff', 'launchanim': datetime.datetime(2026, 1, 2, 3, 4, 5),
            'static-only': [], 'no-bouncing': {}, 'wvous-bl-corner': {'n': [1, 1.0, True]},
        }
        text = profile_text(group('com.apple.dock', 'user', keys, absent=['show-recents']))
        parsed = mp.parse_document(text, 'profile', 'test')
        dock = parsed['preferences'][0]
        self.assertTrue(mp.strict_eq(keys, dock['keys']))
        self.assertEqual(['show-recents'], dock['absent'])
        self.assertNotIn('show-recents', dock['keys'])
        self.assertIn('"autohide": false', text)
        self.assertIn('"largesize": 0,', text)
        self.assertIn('"tilesize": 64.0', text)

    def test_tag_collision_is_refused(self):
        with self.assertRaises(mp.ProfileError):
            mp.to_jsonable({'$data': 'AAAA'})
        with self.assertRaises(mp.ProfileError):
            mp.to_jsonable({'$date': 'x'})

    def test_unrepresentable_values_are_refused(self):
        for bad in (float('nan'), float('inf'), 2 ** 64, datetime.datetime(2026, 1, 1, 0, 0, 0, 5), {1: 'x'}, None):
            with self.assertRaises(mp.ProfileError, msg=repr(bad)):
                mp.to_jsonable(bad)

    def test_key_order_sorts_shortcut_ids_numerically(self):
        self.assertEqual(['9', '10', '100', 'a', 'b'], sorted(['100', 'b', '9', 'a', '10'], key=mp.key_order))

    def test_scalar_flags_are_typed_and_floats_never_rounded_silently(self):
        self.assertEqual(['-bool', 'false'], mp.scalar_flags(False))
        self.assertEqual(['-int', '0'], mp.scalar_flags(0))
        self.assertEqual(['-float', '64.0'], mp.scalar_flags(64.0))
        self.assertEqual(['-string', '1'], mp.scalar_flags('1'))
        self.assertEqual(['-data', '00ff'], mp.scalar_flags(b'\x00\xff'))
        self.assertIsNone(mp.scalar_flags(0.1))  # not exactly a float32: goes through an XML fragment
        self.assertTrue(mp.value_args(0.1)[0].startswith('<real>0.1</real>'))
        self.assertTrue(mp.value_args({'enabled': False})[0].startswith('<dict>'))


# --- allowlist --------------------------------------------------------------


class AllowlistTests(unittest.TestCase):
    def test_machine_specific_and_personal_keys_are_not_allowlisted(self):
        keys = {k for (_d, _s, k) in mp.KEY_INDEX}
        for forbidden in ('persistent-apps', 'persistent-others', 'recent-apps', 'FXRecentFolders', 'GoToField',
                          'GoToFieldHistory', 'FXConnectToLastURL', 'RecentMoveAndCopyDestinations',
                          'NewWindowTargetPath', 'FXDesktopVolumePositions', 'NSUserDictionaryReplacementItems',
                          'AppleLanguages', 'AppleLocale', 'SpacesDisplayConfiguration', 'FXICloudLoggedIn',
                          'mod-count', 'last-analytics-stamp', 'AppleInputSourceHistory'):
            self.assertNotIn(forbidden, keys)

    def test_domains_are_limited_to_user_preference_domains(self):
        domains = {d for (d, _s, _k) in mp.KEY_INDEX}
        for domain in domains:
            self.assertRegex(domain, mp.DOMAIN_RE)
        self.assertFalse({d for d in domains if 'account' in d.lower() or 'MobileMe' in d or 'keychain' in d.lower()
                          or 'security' in d.lower() or 'TCC' in d})

    def test_current_host_scope_is_only_used_for_the_global_domain(self):
        self.assertEqual({mp.GLOBAL}, {d for (d, s, _k) in mp.KEY_INDEX if s == mp.HOST})

    def test_merge_keys_are_exactly_the_shortcut_dictionaries(self):
        merged = {k for (_d, _s, k), spec in mp.KEY_INDEX.items() if spec.merge}
        self.assertEqual({'AppleSymbolicHotKeys', 'NSServicesStatus', 'NSUserKeyEquivalents'}, merged)

    def test_key_equivalents_are_allowed_in_any_valid_user_domain_only(self):
        self.assertTrue(mp.spec_for('com.example.App', mp.USER, 'NSUserKeyEquivalents').merge)
        self.assertIsNone(mp.spec_for('com.example.App', mp.HOST, 'NSUserKeyEquivalents'))
        self.assertIsNone(mp.spec_for('com.example.App', mp.USER, 'SomethingElse'))
        self.assertIsNone(mp.spec_for('/tmp/evil', mp.USER, 'NSUserKeyEquivalents'))


# --- capture ----------------------------------------------------------------


class CaptureTests(unittest.TestCase):
    def capture(self, backend):
        log_stream = io.StringIO()
        doc = mp.capture_profile(backend, mp.Log(log_stream))
        return doc, mp.dump_document(doc), log_stream.getvalue()

    def by_group(self, doc, domain, scope='user'):
        return next(g for g in doc['preferences'] if g['domain'] == domain and g['scope'] == scope)

    def test_full_shortcut_records_survive_including_disabled_missing_fields_and_odd_types(self):
        backend = MemoryBackend({(HOTKEYS_DOMAIN, 'user'): {'AppleSymbolicHotKeys': HOTKEYS}})
        doc, text, _ = self.capture(backend)
        captured = self.by_group(doc, HOTKEYS_DOMAIN)['keys']['AppleSymbolicHotKeys']
        self.assertTrue(mp.strict_eq(HOTKEYS, captured))
        self.assertIs(captured['10']['enabled'], False)
        self.assertNotIn('value', captured['16'])
        self.assertEqual('SAE1.0', captured['176']['value']['type'])
        self.assertEqual([32, 49, 1048576], captured['64']['value']['parameters'])
        # One record per line, numeric order, and the file parses back to the same data.
        ids = re.findall(r'^\s+"(\d+)": \{"enabled"', text, re.M)
        self.assertEqual(['9', '10', '16', '34', '64', '100', '176'], ids)
        self.assertTrue(mp.documents_equal(doc, mp.parse_document(text, 'profile', 'x')))

    def test_absent_keys_are_recorded_as_absent_never_invented(self):
        backend = MemoryBackend({('com.apple.dock', 'user'): {'autohide': False, 'largesize': 0, 'orientation': 'right'}})
        doc, _, _ = self.capture(backend)
        dock = self.by_group(doc, 'com.apple.dock')
        self.assertIs(dock['keys']['autohide'], False)      # false is a value
        self.assertEqual(0, dock['keys']['largesize'])       # zero is a value
        self.assertIn('show-recents', dock['absent'])         # unset is not
        self.assertNotIn('show-recents', dock['keys'])
        self.assertNotIn('autohide', dock['absent'])
        self.assertEqual(set(), set(dock['keys']) & set(dock['absent']))

    def test_only_allowlisted_keys_are_captured(self):
        backend = MemoryBackend({
            ('com.apple.dock', 'user'): {'orientation': 'left', 'persistent-apps': [{'GUID': 1}], 'mod-count': 7,
                                         'recent-apps': [{'x': 1}]},
            ('com.apple.finder', 'user'): {'ShowPathbar': True, 'FXConnectToLastURL': 'afp://10.0.0.1',
                                           'GoToField': '/Users/someone/private', 'FXRecentFolders': [{'name': 'x'}]},
            (mp.GLOBAL, 'user'): {'AppleLanguages': ['en'], 'NSUserDictionaryReplacementItems': [{'with': 'me@example.com'}],
                                  'com.apple.keyboard.fnState': True},
            ('com.example.unlisted', 'user'): {'secret': 'x'},
        })
        _, text, _ = self.capture(backend)
        for leaked in ('persistent-apps', 'mod-count', 'recent-apps', 'FXConnectToLastURL', 'GoToField',
                       'FXRecentFolders', 'AppleLanguages', 'NSUserDictionaryReplacementItems', 'me@example.com',
                       'afp://', '/Users/', 'com.example.unlisted'):
            self.assertNotIn(leaked, text)
        self.assertIn('"com.apple.keyboard.fnState": true', text)

    def test_custom_finder_folder_is_skipped_with_a_warning(self):
        home = MemoryBackend({('com.apple.finder', 'user'): {'NewWindowTarget': 'PfHm'}})
        doc, _, _ = self.capture(home)
        self.assertEqual('PfHm', self.by_group(doc, 'com.apple.finder')['keys']['NewWindowTarget'])
        custom = MemoryBackend({('com.apple.finder', 'user'): {'NewWindowTarget': 'PfLo', 'NewWindowTargetPath': 'file:///Users/x/'}})
        doc, text, warnings = self.capture(custom)
        finder = self.by_group(doc, 'com.apple.finder')
        self.assertNotIn('NewWindowTarget', finder['keys'])
        self.assertNotIn('NewWindowTarget', finder['absent'])   # skipped, not "unset"
        self.assertIn('machine-specific', warnings)
        self.assertNotIn('file:///', text)

    def test_current_host_values_are_kept_apart_from_user_values(self):
        backend = MemoryBackend({
            (mp.GLOBAL, 'currentHost'): {'com.apple.mouse.tapBehavior': 1, 'com.apple.trackpad.version': 5,
                                         'NSStatusItem Preferred Position X': 10.0},
            (mp.GLOBAL, 'user'): {'com.apple.trackpad.scaling': 1.5},
        })
        doc, text, _ = self.capture(backend)
        host = self.by_group(doc, mp.GLOBAL, 'currentHost')
        user = self.by_group(doc, mp.GLOBAL, 'user')
        self.assertEqual(1, host['keys']['com.apple.mouse.tapBehavior'])
        self.assertNotIn('com.apple.mouse.tapBehavior', user['keys'])
        self.assertNotIn('com.apple.trackpad.scaling', host['keys'])
        self.assertNotIn('com.apple.trackpad.version', text)     # not allowlisted
        self.assertNotIn('NSStatusItem', text)
        self.assertNotIn('ByHost', text)

    def test_key_equivalent_overrides_are_discovered_in_app_domains(self):
        backend = MemoryBackend({
            ('com.example.Editor', 'user'): {'NSUserKeyEquivalents': {'Merge All Windows': '@$m', 'Zoom': '^z'}, 'other': 1},
            ('com.example.Plain', 'user'): {'other': 2},
            (mp.GLOBAL, 'user'): {'NSUserKeyEquivalents': {'Save as PDF…': '@$p'}},
            ('com.example.Broken', 'user'): {'NSUserKeyEquivalents': 'not a dict'},
            ('com.example.Dash', 'user'): {'NSUserKeyEquivalents': {'-Sneaky': '@x', 'Fine': '@y'}},
        })
        doc, text, warnings = self.capture(backend)
        editor = self.by_group(doc, 'com.example.Editor')
        self.assertEqual({'Merge All Windows': '@$m', 'Zoom': '^z'}, editor['keys']['NSUserKeyEquivalents'])
        self.assertNotIn('other', editor['keys'])
        self.assertEqual({'Save as PDF…': '@$p'}, self.by_group(doc, mp.GLOBAL)['keys']['NSUserKeyEquivalents'])
        self.assertFalse([g for g in doc['preferences'] if g['domain'] == 'com.example.Plain'])
        self.assertFalse([g for g in doc['preferences'] if g['domain'] == 'com.example.Broken'])
        self.assertEqual({'Fine': '@y'}, self.by_group(doc, 'com.example.Dash')['keys']['NSUserKeyEquivalents'])
        self.assertIn('not a string dictionary', warnings)
        self.assertIn('would be read as a defaults option', warnings)
        self.assertNotIn('Sneaky', text)

    def test_no_overrides_is_reported_and_not_invented(self):
        doc, _, _ = self.capture(MemoryBackend({('com.example.Plain', 'user'): {'other': 2}}))
        glob = self.by_group(doc, mp.GLOBAL)
        self.assertIn('NSUserKeyEquivalents', glob['absent'])
        self.assertTrue(any('no overrides found' in line for line in mp.summarize_capture(doc)))

    def test_services_are_captured_whole(self):
        services = {
            'com.example - Do It - doIt': {'enabled_context_menu': False, 'enabled_services_menu': False,
                                           'presentation_modes': {'ContextMenu': False, 'ServicesMenu': False}},
            'com.example - Keys - keys': {'key_equivalent': ''},
        }
        doc, _, _ = self.capture(MemoryBackend({('pbs', 'user'): {'NSServicesStatus': services, 'FinderActive': {'x': True}}}))
        pbs = self.by_group(doc, 'pbs')
        self.assertTrue(mp.strict_eq(services, pbs['keys']['NSServicesStatus']))
        self.assertNotIn('FinderActive', pbs['keys'])

    def test_capture_is_deterministic_regardless_of_backend_ordering(self):
        def build(seed):
            rng = random.Random(seed)

            def shuffled(mapping):
                items = list(mapping.items())
                rng.shuffle(items)
                return dict(items)

            data = {
                (HOTKEYS_DOMAIN, 'user'): {'AppleSymbolicHotKeys': shuffled(HOTKEYS)},
                ('com.apple.dock', 'user'): shuffled({'autohide': True, 'tilesize': 64.0, 'orientation': 'right'}),
                (mp.GLOBAL, 'currentHost'): {'com.apple.mouse.tapBehavior': 1},
                (mp.GLOBAL, 'user'): {'NSUserKeyEquivalents': shuffled({'Save': '@s', 'Open': '@o', 'Quit': '@q'})},
            }
            for name in ('A', 'B', 'C', 'D', 'E'):
                data[('com.example.' + name, 'user')] = {
                    'NSUserKeyEquivalents': shuffled({'One': '@1', 'Two': '@2', 'Three': '@3', '10': '@t'})}
            return MemoryBackend(data, domain_order=lambda names: rng.sample(names, len(names)))

        texts = {self.capture(build(seed))[1] for seed in range(40)}
        self.assertEqual(1, len(texts), 'capture output depends on backend ordering')
        text = texts.pop()
        positions = [text.index('"com.example.%s"' % n) for n in 'ABCDE']
        self.assertEqual(sorted(positions), positions)
        self.assertLess(text.index('"10": "@t"'), text.index('"One"'))     # numeric-looking names first, then alphabetical
        self.assertLess(text.index('"One"'), text.index('"Three"'))

    def test_profile_carries_no_time_host_or_path(self):
        text = self.capture(MemoryBackend({(HOTKEYS_DOMAIN, 'user'): {'AppleSymbolicHotKeys': HOTKEYS}}))[1]
        for needle in (str(datetime.date.today()), os.path.expanduser('~'), 'localhost', '.local', 'ByHost', 'created'):
            self.assertNotIn(needle, text)
        self.assertEqual({'schema', 'description', 'preferences'}, set(json.loads(text)))

    def test_capture_through_the_cli_writes_only_when_asked_and_only_when_changed(self):
        sb = Sandbox(self)
        sb.seed(HOTKEYS_DOMAIN, {'AppleSymbolicHotKeys': HOTKEYS})
        sb.seed('com.apple.dock', {'autohide': False})
        before = sb.digest()
        # --stdout prints and touches nothing.
        proc = sb.run('capture', '--stdout')
        self.assertEqual(0, proc.returncode, proc.stderr)
        self.assertFalse(os.path.exists(sb.profile))
        self.assertEqual(json.loads(proc.stdout)['schema'], 1)
        # Explicit capture writes the profile...
        proc = sb.run('capture', '--profile', sb.profile)
        self.assertEqual(0, proc.returncode, proc.stderr)
        first = read_bytes(sb.profile)
        self.assertIn('AppleSymbolicHotKeys: 7 records (3 enabled, 4 disabled)', proc.stderr)
        # ...twice gives the same bytes and reports "unchanged"; it never writes preferences.
        proc = sb.run('capture', '--profile', sb.profile)
        self.assertEqual(first, read_bytes(sb.profile))
        self.assertIn('unchanged', proc.stderr)
        self.assertEqual(before, sb.digest())
        self.assertEqual([], sb.writes())


# --- validation -------------------------------------------------------------


class ProfileValidationTests(unittest.TestCase):
    def messages(self, text, kind='profile'):
        with self.assertRaises(mp.ProfileError) as ctx:
            mp.parse_document(text, kind, 'p.json')
        return '\n'.join(ctx.exception.messages)

    def good(self, **overrides):
        doc = {'schema': 1, 'description': 'd', 'preferences': [
            {'domain': 'com.apple.dock', 'scope': 'user', 'keys': {'autohide': True}, 'absent': []}]}
        doc.update(overrides)
        return json.dumps(doc)

    def test_a_good_profile_parses(self):
        self.assertEqual(1, len(mp.parse_document(self.good(), 'profile', 'p.json')['preferences']))

    def test_rejects_keys_outside_the_allowlist_naming_the_key(self):
        text = json.dumps({'schema': 1, 'preferences': [
            {'domain': 'com.apple.dock', 'scope': 'user', 'keys': {'persistent-apps': []}, 'absent': ['mod-count']}]})
        message = self.messages(text)
        self.assertIn("'persistent-apps' is not in the allowlist", message)
        self.assertIn("absent key 'mod-count' is not in the allowlist", message)

    def test_rejects_path_option_and_unknown_domains(self):
        for domain in ('/tmp/x.plist', '-g', '../x', 'a b', ''):
            text = json.dumps({'schema': 1, 'preferences': [
                {'domain': domain, 'scope': 'user', 'keys': {}, 'absent': []}]})
            self.assertIn('invalid domain', self.messages(text), domain)
        self.assertIn('not in the allowlist', self.messages(json.dumps({'schema': 1, 'preferences': [
            {'domain': 'com.example.other', 'scope': 'user', 'keys': {'anything': 1}, 'absent': []}]})))

    def test_rejects_bad_structure_with_locations(self):
        self.assertIn('not valid JSON', self.messages('{nope'))
        self.assertIn('duplicate JSON key', self.messages('{"schema": 1, "schema": 1, "preferences": []}'))
        self.assertIn('NaN is not valid JSON', self.messages('{"schema": 1, "preferences": [], "x": NaN}'))
        self.assertIn('schema', self.messages(self.good(schema=2)))
        self.assertIn('schema', self.messages(self.good(schema=True)))
        self.assertIn('unknown top-level field', self.messages(self.good(extra=1)))
        self.assertIn('scope must be', self.messages(json.dumps({'schema': 1, 'preferences': [
            {'domain': 'com.apple.dock', 'scope': 'host', 'keys': {}, 'absent': []}]})))
        self.assertIn('listed more than once', self.messages(json.dumps({'schema': 1, 'preferences': [
            {'domain': 'com.apple.dock', 'scope': 'user', 'keys': {}, 'absent': []},
            {'domain': 'com.apple.dock', 'scope': 'user', 'keys': {}, 'absent': []}]})))
        self.assertIn('both present and absent', self.messages(json.dumps({'schema': 1, 'preferences': [
            {'domain': 'com.apple.dock', 'scope': 'user', 'keys': {'autohide': True}, 'absent': ['autohide']}]})))
        self.assertIn('null is not a plist type', self.messages(json.dumps({'schema': 1, 'preferences': [
            {'domain': 'com.apple.dock', 'scope': 'user', 'keys': {'autohide': None}, 'absent': []}]})))

    def test_rejects_malformed_shortcut_records(self):
        def hk(records):
            return json.dumps({'schema': 1, 'preferences': [
                {'domain': HOTKEYS_DOMAIN, 'scope': 'user', 'keys': {'AppleSymbolicHotKeys': records}, 'absent': []}]})
        self.assertIn('shortcut IDs are decimal', self.messages(hk({'x': {'enabled': True}})))
        self.assertIn('"enabled" must be a boolean', self.messages(hk({'1': {'enabled': 1}})))
        self.assertIn('must be a dictionary', self.messages(hk({'1': 'on'})))
        self.assertIn('must be a dictionary', self.messages(hk([1])))

    def test_rejects_bad_tagged_values(self):
        def dock(value):
            return json.dumps({'schema': 1, 'preferences': [
                {'domain': 'com.apple.dock', 'scope': 'user', 'keys': {'orientation': value}, 'absent': []}]})
        self.assertIn('bad $data', self.messages(dock({'$data': '***'})))
        self.assertIn('bad $date', self.messages(dock({'$date': 'yesterday'})))

    def test_a_backup_must_say_it_is_one(self):
        self.assertIn('not a restore backup', self.messages(self.good(), kind='backup'))


# --- preview ----------------------------------------------------------------


class PreviewTests(unittest.TestCase):
    def setUp(self):
        self.sb = Sandbox(self)
        self.sb.seed(HOTKEYS_DOMAIN, {'AppleSymbolicHotKeys': {
            '34': {'enabled': True, 'value': {'parameters': [65535, 1, 0], 'type': 'standard'}},   # differs
            '999': {'enabled': True},                                                              # destination only
        }})
        self.sb.seed('com.apple.dock', {'orientation': 'bottom', 'show-recents': True})
        self.sb.write_profile(
            group(HOTKEYS_DOMAIN, 'user', {'AppleSymbolicHotKeys': {'34': HOTKEYS['34'], '64': HOTKEYS['64']}}),
            group('com.apple.dock', 'user', {'orientation': 'right'}, absent=['show-recents']),
        )

    def test_diff_reports_add_change_kept_and_left_alone_without_writing(self):
        before = self.sb.digest()
        proc = self.sb.run('diff', '--profile', self.sb.profile)
        self.assertEqual(1, proc.returncode, proc.stderr)          # differences pending
        out = proc.stdout
        self.assertIn('com.apple.symbolichotkeys [user] AppleSymbolicHotKeys', out)
        self.assertRegex(out, r'~ 34: .*"parameters": \[65535, 1, 0\].* -> .*"parameters": \[65535, 232, 131072\]')
        self.assertIn('+ 64:', out)
        self.assertIn('~ (whole key): "bottom" -> "right"', out)
        self.assertIn('show-recents: unset in the profile but set here; left unchanged', out)
        self.assertIn('1 destination-only entries kept', out)
        self.assertEqual(before, self.sb.digest())
        self.assertEqual([], self.sb.writes())
        self.assertEqual([], self.sb.backup_dirs())

    def test_restore_dry_run_writes_nothing_and_makes_no_backup(self):
        before = self.sb.digest()
        proc = self.sb.run('restore', '--profile', self.sb.profile, '--dry-run')
        self.assertEqual(0, proc.returncode, proc.stderr)
        self.assertIn('dry run: nothing was written', proc.stderr)
        self.assertEqual(before, self.sb.digest())
        self.assertEqual([], self.sb.writes())
        self.assertEqual([], self.sb.backup_dirs())

    def test_diff_exit_status_is_zero_once_in_sync(self):
        self.assertEqual(0, self.sb.run('restore', '--profile', self.sb.profile, '--yes').returncode)
        proc = self.sb.run('diff', '--profile', self.sb.profile)
        self.assertEqual(0, proc.returncode, proc.stdout + proc.stderr)
        self.assertIn('0 to add, 0 to change', proc.stdout)

    def test_the_preview_backend_refuses_every_write_method(self):
        backend = mp.ReadOnlyBackend(MemoryBackend())
        for call in (lambda: backend.set_key('d', 'user', 'k', 1), lambda: backend.set_entry('d', 'user', 'k', 'e', 1),
                     lambda: backend.delete_key('d', 'user', 'k')):
            with self.assertRaises(AssertionError):
                call()

    def test_diff_all_lists_identical_entries_and_only_filters_areas(self):
        self.assertEqual(0, self.sb.run('restore', '--profile', self.sb.profile, '--yes').returncode)
        proc = self.sb.run('diff', '--profile', self.sb.profile, '--all')
        self.assertIn('= com.apple.symbolichotkeys [user] AppleSymbolicHotKeys / 34', proc.stdout)
        proc = self.sb.run('diff', '--profile', self.sb.profile, '--only', 'dock')
        self.assertNotIn('symbolichotkeys', proc.stdout)
        proc = self.sb.run('diff', '--profile', self.sb.profile, '--only', 'nonsense')
        self.assertEqual(2, proc.returncode)
        self.assertIn('unknown area', proc.stderr)


# --- restore ----------------------------------------------------------------


class RestoreTests(unittest.TestCase):
    def setUp(self):
        self.sb = Sandbox(self)

    def restore(self, *extra, **env):
        return self.sb.run('restore', '--profile', self.sb.profile, '--yes', *extra, **env)

    def test_unrelated_preferences_and_shortcut_ids_are_preserved(self):
        sb = self.sb
        sb.seed(HOTKEYS_DOMAIN, {'AppleSymbolicHotKeys': {
            '999': {'enabled': True, 'value': {'parameters': [1, 2, 3], 'type': 'standard'}},
            '34': {'enabled': True, 'value': {'parameters': [65535, 1, 0], 'type': 'standard'}}}, 'UnrelatedKey': 'keep'})
        sb.seed('com.apple.dock', {'persistent-apps': [{'GUID': 5}], 'orientation': 'bottom', 'mod-count': 3})
        sb.seed('com.example.unrelated', {'k': 'v'})
        sb.seed(mp.GLOBAL, {'AppleLanguages': ['en'], 'com.apple.keyboard.fnState': False})
        sb.write_profile(
            group(HOTKEYS_DOMAIN, 'user', {'AppleSymbolicHotKeys': {'34': HOTKEYS['34'], '64': HOTKEYS['64']}}),
            group('com.apple.dock', 'user', {'orientation': 'right'}),
            group(mp.GLOBAL, 'user', {'com.apple.keyboard.fnState': True}),
        )
        proc = self.restore()
        self.assertEqual(0, proc.returncode, proc.stderr)
        hot = sb.read(HOTKEYS_DOMAIN)
        self.assertEqual({'enabled': True, 'value': {'parameters': [1, 2, 3], 'type': 'standard'}},
                         hot['AppleSymbolicHotKeys']['999'])
        self.assertEqual('keep', hot['UnrelatedKey'])
        self.assertTrue(mp.strict_eq(HOTKEYS['34'], hot['AppleSymbolicHotKeys']['34']))
        self.assertTrue(mp.strict_eq(HOTKEYS['64'], hot['AppleSymbolicHotKeys']['64']))
        dock = sb.read('com.apple.dock')
        self.assertEqual({'persistent-apps': [{'GUID': 5}], 'orientation': 'right', 'mod-count': 3}, dock)
        self.assertEqual({'k': 'v'}, sb.read('com.example.unrelated'))
        self.assertEqual({'AppleLanguages': ['en'], 'com.apple.keyboard.fnState': True}, sb.read(mp.GLOBAL))
        # No wholesale replacement: only allowlisted domains were written, one key or entry at a time.
        written = {c['argv'][1] for c in sb.writes()}
        self.assertEqual({HOTKEYS_DOMAIN, 'com.apple.dock', mp.GLOBAL}, written)
        for call in sb.calls():
            self.assertNotIn(call['argv'][0], ('import', 'delete-all'))
            if len(call['argv']) > 1:
                self.assertRegex(call['argv'][1], mp.DOMAIN_RE)

    def test_disabled_records_missing_fields_and_types_land_exactly(self):
        sb = self.sb
        sb.seed(HOTKEYS_DOMAIN, {'AppleSymbolicHotKeys': {
            '10': {'enabled': True, 'value': {'parameters': [1, 1, 1], 'type': 'standard'}},   # will be disabled
            '16': {'enabled': True, 'value': {'parameters': [9, 9, 9], 'type': 'standard'}},   # will lose "value"
        }})
        keys = {'autohide': False, 'largesize': 0, 'tilesize': 64.0, 'mineffect': '1', 'no-bouncing': True}
        sb.write_profile(
            group(HOTKEYS_DOMAIN, 'user', {'AppleSymbolicHotKeys': HOTKEYS}),
            group('com.apple.dock', 'user', keys),
            group('com.apple.HIToolbox', 'user', {'AppleEnabledInputSources': [
                {'InputSourceKind': 'Keyboard Layout', 'KeyboardLayout ID': 0, 'KeyboardLayout Name': 'U.S.'},
                {'Bundle ID': 'com.apple.CharacterPaletteIM', 'InputSourceKind': 'Non Keyboard Input Method'}]}),
        )
        proc = self.restore()
        self.assertEqual(0, proc.returncode, proc.stderr)
        restored = sb.read(HOTKEYS_DOMAIN)['AppleSymbolicHotKeys']
        self.assertTrue(mp.strict_eq(HOTKEYS, restored))
        self.assertIs(restored['10']['enabled'], False)
        self.assertEqual({'enabled': False}, restored['16'])
        self.assertTrue(mp.strict_eq(keys, sb.read('com.apple.dock')))
        self.assertEqual('Keyboard Layout', sb.read('com.apple.HIToolbox')['AppleEnabledInputSources'][0]['InputSourceKind'])
        argvs = [c['argv'] for c in sb.writes()]
        self.assertIn(['write', 'com.apple.dock', 'autohide', '-bool', 'false'], argvs)
        self.assertIn(['write', 'com.apple.dock', 'largesize', '-int', '0'], argvs)
        self.assertIn(['write', 'com.apple.dock', 'tilesize', '-float', '64.0'], argvs)
        self.assertIn(['write', 'com.apple.dock', 'mineffect', '-string', '1'], argvs)
        entry = next(a for a in argvs if a[:5] == ['write', HOTKEYS_DOMAIN, 'AppleSymbolicHotKeys', '-dict-add', '176'])
        self.assertTrue(entry[5].startswith('<dict>') and 'SAE1.0' in entry[5])

    def test_current_host_settings_are_written_to_the_destination_host_scope(self):
        sb = self.sb
        sb.seed(mp.GLOBAL, {'com.apple.trackpad.scaling': 0.5, 'unrelated': 1})
        sb.seed(mp.GLOBAL, {'com.apple.mouse.tapBehavior': 0, 'other-host-key': 'keep'}, scope='currentHost')
        sb.write_profile(
            group(mp.GLOBAL, 'currentHost', {'com.apple.mouse.tapBehavior': 1, 'com.apple.trackpad.scrollBehavior': 2}),
            group(mp.GLOBAL, 'user', {'com.apple.trackpad.scaling': 1.5}),
        )
        proc = self.restore()
        self.assertEqual(0, proc.returncode, proc.stderr)
        self.assertEqual({'com.apple.mouse.tapBehavior': 1, 'com.apple.trackpad.scrollBehavior': 2, 'other-host-key': 'keep'},
                         sb.read(mp.GLOBAL, 'currentHost'))
        self.assertEqual({'com.apple.trackpad.scaling': 1.5, 'unrelated': 1}, sb.read(mp.GLOBAL, 'user'))
        host_writes = [c for c in sb.writes() if c['scope'] == 'currentHost']
        self.assertEqual(2, len(host_writes))
        self.assertEqual(1, len([c for c in sb.writes() if c['scope'] == 'user']))

    def test_repeat_application_is_a_no_op(self):
        sb = self.sb
        sb.seed('com.apple.dock', {'orientation': 'bottom'})
        sb.write_profile(
            group(HOTKEYS_DOMAIN, 'user', {'AppleSymbolicHotKeys': HOTKEYS}),
            group('com.apple.dock', 'user', {'orientation': 'right', 'tilesize': 64.0}),
            group(mp.GLOBAL, 'currentHost', {'com.apple.mouse.tapBehavior': 1}),
        )
        self.assertEqual(0, self.restore().returncode)
        state, writes, backups = sb.everything(), len(sb.writes()), sb.backup_dirs()
        self.assertEqual(1, len(backups))
        proc = self.restore()
        self.assertEqual(0, proc.returncode, proc.stderr)
        self.assertIn('already in sync', proc.stderr)
        self.assertEqual(state, sb.everything())
        self.assertEqual(writes, len(sb.writes()))          # no further writes
        self.assertEqual(backups, sb.backup_dirs())          # and no further backup

    def test_absent_keys_are_never_written_or_deleted(self):
        sb = self.sb
        sb.seed('com.apple.dock', {'show-recents': True, 'orientation': 'bottom'})
        sb.write_profile(group('com.apple.dock', 'user', {'orientation': 'right'}, absent=['show-recents', 'autohide']))
        self.assertEqual(0, self.restore().returncode)
        self.assertEqual({'show-recents': True, 'orientation': 'right'}, sb.read('com.apple.dock'))
        self.assertFalse([c for c in sb.writes() if c['argv'][0] == 'delete'])
        self.assertFalse([c for c in sb.writes() if 'autohide' in c['argv']])

    def test_restore_leaves_the_profile_and_repository_untouched(self):
        sb = self.sb
        sb.write_profile(group('com.apple.dock', 'user', {'orientation': 'right'}))
        before = read_bytes(sb.profile)
        self.assertEqual(0, self.restore().returncode)
        self.assertEqual(before, read_bytes(sb.profile))

    def test_only_limits_the_areas_written(self):
        sb = self.sb
        sb.write_profile(
            group(HOTKEYS_DOMAIN, 'user', {'AppleSymbolicHotKeys': {'34': HOTKEYS['34']}}),
            group('com.apple.dock', 'user', {'orientation': 'right'}),
        )
        self.assertEqual(0, self.restore('--only', 'dock').returncode)
        self.assertEqual({}, sb.read(HOTKEYS_DOMAIN))
        self.assertEqual({'orientation': 'right'}, sb.read('com.apple.dock'))

    def test_refuses_to_write_without_confirmation_and_without_a_terminal(self):
        sb = self.sb
        sb.write_profile(group('com.apple.dock', 'user', {'orientation': 'right'}))
        proc = sb.run('restore', '--profile', sb.profile)
        self.assertEqual(2, proc.returncode)
        self.assertIn('pass --yes', proc.stderr)
        self.assertEqual([], sb.writes())

    def test_key_equivalent_overrides_restore_per_app_without_touching_other_menu_items(self):
        sb = self.sb
        sb.seed('com.example.Editor', {'NSUserKeyEquivalents': {'Existing': '@e'}, 'unrelated': True})
        sb.write_profile(group('com.example.Editor', 'user', {'NSUserKeyEquivalents': {'Merge All Windows': '@$m'}}))
        self.assertEqual(0, self.restore().returncode)
        self.assertEqual({'NSUserKeyEquivalents': {'Existing': '@e', 'Merge All Windows': '@$m'}, 'unrelated': True},
                         sb.read('com.example.Editor'))

    def test_services_choices_restore_entry_by_entry(self):
        sb = self.sb
        sb.seed('pbs', {'NSServicesStatus': {'com.other - Keep - keep': {'key_equivalent': '@k'}}, 'FinderActive': {'a': True}})
        service = {'enabled_context_menu': False, 'enabled_services_menu': False,
                   'presentation_modes': {'ContextMenu': False, 'ServicesMenu': False}}
        sb.write_profile(group('pbs', 'user', {'NSServicesStatus': {'com.example - Do %s - doIt': service}}))
        self.assertEqual(0, self.restore().returncode)
        pbs = sb.read('pbs')
        self.assertTrue(mp.strict_eq(service, pbs['NSServicesStatus']['com.example - Do %s - doIt']))
        self.assertEqual({'key_equivalent': '@k'}, pbs['NSServicesStatus']['com.other - Keep - keep'])
        self.assertEqual({'a': True}, pbs['FinderActive'])

    def test_a_non_dictionary_destination_value_is_replaced_for_merge_keys(self):
        sb = self.sb
        sb.seed(HOTKEYS_DOMAIN, {'AppleSymbolicHotKeys': 'corrupt'})
        sb.write_profile(group(HOTKEYS_DOMAIN, 'user', {'AppleSymbolicHotKeys': {'34': HOTKEYS['34']}}))
        self.assertEqual(0, self.restore().returncode)
        self.assertEqual({'34': HOTKEYS['34']}, sb.read(HOTKEYS_DOMAIN)['AppleSymbolicHotKeys'])


# --- backup and rollback ----------------------------------------------------


class BackupRollbackTests(unittest.TestCase):
    def setUp(self):
        self.sb = Sandbox(self)
        sb = self.sb
        sb.seed(HOTKEYS_DOMAIN, {'AppleSymbolicHotKeys': {
            '34': {'enabled': True, 'value': {'parameters': [65535, 1, 0], 'type': 'standard'}},
            '999': {'enabled': True}}})
        sb.seed('com.apple.dock', {'orientation': 'bottom', 'persistent-apps': [{'GUID': 5}]})
        sb.seed(mp.GLOBAL, {'unrelated': 1}, scope='currentHost')
        sb.write_profile(
            group(HOTKEYS_DOMAIN, 'user', {'AppleSymbolicHotKeys': {'34': HOTKEYS['34'], '64': HOTKEYS['64']}}),
            group('com.apple.dock', 'user', {'orientation': 'right', 'tilesize': 64.0}),
            group(mp.GLOBAL, 'currentHost', {'com.apple.mouse.tapBehavior': 1}),
        )
        self.before = sb.everything()

    def test_backup_lands_outside_the_repository_with_private_permissions(self):
        proc = self.sb.run('restore', '--profile', self.sb.profile, '--yes')
        self.assertEqual(0, proc.returncode, proc.stderr)
        (name,) = self.sb.backup_dirs()
        directory = os.path.join(self.sb.backups, name)
        self.assertFalse(directory.startswith(REPO))
        self.assertEqual(0o700, stat.S_IMODE(os.stat(directory).st_mode))
        path = os.path.join(directory, 'before.json')
        self.assertEqual(0o600, stat.S_IMODE(os.stat(path).st_mode))
        self.assertIn(directory, proc.stderr)
        self.assertIn('rollback ' + directory, proc.stderr)
        backup = mp.load_document(path, 'backup')
        self.assertEqual('backup', backup['kind'])
        self.assertEqual(hashlib.sha256(read_bytes(self.sb.profile)).hexdigest(), backup['source_profile_sha256'])
        groups = {(g['domain'], g['scope']): g for g in backup['preferences']}
        # Prior values are saved whole; keys that did not exist are recorded as absent.
        self.assertEqual(self.before[('user', HOTKEYS_DOMAIN)]['AppleSymbolicHotKeys'],
                         groups[(HOTKEYS_DOMAIN, 'user')]['keys']['AppleSymbolicHotKeys'])
        self.assertEqual({'orientation': 'bottom'}, groups[('com.apple.dock', 'user')]['keys'])
        self.assertEqual(['tilesize'], groups[('com.apple.dock', 'user')]['absent'])
        self.assertEqual(['com.apple.mouse.tapBehavior'], groups[(mp.GLOBAL, 'currentHost')]['absent'])
        self.assertNotIn('persistent-apps', read_bytes(path).decode('utf-8'))   # only affected keys are backed up

    def test_rollback_restores_prior_state_including_deleting_new_keys(self):
        self.assertEqual(0, self.sb.run('restore', '--profile', self.sb.profile, '--yes').returncode)
        self.assertNotEqual(self.before, self.sb.everything())
        proc = self.sb.run('rollback', 'latest', '--yes')
        self.assertEqual(0, proc.returncode, proc.stderr)
        self.assertEqual(self.before, self.sb.everything())
        self.assertEqual(2, len(self.sb.backup_dirs()))        # rollback backed up before it wrote

    def test_rollback_accepts_a_directory_and_dry_run_writes_nothing(self):
        self.assertEqual(0, self.sb.run('restore', '--profile', self.sb.profile, '--yes').returncode)
        (name,) = self.sb.backup_dirs()
        after_restore = self.sb.everything()
        proc = self.sb.run('rollback', os.path.join(self.sb.backups, name), '--dry-run')
        self.assertEqual(0, proc.returncode, proc.stderr)
        self.assertEqual(after_restore, self.sb.everything())
        self.assertEqual([name], self.sb.backup_dirs())
        self.assertEqual(0, self.sb.run('rollback', os.path.join(self.sb.backups, name), '--yes').returncode)
        self.assertEqual(self.before, self.sb.everything())

    def test_rollback_reports_missing_and_wrong_backups(self):
        proc = self.sb.run('rollback', 'latest', '--yes')
        self.assertEqual(2, proc.returncode)
        self.assertIn('no backups found', proc.stderr)
        proc = self.sb.run('rollback', os.path.join(self.sb.dir, 'nope'), '--yes')
        self.assertEqual(2, proc.returncode)
        proc = self.sb.run('rollback', self.sb.profile, '--yes')       # a profile is not a backup
        self.assertEqual(2, proc.returncode)
        self.assertIn('not a restore backup', proc.stderr)
        self.assertEqual(self.before, self.sb.everything())


# --- failure reporting ------------------------------------------------------


class FailureTests(unittest.TestCase):
    def setUp(self):
        self.sb = Sandbox(self)

    def test_a_failed_write_is_reported_with_its_location_and_the_rest_still_applies(self):
        sb = self.sb
        sb.write_profile(
            group('com.apple.AppleMultitouchTrackpad', 'user', {'Clicking': True}),
            group('com.apple.dock', 'user', {'orientation': 'right'}),
        )
        proc = sb.run('restore', '--profile', sb.profile, '--yes', FAKE_DEFAULTS_FAIL_ON='Clicking')
        self.assertEqual(1, proc.returncode)
        self.assertIn('com.apple.AppleMultitouchTrackpad [user] Clicking', proc.stderr)
        self.assertIn('injected failure', proc.stderr)
        self.assertIn('1 problem(s); 1 change(s) verified', proc.stderr)
        self.assertIn('rollback', proc.stderr)
        self.assertEqual({'orientation': 'right'}, sb.read('com.apple.dock'))
        self.assertEqual({}, sb.read('com.apple.AppleMultitouchTrackpad'))
        self.assertEqual(1, len(sb.backup_dirs()))

    def test_a_write_that_does_not_land_as_intended_is_caught_reverted_and_stops_the_run(self):
        sb = self.sb
        previous = [{'InputSourceKind': 'Keyboard Layout', 'KeyboardLayout ID': 252, 'KeyboardLayout Name': 'ABC'}]
        sb.seed('com.apple.HIToolbox', {'AppleEnabledInputSources': previous})
        sb.write_profile(
            group('com.apple.HIToolbox', 'user', {'AppleEnabledInputSources': [
                {'InputSourceKind': 'Keyboard Layout', 'KeyboardLayout ID': 0, 'KeyboardLayout Name': 'U.S.'}]}),
            group('com.apple.dock', 'user', {'orientation': 'right'}),
        )
        proc = sb.run('restore', '--profile', sb.profile, '--yes', FAKE_DEFAULTS_MISPARSE='AppleEnabledInputSources',
                       FAKE_DEFAULTS_MISPARSE_LIMIT='1')
        self.assertEqual(1, proc.returncode)
        self.assertIn('verification failed for com.apple.HIToolbox [user] AppleEnabledInputSources', proc.stderr)
        self.assertIn('read back', proc.stderr)
        self.assertIn('reverted com.apple.HIToolbox', proc.stderr)
        self.assertIn('stopped early', proc.stderr)
        self.assertEqual(previous, sb.read('com.apple.HIToolbox')['AppleEnabledInputSources'])
        self.assertEqual({}, sb.read('com.apple.dock'))        # later groups were not attempted

    def test_a_shortcut_entry_that_does_not_land_reverts_the_whole_key(self):
        sb = self.sb
        original = {'999': {'enabled': True}}
        sb.seed(HOTKEYS_DOMAIN, {'AppleSymbolicHotKeys': dict(original)})
        sb.write_profile(group(HOTKEYS_DOMAIN, 'user', {'AppleSymbolicHotKeys': {'34': HOTKEYS['34'], '64': HOTKEYS['64']}}))
        proc = sb.run('restore', '--profile', sb.profile, '--yes', FAKE_DEFAULTS_MISPARSE='AppleSymbolicHotKeys',
                       FAKE_DEFAULTS_MISPARSE_LIMIT='2')
        self.assertEqual(1, proc.returncode)
        self.assertIn('AppleSymbolicHotKeys / 34: wrote', proc.stderr)
        self.assertEqual(original, sb.read(HOTKEYS_DOMAIN)['AppleSymbolicHotKeys'])

    def test_unreadable_domains_fail_before_anything_is_written(self):
        sb = self.sb
        sb.write_profile(group('com.apple.dock', 'user', {'orientation': 'right'}))
        proc = sb.run('restore', '--profile', sb.profile, '--yes', FAKE_DEFAULTS_EXPORT_FAIL='com.apple.dock')
        self.assertEqual(2, proc.returncode)
        self.assertIn('failed', proc.stderr)
        self.assertEqual([], sb.writes())
        self.assertEqual([], sb.backup_dirs())

    def test_invalid_profiles_are_reported_and_nothing_is_touched(self):
        sb = self.sb
        cases = {
            'not json': '{nope',
            'not allowlisted': json.dumps({'schema': 1, 'preferences': [
                {'domain': 'com.apple.dock', 'scope': 'user', 'keys': {'persistent-apps': []}, 'absent': []}]}),
            'path domain': json.dumps({'schema': 1, 'preferences': [
                {'domain': '/tmp/evil.plist', 'scope': 'user', 'keys': {}, 'absent': []}]}),
        }
        for name, text in cases.items():
            with open(sb.profile, 'w') as handle:
                handle.write(text)
            for command in (['restore', '--yes'], ['diff'], ['validate']):
                proc = sb.run(command[0], '--profile', sb.profile, *command[1:])
                self.assertEqual(2, proc.returncode, '%s / %s' % (name, command))
                self.assertIn('[ERROR]', proc.stderr)
        self.assertEqual([], sb.calls())                      # `defaults` was never even run
        self.assertEqual([], sb.backup_dirs())

    def test_missing_profile_and_non_macos_are_clear_errors(self):
        sb = self.sb
        proc = sb.run('restore', '--profile', os.path.join(sb.dir, 'absent.json'), '--yes')
        self.assertEqual(2, proc.returncode)
        self.assertIn('cannot read', proc.stderr)
        with mock.patch.dict(os.environ):
            os.environ.pop(mp.ENV_DEFAULTS_BIN, None)
            with mock.patch.object(mp.sys, 'platform', 'linux'):
                with self.assertRaises(mp.ToolError):
                    mp.make_backend()


# --- the shipped profile ----------------------------------------------------


@unittest.skipUnless(os.path.exists(SHIPPED_PROFILE), 'no captured profile in the source tree yet')
class ShippedProfileTests(unittest.TestCase):
    def setUp(self):
        with open(SHIPPED_PROFILE, encoding='utf-8') as handle:
            self.text = handle.read()

    def test_it_validates_and_is_in_canonical_form(self):
        doc = mp.parse_document(self.text, 'profile', SHIPPED_PROFILE)
        self.assertEqual(self.text, mp.dump_document(doc))
        self.assertEqual(sorted((g['domain'], g['scope']) for g in doc['preferences']),
                         [(g['domain'], g['scope']) for g in doc['preferences']])

    def test_it_contains_nothing_machine_specific_or_private(self):
        forbidden = {
            'home path': r'/Users/|/home/|/private/|/var/folders',
            'uuid': r'[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}',
            'email': r'[\w.+-]+@[\w-]+\.[\w.-]+',
            'url': r'https?://|file://|afp://|smb://',
            'byhost': r'ByHost',
            'timestamp': r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}',
            'credential word': r'(?i)password|token|secret|apikey|api_key|keychain',
        }
        for label, pattern in forbidden.items():
            self.assertIsNone(re.search(pattern, self.text), label)
        self.assertNotIn(os.environ.get('USER', '\0'), self.text)

    def test_shortcut_records_keep_every_shape_the_mac_uses(self):
        doc = mp.parse_document(self.text, 'profile', SHIPPED_PROFILE)
        hot = next(g for g in doc['preferences'] if g['domain'] == HOTKEYS_DOMAIN)['keys']['AppleSymbolicHotKeys']
        self.assertTrue(all(isinstance(r['enabled'], bool) for r in hot.values()))
        self.assertTrue(any(r['enabled'] is False for r in hot.values()))
        self.assertTrue(any('value' not in r for r in hot.values()))
        self.assertTrue(any(r.get('value', {}).get('type') not in (None, 'standard') for r in hot.values()))


if __name__ == '__main__':
    unittest.main()
