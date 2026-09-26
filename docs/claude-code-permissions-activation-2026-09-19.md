# Claude Code permissions: implemented source change and activation record

Implemented 2026-09-19, **activated and verified 2026-09-20**, against CLI
2.1.267 (Homebrew, darwin-arm64).
Companion to `docs/claude-code-permissions-review-2026-09-19.md`.

Sections 1–2 describe the 2026-09-19 source change, when only
`dot_claude/settings.json` had been touched and nothing had been applied.
Sections 3–4 record activation and the verification run that followed on
2026-09-20. Nothing here has been committed.

**Current state:** activation is complete. The effective mode is `auto`, no
blanket `rm` / `chmod` ask rules survive in any inspected settings source, and
the disposable `chmod +x` and `rm` checks run without an approval prompt.
Section 4 has the evidence, including what was *not* tested.

## 1. What changed in the managed source

`dot_claude/settings.json` maps to `~/.claude/settings.json`
(`chezmoi --source "$PWD" target-path dot_claude/settings.json`). It is a whole
file, not a merge patch, so an apply replaces live user settings entirely.

| Area | Change | Why |
| --- | --- | --- |
| JSON validity | Removed two trailing commas | `jq` and `claude doctor` both rejected the old source; it could not deploy |
| Spelling | `attrubution` → `attribution` | The misspelled key was inert; attribution settings never took effect |
| Mode | `defaultMode: acceptEdits` → `auto` | Matches the live preference; `auto` is supported and is the mode this session ran in |
| Prompts | Removed `Bash(rm *)` and `Bash(chmod *)` from `ask` | These are the rules that forced approval on routine cleanup and `chmod +x` |
| Sandbox | Added `sandbox.enabled: true`, `sandbox.autoAllowBashIfSandboxed: true` | Documented global baseline; sandboxed Bash is auto-allowed instead of prompted |
| Sandbox | Removed `env.CLAUDE_CODE_DISABLE_SANDBOX` | Not present in the installed binary (see validation); an unsupported legacy entry |
| File rules | `Read(**/*key*)` → deliberate key-material patterns | The substring rule blocked 11 ordinary files in this repo (evidence below) |
| File rules | `Read(**/*secret*)` → deliberate secret patterns | Same defect: it blocked `exact_aider-desk/exact_rules/SECURITY-01-SECRETS-AND-INPUTS.md` |
| File rules | `Write(path)` denies → `Edit(path)` denies | `Write(path)` is not the current file-permission mechanism; `Edit` is |
| Stale rule | Dropped `Write(*)` from `allow` | Inert under current semantics. Converting it to `Edit(*)` would have created a blanket edit allowance that does not exist today, so it was removed rather than translated |
| Classifier | `autoMode` not carried into source | The live block describes the `santifer/career-ops` project; that is wrong context for dotfiles and does not belong in Git |

Retained unchanged, deliberately: every `Bash(rm -rf ...)` deny, `Bash(sudo *)`,
`Bash(git reset *)`, `Bash(git rebase *)`, the `.env` protections, and the
`wget` / `curl` / `git merge` asks.

Portable live preferences were carried into the source so an apply does not
regress them: `model: claude-opus-5[1m]`, `enabledPlugins`, `editorMode: vim`,
`viewMode`, `effortLevel`, `agentPushNotifEnabled`, `companyAnnouncements`,
`skipDangerousModePermissionPrompt`, `autoUpdater`, `attribution`, and the three
`env` timeout/updater entries. No credentials, trusted checkout paths, project
details, or runtime state were imported.

### Why this reduces prompts

Precedence is deny > ask > allow, and a narrower allow never overrides a broader
ask or deny. `Bash(chmod +x *)` in `allow` could not have beaten `Bash(chmod *)`
in `ask`; the ask entry had to be deleted from every file that contributes it.
With the asks gone, a sandboxed `chmod` or `rm` is resolved by
`autoAllowBashIfSandboxed` instead of an approval prompt.

Permission arrays combine across settings files, so this is a partial fix until
step 3 below is done.

### Key-material rules: replacement, not removal

Before: `Read(**/*key*)` and `Read(**/*secret*)`.
After: explicit `id_rsa*` / `id_ed25519*` / `id_ecdsa*` / `id_dsa*`, `**/.ssh/**`,
`**/.gnupg/**`, `*.key`, `*_key`, `*.pem`, `*.p12`, `*.pfx`, `*.keystore`, `*.jks`,
`*keyring*`, `**/secrets/**`, `**/.secrets/**`, `secrets.*`, `*.secret`, `*_secret`,
plus the unchanged `**/*token*` and `.env` families.

The `.ssh` and `.gnupg` entries are written as directory-wide `Read` denies,
since reading a private key is the real risk. How broadly they actually resolve
was not verified — see the path-scope correction below.

**Correction (2026-09-20).** An earlier draft of this section claimed that
because the `Edit` denies list key files rather than those directories,
`~/.ssh/config` "stays editable". That is wrong, and the reasoning behind it was
wrong in a way worth stating plainly: a `Read` deny is not read-only in effect.

- The `Edit` tool requires a prior successful `Read` of the file in the same
  conversation. A path you cannot read is therefore a path you cannot edit,
  whether or not an `Edit` rule names it.
- The sandbox refuses *writes* to key-shaped paths. Observed directly: creating
  a throwaway `_git-ignored/cc-permcheck/dummy.pem` through Bash failed with
  `operation not permitted`.

  **Correction (2026-09-20, second pass).** An earlier version of this bullet
  added "purely because `Read(**/*.pem)` matches it. No `Edit` or `Write` rule
  was involved." That inference was unsound. `Edit(**/*.pem)` *is* configured in
  `~/.claude/settings.json`, alongside `Read(**/*.pem)`. Both rules match the
  path, so the observation shows only that the write was blocked — it does not
  isolate the `Read` deny as the cause, and it is not evidence that a `Read`
  deny alone blocks writes. The first bullet above (no `Read`, therefore no
  `Edit`) still stands on its own; this one does not carry the extra weight it
  was given.
- Path scope, **not verified**: the rule as written is `Read(**/.ssh/**)`. Read
  literally, that would match everything beneath any `.ssh` directory —
  `config` and `known_hosts` as much as `id_ed25519`. Two things argue against
  treating that reading as settled: the runtime sandbox renders the
  corresponding entry as `**/.ssh` without the trailing `/**`, and the rule's
  anchoring (repo-relative vs. absolute, and whether `**/` crosses a leading
  `~`) was never established. The effective scope is therefore unknown.

So the status of `~/.ssh/config` under these rules is **undetermined**. It may
well be both unreadable and uneditable, which would be a defensible default but
a real cost — not the free lunch the original text implied. It is equally
possible the rule anchors more narrowly than its text suggests. Do not plan
around either reading without testing the specific path first.

If you want Claude to manage SSH config, the change is the same either way:
narrow to private-key names (the `id_*`, `*.pem`, `*.key` entries already
present) and drop the directory-wide `Read(**/.ssh/**)` — deliberately, not by
assuming an `Edit`-rule gap leaves an opening.

Scope note: the path-scope bullet is reasoned from glob semantics alone. It was
not tested against a real `~/.ssh` file, and testing it that way would mean
touching real key material. The `*.pem` observation does not substitute for that
test, for the reason given above.

## 2. Validation performed

Read-only. No model or paid analysis service was invoked, and no destructive
command was run against real files.

- **Strict JSON**: `jq empty dot_claude/settings.json` passes. A Python
  `object_pairs_hook` parse confirms no duplicate keys and no duplicate entries
  in `allow` / `deny` / `ask`.
- **Doctor**: `claude --settings dot_claude/settings.json doctor` previously
  reported `Invalid settings … Expected object, but received undefined`. That
  finding is gone. (Its unrelated macOS keychain warning is an artifact of this
  execution environment, not a settings problem.)
- **`git diff --check`**: clean.
- **Source-to-target mapping**: confirmed as `~/.claude/settings.json`.
- **chezmoi diff**: inspected with
  `chezmoi --source "$PWD" --refresh-externals=never --no-pager --use-builtin-diff diff ~/.claude/settings.json`.
  Nothing was applied.
- **Preference-loss check**: a key-by-key comparison of live vs. new source shows
  the only removals are `autoMode` (intended), `env.CLAUDE_CODE_DISABLE_SANDBOX`
  (unsupported), `Write(*)`, `Read(**/*key*)`, `Read(**/*secret*)`, the nine
  `Write(path)` denies, and the two rm/chmod asks. Every other live key and value
  is preserved.
- **`CLAUDE_CODE_DISABLE_SANDBOX`**: absent from the installed executable. The
  sandbox-related names it does contain are `CLAUDE_CODE_FORCE_SANDBOX`,
  `CLAUDE_CODE_SANDBOXED`, and `CLAUDE_CODE_BASH_SANDBOX_SHOW_INDICATOR`. The
  settings keys `autoAllowBashIfSandboxed`, `allowUnsandboxedCommands`, and
  `excludedCommands` are all present.
- **`Edit(path)` syntax**: the installed binary carries `Edit(**/*.env)`,
  `Read(**/.env)`, and `Read(**/secrets/**)` as rule examples, confirming `Edit`
  as the current write-restriction form.

### Live evidence that the broad key rule was actively breaking things

Under the current live rules, `git status` in this checkout reports
`Operation not permitted` for eleven tracked files, and
`chezmoi diff` cannot walk the source tree at all:

```
MeinCodex/Notizen/Obsidian/Main/dot_obsidian/hotkeys.json
dot_local/bin/executable_new-ssh-key
private_dot_config/exact_aider-desk/exact_rules/SECURITY-01-SECRETS-AND-INPUTS.md
private_dot_config/exact_gitui/key_bindings.ron
private_dot_config/exact_kitty/pass_keys.py
private_dot_config/exact_nvim/exact_lua/exact_config/keymaps.lua
private_dot_config/exact_nvim/exact_lua/exact_plugins/which-key.lua
private_dot_config/exact_nvim/exact_lua/exact_utils/keymaps_dump.lua
private_dot_config/exact_wezterm/keybinds.lua
private_dot_config/exact_zed/keymap.json
private_dot_config/yazi/keymap.toml
```

`chezmoi: lstat …/hotkeys.json: operation not permitted` — the repository's own
documented diff command fails because of `Read(**/*key*)`. No tracked file matches
any of the replacement patterns.

### Limitations

- Nothing here proves runtime behavior. The permission engine was not exercised;
  a glob approximation was used only to illustrate pattern coverage and is not a
  substitute for Claude's matcher. Section 4 is the real test.
- `claude doctor` could not fetch remote managed policy in this environment
  (Pro/Max account, not applicable). A managed policy, if one ever applies, would
  override all of this.
- `Bash(rm -rf *)` remains a deny, by design. Recursive directory cleanup will be
  **blocked outright**, not prompted. Use `rm file` or `rmdir` for disposable
  fixtures. This is the intended destructive-operation boundary, not a regression.

## 3. Activation: steps as issued, and completion status

> **Status: completed 2026-09-20.** All three steps below have been carried out.
> The instructions are kept as originally written, each annotated with what was
> observed afterwards. Section 4 records the verification run.
>
> - **Step 1 — done.** The `permissions` and `sandbox` blocks in live
>   `~/.claude/settings.json` are identical to the managed source
>   (`diff` over `jq -S '{permissions,sandbox}'`: no output). See the apply-drift
>   note under Step 1 for the one key where live and source now differ.
> - **Step 2 — done.** The reconciled `.claude/settings.local.json` is installed.
>   It contributes no `Bash(rm *)`, no `Bash(chmod *)`, no `defaultMode`, no
>   `Write(*)`, and no broad `Read(**/*secret*)`.
> - **Step 3 — done.** Verification ran in a session started after both files
>   were in place.

*The rest of this section is the handoff as written on 2026-09-19, preserved
verbatim and read in the present tense of that date. Dated notes record what was
observed on activation.*

Source completion is not activation. Until these run, the blanket rm/chmod asks
remain in force in this repository, because permission arrays combine.

**Step 1 — deploy the managed source (scoped, no install hooks):**

```sh
chezmoi --source "$PWD" apply ~/.claude/settings.json
```

This rewrites `~/.claude/settings.json` and removes the live `autoMode.environment`
block. That removal is intended: it describes `santifer/career-ops`, not this or
any other repo. Project-specific behavioral context belongs in a `CLAUDE.md`;
project and local settings files are not read for classifier configuration, so
moving `autoMode` into `.claude/settings.local.json` would not work.

**Apply-drift note (2026-09-20).** The `career-ops` classifier block is gone, as
intended — it now survives only as that project's own unrelated entry under
`projects.` in `~/.claude.json`, which is ordinary per-project state. But live
`~/.claude/settings.json` has since been rewritten by an `auto-mode-setup` run
and no longer matches the managed source textually:

- **Key order differs.** The live file was regenerated with a different key
  ordering, so a plain `chezmoi diff` now shows a large, mostly cosmetic hunk.
  JSON object order is not semantic; this is noise, not a settings difference.
- **A new `autoMode.environment` block exists, live-only.** This one describes
  *this* repository (private `github.com/neumachen/dotfiles`, trusted checkout
  path, sensitive-template notes), not `career-ops`. It is appropriate content,
  and it was not carried into the source — consistent with the section 1
  decision to keep classifier context out of Git.
- **What actually matters is unchanged.** `diff` over
  `jq -S '{permissions,sandbox}'` between source and live produces no output.
  The permission and sandbox configuration this document is about is identical
  in both.

Consequence worth knowing before the next apply: re-running
`chezmoi --source "$PWD" apply ~/.claude/settings.json` **will delete the new
`autoMode` block**, because the source is a whole file and carries no `autoMode`
key. That is the same whole-file behavior described in section 1, now pointed at
content worth keeping. Re-run `auto-mode-setup` afterwards, or accept the loss
deliberately. No apply was run in the course of this verification.

**Step 2 — reconcile the Git-ignored repository-local file.**

`.claude/` is ignored in full (`.gitignore:54`), so there is no tracked project
settings file and `.claude/settings.local.json` must be edited by hand. It still
contributes `Bash(rm *)`, `Bash(chmod *)`, an `acceptEdits` mode override, and a
broad `Read(**/*secret*)` deny.

```sh
jq '
    .permissions.ask   -= ["Bash(rm *)", "Bash(chmod *)"]
  | .permissions.allow -= ["Write(*)"]
  | del(.permissions.defaultMode)
  | .permissions.deny  -= [
      "Read(**/*secret*)",
      "Write(.env)", "Write(.env.local)", "Write(.env.development)", "Write(.env.production)",
      "Write(**/.env)", "Write(**/.env.local)", "Write(**/.env.development)", "Write(**/.env.production)",
      "Write(**/*secret*)"
    ]
  | .permissions.deny += [
      "Read(**/secrets/**)", "Read(**/.secrets/**)", "Read(**/secrets.*)",
      "Read(**/*.secret)", "Read(**/*_secret)",
      "Edit(.env)", "Edit(.env.local)", "Edit(.env.development)", "Edit(.env.production)",
      "Edit(**/.env)", "Edit(**/.env.local)", "Edit(**/.env.development)", "Edit(**/.env.production)",
      "Edit(**/secrets/**)", "Edit(**/.secrets/**)", "Edit(**/secrets.*)",
      "Edit(**/*.secret)", "Edit(**/*_secret)"
    ]
' .claude/settings.local.json > "$TMPDIR/settings.local.json" \
  && mv "$TMPDIR/settings.local.json" .claude/settings.local.json
```

**This step must be run by you, not by Claude (verified 2026-09-20).** Claude
Code carves its own settings files out of the Bash sandbox's writable area:
`.claude/settings.local.json`, `~/.claude/settings.json`, and the
managed-settings paths appear in the sandbox `write.denyWithinAllow` list even
though the repository itself is writable. An attempted atomic replace failed
with `mv: cannot move … Operation not permitted`, leaving the file byte-identical
to its backup. That guard is deliberate — settings define the permission system,
so the agent does not get to rewrite them. Do not disable the sandbox or reach
for another tool to get around it.

A ready-to-install, pre-validated copy and an idempotent jq program are staged
outside Git at `_git-ignored/claude-settings-backups/`, alongside a timestamped
mode-600 backup of the original. The minimal manual command is:

```sh
cp _git-ignored/claude-settings-backups/settings.local.json.reconciled \
   .claude/settings.local.json
```

`cp` onto the existing file preserves its mode (644). **This is the procedure
that was actually used on 2026-09-20**; prefer it. To regenerate instead of
copying — safe to re-run, as the program de-duplicates rather than appending:

```sh
tmp=$(mktemp "$TMPDIR/cclocal.XXXXXXXX.json")
jq -f _git-ignored/claude-settings-backups/reconcile-local.jq \
   .claude/settings.local.json > "$tmp" \
  && cat "$tmp" > .claude/settings.local.json \
  && rm "$tmp"
```

**Portability correction (2026-09-20).** The regeneration snippet previously
ended with `chmod "$(stat -c '%a' …)" "$tmp" && mv "$tmp" …`. `stat -c` is the
GNU form; stock macOS ships BSD `stat`, where the spelling is `stat -f '%Lp'`
and `-c` fails. The command happens to work on *this* machine only because
Homebrew coreutils puts GNU `stat` ahead of `/usr/bin/stat` on `PATH` (verified:
`stat -c '%a'` returns `644`, `stat -f '%Lp'` errors, and `gstat` resolves to
`/opt/homebrew/bin/gstat`). That is an accident of this `PATH`, not something to
rely on.

The form above sidesteps the question: redirecting onto the existing file
truncates it in place, so mode and inode are preserved without consulting `stat`
at all, on either platform. It also drops the `mv`, which is what the sandbox
blocks for this path (see the note below).

What that does and why:

- Removes the duplicated `rm` / `chmod` asks. Required — deleting them from the
  global file alone leaves these effective.
- Deletes the local `defaultMode` so the global `auto` preference applies.
  Local scalar settings override user settings, which is why `acceptEdits` wins today.
- Narrows `Read(**/*secret*)`. Without this, `SECURITY-01-SECRETS-AND-INPUTS.md`
  stays unreadable even after step 1, because the local file contributes the rule.
- Converts the stale `Write(path)` denies to `Edit(path)`.

Deliberately **kept**: every genuinely local approval — `wezterm` / `tmux` /
`nvim` / `stylua` / `lua` / `hs` / `python3` / `gh api` / `chezmoi apply`
entries, the `Read(...)` allows for the smart-splits plugin directories, the
extra `WebFetch` domains, the local `sandbox` block (now redundant with the
global one but harmless), and the already-narrow
`Read(**/*.key)`, `Read(**/*_key)`, `Read(**/*keyring*)` denies.

**Step 3 — restart the Claude Code session.** Settings are read at startup.

## 4. Post-activation verification (performed 2026-09-20)

Run in a session started after steps 1–3, against CLI 2.1.267. No settings, Git
configuration, or sandbox policy were changed during verification.

### Resolved configuration

| Check | Result |
| --- | --- |
| Effective permission mode | **`auto`** |
| Blanket `Bash(rm *)` / `Bash(chmod *)` asks | **None**, in any inspected source |
| Sandbox | **`enabled: true`**, **`autoAllowBashIfSandboxed: true`** |
| `defaultMode` occurrences | Exactly one: `"auto"` in `~/.claude/settings.json` |
| Local `acceptEdits` override | **Gone** from `.claude/settings.local.json` |
| Managed / enterprise policy | None present |

Sources inspected for the rm/chmod asks: `~/.claude/settings.json`,
`.claude/settings.local.json`, `dot_claude/settings.json`, and `~/.claude.json`
(including this project's `allowedTools`, which is empty). Zero occurrences in
any of them. There is no `.claude/settings.json` — this repository contributes
only the `.local.json`. No `/Library/Application Support/ClaudeCode/`
managed-settings file or `managed-settings.d` directory exists, and there is no
`policy-limits.json`.

Rule origins for what survives: the three `ask` entries (`wget`, `curl`,
`git merge`), the five `Bash(rm -rf …)` denies, and the `sandbox` block are each
contributed by *both* the global and local files. The narrow `.ssh` / `.gnupg` /
`*.pem` / `*.p12` deny families come from the global file only. The local file
alone contributes the `wezterm` / `tmux` / `nvim` / `stylua` / `lua` / `hs` /
`python3` / `gh api` / `chezmoi apply` approvals, the smart-splits `Read(...)`
allows, and the extra `WebFetch` domains.

**Method note.** These were read directly from the settings files with `jq` and
`grep` rather than through `/permissions`, `/status`, `/sandbox`, or
`claude auto-mode` as section 3 originally suggested. The runtime's own reported
mode and sandbox state agreed with the files. Reading the files establishes what
each layer contributes and from where, which the slash commands do not show; it
does not independently confirm the resolver's precedence arithmetic.

### Behavioral checks — no approval prompt at any point

```sh
mkdir -p _git-ignored/cc-permcheck
printf '#!/bin/sh\necho disposable-probe-ok\n' > _git-ignored/cc-permcheck/disposable-probe.sh
chmod +x _git-ignored/cc-permcheck/disposable-probe.sh   # no prompt; mode became -rwxr-xr-x
./_git-ignored/cc-permcheck/disposable-probe.sh          # no prompt; printed disposable-probe-ok
rm _git-ignored/cc-permcheck/disposable-probe.sh         # no prompt; file removed
```

Every line ran clean — fixture creation, `chmod +x`, executing the resulting
script, and the `rm`. This is the finding the whole change was aimed at:
`chmod +x` and an ordinary `rm` no longer prompt. Every Bash invocation in the
session resolved through `autoAllowBashIfSandboxed`; no approval dialog appeared
for any command.

### File-read checks

All 11 files that the old `Read(**/*key*)` rule had been blocking are readable
again. Which tool was used matters, because the `Read(...)` rules govern the
`Read` tool while Bash reads are governed by the sandbox's own filesystem policy
— so the two paths are worth distinguishing:

- **Bash (`head`/`head -c 1`) — all 11 files.** Every one succeeded, including
  `MeinCodex/Notizen/Obsidian/Main/dot_obsidian/hotkeys.json`,
  `dot_local/bin/executable_new-ssh-key`, and
  `private_dot_config/exact_aider-desk/exact_rules/SECURITY-01-SECRETS-AND-INPUTS.md`
  — the last confirming the local `Read(**/*secret*)` really is gone.
- **`Read` tool — one file**, `private_dot_config/exact_zed/keymap.json`, which
  returned content normally.

Corroborating the narrowing at the sandbox layer: the session's filesystem
read-deny set lists the replacement patterns (`id_rsa*`, `*.pem`, `*keyring*`,
the `.env` family) and contains no `**/*key*` or `**/*secret*` substring rule.

`git status` no longer prints `Operation not permitted` lines.

### Destructive denies — preserved, enforcement untested

All five `Bash(rm -rf …)` entries (`*`, `/`, `~`, `~/*`, `/*`) are present in
`~/.claude/settings.json`, `.claude/settings.local.json`, and
`dot_claude/settings.json`.

This was confirmed **by inspecting the rules, not by triggering them.** No
`rm -rf` was issued, so the runtime enforcement of these denies remains
**untested**. Presence in the configuration is not proof the resolver blocks the
command. Section 2's caveat still applies regardless: the textual rule does not
cover other option orderings such as `rm -fr` or `rm -r -f`, so it is a speed
bump rather than containment.

### Deliberately skipped

- **Credential-shaped fixtures.** The `dummy.pem` test in the original plan was
  not performed — no credential-shaped file was created or read. The deny
  patterns covering `*.pem`, `*.key`, `.ssh`, and the `.env` family are
  therefore confirmed present in configuration but **unexercised at runtime**.
  If you want that evidence, create the fixture yourself outside Claude:

  ```sh
  mkdir -p _git-ignored/cc-permcheck
  printf 'NOT-A-REAL-KEY-JUST-A-FIXTURE\n' > _git-ignored/cc-permcheck/dummy.pem
  ```

  Then ask Claude to read it and expect a denial. Never test against a real key,
  and do not read real credential files to verify. Clean up with
  `rm _git-ignored/cc-permcheck/dummy.pem`.

### Cleanup

The disposable probe script was removed with `rm`, and
`_git-ignored/cc-permcheck/` with `rmdir`. Nothing from the verification run
remains on disk. The staged assets under
`_git-ignored/claude-settings-backups/` (the reconciled copy, the jq program,
and the mode-600 timestamped backup) were left in place.

### Non-blocking observation: fsmonitor socket error

Ordinary `git` commands in this checkout emit:

```
error: fsmonitor_ipc__send_query: unspecified error on '.git/fsmonitor--daemon.ipc'
```

Observed facts:

- The message goes to stderr. The commands still returned correct, usable output
  and exited `0` — `git status --porcelain` listed the expected working-tree
  changes alongside the error.
- `git -c core.fsmonitor=false status` produced no error and the same output.
- `core.fsmonitor` is `true` in this repository, and
  `.git/fsmonitor--daemon.ipc` exists as a Unix domain socket (`srwxr-xr-x`).

The obvious reading is that the Bash sandbox blocks the connection to that
socket, which would make this a sandbox boundary rather than a permission-rule
problem. **That explanation was not confirmed against sandbox policy** — no
policy entry was produced showing the socket denied, and the sandbox was not
disabled to test the contrast. The `core.fsmonitor=false` result is equally
consistent with any failure in the fsmonitor IPC path. Treat the cause as
probable, not established.

Either way it is cosmetic: git falls back to a full scan and returns correct
results. **No Git configuration was changed** — the `core.fsmonitor=false` run
used a one-shot `-c` override. If the noise is unwanted,
`git config core.fsmonitor false` in this checkout would silence it, at the cost
of the fsmonitor speedup.

### Interpreting future prompts

Attribute any prompt that remains to its actual cause — a specific rule and the
file that contributes it, a sandbox boundary, or a classifier decision — rather
than assuming the change failed.

## 5. Optional follow-ups (not implemented)

Separate decisions, deliberately left alone:

1. **`wget` / `curl` / `git merge` asks.** Kept as requested. If these interrupt
   routine work, remove them from `ask` in both the source and the local file and
   let auto mode evaluate them. `curl` is the most likely nuisance; note that
   `AGENTS.md` already directs REST work through the `aiderdesk-api` wrapper.
2. **`Read(**/*token*)`.** The same substring defect as `**/*key*`. **Optional,
   not outstanding** — re-confirmed 2026-09-20: `git ls-files` matches no tracked
   file against `token`, `.ssh/`, or `keyring`, so nothing in this repository is
   blocked by it and the activation is complete without touching it. It would
   block a `tokenizer.*` or `tokens.lua` in another checkout. Narrow it the same
   way if that ever happens.
3. **Broad allowances.** `Bash(npm *)` covers `npm publish`; `Bash(git push *)`
   covers force-push and arbitrary refspecs; `Bash(gh pr *)` covers `merge` and
   `close`; local approvals add `gh api *` (full authenticated GitHub API
   read/write), `lua *`, `python3 -c ' *`, and `chezmoi apply *`. The last one sits
   directly against this repository's source-versus-deployment boundary and is
   worth reconsidering first. Tool pre-approval is not task authorization.
4. **`skipDangerousModePermissionPrompt: true`.** Preserved from live. It only
   suppresses the bypass-mode entry dialog and does not affect ordinary prompts,
   but it removes a deliberate speed bump in front of bypass mode.
5. **`autoUpdater.disabled` plus `DISABLE_AUTOUPDATER=1`.** Redundant with
   Homebrew-managed updates. Left as-is; update policy was not in scope.
6. **`Bash(rm -rf *)` deny family.** The `/`, `~`, and wildcard variants are
   redundant for that exact prefix, and the textual rule does not cover other
   option orderings such as `rm -fr` or `rm -r -f`. It is a speed bump, not
   containment. Changing deletion policy is a separate decision from reducing
   prompts.
7. **Project-neutral `autoMode.environment`.** Omitted rather than invented, since
   any content would be an unverified claim about the user's trust boundary. Add
   one deliberately if classifier decisions turn out to be too conservative.
