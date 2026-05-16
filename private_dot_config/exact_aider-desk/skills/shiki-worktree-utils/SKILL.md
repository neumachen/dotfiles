---
name: shiki-worktree-utils
description: Worktree detection and path resolution for Shiki protocol. Detects if in worktree, finds shiki state across worktrees and AD data directory.
license: Apache-2.0
---

# Shiki Worktree Utils

Utility functions for detecting worktrees and resolving shiki state locations.

## Worktree Structure

```
Project Root:              X/.aider-desk
Worktree (optional):       X/.aider-desk/task/{task-id}/worktree/.aider-desk
```

## Detection Logic

**Search order:**
1. **Current worktree** (if in worktree): `<worktree>/.aider-desk/shiki/outputs/`
2. **Project root**: `<project-root>/.aider-desk/shiki/outputs/`
3. **Other worktrees**: `<project-root>/.aider-desk/task/*/worktree/.aider-desk/shiki/outputs/`

**Save preference:**
- If in worktree and it has `.aider-desk`: use worktree's `.aider-desk`
- Otherwise: use project root's `.aider-desk`

## Detection Scripts

**Worktree detection:**
```bash
WORKTREE_PATH=""; PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD"); [[ "$PWD" == */.aider-desk/task/*/worktree/* ]] && { WORKTREE_PATH="$PWD"; PROJECT_ROOT=$(echo "$PWD" | sed 's|/\.aider-desk/task/.*||'); }
```

**Find artifacts across all locations:**
```bash
find "$WORKTREE_PATH/.aider-desk/shiki/outputs" "$PROJECT_ROOT/.aider-desk/shiki/outputs" "$PROJECT_ROOT/.aider-desk/task/*/worktree/.aider-desk/shiki/outputs" -type f \( -name "full-prd.md" -o -name "quick-prd.md" -o -name "tasks.md" \) 2>/dev/null | sort
```

**Determine save location:**
```bash
if [ -n "$WORKTREE_PATH" ] && [ -d "$WORKTREE_PATH/.aider-desk" ]; then SAVE_BASE="$WORKTREE_PATH/.aider-desk/shiki/outputs"; else SAVE_BASE="$PROJECT_ROOT/.aider-desk/shiki/outputs"; fi
```

## Usage in Skills

When any shiki skill needs to find or save PRDs/tasks:

1. Detect worktree context (check if CWD is in `.aider-desk/task/*/worktree/*`)
2. Search all locations in priority order
3. Use save preference (worktree's `.aider-desk` if available, else project root)

**Reference this skill** for implementation details - do not duplicate detection scripts in other skills.

## Integration

This utility should be referenced by:
- shiki-refine - Finding existing PRDs
- shiki-compact-recovery - Scanning for artifacts
- shiki-prd - Saving PRDs
- shiki-verify - Finding PRDs and tasks
- shiki-plan - Finding PRDs
- shiki-summarize - Saving outputs
- shiki-implement - Finding tasks
- shiki-archive - Listing PRDs

## See Also

- shiki-using-git-worktrees - Manual worktree management
- using-shiki - Meta-skill for workflow orchestration
