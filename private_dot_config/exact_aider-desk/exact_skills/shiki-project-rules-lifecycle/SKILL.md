---
name: shiki-project-rules-lifecycle
description: "Audit, gap-analyze, and refine a project's existing rule files against observed repo reality. Produces minimal diffs (not rewrites), waits for approval, and delegates the write to Forge when Analyst is active."
license: Apache-2.0
---

# Project Rules Lifecycle

Maintain a project's rules collection as a living mirror of its actual conventions — not as a wish list, not as a copy of someone else's rules. Compare current coverage to observed repo reality, identify gaps, and propose minimal additions or edits.

## When to Use

Use this skill when:

- A repository's rules feel stale, incomplete, or aspirational versus what the code actually does
- The user asks to "tighten the rules", "fill the rule gaps", "review the rules", or "make sure the rules cover X"
- After `shiki-project-discovery` has surfaced a `Gaps` section worth acting on
- Adding a new toolchain, framework, or convention to a repo for the first time
- After a substantial refactor that changes conventions (error handling, testing layout, build flow)

Do not use when:

- The repo has no rules directory and no obvious place to put one — propose the location first, then come back
- The request is to write rules for a brand-new repo from scratch — start with `shiki-project-discovery` first
- The user is asking for a one-off style change in code, not a rule change

## Mode Declaration

**SHIKI MODE: Rules Lifecycle**
Mode: planning
Purpose: Aligning rule files with observed repo reality through minimal, reviewable diffs
Implementation: GATED — diffs are proposed, approval is awaited, writes are delegated to Forge when Analyst is active

## Rules

### Rule: Reality first, rules second

**When:** Considering any rule addition or edit

**Then:** Inspect the repo's actual code before reading the existing rule

**Sequence:**
1. Read enough of the repo to know what the convention actually is.
2. Then read the rule that purports to describe it.
3. The diff is between *what the rule says* and *what the code does* — not between the rule and your preference.

**Never:** Rewrite a rule to enforce a convention the code does not yet follow. That is a refactor pretending to be a rule change.

### Rule: Minimal diff over full rewrite

**When:** Proposing a rule change

**Then:** Default to the smallest patch that addresses the gap

**Allowed change shapes (in order of preference):**

1. Add one new rule section to an existing file.
2. Tighten one existing assertion (e.g., make a "prefer" into a "require" if the code is unanimous).
3. Add a new front-matter glob to an existing rule whose scope has expanded.
4. Add a new rule file when the gap genuinely does not fit any existing file.
5. Full rewrite — only if the existing rule is actively wrong and incrementally patching it would produce something incoherent.

For every change, ask: could this be a smaller diff?

**Never:** Restructure heading hierarchy, reword unchanged sections, or "polish" prose outside the diff's scope. Existing rule text is load-bearing context for the user.

### Rule: Compare current to observed

**When:** Gap-analyzing a rules collection

**Then:** Produce a three-column inventory

| Existing rule              | What the code does            | Gap                                |
| -------------------------- | ----------------------------- | ---------------------------------- |
| `GOLANG-08-TESTING.mdc`    | table-driven tests everywhere | rule says "prefer table-driven" — should be "require" |
| (no rule)                  | uses `errgroup` heavily        | concurrency rule has no `errgroup` section |
| `RUBY-04-RSPEC-CONVENTIONS` | repo uses Minitest, not RSpec  | rule is stale; either drop or repurpose |

The inventory is the input for the diff proposal. Without it, "the rules need updating" is not actionable.

### Rule: Propose, do not write

**When:** Operating under any agent that can write files (Forge, Architect, Power Tools)

**Then:** Present the proposed diff to the user before writing

**Format the proposal as:**
1. The gap, one sentence.
2. The proposed target file (existing rule, or new path).
3. The proposed diff (in unified-diff form or as a clearly delimited replacement block).
4. The rationale, one paragraph.

Wait for explicit approval (yes / proceed / apply / write) before invoking any write tool.

**Exception:** None. Even small rule edits get a proposal, because rules govern the agent's own future behavior — confusion compounds.

### Rule: Delegate writes when Analyst is active

**When:** The active agent is Analyst (read-only) and the user has approved the proposed diff

**Then:** Delegate the write to Forge via `subagents---run_task`

**The Forge prompt must include:**

- The exact absolute path of the rule file to create or modify
- The full intended file content (for new files) or the precise diff (for edits)
- The conventional-commit message Forge should use (e.g., `docs(rules): tighten GOLANG-08 testing rule to require table-driven`)
- A reminder that Forge must not run `git push`
- A reminder that if the rule file lives under a chezmoi `private_` or `exact_` prefix, the `DOTFILES-01-CHEZMOI-CONVENTIONS` rule applies

**Never:** Attempt to write through any other channel from Analyst. Specifically forbidden: shell redirection, `tee`, in-place editors, here-docs to disk, base64-decode into a file, or any other bash idiom that produces or modifies a file. If you find yourself about to write from Analyst, stop — compose a `subagents---run_task` instead.

### Rule: One rule, one concern

**When:** Deciding whether the gap belongs in an existing rule or a new one

**Then:** Apply the single-concern test

**A rule is single-concern when:**
- The `description` front-matter field can be stated in one sentence
- Every section in the rule contributes to that concern
- Removing any section would leave the rule still coherent

**Add to an existing rule if:** the gap is a refinement of its concern.

**Create a new rule if:** the gap introduces a new concern (toolchain, framework, file-type family).

**Refactor an existing rule if:** the existing rule was already trying to cover two concerns. State the refactor explicitly before proposing the diff.

### Rule: Preserve naming conventions

**When:** Creating a new rule file

**Then:** Match the project's existing rule naming convention exactly

**Inspection checklist:**
- File name pattern (e.g., `LANG-NN-TOPIC.mdc` in this repo)
- Front matter format (`description`, `globs`, `alwaysApply`)
- Heading hierarchy
- Section ordering
- Code-fence language tags
- Reference style (cross-rule links, citation format)

**Never:** Introduce a new naming or front-matter style without explicitly proposing it as a meta-change to the user.

## Process

Run as a planning workflow. No file writes until the user has approved the diff.

### Step 1: Verify discovery context

If a discovery summary from `shiki-project-discovery` is not in the conversation, run that skill first. The rules lifecycle is grounded in the discovery output's `Existing rule coverage` and `Gaps` sections.

If discovery has already been done, restate the summary in one line so the user can confirm we are working from the same picture.

### Step 2: Build the rule inventory

For every existing rule file in the project's rules directory:

1. Read the rule.
2. Note its `description` front matter.
3. Note its `globs` (if `alwaysApply: false`) — confirm those glob targets actually exist.
4. Note its top-level concern in one phrase.

Produce a flat list. Do not deduplicate; if two rules cover similar ground, that is itself a finding.

### Step 3: Build the reality inventory

For every claim the existing rules make:

1. Identify the corresponding code area.
2. Check whether the code actually follows the rule.
3. Categorize: **followed**, **partially followed**, **violated**, **stale (no longer applicable)**.

For every notable convention in the code that no rule covers, record it as **uncovered**.

Output is a list of `(claim or convention, status, evidence)` tuples.

### Step 4: Three-column gap analysis

Lay the rule inventory and the reality inventory side by side. The gap column is the actionable output.

| Existing rule    | What the code does       | Gap (action)                    |
| ---------------- | ------------------------ | ------------------------------- |
| `<rule file>`    | `<observed convention>`  | `<add / tighten / loosen / drop / refactor>` |
| (none)           | `<observed convention>`  | `add new rule <name>` or `add section to <existing rule>` |

Keep the gap column to verbs the user can act on.

### Step 5: Propose minimal diffs

For each row in the gap column that the user wants addressed:

1. Identify the target file (existing or new).
2. Draft the smallest change that closes the gap.
3. Write the proposal in the format below.

Always propose. Never write without approval.

### Step 6: Await approval

The user approves diff-by-diff or batches them. Do not stack approvals without explicit confirmation.

### Step 7: Delegate the write

- **From Forge / Architect / Power Tools:** apply the change directly using `power---file_edit` or `power---file_write`.
- **From Analyst:** delegate to Forge via `subagents---run_task` with a self-contained prompt.
- **From any agent in a chezmoi-managed repo:** apply the change to the source path (e.g., `private_dot_config/exact_aider-desk/exact_rules/<name>.mdc`), not the rendered target. Mention `DOTFILES-01-CHEZMOI-CONVENTIONS` in the delegation prompt if relevant.

### Step 8: Verify and report

After the write completes:

1. Re-read the changed file to confirm the diff applied as intended.
2. Report what was changed and where, in one line.
3. Do not run `chezmoi apply`. That belongs to the user.

## Output Format

### Step 4 gap analysis output

```markdown
## Rules gap analysis — <repo>

| Existing rule | What the code does | Gap (action) |
| --- | --- | --- |
| `GOLANG-08-TESTING.mdc` | table-driven tests everywhere | tighten "prefer" to "require" |
| (none) | repo uses `errgroup` extensively | add section to GOLANG-06-CONCURRENCY |
| `RUBY-04-RSPEC-CONVENTIONS.mdc` | repo migrated to Minitest | rule is stale; drop or repurpose |
| (none) | chezmoi `private_*` files | add `DOTFILES-01-CHEZMOI-CONVENTIONS.mdc` |
```

### Step 5 diff proposal output

```markdown
## Proposed rule change <N> of <M>

**Gap:** <one sentence>

**Target:** `<absolute or repo-relative path>`

**Diff:**
\`\`\`diff
--- a/<path>
+++ b/<path>
@@ -<existing context> @@
- <removed line>
+ <added line>
\`\`\`

**Rationale:** <one paragraph>

Apply this change? (yes / no / modify)
```

### Step 7 delegation prompt (when Analyst delegates to Forge)

```
You are Forge. Apply the following rule change.

Target: <absolute path>
Change: <diff or full file content>
Commit: docs(rules): <subject>
Constraints:
- Do not run git push.
- This repo is chezmoi-managed; the target path is the source path. Do not run chezmoi apply.
- Follow DOTFILES-01-CHEZMOI-CONVENTIONS if the path is under a private_ or exact_ parent.
```

## Examples

### Good

```markdown
## Proposed rule change 1 of 2

**Gap:** `GOLANG-08-TESTING.mdc` says "prefer table-driven tests" but every test file in `internal/` uses table-driven form. The rule is weaker than the practice.

**Target:** `private_dot_config/exact_aider-desk/exact_rules/GOLANG-08-TESTING.mdc`

**Diff:**
\`\`\`diff
- Prefer table-driven tests for functions with multiple cases.
+ Table-driven tests are required for functions with multiple cases. Single-case tests may be straight-line.
\`\`\`

**Rationale:** Codebase reality is unanimous on table-driven. The "prefer" wording invites the agent to skip it on small functions, which contradicts every existing test file.

Apply this change? (yes / no / modify)
```

### Bad

```markdown
I've rewritten GOLANG-08-TESTING.mdc to be more comprehensive. It now covers
table-driven tests, mocking, test fixtures, integration tests, snapshot tests,
and property-based tests, with sections for each. Let me know what you think.
```

(No gap analysis. No diff. Full rewrite where a one-line change was needed. Adds sections for patterns not present in the codebase.)

```markdown
The rules look fine but I'll add a new rule file RULES-GENERAL.mdc with my
favorite practices.
```

(No grounding in observed repo. Generic "favorite practices" is exactly the failure mode this skill prevents.)

## Postconditions

Before exiting this skill:

- A three-column gap inventory exists in the conversation
- Every proposed diff cites the gap it closes
- No write has been performed without explicit user approval
- From Analyst: every write was delegated to Forge with a self-contained prompt
- No `chezmoi apply` has been suggested as part of the rule write — that is a separate user action

## Success Metrics

- Each accepted rule change closes a real, observed gap (verifiable in the code).
- Rejected proposals are clearly out-of-scope or aspirational, not careless.
- The diff column in the gap analysis matches the actual changes that landed.
- No rule file gains sections describing conventions the code does not follow.
- The repo's rule directory shrinks or stays flat when the change is "drop a stale rule"; it grows only when a genuine new concern appears.
