---
name: shiki-commit-message
description: Generate conventional commit messages from filtered git diff. Use when committing changes and need a properly formatted commit message.
---

# Shiki Commit Message

Generate conventional commit messages from filtered git diff output.

**Announce at start:** "I'm using the shiki-commit-message skill to generate a commit message."

## Usage

Run the git diff filter script on the desired commit or changes, then analyze the output to generate a conventional commit message.

**Conventional Commits Format:**
```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Valid Types:**
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `style` - Code style changes (formatting, etc.)
- `refactor` - Code refactoring
- `test` - Adding or updating tests
- `chore` - Maintenance tasks
- `perf` - Performance improvements
- `ci` - CI/CD changes
- `build` - Build system changes

## Process

### Step 1: Run the Diff Script

Execute the git diff filter script on the target commit or changes:

```bash
# For staged changes
~/.aider-desk/skills/shiki-commit-message/scripts/git-diff-filter.sh

# For a specific commit
~/.aider-desk/skills/shiki-commit-message/scripts/git-diff-filter.sh HEAD~1

# For a commit range
~/.aider-desk/skills/shiki-commit-message/scripts/git-diff-filter.sh HEAD~3..HEAD

# For specific files
~/.aider-desk/skills/shiki-commit-message/scripts/git-diff-filter.sh path/to/file
```

The script filters out:
- Binary files (images, fonts, etc.)
- Minified files (.min.js, .min.css)
- Build artifacts (build/, dist/, node_modules/)
- Lock files (package-lock.json, yarn.lock, etc.)
- Source maps (.map)

### Step 2: Analyze the Diff

Review the filtered diff output to understand:
- What files changed
- What functionality was added/modified
- The scope of changes
- Any breaking changes

### Step 3: Generate the Message

Create a conventional commit message:

**Simple (single line):**
```
feat: add user authentication
```

**With scope:**
```
feat(auth): add OAuth2 login support
```

**With body:**
```
feat: add user authentication

- Add login form with email/password
- Implement JWT token generation
- Add password hashing with bcrypt
- Create auth middleware for protected routes
```

**Breaking change:**
```
feat!: change user API response format

BREAKING CHANGE: User object now uses camelCase instead of snake_case
```

## Integration

**Used by:**
- **shiki-finishing-a-development-branch** - After compressing commits, use this skill to generate proper commit message before `git commit --amend`

**Workflow:**
```bash
# After git town compress
git town compress

# Generate commit message
shiki-commit-message  # runs diff script, generates message

# Apply the message
git commit --amend -m "<generated message>"

# Continue with sync and propose/ship
git town sync
git town propose
```

## Best Practices

**DO:**
- Use imperative mood ("add" not "added" or "adds")
- Keep the first line under 72 characters
- Reference issues in footers: `Closes #123`
- Use body for complex changes with multiple bullet points

**DON'T:**
- Use "and" to combine multiple changes - split into separate commits
- Include version numbers in commit messages
- Put WIP or TODO in final commit messages
- Make the first line a complete sentence with period

## Examples

**Good:**
```
fix: resolve memory leak in image processing
```

```
feat(api): add rate limiting

- Add per-IP rate limiting middleware
- Configure default limits (100 req/min)
- Add Redis-based counter
- Expose configuration options
```

```
refactor(ui): extract button component

This consolidates duplicate button styles across the application
and provides a single source of truth for button variants.
```

**Bad:**
```
Added login functionality and fixed bugs
```

```
fix the thing
```

```
feat: add stuff and also refactor other stuff
```

## Container/Restricted Environment Fallback

When running in a containerized environment where git commands fail, this skill can still generate commit messages by analyzing the changes made in the current session.

**When git diff fails:**
1. Use file change tracking from the session
2. Analyze modifications made via power tools (file_write, file_edit)
3. Generate commit message based on session activity

**Output for manual commit:**
```
## Commit Message (for manual use)

I cannot run git commands directly. Here's the commit message for your changes:

\`\`\`
<type>(<scope>): <description>

<body>
\`\`\`

**To commit, run:**
\`\`\`bash
git add -A
git commit -m "<paste message above>"
\`\`\`

**Files changed in this session:**
- path/to/file1.go (modified)
- path/to/file2.go (created)
```

**Integration:** When git fails, invoke **shiki-container-git-fallback** for complete manual instructions.
