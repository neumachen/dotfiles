---
name: shiki-project-bootstrap
description: "Use when starting work in a new or unfamiliar repository and you need to decide which global rules already apply, which project-local rules to create in `.aider-desk/rules/`, and whether any runtime guardrails belong as extensions."
license: Apache-2.0
---

# Project Bootstrap

Set up an unfamiliar repository for productive AiderDesk work without polluting the global rules library. Produce a minimal, evidence-grounded plan that classifies findings into three buckets — global rules already covered, project-local rules to create, and runtime extension guardrails — then scaffold only what the user approves.

## When to Use

Use this skill when:

- Starting AiderDesk work in a repository for the first time
- A repository has no `.aider-desk/rules/` directory yet and the user wants to set one up
- Joining an existing project and wanting to know what is and is not already covered
- Auditing a repository before granting an agent broader write permissions

Do not use when:

- Authoring a globally reusable rule (concerns multiple projects) → write a new file in `exact_rules/` via `shiki-write-rule`
- Refreshing the rules of a repository that already has `.aider-desk/rules/` populated → use `shiki-project-rules-refresh`
- Discovery alone is needed without rule scaffolding → use `shiki-project-discovery` directly

## Mode Declaration

**SHIKI MODE: Project Bootstrap**
Mode: planning
Purpose: Classifying observed conventions into global-already-covered, project-local-to-create, and runtime-extension buckets, then scaffolding only what is approved
Implementation: GATED — discovery and the three-bucket plan are produced without writes; file creation only after explicit user approval, and only into the target project, never into `exact_rules/`

## Rules

### Rule: Run discovery first, never skip it

**When:** Bootstrapping any repository

**Then:** Run `shiki-project-discovery` first to produce the grounded summary

**Never:** Propose rules from memory or from the repo name alone. Every recommendation in this skill cites a file, manifest, or directory observed during discovery.

### Rule: Three-bucket classification is mandatory

**When:** Producing the bootstrap plan

**Then:** Every observed convention or risk must be assigned to exactly one of three buckets:

1. **Global rules already covered** — a rule in `~/.config/aider-desk/rules/` (sourced from `private_dot_config/exact_aider-desk/exact_rules/` on the host) already governs this. No action needed; AiderDesk already loads it.
2. **Project-local rules to create** — durable convention that belongs to *this repo only* (mission, domain glossary, repo-specific layout, a deliberate deviation from a global rule). Write to `<repo>/.aider-desk/rules/NN-topic.md`.
3. **Runtime extension guardrail** — behavior best enforced at tool-call time, not by prose (e.g. denying writes outside `lib/`, blocking a specific destructive command in this repo). Suggest as `<repo>/.aider-desk/extensions/`. This skill does not write extension code; it surfaces the candidate and links to AiderDesk's extension shape.

Items that fit none of these are not bootstrapped — they are either out of scope or candidates for promotion to a global rule (in which case use `shiki-write-rule`, not this skill).

### Rule: Project-local rules go to `.aider-desk/rules/`, never to `exact_rules/`

**When:** Creating a rule that applies only to one repository

**Then:** Write it to `<repo>/.aider-desk/rules/<NN-topic>.md`

**Never:** Add a project-specific rule to `private_dot_config/exact_aider-desk/exact_rules/`. The global library is reusable rules only. Project-specific rules in the global library leak one repo's conventions into every other repo.

**Naming convention:** `NN-topic.md` where `NN` is a two-digit sort prefix:
- `00-` for the project mission / one-paragraph purpose
- `10-` / `20-` / `30-` for major topic rules (engineering, domain APIs, output format, etc.)
- `40-` for workflow and safety constraints specific to this repo

This convention is observed in existing populated projects (e.g. `instinctscience/gojira/.aider-desk/rules/`).

**Format:** plain Markdown. No `mdc` front matter is required — AiderDesk loads `.aider-desk/rules/*.md` directly. Front matter (`description:`, `globs:`) may be added if the user wants Cursor-style metadata, but it is not required.

### Rule: Map signals to global rules using the mapping table

**When:** Deciding whether a global rule already covers a detected convention

**Then:** Consult `rule-mapping.md` (sibling file) for the signal → rule mapping

The mapping is structured as: detected signal → matching global rule filename → the concern that rule covers. If a detected signal has a row in the table, the rule is already covered and goes in Bucket 1. If a detected signal has no row, it is a candidate for Bucket 2 or Bucket 3.

**Never:** Add a rule to the recommended list without confirming the file actually exists in `exact_rules/`. The mapping table is reviewed against the actual directory by this skill.

### Rule: Propose minimal rule content from the template

**When:** Recommending a Bucket 2 rule to create

**Then:** Use `rule-template.md` (sibling file) as the starting structure

**Minimum useful project-local rule set** (typical bootstrap):
- `00-project-mission.md` — one paragraph: what this repo is and is not
- `10-<stack>-engineering.md` — repo-specific design posture *that is not already in a global rule*
- `40-workflow-and-safety.md` — anything the agent must never do in this repo (commands to never run, paths to never write, secrets backends to never query)

Keep each file under ~100 lines. If a file is growing past that, the convention probably belongs in a global rule or wants splitting.

### Rule: Surface extension candidates without scaffolding them

**When:** A convention is enforceable at tool-call time more reliably than by prose

**Then:** Note it in Bucket 3 with the candidate behavior and the AiderDesk extension hook that would implement it (denied-pattern, file-write filter, command middleware) — but do not generate extension code

Extension authoring is a separate workflow. This skill points at the right shape; the user implements with `shiki-writing-skills` and the AiderDesk extension docs.

**Examples of Bucket 3 candidates:**
- "Block all writes outside `app/` and `spec/`" → file-write filter
- "This repo never runs `rake db:reset` in any environment" → bash denied-pattern
- "Treat `config/credentials*` as read-only" → file-edit denied paths

### Rule: Never write into the target project without explicit approval

**When:** Producing the bootstrap plan

**Then:** Present the three-bucket plan, the proposed file paths under `<repo>/.aider-desk/`, and the file bodies. Wait for explicit user approval before any write.

**Exception:** None. Project-local rule files govern agent behavior in that repo; the user must own the contents.

### Rule: Delegate writes if the active agent cannot write

**When:** The active agent is Analyst or any other read-only profile, and the user has approved the plan

**Then:** Delegate the writes to Forge via `subagents---run_task` with a self-contained prompt that includes:
- The absolute path of each file to create
- The full intended content of each file
- The conventional-commit message Forge should use (e.g., `chore(<repo>): bootstrap .aider-desk/rules`)
- A reminder that Forge must not run `git push`

## Process

### Step 1: Discovery

Invoke `shiki-project-discovery`. Confirm its summary is in the conversation. Do not re-derive what discovery already produced.

### Step 2: Confirm scope

Confirm with the user:
- The target repository's absolute path
- Whether `.aider-desk/rules/` already exists (if yes, prefer `shiki-project-rules-refresh` instead)
- Whether the user wants the minimum useful set or a broader set

### Step 3: Three-bucket classification

For each finding in the discovery summary (Stack, Validation, Risk areas, Existing rule coverage, Gaps), assign to a bucket using the rule mapping (`rule-mapping.md`):

| Detected signal | Matching global rule | Bucket |
| --- | --- | --- |
| `go.mod` present | `GOLANG-*.mdc` (8 files) | 1 — already covered |
| Go repo uses `errgroup` heavily in one specific package | (no rule covers this repo's pattern) | 2 — project-local `10-go-engineering.md` notes the pattern |
| Repo must never run `terraform apply` to live state | (denied-pattern enforcement) | 3 — extension candidate |

Produce the inventory as a markdown table.

### Step 4: Draft project-local files

For each Bucket 2 item, draft the proposed file body using `rule-template.md` as the starting structure. Keep files short, concrete, and grounded in cited evidence from discovery.

For each Bucket 3 item, name the proposed extension behavior and the AiderDesk hook that implements it. Do not write extension code.

### Step 5: Present the plan

Produce the bootstrap plan in this exact shape:

```markdown
## Bootstrap plan — <repo path>

### Bucket 1 — global rules already covered

- `GOLANG-01-CORE-STYLE.mdc` — Go core style (matches `go.mod` at repo root)
- `GOLANG-07-STATIC-ANALYSIS-AND-FORMATTING.mdc` — gofmt/vet/golangci-lint (matches `.golangci.yml`)
- (one bullet per global rule that matches detected signals)

### Bucket 2 — project-local rules to create

Target directory: `<repo>/.aider-desk/rules/`

- `00-project-mission.md` — <one-sentence summary of the body>
- `10-<stack>-engineering.md` — <one-sentence summary>
- `40-workflow-and-safety.md` — <one-sentence summary>

(Full proposed bodies follow as separate code blocks, one per file.)

### Bucket 3 — runtime extension guardrails (deferred)

- Block writes outside `lib/` and `spec/` — file-write filter
- Block `rake db:reset` — bash denied-pattern

(Not scaffolded by this skill. See AiderDesk extension docs.)
```

### Step 6: Await approval

The user approves the plan as a whole or item-by-item. Do not stack approvals without explicit confirmation.

### Step 7: Scaffold approved items

For each approved Bucket 2 file:
- Ensure `<repo>/.aider-desk/rules/` exists (create with `mkdir -p` if missing).
- Write the file at the approved path.
- If acting from Analyst, delegate the write to Forge as described in the delegation rule.

### Step 8: Verify and report

After writes complete:
- List the created files with `ls <repo>/.aider-desk/rules/`.
- Surface a single conventional-commit suggestion the user can run, e.g.:

  ```text
  chore(<repo>): bootstrap .aider-desk/rules

  Add project-local mission, engineering, and workflow rules grounded
  in observed repo conventions. Global rules already covered by the
  AiderDesk rules library are not duplicated here.
  ```

Do **not** commit on the user's behalf unless they ask.

## Preconditions

- [ ] Target repo's absolute path is known and accessible
- [ ] `shiki-project-discovery` has been run and its summary is in the conversation
- [ ] The user has confirmed they want to scaffold rules (not just inspect)

## Postconditions

- [ ] A three-bucket plan is in the conversation
- [ ] No file has been written without explicit user approval
- [ ] Approved files live at `<repo>/.aider-desk/rules/NN-*.md`, never in `exact_rules/`
- [ ] Bucket 3 candidates are surfaced but not scaffolded
- [ ] A conventional-commit suggestion is provided

## Success Metrics

- The Bucket 1 list contains only global rules whose concerns actually appear in the repo (no over-recommendation).
- The Bucket 2 files are each under 100 lines and contain content that no global rule covers.
- The Bucket 3 list does not include items that prose-rules could enforce just as well.
- A second pass of `shiki-project-discovery` on the same repo would not surface the same gaps.

## Next Steps

- After the initial bootstrap, the standing maintenance flow is `shiki-project-rules-refresh` — re-scan periodically and propose minimal updates.
- If a Bucket 2 finding turns out to apply to multiple repositories, promote it to the global library via `shiki-write-rule` and remove it from the project-local set.
