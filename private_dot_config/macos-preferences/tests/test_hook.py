"""Tests for .chezmoiscripts/run_onchange_after_55-macos-preferences.sh.tmpl.

The hook is rendered by the real `chezmoi execute-template` from a small
temporary source directory (a full source-tree walk is unnecessary and fails
on unrelated dangling symlinks), then the rendered script is run under bash
against a sandbox HOME and tests/fake_defaults. Nothing here touches this
Mac's preferences, home directory, or chezmoi state.

    python3 -m unittest discover -s private_dot_config/macos-preferences/tests -v
"""

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True   # never leave __pycache__ in the source tree

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
HOOK_REL = os.path.join('.chezmoiscripts', 'run_onchange_after_55-macos-preferences.sh.tmpl')
# MACOS_PREFERENCES_HOOK lets the mutation check run this suite against a deliberately broken hook.
HOOK_SOURCE = os.environ.get('MACOS_PREFERENCES_HOOK') or os.path.join(REPO, HOOK_REL)
TOOL_REL = os.path.join('dot_local', 'bin', 'executable_macos-preferences')
PROFILE_REL = os.path.join('private_dot_config', 'macos-preferences', 'profile.json')
TEMPLATE_REL = os.path.join('.chezmoitemplates', 'script_darwin_only')
FAKE = os.path.join(HERE, 'fake_defaults')

FIXTURE_PROFILE = {
    'schema': 1,
    'description': 'fixture',
    'preferences': [
        {'domain': 'com.apple.dock', 'scope': 'user', 'keys': {'orientation': 'right', 'autohide': False},
         'absent': ['show-recents']},
        {'domain': 'NSGlobalDomain', 'scope': 'currentHost', 'keys': {'com.apple.mouse.tapBehavior': 1}, 'absent': []},
    ],
}

CHEZMOI = shutil.which('chezmoi')


def read(path):
    with open(path, 'rb') as handle:
        return handle.read()


@unittest.skipUnless(CHEZMOI, 'chezmoi is not installed')
class HookTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.chmod(FAKE, 0o755)
        cls.base = tempfile.mkdtemp(prefix='macos-prefs-hook-', dir=os.environ.get('TMPDIR'))
        cls.src = os.path.join(cls.base, 'src')
        cls.stage(cls.src, HOOK_REL, read(HOOK_SOURCE))
        for rel in (TOOL_REL, TEMPLATE_REL):
            cls.stage(cls.src, rel, read(os.path.join(REPO, rel)))
        cls.stage(cls.src, PROFILE_REL, json.dumps(FIXTURE_PROFILE).encode())
        cls.config = os.path.join(cls.base, 'chezmoi.toml')
        open(cls.config, 'w').close()

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.base, True)

    @staticmethod
    def stage(root, rel, data):
        path = os.path.join(root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'wb') as handle:
            handle.write(data)

    def render(self, os_name='darwin', src=None):
        src = src or self.src
        hook = os.path.join(src, HOOK_REL)
        args = [CHEZMOI, '--source', src, '--config', self.config, '--no-pager', 'execute-template']
        if os_name == 'darwin':
            proc = subprocess.run(args + ['--file', hook], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        else:
            # Same template text, evaluated as if chezmoi were running on another OS.
            wrapped = ('{{- with (dict "chezmoi" (dict "os" "%s" "arch" "amd64" "homeDir" "/nonexistent")) -}}'
                       % os_name + read(hook).decode() + '{{ end }}')
            proc = subprocess.run(args, input=wrapped, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        self.assertEqual(0, proc.returncode, proc.stderr)
        return proc.stdout

    def sandbox(self, install=True, profile=True):
        home = tempfile.mkdtemp(prefix='home-', dir=self.base)
        state = os.path.join(home, 'fake')
        if install:
            self.stage(home, os.path.join('.local', 'bin', 'macos-preferences'), read(os.path.join(REPO, TOOL_REL)))
            os.chmod(os.path.join(home, '.local', 'bin', 'macos-preferences'), 0o755)
        if profile:
            self.stage(home, os.path.join('.config', 'macos-preferences', 'profile.json'), json.dumps(FIXTURE_PROFILE).encode())
        return home, state

    def run_hook(self, script, home, state, path=None, **extra):
        path_dirs = [os.path.dirname(sys.executable), '/usr/bin', '/bin']
        env = {
            'HOME': home, 'PATH': path if path is not None else os.pathsep.join(path_dirs),
            'XDG_STATE_HOME': os.path.join(home, 'state'), 'TMPDIR': home, 'NO_COLOR': '1',
            'PYTHONDONTWRITEBYTECODE': '1', 'MACOS_PREFERENCES_DEFAULTS_BIN': FAKE,
            'MACOS_PREFERENCES_BACKUP_DIR': os.path.join(home, 'backups'), 'FAKE_DEFAULTS_ROOT': state,
        }
        env.update(extra)
        path_to_script = os.path.join(home, 'hook.sh')
        with open(path_to_script, 'w') as handle:
            handle.write(script)
        return subprocess.run(['/bin/bash', path_to_script], env=env, stdin=subprocess.DEVNULL,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)

    def calls(self, state):
        try:
            return [json.loads(line) for line in read(os.path.join(state, 'calls.jsonl')).decode().splitlines()]
        except FileNotFoundError:
            return []

    # -- rendering ---------------------------------------------------------

    def test_hook_name_makes_it_an_after_hook_that_reruns_on_change(self):
        self.assertRegex(os.path.basename(HOOK_REL), r'^run_onchange_after_\d+-.+\.sh\.tmpl$')

    def test_darwin_render_is_valid_shell_and_lints_clean(self):
        script = self.render('darwin')
        self.assertTrue(script.startswith('#!/bin/bash\n'))
        path = os.path.join(self.base, 'darwin.sh')
        with open(path, 'w') as handle:
            handle.write(script)
        self.assertEqual(0, subprocess.run(['bash', '-n', path]).returncode)
        shellcheck = shutil.which('shellcheck')
        if shellcheck:
            proc = subprocess.run([shellcheck, '-s', 'bash', path], stdout=subprocess.PIPE, universal_newlines=True)
            self.assertEqual(0, proc.returncode, proc.stdout)

    def test_hook_hashes_both_the_profile_and_the_restore_implementation(self):
        script = self.render('darwin')
        profile_sha = hashlib.sha256(read(os.path.join(self.src, PROFILE_REL))).hexdigest()
        tool_sha = hashlib.sha256(read(os.path.join(self.src, TOOL_REL))).hexdigest()
        self.assertIn('profile hash:        ' + profile_sha, script)
        self.assertIn('implementation hash: ' + tool_sha, script)
        # Editing either input changes the rendered text, which is what makes run_onchange re-run.
        for rel, edit in ((PROFILE_REL, b'\n'), (TOOL_REL, b'\n# changed\n')):
            other = os.path.join(self.base, 'src-' + hashlib.md5(rel.encode()).hexdigest()[:8])
            for r in (HOOK_REL, TOOL_REL, TEMPLATE_REL, PROFILE_REL):
                self.stage(other, r, read(os.path.join(self.src, r)))
            self.stage(other, rel, read(os.path.join(self.src, rel)) + edit)
            self.assertNotEqual(script, self.render('darwin', src=other), rel)

    def test_hook_only_ever_restores_and_never_captures(self):
        script = self.render('darwin')
        code = [l for l in script.splitlines() if l.strip() and not l.lstrip().startswith('#')]
        invocations = [l for l in code if '"${TOOL}"' in l and not l.lstrip().startswith(('if [', '[ '))]
        self.assertEqual(1, len(invocations), invocations)
        self.assertIn('restore', invocations[0])
        self.assertIn('--yes', invocations[0])
        self.assertFalse([l for l in code if re.search(r'\bcapture\b', l)])
        self.assertFalse([l for l in code if re.search(r'\b(re-add|import|rollback)\b', l)])

    def test_non_darwin_render_exits_before_doing_anything(self):
        script = self.render('linux')
        code = [l.strip() for l in script.splitlines() if l.strip() and not l.lstrip().startswith('#')]
        self.assertEqual('exit 0', code[0])
        home, state = self.sandbox()
        proc = self.run_hook(script, home, state)
        self.assertEqual(0, proc.returncode, proc.stderr)
        self.assertEqual('', proc.stdout + proc.stderr)
        self.assertEqual([], self.calls(state))
        self.assertFalse(os.path.exists(os.path.join(home, 'state')))
        self.assertFalse(os.path.exists(os.path.join(home, 'backups')))

    # -- running the rendered hook ------------------------------------------

    def test_hook_restores_the_profile_then_does_nothing_on_the_next_run(self):
        script = self.render('darwin')
        home, state = self.sandbox()
        profile = os.path.join(home, '.config', 'macos-preferences', 'profile.json')
        before = read(profile)
        proc = self.run_hook(script, home, state)
        self.assertEqual(0, proc.returncode, proc.stdout + proc.stderr)
        self.assertIn('macOS preferences restored', proc.stdout)
        writes = [c for c in self.calls(state) if c['argv'][0] == 'write']
        self.assertEqual(3, len(writes))
        self.assertEqual({'scope': 'currentHost', 'argv': ['write', 'NSGlobalDomain', 'com.apple.mouse.tapBehavior', '-int', '1']},
                         [w for w in writes if w['scope'] == 'currentHost'][0])
        self.assertEqual(1, len(os.listdir(os.path.join(home, 'backups'))))
        self.assertEqual(before, read(profile))             # the hook never rewrites the profile
        proc = self.run_hook(script, home, state)
        self.assertEqual(0, proc.returncode, proc.stdout + proc.stderr)
        self.assertEqual(3, len([c for c in self.calls(state) if c['argv'][0] == 'write']))
        self.assertEqual(1, len(os.listdir(os.path.join(home, 'backups'))))

    def test_a_failing_restore_makes_the_hook_fail_so_chezmoi_retries_it(self):
        script = self.render('darwin')
        home, state = self.sandbox()
        proc = self.run_hook(script, home, state, FAKE_DEFAULTS_FAIL_ON='orientation')
        self.assertNotEqual(0, proc.returncode)
        self.assertIn('restore failed', proc.stderr)
        self.assertIn('rollback', proc.stderr)

    def test_missing_prerequisites_defer_without_failing_or_writing(self):
        script = self.render('darwin')
        for label, kwargs, needle in (('tool', {'install': False}, 'macos-preferences not present'),
                                      ('profile', {'profile': False}, 'profile.json not present')):
            home, state = self.sandbox(**kwargs)
            proc = self.run_hook(script, home, state)
            self.assertEqual(0, proc.returncode, label + proc.stderr)
            self.assertIn('deferred', proc.stdout + proc.stderr, label)
            self.assertIn(needle, proc.stdout + proc.stderr, label)
            self.assertEqual([], self.calls(state), label)
        home, state = self.sandbox()
        proc = self.run_hook(script, home, state, path=os.path.join(home, '.local', 'bin'))   # no python3 on PATH
        self.assertEqual(0, proc.returncode, proc.stderr)
        self.assertIn('python3 not found', proc.stdout + proc.stderr)
        self.assertEqual([], self.calls(state))

    def test_opt_out_skips_the_restore(self):
        script = self.render('darwin')
        home, state = self.sandbox()
        proc = self.run_hook(script, home, state, DOTFILES_SKIP_MACOS_PREFERENCES='1')
        self.assertEqual(0, proc.returncode, proc.stderr)
        self.assertIn('DOTFILES_SKIP_MACOS_PREFERENCES=1', proc.stdout + proc.stderr)
        self.assertEqual([], self.calls(state))


class RepositoryWiringTests(unittest.TestCase):
    def test_tests_are_excluded_from_the_deployed_home(self):
        ignore = read(os.path.join(REPO, '.chezmoiignore')).decode().splitlines()
        self.assertIn('.config/macos-preferences/tests', ignore)

    def test_the_tool_is_installed_as_an_executable_command(self):
        self.assertTrue(os.path.isfile(os.path.join(REPO, TOOL_REL)))
        self.assertEqual('#!/usr/bin/env python3', read(os.path.join(REPO, TOOL_REL)).decode().splitlines()[0])


if __name__ == '__main__':
    unittest.main()
