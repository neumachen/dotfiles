# Project-Local Rule Templates

Starting structures for files written to `<repo>/.aider-desk/rules/`. Used by `shiki-project-bootstrap` when proposing Bucket 2 files. Keep each file short, concrete, and grounded in discovery evidence.

The naming convention is `NN-topic.md` with a numeric sort prefix, matching the pattern observed in existing populated projects (e.g. `instinctscience/gojira/.aider-desk/rules/`).

---

## Template — `00-project-mission.md`

```markdown
# Project Mission: <repo name>

## Purpose

<One paragraph. What this repo IS. State the verb the repo performs and the
artifact it produces. Cite the README or top-level manifest evidence.>

## Core behavior

- <One bullet per non-obvious behavior the agent must respect.>
- <Bullets are enforceable: the agent can check whether a proposed change
  preserves them.>

## What this repo is NOT

- <Anti-scope. One bullet per common misunderstanding that should be
  explicitly rejected.>
- <Example: "Not a general-purpose web framework — single-purpose CLI."
  "Not multi-tenant — all data is per-user.">

## Out of scope for this repo

- <One bullet per area the agent should refuse to expand into without
  explicit user direction.>
```

Length target: 30–60 lines. If the mission needs more, it is probably trying to also be the engineering rule — split it.

---

## Template — `10-<stack>-engineering.md`

Use only when the repo's engineering posture differs from, or substantially extends, what a global rule already says. If the global rule covers everything, omit this file.

```markdown
# <Stack> Engineering — <repo name>

## Design posture

<Two or three sentences naming the repo's stance. Cite a global rule
if this section extends it: "Extends GOLANG-01-CORE-STYLE with the
following repo-specific conventions.">

## Package / module layout

<Describe the repo's actual layout. Cite directory paths. Do not invent.>

- `<dir>/` — <purpose>
- `<dir>/` — <purpose>

## Dependencies

<Any non-obvious dependency rule: "Never depend on package X from
package Y." "Prefer the stdlib over <library> for parsing.">

## Patterns to follow

- <One bullet per repo-specific pattern, with a file citation.>

## Patterns to reject

- <One bullet per anti-pattern the global rule does not call out.>
```

Length target: 50–100 lines. If much longer, the content probably belongs in the global library — promote via `shiki-write-rule`.

---

## Template — `20-<domain>-api.md`

Use when the repo integrates a domain or external API with non-obvious conventions (Atlassian/Jira, Stripe, Slack, internal RPC, etc.).

```markdown
# <Domain> API Usage — <repo name>

## Source of truth

<Which API the repo uses, version, and where the official docs live.
Cite the manifest pin if any.>

## Conventions

- <One bullet per convention specific to how this repo calls the API.>
- <Authentication source (vault, env, etc.) — without leaking the path.>

## Retry, rate limit, and pagination

<How this repo handles them. Cite the helper or wrapper if one exists.>

## Error handling

<Which errors are user-fatal, which are retried, which are silently
swallowed and why.>
```

Length target: 30–80 lines.

---

## Template — `30-output-format.md`

Use when the repo produces a structured output format (Markdown files, JSON
schema, generated code) with non-obvious conventions.

```markdown
# Output Format — <repo name>

## Canonical artifact

<Path pattern, naming convention, encoding, line endings.>

## Required fields / sections

- <One bullet per required structural element.>

## Determinism

<What makes the output stable across runs. Sorting, timestamps, hashing.>

## Validation

<How to verify the output is well-formed. Cite the validator command.>
```

Length target: 30–80 lines.

---

## Template — `40-workflow-and-safety.md`

Use to capture repo-specific commands and paths the agent must never touch.

```markdown
# Workflow and Safety — <repo name>

## Validation commands

- Build:  `<command>` (via `<wrapper or toolchain>`)
- Test:   `<command>`
- Lint:   `<command>`
- Format: `<command>`

Use the project's wrapper if one exists (`Makefile`, `Taskfile.yml`, `justfile`).

## Commands the agent must never run in this repo

- `<command>` — <reason: production-destructive, requires manual
  approval, etc.>

## Paths the agent must never write

- `<path>` — <reason: generated, secret-bearing, vendored>

## Stateful operations that require explicit user confirmation

- <Migration runs, schema changes, data backfills, external API calls
  that mutate production data.>

## Repository-specific git discipline

- <Branch naming, commit message conventions beyond conventional-commits
  defaults, PR template requirements.>
- Never run `git push` — the human pushes.
```

Length target: 30–80 lines.

---

## Authoring notes

- **Cite evidence.** Every claim should reference a file, manifest, or command in the repo. Project-local rules that read like preferences age badly; ones that read like derivations from the code stay accurate.
- **Defer to global rules.** If a global rule already says it, do not restate it here. Link to it by filename: "See `GOLANG-01-CORE-STYLE.mdc`."
- **Prefer additive over corrective.** A project-local rule that says "ignore `GOLANG-04-ERROR-STYLE` for this repo" is a smell. Either the global rule is wrong, or the repo is an outlier worth flagging — surface that to the user rather than silently overriding.
- **No secrets.** Do not embed credentials, internal hostnames, customer IDs, or anything else that would be unsafe to share with a teammate. Project-local rule files are committed to the repo.
- **Stay short.** Aim for files a new contributor can read in under two minutes. Anything longer is a documentation deliverable, not a rule.
