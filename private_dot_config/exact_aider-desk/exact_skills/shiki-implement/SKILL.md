---
name: shiki-implement
description: "Execute tasks from tasks.md with mandatory code-change discipline. Requires file inspection before edits, TDD for code changes, language-specific tooling (Go), and verification before completion."
license: Apache-2.0
---

# Implement

Execute implementation tasks with optional Shiki skill invocation and verification.

## When to Use

Use this skill when:

- User says "proceed", "continue", "start", "begin"
- User indicates task continuation
- tasks.md exists with unchecked items

Do not use when:

- No tasks.md exists
- No TODO list exists
- User asks about requirements or planning

## Rules

### Rule: Check for compact recovery first

**When:** Starting implementation

**Then:** Check for compact recovery indicators

**Detection indicators:**
- "Conversation Summary" heading present
- Short prompts without clear context (< 30 chars)
- User says "continue", "proceed", "next" without specifying task
- Missing context about what was being worked on
- Confusion indicators: "where were we", "what's next"

**If indicators detected:**
**Then:** Invoke shiki-compact-recovery
**Then:** Proceed after recovery completes

### Rule: Use sensible defaults for task selection

**When:** User indicates continuation

**Then:** Use default behavior without prompting

**Default behavior:**
- User indicates continuation with incomplete TODO: Continue next incomplete task
- User indicates continuation after PRD/tasks.md creation: Execute all tasks
- User mentions specific task: Execute that task only
- User indicates continuation with unclear intent: Ask for clarification

**Continuation intent:** "proceed", "yes", "yeah", "y", "go", "continue", "ok", "okay", "start", "begin"

### Rule: Apply workflow routing

**When:** Starting implementation

**Then:** Apply auto-routing rules

**Routing rules:**
- User says "all" AND tasks > 10: Invoke shiki-two-stage-review-execution
- User says "all" AND tasks ≤ 10: Use shiki-implement
- User says "task N" (single): Use shiki-implement
- User says "phase N": Use shiki-implement
- User wants separate session: Invoke shiki-executing-plans
- Bug investigation: Invoke shiki-systematic-debugging

### Rule: Invoke code change discipline

**When:** About to modify any source file

**Then:** Invoke shiki-code-change-discipline

**Mandatory inspection:**
- Read affected files before editing
- Find call sites and dependencies
- Understand existing patterns
- Plan minimal change

**Fast path criteria (skip full inspection):**
- Change affects ≤ 1 file AND
- Change is ≤ 10 lines AND
- Change is isolated (no API changes) AND
- Change type is: typo fix, comment update, simple bug fix

### Rule: Detect language and invoke language-specific skill

**When:** Implementing in a specific language codebase

**Then:** Invoke language-specific implementation skill

**Language detection:**
- Go: `go.mod` exists → Invoke shiki-go-implementation
- (Other languages: use general shiki-code-change-discipline)

**Go-specific requirements (when detected):**
- Run `gofmt` or `goimports`
- Run `go build ./...`
- Run `go vet ./...`
- Run `go test ./...`
- Follow Go idioms (error handling, naming, interfaces)

### Rule: Require test-driven development for code changes

**When:** Writing new production code

**Then:** Require shiki-test-driven-development

**TDD is mandatory for:**
- New functions/methods
- Bug fixes (write failing test first)
- Behavior changes
- Refactoring (ensure tests exist first)

**TDD exceptions (explicit justification required):**
- Configuration-only changes
- Documentation-only changes
- Generated code
- Throwaway prototypes (explicitly marked)

**If exception applies:** State the exception explicitly before proceeding.

### Rule: Apply minimal change discipline

**When:** Implementing any task

**Then:** Minimize change scope

**Minimal change rules:**
- Make smallest change that accomplishes task
- Do not refactor adjacent code unless explicitly tasked
- Do not "improve" code outside task scope
- Preserve existing patterns and style
- Document any assumptions made

**Exception:** If adjacent changes are required, document why in commit message.

### Rule: Suggest and require relevant skills

**When:** During implementation

**Then:** Apply skills based on task context

**Required skills:**
- Before modifying files: shiki-code-change-discipline (mandatory)
- Before writing new code: shiki-test-driven-development (mandatory, with exceptions above)
- Before claiming completion: shiki-verification-before-completion (mandatory)

**Suggested skills:**
- Complex debugging: shiki-systematic-debugging
- Code review before merge: shiki-requesting-code-review

### Rule: Execute task cycle for each task

**When:** Executing tasks

**Then:** Follow task execution cycle

**Task execution cycle:**
1. Read task (title, description, implementation details)
2. Check PRD for requirements context
3. **Invoke shiki-code-change-discipline** (inspect affected files, understand existing patterns)
4. **Detect language**: If Go codebase (`go.mod` exists) → invoke shiki-go-implementation
5. **Apply TDD**: Write failing test first (unless exception applies)
6. Implement (write minimal, production-quality code following existing patterns)
7. Verification gate (tests, build, lint, language-specific tools)
8. Fix loop if verification fails
9. Risk assessment (what could break, blast radius)
10. Mark complete (edit tasks.md: `- [ ]` → `- [x]`)
11. Next task

### Rule: Apply memory store integration

**When:** Retrieve or store memory

**Then:** Follow eligibility criteria

**When to retrieve:**
- Before starting implementation: Retrieve workflow contracts
- Before complex tasks: Retrieve architectural decisions
- After debugging: Retrieve critical findings

**When to store:**
- After successful chunk validation: Store successful patterns
- After workflow completion: Store milestones and decisions
- Before starting: Store workflow contracts

**Store ONLY if ALL true:**
- Reusable across future tasks
- Stable (unlikely to change soon)
- Actionable (changes future behavior)
- Type matches: user-preference, code-pattern, or task

**Never store:**
- Task progress/status
- One-off bug details
- Implementation details
- Transient notes
- File lists
- Logs/stack traces
- Secrets/tokens/credentials/PII

### Rule: Handle git failures in container environments

**When:** Git commands fail during implementation

**Then:** Invoke shiki-container-git-fallback

**Git failure indicators:**
- `git commit` fails with permission/auth errors
- `git push` fails
- Running in containerized environment

**Fallback behavior:**
- Generate commit message using shiki-commit-message logic
- Provide formatted message for user to copy
- Provide exact git commands for manual execution
- Wait for user confirmation before continuing

**Example:**
```
## Commit Required (Manual)

I cannot execute git commands directly. Please run:

\`\`\`bash
git add -A
git commit -m "feat(api): add user endpoint"
\`\`\`

Let me know when committed.
```

### Rule: Report blocked tasks

**When:** Task is blocked

**Then:** Report blocker type and options

**Blocker types:**
- Dependency
- Unclear
- Technical
- External
- Git/Container (invoke shiki-container-git-fallback)

**Report format:**
> "⚠️ Task {task-id} is blocked. Reason: {description}. Options: provide needed info | skip | clarify"

### Rule: Report progress after each task

**When:** Task completes

**Then:** Report progress

**Progress format:**
```
✅ Task Complete: "{title}"
Progress: [completed]/[total] tasks ([percentage]%)

⏳ Next: "{next task title}"
```

## Process

1. Check for compact recovery indicators
2. If detected, invoke shiki-compact-recovery
3. Detect task scope (all tasks, specific task, unclear)
4. Apply workflow routing
5. Execute task cycle for each task
6. Report progress after each task
7. After all tasks complete, use shiki-verify

## Preconditions

Before using this skill, verify:

- tasks.md exists (use shiki-worktree-utils to locate)
- User intent is implementation (not planning)

**CRITICAL: Before accessing tasks.md**
- Stop if worktree state unknown
- Invoke shiki-worktree-utils
- Get resolved path for tasks.md
- Only then proceed with file operations

## Postconditions

After completing this skill, verify:

- All tasks in tasks.md marked complete
- Verification evidence provided for each task
- Tests pass (0 failures)
- Linter clean (0 errors)

## Success Metrics

This skill is successful when:

- All tasks complete with evidence
- Zero verification failures
- Code committed to branch

## Common Situations

**Situation:** User says "proceed" after planning

**Pattern:**
- Check: tasks.md exists
- If true: Execute all tasks
- If false: Ask what to implement

**Situation:** Verification fails

**Pattern:**
- When: verification_fails
- Then: fix_and_reverify
- Until: verification_passes
