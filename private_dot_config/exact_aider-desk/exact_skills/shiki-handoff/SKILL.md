---
name: shiki-handoff
description: "Produce a structured handoff document so work can resume in a fresh session. Works at any session size; delegates state-gathering to subagents when context is large."
license: Apache-2.0
---

# Handoff

Produce a single self-contained handoff document that lets the user (or another agent) resume the current work in a fresh session without losing intent, progress, or next steps.

The skill is usable at any time and at any session size. Session size only changes *how* state is gathered, not *whether* the skill runs.

## When to Use

Use this skill when:

- User asks for a "handoff", "handoff doc", "context dump", "session summary to resume from", or similar
- User signals context pressure: "before compact", "context is filling up", "getting close to the limit", "before this session dies"
- Ending a long working session and wanting to resume tomorrow / on another machine
- Switching to a different agent profile or model and wanting to carry state across
- Before any irreversible session action (compact, clear, fork) while real work is in flight

Do not use when:

- Work is fully complete and verified → use shiki-archive
- No real progress has been made yet (nothing to hand off)
- User is asking for a commit message → use shiki-commit-message
- User is asking for a PRD or plan → use shiki-prd / shiki-plan
- Conversation was already compacted and state is missing → use shiki-compact-recovery first, then this skill

## Mode Declaration

**SHIKI MODE: Handoff**
Mode: analysis
Purpose: Capturing current workflow state into one resumable document
Implementation: BLOCKED — only the handoff file is written; no source code, tasks.md, or PRDs are modified

## Rules

### Rule: Always available, never gated by token count

**When:** User invokes handoff at any session size

**Then:** Run the skill

**Never:** Refuse because the session is "too small" or wait until some threshold

**Reason:** A handoff at 900 tokens is cheap and useful. A handoff at 900,000 tokens is critical. The skill must work in both cases.

### Rule: Pick execution strategy from a self-check

**When:** Skill starts

**Then:** Choose **inline mode** or **dispatched mode** using the self-check below

**Self-check (no token counting required):**

| Signal | Strategy |
|---|---|
| Short session, few tool calls, single focus area | inline |
| User said "before compact" / "context full" / "close to limit" | dispatched |
| Long session, many tool calls already, or broad repo work | dispatched |
| Many files touched or large artifact scan needed | dispatched |
| Unsure | **dispatched** (default) |

**Reason:** The cost of an unnecessary subagent call is small. The cost of failing to produce a handoff because the orchestrator ran out of context is large.

### Rule: In dispatched mode, do not read project artifacts in the orchestrator

**When:** Strategy is dispatched

**Then:** Delegate every artifact-reading job to a subagent via `subagents---run_task`

**Never:** Use power tools (`file_read`, `grep`, `glob`, `semantic_search`) in the orchestrator to gather handoff content while in dispatched mode

**Reason:** The point of dispatch is to keep large reads out of the orchestrator's context.

### Rule: Resolve save paths before dispatching anything

**When:** Skill starts

**Then:** Invoke shiki-worktree-utils first to resolve `SAVE_BASE`, project root, and worktree path

**Pass the resolved paths to every dispatched subagent.** Subagents must not re-detect worktree state.

### Rule: One narrow job per subagent, with a structured return contract

**When:** Dispatching a state-gathering job

**Then:** Specify exactly one section of the handoff doc, the exact paths to read, and the exact output schema (markdown fragment)

**Never:** Ask a subagent to "summarize the project" or "write the handoff doc"

**Reason:** Narrow jobs are cheap, parallelizable, and recover gracefully from individual failures.

### Rule: Partial handoff is better than no handoff

**When:** A dispatched job fails, times out, or returns nothing

**Then:** Save the document anyway with that section marked `[unavailable — gather manually on resume]`

**Never:** Block the entire handoff on a single missing fragment

### Rule: No new work during handoff

**When:** Running this skill

**Then:** The only file written is the handoff document

**Never:** Edit source code, tasks.md, PRDs, agent configs, or anything else during handoff. Suggested follow-up edits go into the handoff doc's "Next actions" section, not into the repo.

### Rule: Exclude secrets and bulk content

**When:** Filling the handoff doc

**Then:** Reference files by path, not by content. Include short excerpts only when essential.

**Never include:**

- API keys, tokens, OAuth credentials, passwords, PII
- Full file contents
- Raw logs or stack traces (link to them instead)
- Anything covered by `shiki-memory-storage`'s "never store" list

### Rule: Verify the saved file before claiming done

**When:** Handoff doc is written

**Then:** Read the saved file back and confirm the absolute path to the user

**Reason:** Iron Law 1 — no completion claims without verification.

## Process

### 1. Resolve paths

- Invoke **shiki-worktree-utils** to obtain `SAVE_BASE`, `PROJECT_ROOT`, and (if any) `WORKTREE_PATH`
- Target file: `{SAVE_BASE}/handoff/{YYYY-MM-DD-HHMM}-{slug}.md`
- `slug`: short kebab-case derived from the current task name, PRD name, or user-supplied label

### 2. Choose strategy

Apply the self-check rule. Announce the chosen strategy in one short line, e.g. `Handoff strategy: dispatched (long session).`

### 3. Gather state

**Inline mode** — orchestrator does this itself:

- `todo---get_items` for current task progress
- Read `tasks.md` and PRD via power tools (using paths from step 1)
- Inspect git status / branch / diff summary via `bash`

**Dispatched mode** — orchestrator dispatches the jobs below in parallel where possible, sequential otherwise. Each job is a separate `subagents---run_task` call. Pass resolved paths from step 1. Do **not** include the conversation history.

| Job | Subagent input | Return schema |
|---|---|---|
| A. Tasks & progress | `tasks.md` path | Completed tasks (id + title), in-progress task with exact stopping point, next 1–5 tasks |
| B. PRD & goal | PRD path (if any) | Goal, open decisions, success criteria — as bullets |
| C. Branch state | repo root | Current branch, base branch, files changed (path + 1-line role), staged vs unstaged summary |
| D. Repo TODOs (optional) | repo root | TODO/FIXME added in this branch, file:line + 1-line context |

Each subagent returns a markdown fragment ready to drop into the template. Do not ask any subagent to produce the whole document.

### 4. Assemble the document

Use the template below. Fill each section from the matching fragment (inline reads or dispatched returns). For any failed fragment, insert `[unavailable — gather manually on resume]`.

### 5. Save and verify

- Write the file with `file_write`
- Read it back with `file_read`
- Report the absolute path to the user
- Suggest: "Start a fresh task and point it at this file; the new session can activate **shiki-compact-recovery** to rebuild state."

## Handoff Document Template

```markdown
# Handoff — {project or task name}

- **Date:** {YYYY-MM-DD HH:MM TZ}
- **Project root:** {PROJECT_ROOT}
- **Worktree:** {WORKTREE_PATH or "—"}
- **Branch:** {branch} (base: {base})
- **Originating agent / task id:** {agent profile} / {task id}
- **Approximate session size:** {small | medium | large | near-limit}

## 1. Goal (why this work exists)

{One paragraph. Original user request or PRD goal. No implementation detail.}

## 2. Current mode and active skills

- Shiki mode: {Planning | Implementation | Verification | Analysis | Handoff}
- Active skills: {list}

## 3. Completed work

- [x] {task id} — {title} — {1-line outcome, file paths if relevant}
- [x] ...

## 4. In-progress work (exact stopping point)

- **Task:** {id + title}
- **What was being done:** {1–3 sentences}
- **Stopped at:** {file:line, command output, decision point}
- **Why stopped:** {context limit / end of day / blocked on X}

## 5. Open decisions and unresolved questions

- {decision or question} — {options considered, if any}

## 6. Next actions (ordered, ≤5)

1. {concrete next step}
2. ...

## 7. Key files and roles (≤15)

| Path | Role |
|---|---|
| {path} | {1-line role} |

## 8. Resume commands

```bash
# environment / branch
git -C {PROJECT_ROOT} status --short
git -C {PROJECT_ROOT} switch {branch}

# project-specific verification
{e.g. chezmoi diff, go test ./..., nvim --headless "+checkhealth" "+qa"}
```

## 9. Memory promotion candidates

Patterns / preferences worth promoting via shiki-memory-storage on resume:

- {candidate} — {why it is reusable, stable, actionable}

## 10. Excluded on purpose

- Secrets, tokens, credentials, PII
- Full file contents (paths only)
- Raw logs (linked, not pasted)
```

## Preconditions

- [ ] `shiki-worktree-utils` is available and resolves `SAVE_BASE`
- [ ] At least one of: an active TODO list, a tasks.md, a PRD, or a non-empty git diff exists (otherwise there is nothing to hand off)

## Postconditions

- [ ] Handoff file exists at `{SAVE_BASE}/handoff/{timestamp}-{slug}.md`
- [ ] File was read back and its absolute path was reported to the user
- [ ] No source code, tasks.md, PRD, or agent config was modified
- [ ] No secrets, full file contents, or raw logs were embedded

## Success Metrics

This skill is successful when:

- A fresh session can read only the handoff doc and resume work without re-asking the user for context
- The skill completes even at very large session sizes (because dispatched mode keeps the orchestrator's context small)
- A failed sub-job degrades one section, not the whole document

## Integration

Works with:

- **shiki-worktree-utils** — resolves save paths and project root (required first step)
- **shiki-compact-recovery** — the resume side; recovery scans `{SAVE_BASE}/handoff/` (via shiki-worktree-utils) and uses the most recent handoff doc as primary resume context
- **shiki-memory-storage** — section 9 lists candidates; actual storage happens on resume, not here
- **shiki-dispatching-parallel-agents** — if available, use it to run jobs A–D in parallel during dispatched mode
- **shiki-archive** — different lifecycle stage. Archive = work is done. Handoff = work is paused.

## Next Steps

After saving the handoff:

1. Suggest the user start a fresh task and pass the handoff file path as the first message
2. Suggest activating **shiki-compact-recovery** in the new session to rebuild TODO list and mode
3. Optionally store any clearly-eligible items from section 9 via memory tools — apply the strict eligibility filter from `shiki-memory-storage`
