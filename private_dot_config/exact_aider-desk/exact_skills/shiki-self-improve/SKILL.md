---
name: shiki-self-improve
description: "AiderDesk config self-improvement. Audits agent profiles, rules, skills, and custom commands, then proposes and applies targeted improvements. Use when the agent should improve its own configuration."
license: Apache-2.0
---

# Self-Improve

Audit and improve the AiderDesk configuration: agent profiles, global rules, skills, and custom commands.

## When to Use

Use this skill when:

- User asks the agent to "improve itself", "tune the config", or "review the setup"
- After a recurring workflow pain point is identified
- After a new language or toolchain is introduced to the project
- Periodically (e.g., after completing a major feature branch)

Do not use when:

- User wants to improve application code → Use shiki-improve or shiki-implement
- User wants a code review → Use shiki-review

## Mode Declaration

**SHIKI MODE: Config Audit**
Mode: planning
Purpose: Auditing and improving AiderDesk configuration files
Implementation: AUTHORIZED for config files only (skills, rules, commands, agent configs)

## Preconditions

- [ ] `skills---activate_skill` tool available
- [ ] `power---file_read` access to `~/.config/aider-desk/`
- [ ] `power---glob` available for directory scanning

## Phase 1: Discovery

Scan the global AiderDesk config directory:

```bash
ls ~/.config/aider-desk/agents/
ls ~/.config/aider-desk/skills/
ls ~/.config/aider-desk/rules/
ls ~/.config/aider-desk/commands/
```

Also check for project-level overrides:
```bash
ls .aider-desk/agents/ 2>/dev/null
ls .aider-desk/commands/ 2>/dev/null
```

Read each `agents/*/config.json` and each `skills/*/SKILL.md`.

## Phase 2: Audit Checklist

Evaluate against these criteria:

### Agent Profiles
- [ ] Each profile has non-empty `customInstructions` describing when to use it
- [ ] No two profiles have identical model + settings + instructions (duplicates)
- [ ] `maxIterations` is set appropriately (0 = unlimited; flag if cheap/triage profiles use 0)
- [ ] `memory---delete_memory` / `update_memory` consistency: if `store_memory` is `always`, at minimum `update_memory` should not be `never`
- [ ] Subagent blocks: if `useSubagents: true`, check whether `subagent.enabled` should be `true` for delegation workflows
- [ ] `enabledServers` is empty — flag as opportunity if MCP servers would benefit the profile
- [ ] `toolSettings.power---bash.allowedPattern` is not overly restrictive for the profile's purpose

### Rules
- [ ] No duplicate numeric prefixes in filenames (e.g., two `GOLANG-06-*.md`)
- [ ] Rules exist for every language/toolchain actively used in recent commits
- [ ] Each rule file has a clear single-responsibility title
- [ ] No rule file is >300 lines (split if so — agents load rules in full)

### Skills
- [ ] Each `SKILL.md` has a `name` and `description` in front matter
- [ ] Skills cover the full Shiki lifecycle: discovery → PRD → plan → implement → verify → finish
- [ ] No skill gaps for recurring workflows visible in git log or TODO history
- [ ] Skills that reference other skills use correct names (cross-reference check)

### Custom Commands
- [ ] `~/.config/aider-desk/commands/` exists and has at least a few trigger shortcuts
- [ ] Commands exist for the most common multi-step workflows
- [ ] Each command `.md` file has `description:` front matter

## Phase 3: Generate Improvement Plan

For each finding, produce a structured entry:

```
### [FINDING-N] <Title>
Severity: high | medium | low
Area: agents | rules | skills | commands
File: <path>
Issue: <what is wrong or missing>
Recommendation: <what to add/change/remove>
Action: create | edit | delete
```

Group findings by severity. Present the plan to the user before making any changes.

## Phase 4: Apply Changes (with confirmation)

For each approved change:

1. Use `shiki-write-rule` to create or edit rule files
2. Use `shiki-write-skill` to create or edit skill files
3. Use `power---file_edit` to update `config.json` for agent profiles
4. Use `power---file_write` to create new command `.md` files

**Never** delete existing files without explicit user confirmation.

After all changes, re-run Phase 2 checklist to verify improvements applied correctly.

## Postconditions

- [ ] Improvement plan presented and approved by user
- [ ] All approved changes applied
- [ ] No duplicate rule prefixes remain
- [ ] All agent profiles have non-empty `customInstructions`
- [ ] Summary of changes saved to memory via `shiki-memory-storage`

## Memory Storage

After completion, store:
- What config improvements were made (type: `user-preference`)
- Any recurring patterns found (type: `code-pattern`)

## Next Steps

After self-improvement:
- Run a test workflow to validate agent behavior reflects the changes
- Commit the updated dotfiles to version control
