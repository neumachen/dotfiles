---
name: slack-copy-output
description: "Format the final user-facing reply as Slack-compatible, paste-ready mrkdwn. Use when the user asks for Slack output, copy-paste output, or says \"for Slack\". Single-asterisk emphasis, no rendered code fence wrapper."
license: Apache-2.0
---

# Slack Copy Output

Format the final user-facing reply as unrendered, paste-ready Slack mrkdwn.

**Announce at start:** "I'm using the slack-copy-output skill to format this for Slack."

## When to Use

Use this skill when:

- The user asks for output "for Slack", "Slack-ready", or "copy-paste"
- The user invokes a Slack output trigger or command
- The destination surface is the Slack message composer

Do not use when:

- The reply is consumed inside the AiderDesk chat UI or on GitHub (use standard Markdown)
- Producing inter-agent reports (Forge / Scout reports return to Analyst, not the user)

## Mode Declaration

**SHIKI MODE: OUTPUT-FORMATTING**

- Mode: Output formatting (non-destructive, applies to the final reply only)
- Purpose: Deliver paste-ready Slack mrkdwn for the human Slack composer
- Implementation: Rewrite the final reply per the rules below; do not change analysis content

## Rules

### Rule: Use single-asterisk emphasis

**When:** Emitting Slack-bound output

**Then:** Use `*text*` for emphasis, never `**text**`

**Never:** Apply this inside inline code spans or fenced code blocks — code content is
emitted verbatim (a diff line containing `**` must stay `**`).

**Reason:** Slack mrkdwn renders `*text*` as bold; `**` is not valid Slack bold.

### Rule: Keep Markdown link syntax for the composer

**When:** Referencing a URL in Slack-bound output

**Then:** Use `[text](url)` (per OUTPUT-01)

**Reason:** The target surface is the Slack message composer, which auto-converts pasted
`[text](url)` into a link on send. Programmatic mrkdwn surfaces (webhooks, bots) require
`<url|text>` instead — if the destination is programmatic, state that and switch syntax.

### Rule: Deliver unrendered, paste-ready text

**When:** Emitting the final Slack-bound reply

**Then:** Output raw Markdown text directly in the reply

**Never:** Wrap the whole reply in a rendered code fence; the user must copy raw mrkdwn.

**Reason:** Wrapping in a fence defeats copy-paste. Mirrors the commit-prompt's
"no code fences" delivery precedent.

### Rule: Cite commit SHA when a commit is involved

**When:** The Slack-bound reply reports a commit

**Then:** Reference the SHA explicitly (per OUTPUT-01); never fabricate one

## Process

### 1. Confirm the surface

- Confirm destination is the human Slack composer (default) vs programmatic mrkdwn.
- If programmatic, switch links to `<url|text>` and note the switch.

### 2. Rewrite the final reply

- Replace every `**bold**` with `*bold*` outside code.
- Keep `[text](url)` links; leave code-span/fence URLs literal.
- Ensure any commit reference includes its SHA.

### 3. Emit raw

- Print the result as raw Markdown text, not wrapped in an outer rendered fence.
- Tell the user where the copy-paste region begins.

## Preconditions

- [ ] The reply is destined for Slack (composer or programmatic surface identified)
- [ ] The analysis/content is already complete (this skill only reformats)

## Postconditions

- [ ] No `**` outside code spans/fences
- [ ] All links are `[text](url)` (or `<url|text>` if programmatic)
- [ ] Any commit reference includes its SHA
- [ ] Output is raw Markdown, not wrapped in an outer rendered code fence
- [ ] Code spans and fenced blocks are emitted verbatim

## Success Metrics

This skill is successful when:

- The user can paste the reply into the Slack composer and it renders correctly
- Emphasis renders as bold in Slack, links resolve, and no raw `**` is visible
- Code blocks remain intact and unmodified

## Integration

- **OUTPUT-01-LINKS-AND-COMMIT-REFS** — supplies the always-on link and commit-SHA clauses;
  this skill adds only the Slack-specific emphasis and unrendered-delivery clauses.
- **shiki-handoff** — shares the "emit a paste-ready block as the final action" pattern.

## Next Steps

- After emitting, stop. Do not re-wrap or re-render the output.
