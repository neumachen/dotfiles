---
name: shiki-write-skill
description: "Author or edit a Shiki skill (SKILL.md). Enforces front matter, When-to-Use, Rules, Preconditions, Postconditions, and Success Metrics structure. Use when creating new reusable agent workflows."
license: Apache-2.0
---

# Write Skill

Author or edit a Shiki skill file with correct structure, front matter, and contract sections.

## When to Use

Use this skill when:

- Creating a new reusable agent workflow
- Adding missing preconditions/postconditions to an existing skill
- Splitting an overly broad skill into focused ones
- Updating a skill after a workflow change

Do not use when:

- Writing a rule (language/toolchain guideline) → Use shiki-write-rule
- Writing a custom command shortcut → Create a `.md` file in `commands/`
- Modifying agent `config.json` settings

## Mode Declaration

**SHIKI MODE: Skill Authoring**
Mode: implementation
Purpose: Creating or editing a Shiki SKILL.md file
Implementation: AUTHORIZED for skill files in `~/.config/aider-desk/skills/`

## Directory Convention

Each skill lives in its own directory:

```
~/.config/aider-desk/skills/
└── shiki-<name>/
    ├── SKILL.md        # Required
    └── scripts/        # Optional: helper scripts the skill references
```

Naming rules:
- Directory name = skill name (must match `name:` in front matter)
- Use `shiki-` prefix for all Shiki workflow skills
- Use lowercase kebab-case

## Required SKILL.md Structure

```markdown
---
name: shiki-<name>
description: "<One sentence: what it does and when to use it.>"
license: Apache-2.0
---

# <Human Title>

<One-paragraph overview.>

## When to Use

Use this skill when:
- <concrete trigger condition>

Do not use when:
- <anti-pattern / wrong context>

## Mode Declaration

**SHIKI MODE: <Mode Name>**
Mode: planning | implementation | verification | analysis
Purpose: <what this skill is doing>
Implementation: AUTHORIZED | BLOCKED - <reason>

## Rules

### Rule: <Rule Name>

**When:** <condition>
**Then:** <action>
**Never:** <prohibition> (optional)

(Repeat for each behavioral rule.)

## Preconditions

- [ ] <artifact or tool that must exist before this skill runs>

## Postconditions

- [ ] <artifact or state that must exist after this skill completes>

## Success Metrics

This skill is successful when:
- <measurable outcome>

## Next Steps

<What skill or action typically follows this one.>
```

## Quality Checklist

Before saving a skill file, verify:

- [ ] Front matter has `name:` and `description:`
- [ ] `description:` is ≤ 200 characters (it's loaded as metadata on every session start)
- [ ] `When to Use` includes both positive triggers AND explicit "Do not use when" cases
- [ ] Mode Declaration block is present with correct mode type
- [ ] At least one `Rule:` block with `When/Then` structure
- [ ] Preconditions and Postconditions are present
- [ ] No implementation code in the skill (skills are instructions, not code)
- [ ] References to other skills use the exact skill `name:` value
- [ ] File is under 400 lines (split into focused skills if longer)

## Registering the Skill

After saving the file, the skill is available immediately — AiderDesk loads skill metadata
on each session start from the directory. Verify it loads by activating it:

```
skills---activate_skill { "name": "shiki-<name>" }
```

## Postconditions

- [ ] `SKILL.md` saved at `~/.config/aider-desk/skills/shiki-<name>/SKILL.md`
- [ ] Front matter validated
- [ ] Quality checklist passed
- [ ] Skill verified loadable in current session

## Next Steps

After writing a skill, add it to the Shiki router (`shiki-router`) if it introduces a new
workflow type or entry point. Test by triggering a sample user prompt that should activate it.
