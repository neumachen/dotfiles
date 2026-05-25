---
name: shiki-write-rule
description: "Author or edit a global AiderDesk rule file. Enforces correct naming convention, single-responsibility principle, and rule file structure. Use when adding new language/toolchain rules or updating existing ones."
license: Apache-2.0
---

# Write Rule

Author or edit a global AiderDesk rule file with correct naming, structure, and scope.

## When to Use

Use this skill when:

- Adding rules for a new language or toolchain
- Splitting an oversized rule file into focused files
- Fixing a duplicate numeric prefix
- Updating an existing rule after a project convention changes

Do not use when:

- Creating a skill (reusable workflow) → Use shiki-write-skill
- Writing project-level AGENTS.md instructions
- Modifying agent `config.json` settings

## Mode Declaration

**SHIKI MODE: Rule Authoring**
Mode: implementation
Purpose: Creating or editing AiderDesk rule files
Implementation: AUTHORIZED for rule files in `~/.config/aider-desk/rules/`

## Naming Convention

Rule files MUST follow this pattern:

```
<DOMAIN>-<NN>-<TOPIC-IN-CAPS-WITH-HYPHENS>.md
```

Examples:
- `GOLANG-01-CORE-STYLE.md`
- `GOLANG-08-INTERFACES.md`
- `SECURITY-01-SECRETS-AND-INPUTS.md`
- `SQL-01-QUERY-STYLE.md`
- `SHELL-01-SAFETY.md`

Rules:
- `<NN>` is a zero-padded two-digit number (01–99)
- Each domain's numbers must be unique — check existing files before assigning
- One topic per file; never combine unrelated concerns

## Rule File Structure

```markdown
# <Domain> Rule: <Topic>

<One-sentence summary of what this rule governs.>

## When This Rule Applies

<List of situations, file types, or operations where this rule is enforced.>

## Required Behavior

<Concrete imperatives — what the agent MUST do.>

- Use X not Y
- Always Z before W
- Never do A

## Examples

### Good

```<lang>
// correct example
```

### Bad

```<lang>
// incorrect example — explain why
```

## Exceptions

<Any known legitimate exceptions, or "None." if none exist.>
```

## Quality Checklist

Before saving a rule file, verify:

- [ ] Filename follows `DOMAIN-NN-TOPIC.md` convention
- [ ] No other file in the same domain uses the same `NN`
- [ ] Single responsibility: only one topic covered
- [ ] Has at least one Good and one Bad example
- [ ] Length is under 300 lines (split if longer)
- [ ] No references to AI tool names in examples (keep rules tool-agnostic)

## File Location

Global rules: `~/.config/aider-desk/rules/<FILENAME>.md`
Project rules: `.aider-desk/rules/<FILENAME>.md` (project-scoped overrides)

## Postconditions

- [ ] File saved at correct path
- [ ] Naming convention verified
- [ ] No duplicate numeric prefix in domain

## Next Steps

After writing a rule, the change takes effect immediately for new agent sessions.
To verify the rule is loaded, start a new conversation and ask the agent to summarize active rules.
