---
name: slack-copy-output
description: "Format the final user-facing reply as Slack-compatible, paste-ready mrkdwn. Use when the user asks for Slack output, copy-paste output, or says \"for Slack\". Single-asterisk emphasis, wrapped in a Markdown code block for clean copy-paste."
license: Apache-2.0
---

# Slack Copy Output

Format the final user-facing reply as paste-ready Slack mrkdwn wrapped in a Markdown code block.

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

### Rule: Wrap the reply in a Markdown code block

**When:** Emitting the final Slack-bound reply

**Then:** Wrap the entire reply in a fenced Markdown code block (```) so the raw mrkdwn
stays literal and one-click copyable.

**Never:** Emit the Slack mrkdwn outside a code fence; rendered emphasis/links defeat
copy-paste of the raw markers.

**Note:** If the reply itself contains a fenced code block, the outer wrapping fence must
use more backticks than any inner fence (e.g. four backticks outside, three inside) so the
block does not terminate early.

**Reason:** The user copies the raw mrkdwn (`*text*`, `[text](url)`) out of the code block
and pastes it into the Slack composer, which renders it on send.

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

### 3. Emit inside a code fence

- Print the result inside a fenced Markdown code block so the mrkdwn stays raw.
- If the reply contains its own fenced block, use a longer outer fence (more backticks).
- Tell the user the code block is the copy-paste region.

## Preconditions

- [ ] The reply is destined for Slack (composer or programmatic surface identified)
- [ ] The analysis/content is already complete (this skill only reformats)

## Postconditions

- [ ] No `**` outside code spans/fences
- [ ] All links are `[text](url)` (or `<url|text>` if programmatic)
- [ ] Any commit reference includes its SHA
- [ ] Output is wrapped in a Markdown code block so the raw mrkdwn is copy-paste-ready
- [ ] Code spans and fenced blocks are emitted verbatim

## Success Metrics

This skill is successful when:

- The user can paste the reply into the Slack composer and it renders correctly
- Emphasis renders as bold in Slack, links resolve, and no raw `**` is visible
- Code blocks remain intact and unmodified

## Integration

- **OUTPUT-01-LINKS-AND-COMMIT-REFS** — supplies the always-on link and commit-SHA clauses;
  this skill adds only the Slack-specific emphasis and code-block-wrapped-delivery clauses.
- **shiki-handoff** — shares the "emit a paste-ready block as the final action" pattern.

## Next Steps

- After emitting the code block, stop. Do not add commentary inside the fence.
