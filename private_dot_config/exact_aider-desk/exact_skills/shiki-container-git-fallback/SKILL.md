---
name: shiki-container-git-fallback
description: "Fallback behavior when git commands fail in containerized environments. Provides commit messages and instructions for manual execution by the user."
license: Apache-2.0
---

# Container Git Fallback

Fallback behavior when git commands cannot be executed directly (e.g., containerized AiderDesk environments).

## When to Use

Use this skill when:

- Git commands fail with permission errors
- Git commands fail with authentication errors
- Running in a containerized environment without git access
- `git commit`, `git push`, `git branch` operations fail
- User indicates they need to run git commands manually

Do not use when:

- Git commands succeed normally
- Issue is a recoverable git error (merge conflict, etc.)

## Rules

### Rule: Detect git failure

**When:** Git command fails

**Then:** Classify failure type

**Failure types:**

| Error Pattern | Type | Action |
|---------------|------|--------|
| `fatal: not a git repository` | No repo | Report error, stop |
| `Permission denied` | Container/auth | Use fallback |
| `could not read Username` | Auth missing | Use fallback |
| `unable to access` | Network/auth | Use fallback |
| `failed to push` | Push blocked | Use fallback |
| `pre-commit hook` failed | Hook error | Report, ask user |

**Container indicators:**
- Running in Docker/Podman
- No SSH keys available
- No git credentials configured
- Mounted volume without git config

### Rule: Provide commit message for manual commit

**When:** `git commit` fails due to container/auth issues

**Then:** Provide formatted commit message for user

**Output format:**
```
## Git Commit Required (Manual)

I cannot execute git commands directly. Please run:

\`\`\`bash
git add -A
git commit -m "<commit message here>"
\`\`\`

**Commit Message:**
\`\`\`
<type>(<scope>): <description>

<body>

<footer>
\`\`\`

**Files changed:**
- path/to/file1.go
- path/to/file2.go

Let me know when committed, and I'll continue.
```

**Always include:**
- Full conventional commit message (invoke shiki-commit-message logic)
- List of files that should be staged
- Clear instruction to notify when done

### Rule: Provide branch instructions for manual branching

**When:** `git branch` or `git checkout -b` fails

**Then:** Provide branch creation instructions

**Output format:**
```
## Git Branch Required (Manual)

I cannot create branches directly. Please run:

\`\`\`bash
git checkout -b <branch-name>
\`\`\`

**Suggested branch name:** `<type>/<description>`

Let me know when the branch is created, and I'll continue.
```

### Rule: Provide push instructions for manual push

**When:** `git push` fails due to container/auth issues

**Then:** Provide push instructions

**Output format:**
```
## Git Push Required (Manual)

I cannot push directly. Please run:

\`\`\`bash
git push -u origin <branch-name>
\`\`\`

**Current branch:** `<branch-name>`
**Commits to push:** <N> commit(s)

Let me know when pushed, and I'll continue.
```

### Rule: Provide PR instructions for manual PR creation

**When:** `gh pr create` or equivalent fails

**Then:** Provide PR creation instructions

**Output format:**
```
## Pull Request Required (Manual)

I cannot create PRs directly. Please create a PR with:

**Title:** `<PR title>`

**Description:**
\`\`\`markdown
## Summary
<summary>

## Changes
- <change 1>
- <change 2>

## Test Plan
- [ ] <verification step>
\`\`\`

**Base branch:** `main` (or `master`)
**Head branch:** `<feature-branch>`

Let me know when the PR is created, and I'll continue.
```

### Rule: Wait for user confirmation

**When:** Manual git action requested

**Then:** Wait for user confirmation before continuing

**Confirmation phrases to recognize:**
- "done"
- "committed"
- "pushed"
- "created"
- "ok"
- "ready"
- "continue"

**After confirmation:**
- Verify state if possible (e.g., check file timestamps)
- Continue with next step

### Rule: Batch multiple git operations

**When:** Multiple git operations needed

**Then:** Batch into single manual instruction block

**Example:**
```
## Git Operations Required (Manual)

I cannot execute git commands directly. Please run these commands in order:

\`\`\`bash
# 1. Stage changes
git add -A

# 2. Commit
git commit -m "feat(auth): add OAuth2 login support

- Add login form with email/password
- Implement JWT token generation
- Add password hashing with bcrypt"

# 3. Push
git push -u origin feature/auth
\`\`\`

Let me know when complete, and I'll continue.
```

### Rule: Generate commit message using standard format

**When:** Providing commit message for manual commit

**Then:** Follow conventional commits format

**Use shiki-commit-message rules:**
- Analyze the changes made in current session
- Determine appropriate type (feat, fix, refactor, etc.)
- Include scope if clear
- Write imperative mood description
- Add body for non-trivial changes
- Include breaking change footer if applicable

**Commit message generation process:**
1. List files changed in session
2. Categorize changes (new feature, bug fix, refactor, etc.)
3. Identify scope from file paths
4. Write description summarizing the change
5. Add body explaining why if non-trivial

## Process

1. Attempt git command
2. If failure detected, classify failure type
3. If container/auth failure:
   - Generate appropriate manual instructions
   - Include all necessary details (commit message, branch name, etc.)
   - Wait for user confirmation
4. After confirmation, continue workflow

## Preconditions

Before using this skill, verify:

- Git command has actually failed
- Failure is due to container/auth issues (not logic error)
- Changes to commit/push exist

## Postconditions

After completing this skill, verify:

- User has clear instructions for manual execution
- Commit message follows conventional commits
- User has confirmed completion before continuing

## Success Metrics

This skill is successful when:

- User can execute git operations manually without confusion
- Commit messages are properly formatted
- Workflow continues smoothly after manual git operations
- No information is lost due to git command failures

## Integration

This skill is invoked by:
- **shiki-finishing-a-development-branch** - When git operations fail
- **shiki-implement** - When committing task completion fails
- **shiki-commit-message** - When git diff or commit fails
- **shiki-two-stage-review-execution** - When committing between tasks fails

## Common Situations

**Situation:** First git command fails in session

**Pattern:**
- Detect container environment
- Inform user: "I'm running in a container and cannot execute git commands directly. I'll provide commands for you to run manually."
- Switch to fallback mode for all subsequent git operations

**Situation:** Partial git success

**Pattern:**
- Some commands work (e.g., `git status`, `git diff`)
- Others fail (e.g., `git commit`, `git push`)
- Use fallback only for failing commands
- Continue using working commands for information gathering

**Situation:** User forgets to confirm

**Pattern:**
- After providing manual instructions, wait for response
- If user asks another question without confirming, remind:
  "Before I continue, please confirm you've completed the git operations I provided earlier."

**Situation:** Multiple tasks completed, need single commit

**Pattern:**
- Accumulate changes across tasks
- Generate comprehensive commit message covering all changes
- Provide single commit instruction at end of batch
