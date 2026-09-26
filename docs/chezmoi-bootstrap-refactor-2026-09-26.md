# Chezmoi bootstrap refactor — completion report

Completed 2026-09-26. Base `acd81396`; all work is now in `main` (`8f610c52`).
Verified against chezmoi v2.72.2 upstream source, not documentation memory.

## What was asked

Audit the whole chezmoi installation path for a brand-new machine, report what
is missing, and make it a genuine one-shot install. Two specific complaints:

1. It never asks for the 1Password vault or the 1Password SSH key item.
2. It exits when Xcode or the Xcode license is missing, instead of deferring
   and configuring it on a later pass.

## Root causes found

### 1. The 1Password prompts were structurally unreachable

`.chezmoi.yaml.tmpl` gated them behind `{{ if stat "/Applications/1Password.app" }}`.
chezmoi renders the config template during `chezmoi init`, **before** any
`.chezmoiscripts` run — and `1password` is a Brewfile cask installed later by a
script. On a fresh Mac the gate was always false, so the prompts never fired.

Worse, the result was permanent. chezmoi's `promptStringOnce`
(`internal/cmd/interactivetemplatefuncs.go:220-235`) returns the stored value
whenever the **key exists**, regardless of emptiness:

```go
if value, ok := nestedMap[lastKey]; ok {
    if stringValue, ok := value.(string); ok { return stringValue }
}
```

The template unconditionally emitted `vault: {{ $vault | quote }}` → `vault: ""`.
That empty string was written to `~/.config/chezmoi/chezmoi.yaml` and never
re-prompted on any future apply.

### 2. `run_once_*` scripts swallowed their own failures

chezmoi records such a script as done **only on exit 0**. All three critical
bootstrap scripts converted failure into a warning plus `exit 0`, so a partial
bootstrap was never retried:

| Script | Failure path | Consequence |
| --- | --- | --- |
| `run_once_02-install-brew-apps` | `brew bundle` fails → warn → exit 0 | Partial install, never retried. Casks needing driver/password approval fail routinely. |
| `run_once_03-install-mise` | `mise install` fails → warn → exit 0 | 10 runtimes plus cargo/go/npm/aqua/gem backends; partial failure near-certain. |
| `run_once_04-switch-to-ssh` | six separate `exit 0` early-outs | Never reached its own deferred re-apply block — the mechanism meant to paper over cause 1. |

Recovery required `chezmoi state delete-bucket --bucket=scriptState`, documented
nowhere.

### 3. The mise hook killed the terminal running the install

`run_once_03-install-mise` did `kill -TERM "${PPID}"` or spawned a new WezTerm
window **in the middle of `chezmoi apply`**, destroying the session driving the
install and orphaning every remaining step.

### 4. Zero Xcode / Command Line Tools handling

`grep -ri 'xcode|CommandLineTools|xcode-select|xcrun'` across all bootstrap
files returned no hits. On a bare Mac:

- `/usr/bin/git` and `/usr/bin/python3` are CLT shims that raise a GUI dialog
  and fail with `xcrun: error: invalid active developer path`. Confirmed on this
  host: `/usr/bin/python3 -c 'print("ok")'` fails.
- chezmoi's `useBuiltinGitAutoFunc` (`config.go:3134`) uses system git whenever
  `git` is in PATH, so even the clone broke.
- `.chezmoiexternal.toml` used `filter.command = "python3"` for the Tokyo Night
  Storm theme, which aborted the entire apply.
- The Homebrew installer itself requires CLT and tries to install it
  interactively from inside a chezmoi script.
- Nothing checked or accepted the Xcode license.

### 5. `envvars` was hand-maintained host state holding a live credential

`dot_zprofile.tmpl` rendered `{{ range .envvars }}`, but `.chezmoi.yaml.tmpl`
never defined `envvars`. It had been hand-added to one host's chezmoi config
containing a plaintext bearer token — not reproducible, and a secret living
outside 1Password.

### 6. Script ordering relied on alphabet luck

chezmoi's order is `run_before_*` → target updates sorted by attribute-stripped
target name (scripts interleaved with files; `.` = 0x2E sorts before digits
0x30+) → `run_after_*`. `run_once_05-obsidian-vault-dirs` only worked because
`0` < `M`, and `run_once_*` only beat `run_onchange_*` because `e` < `h` at
index 7. No script used the explicit `before_`/`after_` attributes.

### 7. Smaller gaps

`README.md` was 4 lines with no install documentation. No `Brewfile.lock.json`.
`brew "mas"` installed but zero `mas` entries. No hook ran `set-shell-zsh`.
`executable_new-ssh-key` read `${FILENAME}.pub` before `FILENAME` was assigned
and backed up `id_rsa*` while generating `id_ed25519`.

## What changed

Design principle: **the installer is a converging state machine, not a linear
sequence.** A missing prerequisite is never fatal — it is recorded as deferred,
the installer continues, and a later pass configures it once the prerequisite
exists.

### Commits

| Commit | Subject |
| --- | --- |
| `af8002b3` | fix(bootstrap): make chezmoi init prompt unconditionally and converge on re-apply |
| `a3780625` | feat(bootstrap): rewrite install.sh as a resumable converging installer |
| `2fc583f6` | fix(bootstrap): harden schema migration, skip sentinels and stall detection |
| `dbb79555` | docs(readme): document the resumable converging bootstrap |
| `f5c90f3b` | docs(readme): document the corrected install.sh invocation forms |
| `d2dec162` | docs(readme): document all three install.sh invocation forms |
| `c4988698` | fix(install): make the piped one-liner invocation form work |

All seven are signed (SSH format via 1Password `op-ssh-sign`, signer
`kareem@hepburn.info`) and pass `git verify-commit`. 32 files, +6986/−429.

### Prompts now fire unconditionally

`.chezmoi.yaml.tmpl` asks for `git.email`, `git.name`, `onepassword.enabled`,
`onepassword.vault`, `onepassword.ssh_key_item` (a 1Password **item name or
UUID** — the public key is resolved from it, not pasted), `onepassword.account`,
the `TSTRUCT_TOKEN` `op://` reference, and `bootstrap.defer_clt` /
`defer_xcode`.

Two rules make this durable:

- **Empty means unset.** Every value is read through a `hasKey` guard and
  re-prompted only when it is the empty string. This fixes the poisoned-`""`
  trap.
- **`-` means deliberately skipped** and is stored verbatim, so optional values
  do not re-prompt on every future `chezmoi init`. Consumers normalize `-` and
  `none` (case-insensitive, trimmed) to empty.

The git signing block moved out of the data and into `private_profile.tmpl`,
gated on resolved state — which is why a correct git config no longer needs a
second `chezmoi apply`.

### Convergence mechanism

Every bootstrap script embeds a **dependency hash comment** covering everything
it needs (tool presence, config values, resolved-file presence). When a
prerequisite appears, the rendered content changes, the hash changes, and
chezmoi re-runs the script. Combined with the exit-code rule — prerequisite
absent → log `deferred:` and exit 0; prerequisite present but the operation
genuinely failed → exit non-zero so it retries — the machine converges over
successive applies instead of getting stuck.

New layout, in execution order:

```
run_before_10-obsidian-vault-dirs.sh.tmpl
run_20-install-homebrew.sh.tmpl
run_onchange_after_30-linuxify.sh.tmpl
run_onchange_after_40-install-brew-apps.sh.tmpl
run_onchange_after_50-install-mise.sh.tmpl
run_onchange_after_60-generate-git-profiles.sh.tmpl
run_onchange_after_70-resolve-1password.sh.tmpl
run_onchange_after_75-switch-to-ssh.sh.tmpl
run_onchange_after_80-link-aider-desk-home.sh.tmpl
run_onchange_after_85-obsidian-plugin-sync-launchd.sh.tmpl
run_onchange_after_90-regen-completions.sh.tmpl
run_onchange_after_95-yazi-pack.sh.tmpl
run_after_99-bootstrap-status.sh.tmpl
```

The terminal-kill block and the obsolete deferred re-apply block were deleted.

### Resolved-state files

Script-generated, mode 0600, listed in `.chezmoiignore`. Never edit by hand;
delete and re-run `chezmoi apply` to force regeneration.

| Path | Written by | Meaning |
| --- | --- | --- |
| `~/.config/git/ssh-signing-key` | `run_onchange_after_70-resolve-1password` | one line: the SSH public key resolved from the 1Password item. Its presence enables `signingKey`, `[gpg "ssh"]`, `allowed_signers` and the `insteadOf = "https://github.com/"` rewrite. |
| `~/.config/sh/secrets.env` | same | `export NAME='<value>'` lines resolved via `op read`. Sourced by `.zprofile` rather than rendered inline, so a locked or absent 1Password never blocks login. |
| `~/.cache/chezmoi/bootstrap-status.json` / `.txt` | `run_after_99-bootstrap-status` | the status document; `.txt` is a single word the converge loop reads. |

### install.sh — six stages

| Stage | Behaviour |
| --- | --- |
| 0 preflight | read-only report: macOS version, arch, CLT, Xcode, license, Homebrew, chezmoi, 1Password app/CLI/agent, GitHub SSH, network, disk, sudo cache. Never aborts. |
| 1 CLT gate | if absent, explains why, runs `xcode-select --install`, then polls with a visible countdown (15 min default, 10 s interval). `s` skips/defers, `r` re-raises. Never exits. |
| 2 Xcode + license | asks whether full Xcode is wanted (default no). Offers `sudo xcodebuild -license accept`, `-runFirstLaunch`, `xcode-select -s`, re-checking up to 3 times. Defers if absent. Never exits. |
| 3 chezmoi bootstrap | creates dirs, installs chezmoi (prefers brew, else the curl installer), runs `chezmoi init --apply`. Passes `--use-builtin-git=true` when CLT is deferred so the `/usr/bin/git` shim cannot break the clone. Does not `exec`, so later stages still run after a failure. |
| 4 converge loop | up to `--max-passes` (default 5) rounds of `chezmoi apply --keep-going`, re-reading the status word. Stops on green, or when two consecutive passes yield the same `id`/`state` pairs. Between passes prints amber/red checks with remediation and, on a TTY, asks to fix-and-Enter or `q`. |
| 5 postflight | re-runs `bootstrap-status`, prints the table, then a manual-actions checklist containing only the items actually amber/red. Exits 0 even when deferred. |

Flags: `--yes`, `--reprompt`, `--max-passes N`, `--skip-clt`, `--skip-xcode`,
`--verbose`, `--dry-run`, `-h/--help`.

`--reprompt` passes `--prompt` to `chezmoi init`, forcing every prompted value
to be re-asked. **This is the recovery path for a poisoned config.**

Three invocation forms work: `./install.sh` from a clone; `sh -c "$(curl -fsSL URL)"`;
and `curl -fsSL URL -o /tmp/dotfiles-install.sh && bash /tmp/dotfiles-install.sh`
(the most robust — survives a flaky network mid-run and is re-runnable).

### bootstrap-status

`~/.local/bin/bootstrap-status`. Modes: bare (table + writes both cache files),
`--json`, `--quiet`, `--check <id>`, `--no-write`, `--help`.

14 checks in order: `clt`, `xcode`, `xcode_license`, `homebrew`, `chezmoi`,
`onepassword_app`, `onepassword_cli`, `onepassword_vault`, `ssh_signing_key`,
`github_ssh`, `brewfile`, `mise`, `secrets`, `git_remote_ssh`.

`overall` is red if any check is red, else amber if any is amber, else green.
Amber means deferred and will converge; red means actionable now.

Always exits 0 for a valid invocation (usage errors exit 2) — it is a reporter,
not a gate. Never mutates, never prompts, never needs a TTY, never prints a
secret value. Works on a bare Mac with no Homebrew, chezmoi, `jq` or CLT,
falling back to a pure-bash parse of `~/.config/chezmoi/chezmoi.yaml`.

Env overrides: `BOOTSTRAP_STATUS_DIR`, `BOOTSTRAP_CHEZMOI_CONFIG`.

### Other fixes

- Tokyo Night Storm shiki theme is **vendored** at
  `MeinCodex/Notizen/Obsidian/Main/dot_obsidian/shiki-themes/tokyo-night-storm.json`
  instead of downloaded and filtered with `python3`.
- `HOMEBREW_BUNDLE_FILE_GLOBAL` is exported so `brew bundle --global` resolves
  `~/.config/homebrew/Brewfile` deterministically. **`HOMEBREW_BREWFILE` is not
  a Homebrew variable** — verified absent from Homebrew 7.0.6; do not
  "simplify" it to that.
- `.chezmoiignore` Obsidian patterns used **source** paths (`dot_obsidian`) but
  the file matches **target** paths (`.obsidian`), so all of them were dead.
  Fixed; verified 7 previously-unignored runtime files are now ignored.
- `75-switch-to-ssh` and the `git_remote_ssh` check read
  `git config --get remote.origin.url` instead of `git remote get-url origin`,
  which returns the `insteadOf`-rewritten URL and masked an HTTPS origin.
- `install.sh` re-exec guard: `exec bash "$0"` assumed `$0` names the script.
  Under a piped invocation on a non-bash shell it tried to run a file named
  `sh`. Now validates `$0` by content marker, otherwise re-fetches to a mktemp
  file, validates shebang + marker + non-empty (refusing a 404, captive portal
  or truncated body), restores stdin from `/dev/tty` only when one can actually
  be opened, and hands the temp path to the child for cleanup on EXIT.
- `executable_new-ssh-key` use-before-set and wrong backup paths fixed.
- `README.md` expanded from 4 lines to a full operator document.

## Verification performed

- `shellcheck` clean on every script created or modified; `bash -n`,
  `/bin/bash -n` (3.2) and `sh -n` on `install.sh`.
- `.chezmoi.yaml.tmpl` rendered in a fully isolated `/tmp` sandbox
  (`-S`/`-c`/`-D`/`--cache`/`--persistent-state`). Proven: an all-skipped
  config re-prompts **nothing** across three consecutive re-inits; blanking one
  value re-asks exactly that one; no malformed `op:///` reference is emitted.
- **Legacy-config regression test**: with a fixture containing only pre-refactor
  keys, and separately with `data: {}`, a full-tree `chezmoi diff` exits 0 with
  zero `map has no entry for key` errors across all 21 templates. Rendered git
  config correctly has no signing block and no `insteadOf` rewrite.
- Git signing block ordering verified with `git config --file ... --list`:
  `user.signingkey` lands inside `[user]`, before `[gpg]`.
- Re-exec guard tested end-to-end under zsh (a genuine non-bash shell, since
  macOS `/bin/sh` is bash and skips the guard): Case A rc=0; Case B rc=0 with
  zero temp files left behind; unfetchable URL rc=2 executing nothing; a
  substituted bogus script rc=2 with the hijacked body **not** run.
- `bootstrap-status` run for real: valid JSON, 14 ids in contract order,
  correct roll-up, and complete output under `PATH=/usr/bin:/bin:/usr/sbin:/sbin`
  with no `jq`, no `chezmoi` and no `op`.
- Vendored theme confirmed strict JSON and listed by `chezmoi managed`.
- `git diff --check` clean; `git verify-commit` passes on all seven commits.

No `chezmoi apply`, no real `chezmoi init`, no `brew`, no `mise install`, no
`sudo`, no `xcode-select --install` and no real `op` invocation was run at any
point. All validation was hermetic.

## Known limitations and deliberate omissions

**Nobody has run the new `install.sh` end-to-end on an actual bare Mac.** All
validation was hermetic — `--dry-run`, stubbed `chezmoi`/`brew`/`sudo`, `/tmp`
sandboxes, synthetic configs. The six-stage flow, the CLT polling loop, the
converge loop and the 1Password resolver have never executed against a real
fresh machine. The logic is verified; the integration is not. Retire this risk
on a VM or a spare Mac, or run `./install.sh --dry-run` on the new device first.

Flagged during the audit and deliberately not implemented:

- `mas` is installed by the Brewfile but there are zero `mas` entries — App
  Store apps remain unmanaged.
- No `Brewfile.lock.json`, so versions are not reproducible across machines
  (gitignored by choice).
- No hook runs `set-shell-zsh`; it is documented as a manual action instead.
- `bootstrap-status` has no check for chezmoi destination drift.

## Action items

1. **Re-run `chezmoi init` on existing machines.** chezmoi does **not**
   regenerate the config file when `.chezmoi.yaml.tmpl` changes; it only prints
   `warning: config file template has changed, run chezmoi init to regenerate
   config file`. Templates are `hasKey`-guarded so an old config still renders
   with features inert, but the new behaviour needs `./install.sh --reprompt`.
2. **Migrate `envvars` → `secrets`.** Legacy `envvars` entries are preserved
   across re-init and still exported, but should move into `data.secrets` as
   `op://` references and then be deleted from `envvars`. This removes the
   plaintext token from the chezmoi config.
3. **Clear the dangling symlinks breaking `chezmoi data`.** Pre-existing and
   unrelated to this work: 17 symlinks under
   `.aider-desk/extensions/bmad/node_modules/.bin/` point into a deleted
   `/var/folders/.../aider-desk-ext-UAzcdQ/`. `chezmoi apply`, `diff` and
   `status` still work; `chezmoi data` fails outright.
4. **Resolve the 41 chezmoi destination-drift entries** before the next apply.
   Seven of them are local files under `exact_` source directories that
   `chezmoi apply` would **delete**: `.config/hammerspoon/Spoons`,
   `.config/opencode/{.gitignore,package.json,package-lock.json,tui.json}`,
   `.config/zed/{prompts,themes}`. Add them to source or to `.chezmoiignore`
   first.

## Recovery commands

| Symptom | Fix |
| --- | --- |
| A prompt value is stuck empty and never re-asks | `install.sh --reprompt` (or `chezmoi init --prompt`) |
| `warning: config file template has changed` | re-run `chezmoi init` |
| A bootstrap step was skipped and never retries | `chezmoi state delete-bucket --bucket=scriptState`. For one script, find its hash with `chezmoi state get-bucket --bucket=scriptState` (keys are sha256 of rendered content, not filenames), then `chezmoi state delete --bucket=scriptState --key=<HASH>` |
| `xcrun: error: invalid active developer path` | `xcode-select --install`, then re-run |
| `op` present but `onepassword_cli` amber | 1Password → Settings → Developer → enable "Integrate with 1Password CLI" |
| `ssh_signing_key` red | unlock 1Password, approve the signing request, re-run `chezmoi apply` |
| `brewfile` red | re-run `chezmoi apply`; check which casks need GUI approval |
| `git_remote_ssh` red | origin is still HTTPS; `chezmoi apply` rewrites it once SSH works |
| What is outstanding right now? | `bootstrap-status` |
