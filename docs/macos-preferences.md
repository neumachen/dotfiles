# macOS preferences: capture and restore

`macos-preferences` reproduces a curated set of macOS preferences on a new Mac,
starting with the **enabled and disabled keyboard shortcuts** in
System Settings → Keyboard → Keyboard Shortcuts. It reads and writes only
through the `defaults` command, only for keys on a built-in allowlist, and never
by importing or copying whole preference files.

Status as of 2026-09-30 (macOS 26.6.2): capture, comparison and the tool's logic
are tested; **restoring onto a new Mac and the physical shortcut behaviour are
UNVERIFIED** until you try them on the destination (see
[Verification status](#verification-status)).

## Where things live

| Source path | Deployed to | Role |
| --- | --- | --- |
| `dot_local/bin/executable_macos-preferences` | `~/.local/bin/macos-preferences` | The tool (Python 3.9+, standard library only) |
| `private_dot_config/macos-preferences/profile.json` | `~/.config/macos-preferences/profile.json` | The captured profile |
| `.chezmoiscripts/run_onchange_after_55-macos-preferences.sh.tmpl` | (runs; not deployed) | Darwin-only restore hook |
| `private_dot_config/macos-preferences/tests/` | (source-only, ignored) | Tests and a fake `defaults` |
| — | `~/.local/state/macos-preferences/backups/` | Pre-restore backups (created on demand) |

`macos-defaults-snapshot` is a different tool. It dumps and re-imports whole
domains (including accounts, Bluetooth and security domains) and its `restore`
replaces them wholesale. Do not use it to migrate to another Mac; use it, if at
all, as a forensic dump.

## What is captured

Only the keys named in the allowlist (`KEY_INDEX` in the tool; 164 keys). Keys
the Mac does not have are recorded under `"absent"` and are never invented.

| Area (`--only`) | Domain → keys |
| --- | --- |
| `shortcuts` | `com.apple.symbolichotkeys` → every `AppleSymbolicHotKeys` record, whole (enabled flag, parameter arrays, record type, records without a `value`) |
| `services` | `pbs` → `NSServicesStatus` (every service's enabled state and custom shortcut) |
| `app-shortcuts` | `NSUserKeyEquivalents` in `NSGlobalDomain` and in **every app domain that has one** (discovered at capture time) |
| `keyboard` | `NSGlobalDomain`: `com.apple.keyboard.fnState`, key repeat, press-and-hold, full keyboard access, smart-substitution toggles, quote styles |
| `input-sources` | `com.apple.HIToolbox` → enabled/selected input sources, current layout |
| `trackpad` | both `AppleMultitouchTrackpad` domains; `NSGlobalDomain` scroll/click scaling; **current-host** `NSGlobalDomain` tap-to-click and gesture keys |
| `dock` | `com.apple.dock` (position, size, auto-hide, magnification, hot corners, recents), `com.apple.spaces`, `com.apple.WindowManager`, `AppleSpacesSwitchOnActivate` |
| `finder` | `com.apple.finder` view/desktop/path-bar/trash options, `AppleShowAllExtensions` |
| `appearance` | `NSGlobalDomain` appearance, accent/highlight, scroll bars, menu bar, sidebar icon size |

Deliberately **not** captured: accounts and credentials, iCloud state, device
pairings, host UUIDs, recent items and "Go to" history, Dock and sidebar
contents (they hold bookmarks and paths), window geometry, permissions (TCC)
databases, text replacements, language/region, and anything under
`Library/Preferences/ByHost` other than the allowlisted current-host keys.
A Finder "New windows show" choice of a custom folder (`PfLo`) is skipped with a
warning because it needs a machine path.

## Daily use

Everything is explicit. Nothing runs `capture` for you.

```sh
macos-preferences capture             # read this Mac -> ~/.config/macos-preferences/profile.json
macos-preferences diff                # what would restore change? (read-only)
macos-preferences diff --all          # ... and list identical entries too
macos-preferences restore --dry-run   # same preview, via restore
macos-preferences restore             # back up, apply, verify (asks first)
macos-preferences restore --only shortcuts,services --yes
macos-preferences rollback latest     # undo the most recent restore
macos-preferences validate            # check a profile; works on any OS
```

Exit codes: `diff` 0 = in sync, 1 = differences pending, 2 = error. `restore`
and `rollback` 0 = done, 1 = a write failed or did not verify, 2 = usage,
profile or environment error.

### Updating the profile after you change a shortcut

1. Change the shortcut in System Settings.
2. `macos-preferences capture`
3. `chezmoi re-add ~/.config/macos-preferences/profile.json`
4. `git diff` shows exactly which shortcut records changed, one line each. Commit.

Never edit `profile.json` by hand; it is generated and validated against the
allowlist. To capture another key, add it to the allowlist in the tool
(`_grp(...)`), add or adjust a test, and recapture.

### What the chezmoi hook does

`run_onchange_after_55-macos-preferences.sh.tmpl` runs on macOS only, after
files are applied, and only when the profile **or** the tool changed (both are
hashed into the hook). It runs `restore --yes`, never `capture`. If everything
already matches it writes nothing and makes no backup. If the tool, profile or
`python3` is missing it defers (exit 0) and the dependency hashes re-trigger it
once they appear. If a write fails it exits non-zero so chezmoi retries it.
Skip it for one apply with `DOTFILES_SKIP_MACOS_PREFERENCES=1`.

## How restore behaves

- **Merge, not replace.** The shortcut, Services and key-equivalent
  dictionaries are applied entry by entry (`defaults write … -dict-add`). A
  shortcut ID, service or menu item that the profile does not mention is left
  exactly as it is on the destination. A shortcut record itself is replaced whole,
  so a record that lost its `value` on the source loses it on the destination.
- **Never deletes.** Keys listed under `"absent"` are left alone (the preview
  shows a `!` line if the destination has a value there).
- **Current-host settings** are written with `defaults -currentHost` on the
  destination, so the destination's own host UUID is used. No host identifier is
  stored in the profile.
- **Types are preserved.** In the profile `false` is a boolean, `0` an integer,
  `0.0` a real, `{"$data": "<base64>"}` data and `{"$date": "<ISO-8601>"}` a
  date. Comparison is type-exact (`0` ≠ `false` ≠ `0.0`); the two trackpad
  domains on the source Mac genuinely disagree on `DragLock` (`0` vs `false`) and
  both are kept.
- **Verified.** After writing a domain the tool reads it back and compares each
  value type-exactly. A value that did not land is reverted and the run stops.
- **No live-file access.** It never imports a domain and never copies files under
  `Library/Preferences`, so `cfprefsd` stays consistent.

## Backups and recovery

Before any write, the values about to change are saved to
`~/.local/state/macos-preferences/backups/<UTC timestamp>/before.json`
(directory `0700`, file `0600`, outside the repository; override the root with
`MACOS_PREFERENCES_BACKUP_DIR`). A backup holds the whole prior value of each
touched key, or an `"absent"` entry if the key did not exist. Only affected keys
are saved, never whole domains.

```sh
macos-preferences rollback latest --dry-run     # see exactly what would be put back
macos-preferences rollback latest               # do it (takes its own backup first)
macos-preferences rollback ~/.local/state/macos-preferences/backups/20260930T120000Z
```

Rollback restores whole keys (a dictionary such as `AppleSymbolicHotKeys` returns
to its exact prior contents, including removing entries the restore added) and
deletes keys that did not exist before. Last resort for one key, using values
from `before.json`: `defaults write <domain> <key> …` or `defaults delete
<domain> <key>` (add `-currentHost` for current-host keys).

## When a logout or restart is needed

The tool prints these after a successful restore. They are guidance, not
guarantees; whether a given change is picked up without them is UNVERIFIED.

| Area | Do this |
| --- | --- |
| `shortcuts`, `keyboard`, `input-sources`, `services`, `trackpad`, `appearance` | Log out and back in (a restart also works). |
| `app-shortcuts` | Quit and reopen each affected app. |
| `dock` | `killall Dock`; hot corners, Stage Manager and tiling may need a logout. |
| `finder` | `killall Finder`. |

The tool never restarts anything itself.

## Unsupported: migrate these by hand

- **Shortcuts.app workflows.** Not keyboard-shortcut preferences and not handled
  here at all: the tool does not read, export or restore them. Move them with
  iCloud sync (same Apple ID) or by exporting each one from the Shortcuts app
  and importing it on the new Mac. Any keyboard shortcut or menu placement
  attached to a workflow, and its privacy permissions, must be set again in the
  Shortcuts app afterwards. Confirm the exact behaviour on the new Mac.
- **Overrides inside sandboxed apps' containers.** `defaults` cannot see them, so
  discovery does not either. Re-create them in System Settings → Keyboard → App
  Shortcuts.
- **Domains whose name starts with `-`** cannot be passed safely to `defaults`;
  capture skips them with a warning.
- Dock contents, Finder sidebar, text replacements, language and region,
  Dictation/Siri shortcuts, Touch ID, Focus, notifications, displays, sound,
  login items, default apps, Bluetooth pairings, Wi-Fi, Passwords, Apple ID/iCloud
  sign-in, FileVault, and **Privacy & Security permissions** (each app must be
  granted again).
- **Karabiner-Elements and Hammerspoon** are separate, repo-managed configs (see
  next section), not part of this profile.

### Known differences, reported but deliberately not resolved here

1. **Karabiner F19.** The live `~/.config/karabiner/karabiner.json` maps F19 to
   **Cmd+F5**; the repository's `private_dot_config/karabiner/private_karabiner.json`
   maps it to **Hyper+F5** (Cmd+Ctrl+Opt+Shift). That is the only difference
   between the two files apart from the rule's description. Decide which is
   intended, then update one side. The enabled system shortcuts in the profile
   include IDs 34, 35, 36, 37, 79, 81 and 163; whether one of them is what this
   F19 rule is meant to trigger has not been checked.
2. **Hammerspoon.** The live `~/.config/hammerspoon/init.lua` (424 lines) differs
   from the modified working-tree `private_dot_config/exact_hammerspoon/init.lua`
   (467 lines) and from `HEAD` (269 lines). The live file implements a WezTerm
   ⌘C-triggered fenced-code chooser; the working tree implements a ⌘⌥V
   paste-time one. Neither application configuration was re-added.

## Verification status

| Claim | Status |
| --- | --- |
| Capture reads this Mac: 95 shortcut records (7 enabled: 34, 35, 36, 37, 79, 81, 163; 88 disabled), 19 Services, 0 key-equivalent overrides across 736 domains | Verified (2026-09-30, read-only) |
| Capture is byte-identical across runs and across Python 3.14 and the system 3.9.6 | Verified |
| `diff` of the shipped profile against this live Mac: 0 to add, 0 to change, 232 identical (type-exact) | Verified |
| Preview cannot write: the backend is wrapped so a write raises; verified by test and by running `diff`/`restore --dry-run` live (no backup directory appeared) | Verified |
| Restore/rollback logic: merge, unrelated entries preserved, disabled and field-less records, `SAE1.0`, current-host scope, repeat run, backup, rollback, failure and read-back mismatch reporting | Verified against `tests/fake_defaults`, a **model** of `defaults` (70 tests, plus mutation checks) |
| Darwin hook renders, lints, hashes both inputs, non-Darwin renders to `exit 0` and does nothing, hook never captures | Verified (real `chezmoi execute-template`) |
| The exact `defaults write` argument forms (`-bool/-int/-float/-string`, bare XML fragments for dictionaries/arrays, `-dict-add` with an XML value, `-currentHost write`) are accepted by the real `defaults` and store the intended types | **UNVERIFIED.** No write was run against the real `defaults`. The tool's own read-back catches a mismatch at run time; check on the destination first. |
| Restoring onto a new Mac reproduces the settings | **UNVERIFIED** until run there |
| Shortcuts physically behave the same after logout/login | **UNVERIFIED** |
| The restart guidance table | **UNVERIFIED** |

### First run on the new Mac (suggested)

```sh
macos-preferences validate
macos-preferences diff                              # everything should show as "+" or "~", nothing scary
macos-preferences restore --only dock --yes         # small, easy to see, easy to undo
macos-preferences rollback latest --yes             # optional: prove the undo path works
macos-preferences restore --yes                     # the rest
```

Then log out and back in, and try the shortcuts you care about.

## Testing

```sh
python3 -m unittest discover -s private_dot_config/macos-preferences/tests -v
/usr/bin/python3 -m unittest discover -s private_dot_config/macos-preferences/tests   # the Python a new Mac has
```

Nothing in the tests touches real preferences: the tool is pointed at
`tests/fake_defaults` through `MACOS_PREFERENCES_DEFAULTS_BIN`. The hook tests
render with the real `chezmoi execute-template` from a small temporary source
directory (a full source-tree render trips over an unrelated dangling symlink
under `.aider-desk/`). `chezmoi apply` is never run.
