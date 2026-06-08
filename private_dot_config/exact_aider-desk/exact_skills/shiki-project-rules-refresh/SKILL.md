---
name: shiki-project-rules-refresh
description: "Use when revisiting a repository that already has `.aider-desk/rules/` populated and the rules feel stale, the repo has shifted, or you want to confirm coverage is still tight. Proposes minimal updates instead of rewriting."
license: Apache-2.0
---

# Project Rules Refresh

Re-scan a repository whose project-local rules already exist, compare them to current repo reality, and propose the smallest possible updates. This is the standing maintenance skill for `.aider-desk/rules/` — the standing maintenance counterpart to the one-time `shiki-project-bootstrap`.

## When to Use

Use this skill when:

- A repository already has `<repo>/.aider-desk/rules/` populated and feels out of date
- After a substantial refactor that changed conventions (error handling style, test layout, build wrapper)
- After a stack addition or removal (e.g., the repo grew a TypeScript frontend on top of a Go backend)
- Periodic hygiene pass on a project the user has been working in for a while
- After global rules are added or removed in `exact_rules/` (existing project-local rules may now be redundant or insufficient)

Do not use when:

- Repository has no project-local rules yet → use `shiki-project-bootstrap`
- Authoring a globally reusable rule → use `shiki-write-rule`
- Refreshing global rules in `exact_rules/` against any single repo's reality → use `shiki-project-rules-lifecycle`

## Mode Declaration

**SHIKI MODE: Project Rules Refresh**
Mode: planning
Purpose: Producing the smallest minimum update to project-local rule files to align them with current repo reality
Implementation: GATED — analysis and update proposals are produced without writes; file edits only after explicit user approval

## Rules

### Rule: Re-run discovery; do not trust prior summaries

**When:** Starting a refresh pass

**Then:** Run `shiki-project-discovery` again. The repo's stack, validation commands, risk areas, and conventions may have shifted since the last bootstrap.

**Never:** Refresh against a discovery summary older than the current session. Discovery is cheap; stale assumptions are expensive.

### Rule: Defer to `shiki-project-rules-lifecycle` for the diffing primitive

**When:** Producing the three-column gap analysis

**Then:** Use the comparison protocol from `shiki-project-rules-lifecycle`:

| Existing rule | What the code does | Gap (action) |
| --- | --- | --- |

The lifecycle skill defines the canonical gap-analysis shape; this refresh skill is the *entry point* for that flow scoped to a single repo's `.aider-desk/rules/` directory rather than to the global library.

**Never:** Duplicate the gap-analysis methodology here. If the protocol changes, it changes in `shiki-project-rules-lifecycle` and is inherited by this skill.

### Rule: Minimal update, not rewrite

**When:** Proposing an update to an existing project-local rule

**Then:** Default to the smallest diff that closes the observed gap

Allowed change shapes, in order of preference:
1. Edit one section or one bullet of an existing file.
2. Add one new section to an existing file.
3. Add a new `NN-topic.md` file when the gap genuinely does not fit an existing file.
4. Delete or replace a file when the convention it describes no longer exists in the repo.
5. Full rewrite — only if the existing file is actively wrong and an incremental patch would produce something incoherent.

**Never:** Reformat unchanged sections, renumber existing files for "consistency," or restructure heading hierarchy outside the gap's scope.

### Rule: Promote, do not duplicate

**When:** A convention in a project-local rule has appeared in two or more repositories independently

**Then:** Surface it as a global-rule candidate. The action is "promote to `exact_rules/` via `shiki-write-rule`, then remove the project-local copy here."

This keeps the project-local rule set lean and prevents the global library from being shadowed by per-repo copies that drift independently.

### Rule: Drop, do not preserve, stale rules

**When:** A project-local rule describes a convention the repo no longer follows

**Then:** Propose dropping the rule, with citation of the code that contradicts it

**Never:** Edit a stale rule to weaken its assertion just to keep the file alive. A rule the code doesn't follow is misinformation.

### Rule: Delegate writes from read-only profiles

**When:** Active agent is Analyst or any other read-only profile, and the user has approved the proposed update set

**Then:** Delegate the writes to Forge via `subagents---run_task` with:
- The absolute path of each file to edit, create, or delete
- The exact diff or full file content for each
- The conventional-commit message Forge should use (e.g., `docs(<repo>): refresh .aider-desk/rules`)
- A reminder that Forge must not run `git push`

## Process

### Step 1: Re-run discovery

Invoke `shiki-project-discovery`. Note the date and the discovery output in the conversation.

### Step 2: Inventory current project-local rules

```bash
ls <repo>/.aider-desk/rules/
```

For each file:
- Read it.
- Note its one-sentence concern.
- Note its claims that are testable against the code.

### Step 3: Three-column gap analysis

Adopt the format from `shiki-project-rules-lifecycle`:

| Existing rule | What the code does | Gap (action) |
| --- | --- | --- |
| `00-project-mission.md` | mission has expanded to cover a new product surface | add a new bullet to "Core behavior" |
| `10-go-engineering.md` | repo dropped `errgroup` in favor of explicit waitgroups | drop the `errgroup` section |
| (no rule) | repo grew a TypeScript frontend | add `20-typescript-frontend.md` |
| `40-workflow-and-safety.md` | wrapper changed from `Makefile` to `Taskfile.yml` | update the "Validation commands" section |

Every row cites observed evidence (file path, command output, or grep result). No row is speculative.

### Step 4: Re-check global rule coverage

For each existing project-local rule, check whether a global rule now covers the same concern. If yes, the row's action becomes "drop project-local copy; rely on global rule." Cite the global rule's filename.

This catches the case where the global library has grown since the last bootstrap.

### Step 5: Propose minimal diffs

For each gap-row the user wants addressed:

1. Identify the target file (existing project-local rule or new path).
2. Draft the smallest change that closes the gap.
3. Write the proposal in this format:

```markdown
## Refresh change <N> of <M>

**Gap:** <one sentence>

**Target:** `<repo>/.aider-desk/rules/<file>`

**Diff:**
\`\`\`diff
--- a/<repo>/.aider-desk/rules/<file>
+++ b/<repo>/.aider-desk/rules/<file>
@@ <context> @@
- <removed>
+ <added>
\`\`\`

**Rationale:** <one paragraph>

Apply this change? (yes / no / modify)
```

### Step 6: Await approval

The user approves diff-by-diff or as a batch. Do not stack approvals without explicit confirmation.

### Step 7: Apply approved changes

- From Forge / Architect / Power Tools: apply using `power---file_edit` or `power---file_write`.
- From Analyst: delegate to Forge per the delegation rule.

### Step 8: Verify and report

After writes complete:
- Re-read each changed file to confirm the diff applied as intended.
- Report what was changed and where, in one line per file.
- Surface a single conventional-commit suggestion the user can run, e.g.:

  ```text
  docs(<repo>): refresh .aider-desk/rules

  Bring project-local rules in line with current repo conventions
  (Taskfile wrapper, removed errgroup section, new TS frontend rule).
  Drop the rule for the now-removed `legacy/` module.
  ```

Do **not** commit on the user's behalf unless they ask.

## Preconditions

- [ ] Target repo's absolute path is known and accessible
- [ ] `<repo>/.aider-desk/rules/` already exists and is non-empty (if empty, use `shiki-project-bootstrap` instead)
- [ ] Current `shiki-project-discovery` summary is in the conversation

## Postconditions

- [ ] A three-column gap analysis is in the conversation
- [ ] Every proposed change cites the gap it closes
- [ ] No write has been performed without explicit user approval
- [ ] No project-local rule has been edited to remain alive in contradiction of the code
- [ ] Promotion candidates (per-repo rules that should be global) are surfaced separately

## Success Metrics

- Each accepted update closes a real, observed gap (verifiable in the code).
- Rejected proposals are clearly out-of-scope or premature, not careless.
- The repo's `.aider-desk/rules/` directory shrinks or stays flat when the change is "drop a stale rule"; it grows only when a new concern is observed.
- A second refresh pass immediately after this one surfaces no new gaps.

## Next Steps

- If the refresh surfaced promotion candidates, follow up with `shiki-write-rule` to add them to `exact_rules/`, then re-run refresh to drop the project-local copies.
- If the refresh surfaced runtime-enforcement candidates (best handled by an extension), follow up via the AiderDesk extension authoring flow — this skill does not scaffold extensions.
