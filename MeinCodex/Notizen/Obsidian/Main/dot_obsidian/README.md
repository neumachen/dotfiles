# Obsidian Vault — Configuration Reference

This directory (`dot_obsidian/`) is the Obsidian configuration source managed by
Chezmoi. It is symlinked to `.obsidian/` at the vault root on the host machine
after `chezmoi apply`. Do not rename or restructure this directory.

Vault content (notes, attachments, etc.) lives at the host vault path and is not
tracked here. Only configuration is tracked: plugin settings, hotkeys, appearance,
snippets, and templates.

---

## Vault Structure

```
<vault-root>/
├── akten/          project folders, filed by creation date under YYYY/MM/DD/
│   └── YYYY/MM/DD/<short-uuid>-<slug>/index.md
│                   (see "Akten Project Folders" below)
├── assets/         attachments (images, PDFs, files)
├── kadai/          task notes — file-per-task with `task:` frontmatter, filed by creation date
│   └── YYYY/MM/DD/ created on demand by the new-task template
├── templates/      Templater templates (also tracked by Chezmoi)
├── zakki/          general notes — filed by creation date under YYYY/MM/DD/, categorized by tags
│   └── YYYY/MM/DD/ created on demand by the new-zakki template
└── .obsidian/      ← this directory (dot_obsidian in Chezmoi)
```

Zakki organization is **date-based on disk** and **tag-based by category**. When a Zakki is
later consolidated into an Akten (record), its tag becomes the Akten's record category.

---

## Note Identity

Every note carries a standard frontmatter block:

```yaml
---
id:       YYYYMMDDHHMMSS-<ulid>  (e.g. 20260427143012-01jspxyzfhq8mw7s3a4b5c6d7e)
                                  — lex-sortable, time-ordered; never changes after creation
title:    human-readable title
aliases:
tags:
  - example
created:  YYYY-MM-DD HH:mm:ss
updated:  YYYY-MM-DD HH:mm:ss  ← auto-maintained by Linter on every save
---
```

Filenames are the bare ID (`20260427143012-01jspxyzfhq8mw7s3a4b5c6d7e.md`). Titles live in
frontmatter, not filenames. The `YYYYMMDDHHMMSS-` prefix makes filenames lex-sort by creation
time; the lowercase Crockford-base32 ULID suffix provides per-second uniqueness.

Task notes additionally carry flat dotted-key fields in the same frontmatter block —
`task.task_id`, `task.start-date`, `task.due-date`, `task.priority`, `task.status`,
`task.icon`, `task.meta.attr`. The dotted names are deliberate: Obsidian's Properties UI
flattens any truly nested YAML object into a JSON-string field, so we use literal
`task.<field>` keys instead. Each one then renders as its own row in Properties (Number for
priority, Date & time for the dates, Text for the rest), and Bases reads them as ordinary
string-keyed fields. See REFERENCE.md for the full task schema.

---

## Templates

Located at `<vault-root>/templates/`. All templates use Templater syntax.

| File | Hotkey | Purpose |
|---|---|---|
| `new-zakki.md` | `Cmd+N` | General note — prompts for title, lands in `zakki/YYYY/MM/DD/<id>` with `zakki` tag |
| `new-akten.md` | — | Project folder — prompts for title, creates `akten/YYYY/MM/DD/<short-uuid>-<slug>/index.md` with `akten` tag |
| `new-task.md` | `Cmd+Shift+T` | Task note — fast (title only) or full (title, priority, due, description) prompt; lands in `kadai/YYYY/MM/DD/<id>` with `task` tag and flat `task.*` frontmatter fields (`task_id`, `start-date`, `due-date`, `priority`, `status`, `icon`, `meta.attr`). The note's H1 prefixes the title with the status icon. |
| `meeting.md` | `Cmd+Alt+M` | Meeting note |
| `add-tag.md` | `Cmd+Alt+T` | Adds a tag to the current note's frontmatter via prompt |

To pick any template interactively (including `new-akten`), use `Cmd+Shift+N`
(Templater → *Create new note from template*). To insert a template into the
current note, use `Cmd+Shift+I`.

---

## Akten Project Folders

Each project under `akten/` is a folder containing `index.md`, never a flat note.
Projects are filed by creation date under `YYYY/MM/DD/` (matching the `zakki/`
and `kadai/` layout). Creation/update timestamps live only in the `index.md`
frontmatter — not in the directory name.

Path format:

    akten/YYYY/MM/DD/<short-uuid>-<title-slug>/index.md

- `YYYY/MM/DD` — local creation date, zero-padded.
- `<short-uuid>` — 8 lowercase Crockford-base32 chars (`0-9 a-z` minus `i l o u`),
  ~40 bits of entropy. Random, not sortable; ordering by creation time isn't
  needed since the `YYYY/MM/DD/` path already groups by day and projects aren't
  browsed chronologically.
- `<title-slug>` — title NFD-folded to ASCII, lowercased, non-`[a-z0-9]` → `-`,
  runs collapsed, trimmed, truncated to 60 chars on a `-` boundary; falls back
  to `untitled` if empty.

`index.md` carries the standard note frontmatter (`id`, `title`, `aliases`,
`tags: [akten]`, `created`, `updated`). Add subfolders or sibling notes inside
the project folder freely; the project's identity is the folder name and its
canonical entry point is `index.md`.

Examples:
- `akten/2026/05/02/7k3qxh2v-q3-tax-review-fy26/index.md`
- `akten/2026/05/02/9pmt4az2-migration-postgres-aurora/index.md`
- `akten/2026/05/02/r4w8nx0j-arger-mit-dem-vermieter/index.md`

---

## Core Plugins

| Plugin | Enabled |
|---|---|
| File Explorer | ✅ |
| Global Search | ✅ (hotkey suppressed — Omnisearch used instead) |
| Quick Switcher | ✅ (via Shift+Shift) |
| Backlinks | ✅ |
| Tag Pane | ✅ |
| Page Preview | ✅ |
| Daily Notes | ❌ (deferred — see *Daily Journal* note below) |
| Templates | ✅ (core) |
| Command Palette | ✅ |
| Editor Status | ✅ |
| Bookmarks | ✅ |
| Outline | ✅ |
| Word Count | ✅ |
| File Recovery | ✅ |
| Bases | ✅ |
| Graph | ❌ |
| Canvas | ❌ |
| Outgoing Links | ❌ |
| Properties | ❌ |
| Sync / Publish | ❌ |

---

## Community Plugins

| Plugin ID | Purpose |
|---|---|
| `obsidian-linter` | Auto-formats markdown on save — enforces heading style, spacing, tag format, timestamps |
| `obsidian-minimal-settings` | Minimal theme controls — Ayu Dark scheme, colorful headings, 45-char line width |
| `obsidian-doubleshift` | Double-Shift → Quick Switcher |
| `table-editor-obsidian` | Tab/Enter navigation in markdown tables |
| `nldates-obsidian` | Natural language date autocomplete via `@` trigger |
| `omnisearch` | Replaces built-in search — vault-wide and in-file, Vim navigation |
| `obsidian-style-settings` | UI controls for Minimal theme styling |
| `mysnippets-plugin` | CSS snippet manager in status bar |
| `obsidian-editor-shortcuts` | VS Code-style editor shortcuts |
| `obsidian-plugin-update-tracker` | Checks for plugin updates every 30 minutes |
| `settings-search` | Search bar inside Obsidian Settings |
| `tag-wrangler` | Rename, merge, search tags from tag pane |
| `homepage` | Opens `Welcome.md` on startup |
| `calendar` | Calendar widget in right sidebar |
| `templater-obsidian` | Template engine — powers all note creation flows |
| `obsidian-tasks-plugin` | Cross-vault task tracking — global filter: `#task` |

---

## Appearance

- **Theme:** Minimal (Ayu Dark)
- **Accent:** `#872ac6`
- **Base font size:** 16px
- **Line width:** 45 chars (readable line length on)
- **Mode:** Dark

### Active CSS Snippets

| File | Purpose |
|---|---|
| `editor-frontmatter.css` | Subdued frontmatter styling |
| `editor-tables.css` | Table borders, alternating rows |
| `plugin-mysnippets.css` | MySnippets status bar menu tweaks |
| `ui-compact-tab-header.css` | Compact tab bar |
| `ui-default-style-settings.css` | Default Style Settings overrides |
| `ui-statusbar-tweaks.css` | Status bar layout tweaks |

All snippet files follow `category-name.css` naming (lowercase, hyphenated).

---

## Editor Settings

| Setting | Value |
|---|---|
| Vim mode | ✅ enabled |
| Auto-pair markdown | ❌ disabled |
| Readable line length | ✅ enabled |
| Inline title | ❌ disabled |
| Line numbers | ❌ disabled |
| Indent guides | ✅ enabled |
| Tab size | 4 |
| Always update links | ✅ enabled |
| Trash | Local (`.trash/` inside vault) |
| Attachments folder | `assets/` |
| New note folder | `zakki/` (fallback for non-Templater "New note"; Templater `Cmd+N` writes to `zakki/YYYY/MM/DD/`) |

---

## Daily Journal (deferred)

There is no dedicated daily journal yet. For now, daily entries are effectively
derived from Zakki — filtering by date folder or by `created` frontmatter is the
intended way to read "the journal for a given day". The Daily Notes core plugin
is therefore disabled.

Eventually a dedicated daily journal directory will be added, following the same
date-folder + sortable-ID convention as Zakki. Its directory name will be German
(TBD), to match the naming style of `Notizen`/`Akten`/`Zakki`.

---

## See Also

- `REFERENCE.md` — keyboard shortcuts and service accounts
