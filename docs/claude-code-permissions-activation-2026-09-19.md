# Claude Code permissions: implemented source change and activation handoff

Implemented 2026-09-19 against CLI 2.1.267 (Homebrew, darwin-arm64).
Companion to `docs/claude-code-permissions-review-2026-09-19.md`.

Only `dot_claude/settings.json` was changed. No live or repository-local settings
file was modified, and nothing was applied, installed, or committed.

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

`Read` denies cover the whole `.ssh` and `.gnupg` directories, since reading a
private key is the real risk. The `Edit` denies target key files themselves
rather than those directories, so `~/.ssh/config` stays editable.

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

## 3. Activation: exact remaining steps

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

## 4. Post-activation test (not yet performed)

None of these were run. Do not treat them as passing until they are, in a fresh
session after steps 1–3.

Inspect resolved configuration:

- `/permissions` — confirm no `Bash(rm *)` or `Bash(chmod *)` under `ask`, and
  check which file each surviving rule comes from.
- `/status` — confirm the effective mode is `auto`.
- `/sandbox` — confirm `enabled` and `autoAllowBashIfSandboxed` resolve true.
- `claude auto-mode` — inspect classifier state; confirm no career-ops context.

Behavioral checks, using disposable fixtures under the globally-ignored
`_git-ignored/` directory:

```sh
mkdir -p _git-ignored/cc-permcheck
printf '#!/bin/sh\necho disposable-probe-ok\n' > _git-ignored/cc-permcheck/disposable-probe.sh
chmod +x _git-ignored/cc-permcheck/disposable-probe.sh   # expect: no prompt
rm _git-ignored/cc-permcheck/disposable-probe.sh          # expect: no prompt
```

- Ordinary keymap file is readable: open
  `private_dot_config/exact_nvim/exact_lua/exact_config/keymaps.lua`. It should
  load, and `git status` should no longer print `Operation not permitted` lines.
- Credential patterns still match, using a dummy only:
  `printf 'NOT-A-REAL-KEY\n' > _git-ignored/cc-permcheck/dummy.pem`, then try to
  read it — expect denial by `Read(**/*.pem)`. Never test against a real key,
  and do not read real credential files to verify.
- Intentional denies intact: `rm -rf _git-ignored/cc-permcheck` should be
  **denied**. Clean up with `rm _git-ignored/cc-permcheck/dummy.pem` and
  `rmdir _git-ignored/cc-permcheck` instead.

Attribute any prompt that remains to its actual cause — a specific rule and the
file that contributes it, a sandbox boundary, or a classifier decision — rather
than assuming the change failed.

## 5. Optional follow-ups (not implemented)

Separate decisions, deliberately left alone:

1. **`wget` / `curl` / `git merge` asks.** Kept as requested. If these interrupt
   routine work, remove them from `ask` in both the source and the local file and
   let auto mode evaluate them. `curl` is the most likely nuisance; note that
   `AGENTS.md` already directs REST work through the `aiderdesk-api` wrapper.
2. **`Read(**/*token*)`.** The same substring defect as `**/*key*`, currently
   harmless here (no tracked file matches). It would block a `tokenizer.*` or
   `tokens.lua` in another checkout. Narrow it the same way if that happens.
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
