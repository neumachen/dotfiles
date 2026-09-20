# Claude Code permission review

Reviewed 2026-09-19. Installed CLI: 2.1.267, Homebrew, darwin-arm64.

## Recommendation

Remove the blanket `Bash(rm *)` and `Bash(chmod *)` entries from `permissions.ask` in every contributing settings file. Preserve the live user preference for `defaultMode: "auto"`, reconcile the source to it, and remove this repository's conflicting `acceptEdits` override. Enable the documented Bash sandbox globally. Retain the existing deliberate deny rules initially; changing the deletion policy is separate from reducing prompts.

This addresses repetitive approvals without adding unrestricted `rm` or `chmod` allow rules. In auto mode, actions not otherwise resolved can receive classifier review; this is not a promise that every command will run or that no prompts remain. A narrower alternative is `acceptEdits` plus sandbox auto-allow if classifier use is undesirable or unavailable.

## Inspected settings and ownership

| File | Findings |
| --- | --- |
| `dot_claude/settings.json` | Tracked chezmoi source; maps to `~/.claude/settings.json`. `acceptEdits`; five broad ask entries; no sandbox block; trailing commas and misspelled `attrubution`. |
| `~/.claude/settings.json` | Valid JSON. `auto`; same five ask entries; newer model selection, plugins, UI preferences, and a project-specific `autoMode.environment` absent from source. |
| `.claude/settings.local.json` | Valid JSON; Git-ignored. Repeats global permission lists; `acceptEdits`; sandbox enabled with auto-allow; additional accumulated command approvals. |

No shared `.claude/settings.json`, user/project `CLAUDE.md`, or managed-settings file/directory was found at the explicit locations checked. No Claude launch wrapper was found in the inspected managed shell, mise, hook, and utility locations. This does not establish the flags or mode of an already-running session. Remote managed policy could not be fetched by the CLI in this execution environment.

## Findings

### 1. The configuration explicitly requests the interruptions

Source lines 67–73, live user lines 72–78, and local lines 99–105 contain the same ask list:

```json
[
  "Bash(rm *)",
  "Bash(chmod *)",
  "Bash(wget *)",
  "Bash(curl *)",
  "Bash(git merge *)"
]
```

Deny takes precedence over ask, and ask over allow, regardless of rule specificity. Consequently, adding `Bash(chmod +x *)` to allow will not override the existing `Bash(chmod *)` ask rule. These command-scoped asks also remain effective in auto mode and sandbox auto-allow. [Permission rules](https://code.claude.com/docs/en/permissions), [auto-mode checkpoints](https://code.claude.com/docs/en/auto-mode-config#add-a-human-checkpoint).

Permission lists combine across settings files. Removing an entry from the global file leaves the repository-local copy effective; an empty local ask list does not erase inherited asks. Local scalar settings ordinarily override user settings, explaining the source-level `auto` versus `acceptEdits` discrepancy here. [Settings precedence](https://code.claude.com/docs/en/settings#settings-precedence).

### 2. The tracked source is not ready to apply

`jq empty dot_claude/settings.json` fails at line 88. The final attribution object and the root object contain trailing commas. `claude --settings dot_claude/settings.json doctor` also reports this source as invalid. The live user and repository-local files pass strict JSON parsing.

The source spells `attribution` as `attrubution` at line 85. Fix both defects before deployment. The source is a complete file: chezmoi's read-only diff shows an apply would replace the current live settings, including its newer model, enabled plugins, editor preference, and auto-mode context. Reconcile intentionally; do not overwrite live preferences with this older source or import all live machine-specific content into Git.

### 3. Sandbox configuration is inconsistent

The source and live user file have no `sandbox` block. Only this repository's local settings enable `sandbox.enabled` and `sandbox.autoAllowBashIfSandboxed`. This is not a global sandbox baseline.

Both source and live user settings contain `CLAUDE_CODE_DISABLE_SANDBOX=1`. That name was absent from the current official environment-variable reference and a literal search of the installed executable. Treat it as an unverified legacy entry, not proof that sandboxing is disabled. Replace ambiguity with documented sandbox settings and verify the resolved configuration through `/sandbox`. [Environment variables](https://code.claude.com/docs/en/env-vars).

Suggested global baseline:

```json
"sandbox": {
  "enabled": true,
  "autoAllowBashIfSandboxed": true
}
```

The sandbox limits filesystem/network access, not the consequences of every operation within its writable area. Non-sandboxed fallback and new network access can still need approval. Setting `allowUnsandboxedCommands: false` is an optional stricter policy that blocks fallback; it can break host-integration workflows and should not be added merely to suppress prompts. macOS uses its built-in sandbox support. [Sandbox behavior](https://code.claude.com/docs/en/sandboxing).

### 4. Several existing rules are stale or excessively broad

- `Read(**/*key*)` also covers ordinary source names such as `keymaps.lua`, `keybinds.lua`, `which-key.lua`, and `keymap.json`, all present in this checkout. The local file uses narrower patterns, but the inherited global deny remains. Replace the global substring ban with deliberate credential paths/patterns, preserving protection for real secrets.
- `Write(path)` rules, including `Write(*)` and the secret-file denials, are not the current file-path permission mechanism. Current Claude Code consults `Read(path)` and `Edit(path)`; use `Edit` for write restrictions. Existing `Read` denials provide some overlapping protection, so this is not evidence that all listed secrets are currently writable. [File permission semantics](https://code.claude.com/docs/en/permissions#read-and-edit).
- `Bash(rm -rf *)` is a textual deny, not an exhaustive deletion policy. Its separate `/`, `~`, and wildcard-target entries are redundant for that exact prefix. Different option ordering and invocation forms need independent evaluation. Keep its current behavior initially; do not sell a longer pattern list as containment.
- Global permissions already allow `git push`, all `gh pr` subcommands, and all `npm` subcommands. Local approvals also include `gh api`, `lua`, Python snippets, WezTerm commands, and `chezmoi apply`. Review this accumulated list against actual workflow needs. In particular, `chezmoi apply` deserves attention given this repository's explicit source-versus-deployment boundary. Tool pre-approval is distinct from task authorization.
- `skipDangerousModePermissionPrompt` records acceptance of the bypass-mode entry dialog; the installed executable's schema describes it that way. It does not suppress ordinary command approval prompts.
- `autoUpdater.disabled` is not needed to explain this problem. The CLI reports updates managed by Homebrew; the documented `DISABLE_AUTOUPDATER` entry is already present. Validate redundant/unsupported keys during maintenance, without changing the user's update policy.

### 5. Auto-mode context is scoped to the wrong place

The live global `autoMode.environment` describes one career-ops repository, including a hardcoded trusted checkout and remote. That is configuration evidence, not verified information about that repository. Applying it globally can give the classifier irrelevant context in dotfiles and other projects; no specific false denial was reproduced.

Use project-neutral global trust descriptions. Put repository-specific behavioral context in `CLAUDE.md` or a deliberate per-invocation settings file. Do not simply move `autoMode` into `.claude/settings.local.json`: current documentation excludes project and local files from classifier configuration. [Classifier configuration scopes](https://code.claude.com/docs/en/auto-mode-config#where-the-classifier-reads-configuration).

## Order of changes

1. Repair the source JSON and attribution spelling. Reconcile portable live preferences before any apply.
2. Remove blanket rm/chmod asks from source and, in a separately authorized activation step, all contributing live/local files. Preserve auto globally and remove the local mode override if using the preferred auto approach.
3. Establish global sandbox settings and verify them. Do not add broad deletion/chmod allow rules.
4. If curl/wget/git-merge prompts are also unwanted, remove those broad asks and let the selected mode evaluate them. Keep explicit asks only for actions where a human checkpoint is actually wanted.
5. Fix misleading file rules and stale global classifier context. Review broad accumulated allows without automatically replacing each with another prompt.

For the alternative `acceptEdits` approach, current Claude Code already handles ordinary in-scope `rm` alongside common filesystem edits. `chmod` is not in the documented auto-approved filesystem command list, so removing its ask alone need not eliminate prompts; sandbox auto-allow or a consciously chosen narrow allowance is needed. `dontAsk` automatically denies would-be prompts and can interrupt useful work; `bypassPermissions` removes checks. Neither is the default recommendation. [Permission modes](https://code.claude.com/docs/en/permission-modes).

## Evidence and limits

- Read the complete tracked, live user, and repository-local settings; checked relevant ignore rules and managed-file mapping.
- Checked CLI version/help, source/live JSON parsing, and the chezmoi source-to-live diff without applying it.
- Ran `claude doctor` and `claude --settings dot_claude/settings.json doctor`. The second explicitly diagnosed the source. Doctor could not fetch remote policy or access usable sign-in credentials in this execution environment; its keychain warning is not evidence about authentication in the user's normal terminal.
- Did not invoke a model, run rm/chmod probes, change settings, install anything, apply dotfiles, or inspect private conversation logs. No interactive permission decision or sandbox operation was reproduced. Proposed behavior remains to be validated after authorized implementation and activation.
- Existing untracked Obsidian review document was left untouched. This review document is the only added deliverable.

## Claude Code implementation prompt

```text
Work in /Users/kareemh/MeinCodex/Codebasis/github.com/neumachen/dotfiles.
Read AGENTS.md and docs/claude-code-permissions-review-2026-09-19.md first.
Implement a source-only Claude Code settings cleanup that reduces repetitive
permission prompts. Do not apply dotfiles, edit ~/.claude/settings.json, edit
the ignored .claude/settings.local.json, commit, push, or install anything.
Prepare the exact live/local reconciliation as a separate patch or instructions
for later activation. Preserve unrelated changes.

Goal: routine task-local chmod and cleanup should not always ask solely because
of broad command rules. Preserve the live user's auto-mode preference and use
documented sandboxing. This is not permission to enable bypassPermissions,
globally allow all Bash/rm/chmod, or weaken deliberate destructive-action denies.

Evidence as of 2026-09-19, CLI 2.1.267:
- dot_claude/settings.json maps to ~/.claude/settings.json and is a whole-file
  source, not a merge patch. It has trailing commas and attrubution misspelled.
- Both jq and Claude doctor reject that source. Live user/local JSON is valid.
- Source and local defaultMode are acceptEdits; live user defaultMode is auto.
- All three contain ask rules for rm, chmod, curl, wget, and git merge.
- Only the local file explicitly enables sandbox and sandbox auto-allow.
- The live user file has newer model, plugin, and UI preferences than source.
- The live global autoMode.environment is incorrectly specific to one project.
- Global Read(**/*key*) denies ordinary keymap source files. Local narrower
  entries cannot cancel that inherited deny.
- Current file-path permissions use Read and Edit, not Write(path).

Required source work:
1. Re-read all relevant settings and compare current state. Fix JSON syntax and
   attribution spelling. Preserve intentionally selected portable live model,
   plugin, and UI preferences so eventual deployment does not regress them.
   Do not copy secrets, hardcoded trusted directories, or runtime state to Git.
2. Set the source's global permissions.defaultMode to auto. Remove rm/chmod
   from source permissions.ask. Keep the other three ask entries unchanged in
   this first pass; list their optional removal separately.
3. Add sandbox.enabled=true and sandbox.autoAllowBashIfSandboxed=true globally.
   Remove the unverified legacy CLAUDE_CODE_DISABLE_SANDBOX setting. Do not
   change unsandboxed-fallback policy without a stated requirement.
4. Retain existing deliberate Bash deny behavior initially. Correct file-path
   write protections to Edit rules, and replace the overbroad key substring
   ban with deliberate credential patterns that allow ordinary keymap files.
   Keep existing credential protection intent and verify path semantics.
5. Do not import the project's specific autoMode.environment into global
   dotfiles. Prepare a project-neutral replacement or removal proposal for
   activation. Current project/local autoMode blocks are not a supported fix.
6. Document exact local reconciliation: remove duplicated rm/chmod asks and
   the local acceptEdits override, preserve genuinely local approvals, and
   identify any remaining inherited rules. Do not mutate local/live settings.
7. Flag the broad npm, gh pr, git push, interpreter, gh api, and chezmoi apply
   allows for a separate policy decision; do not silently rewrite all policy.

Validation now:
- Strict JSON parsing; git diff --check; source-to-target mapping.
- Validate source with the installed Claude CLI's read-only doctor path.
- Read-only chezmoi diff: show every future live change and any preference loss.
- Explain deny > ask > allow and additive permission arrays in the handoff.
- No fake shell-rule matcher as a substitute for Claude's permission engine.

Activation validation to document, not execute without authorization:
- Apply only the reconciled settings and local changes deliberately.
- In a fresh normal Claude session, inspect /permissions, /status, /sandbox,
  and claude auto-mode config. Confirm effective mode and rule origins.
- Use disposable, explicitly named project-local fixture files to check chmod
  +x and removal of a file the session just created. Confirm routine operations
  no longer force approval from blanket rm/chmod asks.
- Preserve existing rm -rf deny behavior; evaluate it only against disposable
  fixtures if approved. Never test home/root/real-data deletion.
- Check a representative ordinary keymap file is readable and secret-deny
  patterns still work using dummy fixtures, without reading real credentials.
- Report source completion separately from activation and observed runtime
  behavior. Remaining prompts must be attributed to their actual rule, scope,
  sandbox boundary, or classifier decision.

Deliver a focused source diff, validation results, and a precise activation
handoff. Reconfirm current official documentation if installed behavior differs.
```
