# Obsidian — Quick Reference

## Keyboard Shortcuts

### Note Creation

| Shortcut | Action |
|---|---|
| `Cmd+N` | New **Zakki** note — prompts for title, lands in `zakki/<id>` |
| `Cmd+Shift+N` | Templater template picker — choose any template to create a new note |
| `Cmd+Shift+T` | New **Task** note — fast (title only) or full (title, priority, due, description); lands in `kadai/YYYY/MM/DD/<id>` |
| `Cmd+Alt+M` | New **meeting** note |

### Editing

| Shortcut | Action |
|---|---|
| `Cmd+S` | Lint and save (formats + saves current note) |
| `Cmd+Shift+I` | Insert template into current note |
| `Cmd+Alt+T` | **Add tag** to current note (prompts for tag name) |
| `Alt+↓` | Move current line down |
| `Alt+↑` | Move current line up |

### Tasks

| Shortcut | Action |
|---|---|
| `Cmd+Shift+T` | New **Task** note (template-driven, file-per-task) — see *Note Creation* above |
| `Cmd+Alt+K` | Open Tasks-plugin modal on the current inline checkbox (edit fields of an inline `- [ ] #task` line) |
| `Cmd+Enter` | Toggle inline task done |

### Navigation

| Shortcut | Action |
|---|---|
| `Shift+Shift` | Quick Switcher |
| `Cmd+F` | Omnisearch — in-file (Vim: j/k navigate, Enter open) |
| `Cmd+Shift+F` | Omnisearch — vault-wide |

---

## Task Workflow

Tasks live as **one-file-per-task** under `kadai/YYYY/MM/DD/<id>.md`. Create them
with `Cmd+Shift+T` — Templater prompts for fast (title only) or full (title,
priority, due, description). Each task file carries the standard note frontmatter
(`id`, `title`, `aliases`, `tags`, `created`, `updated`) plus flat `task.*` fields
holding the structured task metadata.

The H1 of each task file is `# <icon> <title>` — the status icon flows from the
`task.icon` frontmatter field, so changing the icon updates the rendered heading
on next save.

Inline `- [ ] #task` checkboxes inside a task file (e.g. subtasks under
`## Subtasks`) are still picked up by the `obsidian-tasks-plugin` via the `#task`
global filter. Use `Cmd+Alt+K` to open the Tasks modal on a checkbox line and
`Cmd+Enter` to toggle one between open and done.

### Task Frontmatter (`task.*` fields)

The fields are flat dotted keys, not a YAML-nested object. Obsidian's Properties
panel collapses any nested YAML to a JSON-string field, so we use literal
`task.<name>` keys — Properties then shows each one as its own row.

| Field | Properties type | Notes |
|---|---|---|
| `task.task_id`    | Text          | UUID v4 — generated at creation |
| `task.start-date` | Date & time   | `YYYY-MM-DDTHH:mm:ss` (local) — defaults to creation time |
| `task.due-date`   | Date & time   | `YYYY-MM-DDTHH:mm:ss` (local) — empty if not set |
| `task.priority`   | Number        | 0–5 in 0.5 increments |
| `task.status`     | Text          | `incipient` · `in-progress` · `completed` · `rescinded` · `aborted` (defaults to `incipient`) |
| `task.icon`       | Text (emoji)  | Defaults from status: ⏳ incipient · 🚧 in-progress · ✅ completed · 🚫 rescinded · ❌ aborted. Editable in Properties. |
| `task.meta.attr`  | Text          | Freeform placeholder for ad-hoc per-task attributes |

`created` / `updated` are deliberately **not** duplicated under `task.*` — they
already exist at the top level of every note's frontmatter and are auto-maintained
by `obsidian-linter` on every `Cmd+S`.

Date fields are stored without a timezone offset so Obsidian recognizes them as
the native **Date & time** property type (sortable, calendar-pickable). Times are
implicitly local — fine for a single-timezone vault.

### Querying tasks

The `obsidian-tasks-plugin` queries inline checkboxes only. To query the
file-level `task.*` fields, use **Bases** (core, enabled) — e.g. a Base filtered
by `tags contains task` with columns `task.icon`, `task.status`, `task.priority`,
`task.due-date`. Inline subtasks within task files remain queryable via ordinary
`tasks` blocks:

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
