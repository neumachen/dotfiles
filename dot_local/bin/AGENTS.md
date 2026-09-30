# LOCAL COMMAND UTILITIES

## OVERVIEW

Standalone installed commands for dotfiles, package tools, fuzzy pickers, logging, and vault maintenance.

## WHERE TO LOOK

| Task | Source file(s) | Coupling |
| --- | --- | --- |
| chezmoi operations | `executable_dotc` | Interactive apply/re-add; default force and keep-going flags |
| Homebrew operations | `executable_dotb` | Install, uninstall, upgrade, purge via fzf |
| mise upgrades | `executable_dotm` | Outdated-tool picker and list subcommand |
| Custom command completion | `executable_regen-zsh-completions` | Inline definitions for dotc, dotb, dotm, fzdocker |
| Logging | `executable_echo-log`, `executable_echo-*` | Level wrappers delegate to installed `echo-log` |
| Logged execution | `executable_echo-run`, `executable_safe-run` | `safe-run` delegates to `echo-run`; utilities also call `echo-run` directly |
| File/search pickers | `executable_fzopen`, `executable_fzrg`, `executable_fzedit`, `executable_fzgrep` | fzf, editor, preview commands; some source XDG shell library |
| Resource pickers | `executable_fzdocker`, `executable_fzpods`, `executable_fzkill`, `executable_fzapt` | Backend-specific commands can mutate selected resources |
| Clipping organization | `executable_obsidian-clip-sort` | Sorts source URLs into host directories; quarantines duplicate notes |
| Plugin settings capture | `executable_obsidian-plugin-sync` | launchd-triggered chezmoi re-add of manifest.json/data.json |
| macOS preferences | `executable_macos-preferences` | Python 3.9+; allowlisted capture/diff/restore/rollback of shortcuts and settings via `defaults`; profile, hook and tests below |

## CONVENTIONS AND COUPLING

- Keep dotc/dotb/dotm/fzdocker names, subcommands, and options aligned with inline completion
  definitions in `executable_regen-zsh-completions`.
- `.chezmoiscripts/run_onchange_after_regen-completions.sh.tmpl` hashes that
  generator. Regeneration writes installed zsh completion files and compiles them.
- Scripts resolve installed dependencies through `PATH`, including sibling
  commands without their `executable_` source prefix.
- `fzopen` and `fzrg` source `${XDG_CONFIG_HOME:-$HOME/.config}/sh/lib.sh`;
  the source counterpart is `private_dot_config/sh/lib.sh`.
- `echo-run` prints a quoted command to stderr, then executes its original
  arguments unless `ECHO_RUN_ECHO_ONLY` is set. It does not expand aliases.
- `echo-log` owns level/color formatting; `LOG_DATE` also invokes `echo-date`.
  Level wrappers such as `echo-fatal` log a label; they do not explicitly exit.
- `dotc` enables force, keep-going, and recursive behavior by default through
  `DOTFILES_FORCE`, `DOTFILES_KEEP_GOING`, and `DOTFILES_RECURSIVE`.
- `obsidian-clip-sort` defaults to dry-run. `--apply` moves notes and quarantines
  duplicates; `--vault`/`VAULT_DIR` selects a vault. Preserve macOS Bash 3.2 support.
- Plugin sync changes source files with `chezmoi re-add`. Coordinate its script
  with `private_Library/LaunchAgents/com.neumachen.obsidian-plugin-sync.plist.tmpl`
  and `.chezmoiscripts/run_onchange_after_obsidian-plugin-sync-launchd.sh.tmpl`.
  The hook hashes both files; the plist supplies a login Bash environment.
- `macos-preferences` is coupled to `private_dot_config/macos-preferences/profile.json`
  (generated; never hand-edit), `.chezmoiscripts/run_onchange_after_55-macos-preferences.sh.tmpl`
  (hashes the profile and this file; runs `restore --yes` only, never `capture`), and
  `private_dot_config/macos-preferences/tests/` (source-only; ignored in `.chezmoiignore`).
  The allowlist (`KEY_INDEX`) is the only definition of what may be captured or
  restored; `restore` re-validates the profile against it. Guide: `docs/macos-preferences.md`.
- `macos-preferences` writes only with `defaults write`/`delete` (never `defaults import`,
  never files under `Library/Preferences`), backs up affected values first, and verifies by
  read-back. Keep it standard-library Python 3.9 compatible: a new Mac has only the
  Command Line Tools `/usr/bin/python3` until mise runs. It logs in the `echo-*` format
  in-process to stderr so stdout stays clean for reports.
- `macos-defaults-snapshot` is unrelated: it dumps and re-imports whole domains and is
  not a safe way to migrate preferences to another Mac.

## VALIDATION

Choose the interpreter from each script's actual shebang. From the repository root:

```sh
sh -n dot_local/bin/executable_dotc
sh -n dot_local/bin/executable_echo-run
bash -n dot_local/bin/executable_dotb
/bin/bash -n dot_local/bin/executable_obsidian-clip-sort
python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' dot_local/bin/executable_macos-preferences
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s private_dot_config/macos-preferences/tests
```

The macos-preferences tests use a fake `defaults` and a sandbox HOME; they never read or
write real preferences. Run `macos-preferences diff` or `validate` for live checks;
`restore` and `rollback` change real preferences and are not validation commands.

## ANTI-PATTERNS

- Do not treat every extensionless file as Bash. POSIX sh and Bash coexist.
- `executable_linuxify.tmpl` begins with a modeline and template conditional;
  its Darwin branch contains a Bash shebang. Check rendered content, not the raw
  template, and do not classify it by the first line alone.
- Do not run ShellCheck across the directory indiscriminately. Select concrete
  shell sources; `shellcheck-all` searches host paths rather than this source tree.
- Do not invoke maintenance commands as syntax checks: pickers, completions,
  package commands, and vault sync can change host or source state.
