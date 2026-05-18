---
name: shiki-archive
description: Project management and archiving. Move completed work to .aider-desk/shiki/archive/. Generate completion summary.
license: Apache-2.0
---

# Archive

Archive completed projects and manage workspace organization.

## Mode Declaration

**SHIKI MODE: Archival**
Mode: management
Purpose: Organizing completed projects
Implementation: BLOCKED (file operations only)

## Archive Operations

**Interactive Archive:**

Reference **shiki-worktree-utils** for worktree detection to find all PRD projects.

1. List all PRD projects (search worktrees + project root)
2. Check which have 100% tasks completed
3. User selects which to archive
4. Move project to `.aider-desk/shiki/archive/` (always to project root)

**Archive Specific Project:**
1. Check task completion status in tasks.md
2. Warn if tasks incomplete
3. Get user confirmation
4. Move project directory

**Force Archive (Incomplete Tasks):**
- Use when project scope changed or tasks no longer relevant
- User explicitly confirms archiving incomplete work

**Delete Project (Permanent Removal):**
- Destructive action, cannot be restored
- Only for: failed experiments, duplicates, test data, abandoned prototypes
- Default: Archive (safe option) unless user explicitly requests delete

## File Operations (v5 Agentic-First)

Use native tools:
- **Read tool**: Check tasks.md completion status
- **Bash/mv**: Move directories to archive
- **Bash/rm**: Delete (with explicit confirmation only)
- **Bash/ls**: List projects and archive contents

## Archive Workflow

1. Check project exists and verify task completion
2. Warn if incomplete tasks (unless --force)
3. Get explicit confirmation
4. Move: `.aider-desk/shiki/outputs/{prd-name}` → `.aider-desk/shiki/archive/{prd-name}`
5. Verify operation completed
6. Generate completion summary

## Completion Summary

Include:
- Project name
- Tasks completed (X/Y)
- Key features implemented
- Date archived
- Notes for future reference

## Integration

References: `.aider-desk/shiki/instructions/workflows/archive.md`

## Next Steps

After archival, suggest:
- Start new project with shiki-prd
- Review archived projects
- Return to other work
