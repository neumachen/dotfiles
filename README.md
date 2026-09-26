# dotfiles

This repository contains my dotfiles I use for my dev machines (personal or
work).

They are managed by [chezmoi](https://www.chezmoi.io/). This checkout is the
*source tree*; its encoded filenames (`dot_`, `private_`, `exact_`,
`executable_`, `symlink_`, `.tmpl`) deploy into `$HOME`.

Two tools drive a fresh machine:

| Tool | Source | Deploys to | Role |
| --- | --- | --- | --- |
| `install.sh` | `install.sh` | *not deployed* (in `.chezmoiignore`) | resumable, converging bootstrap |
| `bootstrap-status` | `dot_local/bin/executable_bootstrap-status` | `~/.local/bin/bootstrap-status` | read-only reporter |

**The installer is a converging state machine, not a linear sequence.** A
missing prerequisite is never fatal: it is recorded as *deferred*, the
installer continues, and a later pass configures it once the prerequisite
exists. Re-running `install.sh` resumes. `bootstrap-status` shows what is
still outstanding at any time.

> **Already configured a machine with an older version of this repo?** Jump
> straight to [Migrating an existing machine](#migrating-an-existing-machine).
> chezmoi does *not* regenerate `~/.config/chezmoi/chezmoi.yaml` when
> `.chezmoi.yaml.tmpl` changes — it only warns.

## Quick start

From a fresh Mac, download the installer and run it (this keeps the TTY, so
the prompts work):

```sh
curl -fsSL https://raw.githubusercontent.com/neumachen/dotfiles/main/install.sh \
  -o /tmp/dotfiles-install.sh
sh /tmp/dotfiles-install.sh
```

`install.sh` re-execs itself under `bash` when started with `sh`, detects that
it is *not* running from a clone, and has `chezmoi init --apply` clone
`https://github.com/neumachen/dotfiles.git` over HTTPS (no SSH key needed).

Or from an existing clone — `install.sh` detects `.chezmoi.yaml.tmpl` next to
it and passes `--source=<clone>` to chezmoi instead of cloning:

```sh
git clone https://github.com/neumachen/dotfiles.git \
  ~/MeinCodex/Codebasis/github.com/neumachen/dotfiles
cd ~/MeinCodex/Codebasis/github.com/neumachen/dotfiles
sh install.sh
```

That clone path is the canonical one: it matches the `sourceDir` baked into
`.chezmoi.yaml.tmpl`.

Afterwards:

```sh
sh install.sh                 # resume — picks up where the last run stopped
bootstrap-status              # what is still outstanding (read-only)
sh install.sh --reprompt      # re-answer every chezmoi prompt
sh install.sh --dry-run       # walk every stage, execute nothing
```

`curl … | bash` also works, but stdin is then a pipe, so `install.sh`'s own
`[y/N]` prompts silently take their defaults and the Command Line Tools gate
cannot be skipped interactively. Prefer downloading the file.

### Flags

Verbatim from `install.sh --help`:

| Flag | Effect |
| --- | --- |
| `--yes` | never prompt; take the default and defer anything ambiguous |
| `--reprompt` | pass `--prompt` to `chezmoi init` so every `prompt*Once` value is re-asked. **This is the recovery path for a poisoned `~/.config/chezmoi/chezmoi.yaml`.** |
| `--max-passes N` | max `chezmoi apply` passes in the converge loop (default 5; `0` skips the loop and goes straight to the report). `--max-passes=N` also accepted |
| `--skip-clt` | do not raise or wait for the Command Line Tools dialog |
| `--skip-xcode` | do not ask about full Xcode or its license |
| `--verbose` | pass `-v` to chezmoi and echo every command before running it |
| `--dry-run` | walk every stage printing what it would do; execute nothing (no `mkdir`, no downloads, no chezmoi, no brew, no sudo) |
| `-h`, `--help` | help |

Environment overrides: `BOOTSTRAP_STATUS_DIR` (cache directory, default
`~/.cache/chezmoi`) and `CLT_TIMEOUT` (Command Line Tools poll timeout in
seconds, default `900`).

### Guarantees

- It never exits non-zero *because a prerequisite is missing*.
- It never kills or replaces your shell. The only `exec` re-execs this same
  script under `bash` when it was started as `sh install.sh`; chezmoi is
  deliberately **not** `exec`'d, so its exit status is captured and the later
  stages still run.
- It is idempotent and resumable.
- `Ctrl-C` prints `interrupted — re-run install.sh to resume; nothing is
  broken` and exits 130.

The only non-zero exits are: an unsupported OS (not macOS and not Linux),
`bash` missing when invoked via `sh`, a usage error (exit 2), chezmoi absent
with no `curl`/`wget`/`brew` to fetch it, and interruption (130). Typing `q`
at a prompt is **not** an error exit — it stops the loop and still runs the
report, exiting 0.

## What it asks you

`chezmoi init` renders `.chezmoi.yaml.tmpl`, which *is* the config file. The
prompts fire in this order, and only when the stored value is empty or the key
is absent:

| # | Prompt | Default | To skip |
| --- | --- | --- | --- |
| 1 | `Git user email` | — | mandatory; leave empty and it asks again next `chezmoi init` |
| 2 | `Git user name` | — | mandatory; same as above |
| 3 | `Use 1Password for git SSH signing and secrets` | `true` | answer `false` (skips prompts 4–7) |
| 4 | `1Password vault name (e.g. Private)` | `Private` | `-` |
| 5 | `1Password item NAME or UUID holding your SSH key` | — | `-` |
| 6 | `1Password account shorthand` | — | `-` |
| 7 | `1Password reference for TSTRUCT_TOKEN (op://vault/item/field)` | `op://<vault>/Tstruct/token` | `-` |
| 8 | `Defer Command Line Tools install during bootstrap` | `false` | — |
| 9 | `Defer full Xcode install during bootstrap` | `false` | — |

Two rules make this a one-shot install:

- **Empty means unset.** Every prompted value is read through a `hasKey` guard
  and re-prompted only when it is the empty string. (chezmoi's
  `promptStringOnce` returns the stored value whenever the *key exists* — even
  when it is `""` — so an unconditional `vault: ""` would never be re-asked.)
- **`-` means "deliberately skipped"** and is stored verbatim, so optional
  values do not re-prompt on every future `chezmoi init`. Every consumer
  normalises `-` (and `none`, case-insensitive, trimmed) back to empty.

> **`ssh_key_item` is a 1Password item NAME or UUID — not a pasted public
> key.** This changed. The key material now lives in a 1Password item and is
> resolved into `~/.config/git/ssh-signing-key` at apply time. The old
> `onepassword.ssh_signing_key` data key is legacy: it is carried forward if
> present but never prompted for.

## Prerequisites

Nothing here is fatal. "Deferred" means the installer records it, continues,
and a later pass (or a later `install.sh` run) configures it.

| Requirement | Needed? | If missing |
| --- | --- | --- |
| macOS or Linux | **required** | `install.sh` exits 1. macOS is the supported target |
| `bash` | **required** | exits 1 if invoked via `sh` with no `bash` on PATH |
| `curl` or `wget` | **required** to fetch chezmoi | exits 1 only when chezmoi is absent *and* neither exists *and* there is no brew |
| Network | required for downloads | downloads deferred; stage 0 reports `github.com` reachability |
| Command Line Tools | recommended on macOS | stage 1 raises `xcode-select --install` and polls. Skip or timeout → deferred, and stage 3 forces `--use-builtin-git=true` so the `/usr/bin/git` shim cannot break the clone |
| Full Xcode + license | optional | CLT is sufficient for this repo. If Xcode is present but the license is not accepted, stage 2 offers `sudo xcodebuild -license accept`, re-checking up to 3 times |
| Homebrew | optional | `run_20-install-homebrew.sh.tmpl` installs it — but defers itself when CLT is absent, because the Homebrew installer needs a compiler toolchain |
| 1Password 8 desktop app | optional | a Brewfile cask, installed *after* `chezmoi init`. Its resolved path is stored as `data.onepassword.app_path`, never used to gate the prompts |
| `op` CLI | optional | Brewfile cask `1password-cli` |
| 1Password → Settings → Developer → *Integrate with 1Password CLI* | optional | **GUI-only.** Without it `op` is present but not signed in, so `onepassword_cli` stays amber |
| 1Password SSH agent + an SSH key item | optional | **GUI-only.** Needed for `ssh_signing_key` and `github_ssh` to go green |
| An SSH key registered with GitHub | optional | until then `git_remote_ssh` stays amber and the origin remains HTTPS |

On Linux, stages 1 and 2 are no-ops and 6 of the 13 `.chezmoiscripts/` hooks
are gated on `chezmoi.os == "darwin"` — including the Homebrew, Brewfile and
mise installers. A Linux host gets the dotfiles but not the macOS provisioning
chain.

## The six stages

| Stage | Name | Behaviour |
| --- | --- | --- |
| 0 | preflight (read-only) | reports OS version, arch, network, free disk, sudo cache and the 1Password agent socket, then prints the full `bootstrap-status` table when that tool is available — otherwise a minimal inline probe of CLT, Xcode, license, Homebrew, chezmoi, `1Password.app` and `op`. Never aborts, changes nothing |
| 1 | Command Line Tools gate | if CLT is absent, explains why it matters, runs `xcode-select --install`, then polls with a visible countdown (default timeout 15 min, interval 10 s). On a TTY, `s` skips/defers and `r` re-raises the dialog. Skip or timeout → deferred, continue. Never exits |
| 2 | Xcode + license gate | asks whether full Xcode is wanted (default **no** — CLT suffices). If Xcode is present but the license is not accepted, offers `sudo xcodebuild -license accept` (plus `-runFirstLaunch` and `xcode-select -s`), re-checking up to 3 times. If Xcode is absent but wanted, prints how to get it and defers. Never exits |
| 3 | chezmoi bootstrap | creates required dirs, installs chezmoi (prefers `brew install chezmoi` when brew exists, else the `git.io/chezmoi` curl installer), then runs `chezmoi init --apply`. Passes `--use-builtin-git=true` when CLT is deferred. Does **not** `exec`, so later stages still run after a failure |
| 4 | converge loop | up to `--max-passes` (default 5) rounds of `chezmoi apply --keep-going --use-builtin-git=…`, re-reading `~/.cache/chezmoi/bootstrap-status.txt` after each. Stops on `green`, or when two consecutive passes produce the same `id`/`state` pairs (stall = no further progress without human action). Between passes it prints the amber/red checks with concrete remediation and, on a TTY, asks you to fix them and press Enter, or type `q` to finish |
| 5 | postflight report | re-runs `bootstrap-status`, prints the full table, then a **manual actions** checklist containing only the items that are actually amber/red. Exits 0 even when things are deferred |

Between stages 2 and 3, `install.sh` exports `BOOTSTRAP_DEFER_CLT` and
`BOOTSTRAP_DEFER_XCODE` so the chezmoi hooks started by stages 3 and 4 can see
the gate outcomes; they mirror the `bootstrap.defer_clt` /
`bootstrap.defer_xcode` data keys.

## `bootstrap-status`

A strictly read-only reporter. It never mutates anything, never prompts, never
requires a TTY, and never prints a secret value (for `secrets` it reports only
variable *names* and whether each resolved). It always exits 0 for a valid
invocation; usage errors exit 2. **It is a reporter, not a gate.**

It runs on a bare Mac with no Homebrew, no chezmoi, no `jq` and no Command
Line Tools — only `/bin`, `/usr/bin` and `/usr/sbin` utilities are assumed,
and every optional tool is guarded with `command -v`. When `chezmoi data` is
unavailable it falls back to a pure-bash parser of
`~/.config/chezmoi/chezmoi.yaml`.

### Modes

| Invocation | Effect |
| --- | --- |
| `bootstrap-status` | human-readable table + write both cache files |
| `bootstrap-status --json` | emit the JSON document (also writes the cache) |
| `bootstrap-status --quiet` | emit only the overall word: `green`\|`amber`\|`red` |
| `bootstrap-status --check <id>` | evaluate and print a single check (never writes the cache — the document is partial) |
| `bootstrap-status --no-write` | do not write the cache files, stdout only |
| `bootstrap-status --help` | help |

### The 14 checks, in evaluation order

```
clt  xcode  xcode_license  homebrew  chezmoi  onepassword_app
onepassword_cli  onepassword_vault  ssh_signing_key  github_ssh
brewfile  mise  secrets  git_remote_ssh
```

### States

| State | Meaning |
| --- | --- |
| `green` | satisfied, or not applicable on this host |
| `amber` | **deferred** — will converge on a later pass, or needs a human at the GUI |
| `red` | **actionable now** |

`overall` is `red` if any check is red, else `amber` if any is amber, else
`green`.

### Cache files

Written atomically (temp file in the same directory, then `mv`), mode `0600`,
in a `0700` directory:

```
~/.cache/chezmoi/bootstrap-status.json
~/.cache/chezmoi/bootstrap-status.txt    # exactly one word: green|amber|red
```

The `.txt` file is what the stage 4 converge loop reads. Override the directory
with `BOOTSTRAP_STATUS_DIR`; override the fallback config path with
`BOOTSTRAP_CHEZMOI_CONFIG`.

## Manual actions only a human can do

Stage 5 prints the per-check remediation for whatever is amber/red, plus — once
Homebrew is green — this GUI-only block. These cannot be automated:

- [ ] **Karabiner-Elements** — System Settings → Privacy & Security → approve
      the driver extension, then reboot if prompted
- [ ] **Little Snitch / Micro Snitch** — System Settings → Privacy & Security →
      allow the system extension
- [ ] **OrbStack** — approve the privileged helper on first launch
- [ ] **Accessibility / Input Monitoring** — System Settings → Privacy &
      Security → grant to Hammerspoon, Alfred, AutoRaise, Homerow, Karabiner
- [ ] **1Password** — Settings → Developer → enable *Integrate with 1Password
      CLI* (fixes `onepassword_cli` amber)
- [ ] **1Password** — Settings → Developer → enable the *SSH agent*, add the
      SSH key item, and approve the agent prompt when it appears (fixes
      `ssh_signing_key` / `github_ssh`)
- [ ] `mas signin` — the Brewfile installs `mas`; the repo currently has no
      `mas` entries
- [ ] `sudo xcodebuild -license accept` — only if you install full Xcode
- [ ] `xcode-select --install` — only if you skipped or timed out at stage 1
- [ ] `set-shell-zsh` — registers Homebrew zsh in `/etc/shells`; no chezmoi
      hook does this
- [ ] `exec zsh -l` — reload the shell

## How convergence works

Two chezmoi facts are load-bearing:

1. chezmoi records a `run_once_` / `run_onchange_` script as done **only when
   it exits 0**.
2. A `run_onchange_` script re-runs when its own *rendered content* changes.

Every bootstrap script therefore embeds a **dependency hash comment** covering
everything it needs — tool presence, config values, resolved-file presence. For
example `run_onchange_after_40-install-brew-apps.sh.tmpl`:

```
# dep hash: brewfile={{ include "private_dot_config/exact_homebrew/Brewfile.tmpl" | sha256sum }}
# dep hash: brew={{ if lookPath "brew" }}yes{{ else }}no{{ end }}
# dep hash: brew-bin={{ if or (stat "/opt/homebrew/bin/brew") (stat "/usr/local/bin/brew") }}yes{{ else }}no{{ end }}
```

When a prerequisite appears, the rendered content changes, the hash changes,
and chezmoi re-runs the script automatically. Combined with the exit-code rule:

| Situation | Script behaviour |
| --- | --- |
| prerequisite absent | log `deferred: …` and **exit 0** — the dep hash flips later and re-runs it |
| prerequisite present, operation genuinely failed | **exit non-zero** — chezmoi does not mark it done, so it retries |

The machine converges over successive applies instead of getting stuck. This
is why the old `run_once_*` scripts were fatal to a fresh install: they turned
every failure into a warning plus `exit 0`, so chezmoi marked them done and
never retried.

### Script ordering

chezmoi runs, in order:

1. `run_before_*` scripts, alphabetically;
2. target-state updates, alphabetically by attribute-stripped target name, with
   scripts interleaved with files (`.` sorts before digits, so all dotfiles are
   applied before `20-install-homebrew.sh`);
3. `run_after_*` scripts, alphabetically.

`run_before_10-obsidian-vault-dirs` must be a `before_` script because it
creates directories that chezmoi then applies files into.

### Current `.chezmoiscripts/`, in execution order

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

(`ls .chezmoiscripts/` lists these alphabetically, which is *not* the
execution order.)

### The chezmoi data schema

`.chezmoi.yaml.tmpl` renders `~/.config/chezmoi/chezmoi.yaml`:

```yaml
data:
  onepassword:
    enabled: <bool>            # use 1Password for SSH signing and secrets
    vault: <string>            # e.g. "Private"
    account: <string>          # optional account shorthand
    ssh_key_item: <string>     # 1Password item NAME or UUID holding the SSH key
    ssh_signing_key: <string>  # LEGACY — the old pasted public key
    app_path: <string>         # resolved 1Password.app path, or ""
  git:
    email: <string>
    name: <string>
    profile: |
      [user]
        email = <email>
        name = <name>
    profiles: []
  secrets:
    TSTRUCT_TOKEN: <string>    # op://vault/item/field reference, or "-" to skip
  envvars: []                  # LEGACY list of "NAME=value"
  bootstrap:
    defer_clt: <bool>
    defer_xcode: <bool>
```

The git **signing block no longer lives in the data**. It moved to
`private_dot_config/exact_git/private_profile.tmpl` and is gated on *resolved*
state (`stat ~/.config/git/ssh-signing-key`), which is why a correct git config
no longer needs a second `chezmoi apply`.

### Resolved-state files

Generated by the hooks, mode `0600`, and listed in `.chezmoiignore`:

| Path | Written by | Meaning |
| --- | --- | --- |
| `~/.config/git/ssh-signing-key` | `run_onchange_after_70-resolve-1password.sh.tmpl` | one line: the SSH **public** key resolved from the 1Password item. Its presence is what enables `signingKey`, `[gpg "ssh"]`, `allowed_signers` and the `insteadOf = "https://github.com/"` rewrite |
| `~/.config/sh/secrets.env` | same | `export NAME='<value>'` lines resolved from `data.secrets` via `op read`. Sourced by `.zprofile` rather than rendered inline, so a locked or absent 1Password never blocks login |
| `~/.cache/chezmoi/bootstrap-status.json` / `.txt` | `run_after_99-bootstrap-status.sh.tmpl` | the status document |

These are **not** authored config. Never edit them by hand; delete them and
re-run `chezmoi apply` to force regeneration.

> `~/.config/git` is an `exact_` directory, so chezmoi deletes any file in it
> that is not in the source state. The `.chezmoiignore` entry for
> `.config/git/ssh-signing-key` is load-bearing — without it every apply would
> wipe the resolved key.

### Two Brewfile notes

`HOMEBREW_BUNDLE_FILE_GLOBAL` is exported (in `.zprofile`, and pinned for the
probe in the brew hook) so `brew bundle --global` resolves
`~/.config/homebrew/Brewfile` deterministically instead of falling through to
`~/.Brewfile` in environments where `XDG_CONFIG_HOME` is unset.

`HOMEBREW_BREWFILE` is **not** a Homebrew variable — it appears nowhere in
Homebrew's source. Do not "simplify" the above to it.

The Tokyo Night Storm shiki theme is **vendored** at
`MeinCodex/Notizen/Obsidian/Main/dot_obsidian/shiki-themes/tokyo-night-storm.json`
rather than downloaded via `.chezmoiexternal.toml` with
`filter.command = "python3"`. On a fresh Mac `/usr/bin/python3` is a CLT shim,
so that filter died with `xcrun: error: invalid active developer path` and
aborted the entire apply. Re-vendor by hand if the upstream theme changes.

## Migrating an existing machine

**An existing host's `~/.config/chezmoi/chezmoi.yaml` predates the current
schema, and chezmoi will not fix it for you.**

chezmoi does **not** regenerate the config file when `.chezmoi.yaml.tmpl`
changes. On a plain `chezmoi apply` it only prints:

```
warning: config file template has changed, run chezmoi init to regenerate config file
```

Every template is now `hasKey`-guarded, so an old config still *renders* — but
the new features stay inert: `onepassword.enabled` reads as absent, `secrets`
as an empty dict, `bootstrap.*` as `false`. To actually get the new behaviour
you must re-run `chezmoi init`. The easy way:

```sh
sh install.sh --reprompt
```

That passes `--prompt` to `chezmoi init`, re-asking every value. (Plain
`chezmoi init` also works and preserves existing answers, but will not re-ask
values that are already set.)

### `envvars` → `secrets`

The legacy `data.envvars` list was a hand-maintained set of `"NAME=value"`
strings rendered inline into `.zprofile` — plaintext credentials living
outside 1Password, and not reproducible on a new machine.

- Existing `envvars` entries are **preserved verbatim across a re-init**, so a
  re-render never silently drops a live entry, and they are still exported.
- `.zprofile` renders them *after* the `secrets.env` source line, so migrated
  values win.
- Migrate each one: put the value in a 1Password item, add
  `NAME: op://vault/item/field` under `data.secrets`, then delete it from
  `envvars`. `run_onchange_after_70-resolve-1password` writes it to
  `~/.config/sh/secrets.env` (mode `0600`).

`bootstrap-status` reports the leftover for you:

```
amber  secrets  no .secrets configured — legacy .envvars still holds 1 entry;
                run 'install.sh --reprompt' to migrate it
```

## Troubleshooting / recovery

| Symptom | Cause | Fix |
| --- | --- | --- |
| A prompt value is stuck empty and never re-asks | a pre-fix config stored `""`, and `promptStringOnce` returns the stored value whenever the key exists | `sh install.sh --reprompt` (or `chezmoi init --prompt`) |
| `warning: config file template has changed` | chezmoi never regenerates the config on apply | `sh install.sh --reprompt` (or `chezmoi init`) |
| A `run_once_` / `run_onchange_` step was skipped and never retries | chezmoi recorded it as done in the `scriptState` bucket | `chezmoi state delete-bucket --bucket=scriptState`, then `chezmoi apply`. See the note below for a single script |
| `xcrun: error: invalid active developer path` | `/usr/bin/git`, `/usr/bin/python3` etc. are CLT shims | `xcode-select --install`, then `sh install.sh` |
| `op` present but `onepassword_cli` amber | CLI integration is off, so `op account list` fails | 1Password → Settings → Developer → enable *Integrate with 1Password CLI* |
| `ssh_signing_key` red | `~/.config/git/ssh-signing-key` was not resolved | unlock 1Password, approve the signing request, re-run `chezmoi apply` |
| `github_ssh` amber with "probe timed out … waiting for interactive approval" | the agent socket is reachable but 1Password is waiting on a GUI approval | unlock/approve in the 1Password app, then re-run |
| `brewfile` red | Brewfile has missing entries | re-run `chezmoi apply`; check which casks need GUI approval |
| `git_remote_ssh` red | GitHub SSH works but the origin is still HTTPS | `chezmoi apply` — the switch-to-ssh hook rewrites it |
| `git_remote_ssh` amber | the origin is HTTPS and GitHub SSH is not green yet | deferred until the SSH agent works |
| `mise` red | declared tool versions are not installed | `mise install` |
| `secrets` red | `~/.config/sh/secrets.env` is missing, not `0600`, or stale | unlock 1Password, re-run `chezmoi apply` |
| What is outstanding right now? | — | `bootstrap-status` (read-only) |

**Re-running a single script.** `chezmoi state delete-bucket` takes only
`--bucket`; it clears *every* recorded script. The `scriptState` bucket is keyed
by a sha256 of the script's rendered content, not by its name, so to clear one
script look up its key first:

```sh
chezmoi state get-bucket --bucket=scriptState        # find the key whose "name" matches
chezmoi state delete --bucket=scriptState --key=<KEY>
```

Check `chezmoi state --help` for the full set (`data`, `delete`,
`delete-bucket`, `dump`, `get`, `get-bucket`, `reset`, `set`).

## Repository layout

`AGENTS.md` has the detailed map, the prefix semantics and the child
`AGENTS.md` files (`dot_local/bin/`, `private_dot_config/exact_nvim/`,
`private_dot_config/exact_aider-desk/`, `MeinCodex/Notizen/Obsidian/`). The
short version:

| Source | Target | Contents |
| --- | --- | --- |
| `dot_zshenv.tmpl` | `~/.zshenv` | every-shell environment: XDG paths, `ZDOTDIR`, Zim/mise |
| `private_dot_config/exact_zsh/` | `~/.config/zsh/` | `.zprofile`, `.zshrc`, `zimrc.zsh`, completions |
| `private_dot_config/sh/` | `~/.config/sh/` | `lib.sh`; `secrets.env` is generated here, not tracked |
| `private_dot_config/exact_git/` | `~/.config/git/` | `config`, `profile`, `allowed_signers`, `ignore`, hooks |
| `private_dot_config/exact_homebrew/` | `~/.config/homebrew/` | `Brewfile` |
| `private_dot_config/exact_mise/` | `~/.config/mise/` | `config.toml` and `conf.d/` fragments |
| `private_dot_config/exact_nvim/` | `~/.config/nvim/` | Neovim config |
| `private_dot_config/exact_aider-desk/` | `~/.config/aider-desk/` | agent profiles, rules, skills |
| `dot_local/bin/` | `~/.local/bin/` | executable utilities, incl. `bootstrap-status` |
| `dot_tmux.conf`, `dot_tmux/` | `~/.tmux.conf`, `~/.tmux/` | tmux |
| `MeinCodex/Notizen/Obsidian/` | `~/MeinCodex/Notizen/Obsidian/` | vault config (notes are not tracked) |
| `.chezmoiscripts/` | *not deployed* | apply-time hooks |
| `.chezmoitemplates/` | *not deployed* | shared shell fragments for those hooks |
| `.chezmoiexternal.toml` | — | downloaded dependencies |
| `.chezmoiignore` | — | target exclusions (incl. `README.md`, `AGENTS.md`, `install.sh`) |
| `.chezmoiremove` | — | obsolete target paths to delete on apply |

## Development / validation

`chezmoi apply` and `install.sh` **mutate the machine** — they install packages,
rewrite links and profiles, and can restart terminals. They are not validation
tools.

Safe, read-only checks:

```sh
bootstrap-status                                   # resolved bootstrap state
sh install.sh --dry-run                            # walk every stage, execute nothing
chezmoi --source "$PWD" source-path                # source → target mapping
chezmoi --source "$PWD" target-path <source-path>
chezmoi --source "$PWD" --refresh-externals=never managed \
  --include files --path-style source-relative
chezmoi --source "$PWD" --refresh-externals=never --use-builtin-diff diff <target>
chezmoi execute-template '{{ .chezmoi.os }}'       # test a template expression
shellcheck <script>                                # render .tmpl first
git diff --check                                   # whitespace errors
```

Notes:

- Render `.tmpl` files before shellchecking them — the Go template syntax is
  not valid shell.
- `chezmoi diff` with no target can be very slow here: it evaluates all
  1Password-templated source before filtering. Pass a concrete target, or use
  `chezmoi status` for a fast added/modified/deleted summary.
- There is no root build, CI workflow, or repository-wide test runner.
