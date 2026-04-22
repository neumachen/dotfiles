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
├── akten/          project notes
├── assets/         attachments (images, PDFs, files)
├── templates/      Templater templates (also tracked by Chezmoi)
├── zakki/          all general notes — organized by tags, not folders
└── .obsidian/      ← this directory (dot_obsidian in Chezmoi)
```

---

## Note Identity

Every note carries a standard frontmatter block:

```yaml
---
id:       8-character hex short ID (e.g. a3f9b2c1) — stable, never changes
title:    human-readable title
aliases:
tags:
  - example
created:  YYYY-MM-DD HH:mm:ss
updated:  YYYY-MM-DD HH:mm:ss  ← auto-maintained by Linter on every save
---
```

Filenames are the bare ID (`a3f9b2c1.md`). Titles live in frontmatter, not filenames.
Task notes additionally carry a nested `task:` block (see Templates section below).

---

## Templates

Located at `<vault-root>/templates/`. All templates use Templater syntax.

| File | Hotkey | Purpose |
|---|---|---|
| `new-note.md` | `Cmd+N` | Opens Templater template picker — select a template to create a new note |
| `new-akten-note.md` | `Cmd+Shift+N` | Project note — prompts for title, lands in `akten/` with `akten` tag |
| `new-task-note.md` | `Cmd+Alt+N` | Task note — asks note/inline, prompts for title, inserts link at cursor |
| `daily-journal.md` | via Calendar | Daily journal — uses core Templates syntax, lands in `zakki/` |
| `add-tag.md` | `Cmd+Alt+T` | Adds a tag to current note's frontmatter via prompt |

### Task Note Frontmatter

```yaml
task:
  status: open       # open | in-progress | blocked | done | cancelled
  due:               # YYYY-MM-DD HH:mm:ss
  priority:          # low | medium | high | urgent
```

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
| Daily Notes | ✅ |
| Templates | ✅ (core — used for daily journal only) |
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
| New note folder | `zakki/` |

---

## See Also

- `REFERENCE.md` — keyboard shortcuts and service accounts
