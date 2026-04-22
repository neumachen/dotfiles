# Obsidian — Quick Reference

## Keyboard Shortcuts

### Note Creation

| Shortcut | Action |
|---|---|
| `Cmd+N` | Templater template picker — choose any template to create a new note |
| `Cmd+Shift+N` | New Akten note (direct → lands in `akten/`) |
| `Cmd+Alt+N` | New task note (asks note/inline → inserts link at cursor) |

### Editing

| Shortcut | Action |
|---|---|
| `Cmd+S` | Lint and save (formats + saves current note) |
| `Cmd+Shift+I` | Insert template into current note |
| `Cmd+Alt+T` | Add tag to current note (prompts for tag name) |
| `Alt+↓` | Move current line down |
| `Alt+↑` | Move current line up |

### Tasks

| Shortcut | Action |
|---|---|
| `Cmd+Shift+T` | Create or edit task (opens Tasks modal) |
| `Cmd+Enter` | Toggle task done |

### Navigation

| Shortcut | Action |
|---|---|
| `Shift+Shift` | Quick Switcher |
| `Cmd+F` | Omnisearch — in-file (Vim: j/k navigate, Enter open) |
| `Cmd+Shift+F` | Omnisearch — vault-wide |

---

## Task Workflow

1. Position cursor where you want the task reference
2. Press `Cmd+Alt+N`
3. Choose **Yes** (dedicated note) or **No** (inline only)
4. Type the task title
5. If Yes: a task note is created in `zakki/` and `[[id|Title]]` is inserted at cursor
6. Open the task note to add due date, priority, description, acceptance criteria

### Task Frontmatter Values

| Field | Options |
|---|---|
| `task.status` | `open` · `in-progress` · `blocked` · `done` · `cancelled` |
| `task.priority` | `low` · `medium` · `high` · `urgent` |
| `task.due` | `YYYY-MM-DD HH:mm:ss` |

### Tasks Query Example

````
```tasks
not done
tags include task
```
````

---

## Services & Accounts

> Do not store passwords here. Use a password manager for credentials.
> This file is tracked in git via Chezmoi.

| Service | Account / Notes |
|---|---|
| Obsidian account | |
| GitHub | |
| | |

---

## Notes

- The `#task` global filter distinguishes Tasks-managed checkboxes from plain markdown checkboxes
- `updated` frontmatter is auto-maintained by Linter on every `Cmd+S`
- Snippet IDs match filenames exactly (e.g. `editor-frontmatter` = `editor-frontmatter.css`)
- All Templater paths are vault-relative — no hardcoded filesystem paths
