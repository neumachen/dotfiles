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
id:               <short-id-or-ulid>            — see "Document ID" below
path:             <vault-relative file path including .md>
filename:         <bare filename stem, without .md>   — `index` for Akten, ULID for the rest
title:            human-readable title
type:             akten | vermerk | zakki | kadai   — document kind, set by template
aliases:
tags:
  - example
created_at.utc:   "YYYY-MM-DDTHH:mm:ssZ"        — set at creation, never updated
created_at.local: "YYYY-MM-DDTHH:mm:ss±HH:MM"   — local wall-clock + offset at creation
modified_at.utc:  "YYYY-MM-DDTHH:mm:ssZ"        — auto-maintained by Linter on every save
modified_at.local:"YYYY-MM-DDTHH:mm:ss±HH:MM"   — set at creation; not refreshed on save (see below)
---
```

### Document ID

Every note's `id` is the bare identifier — no type prefix. The shape depends on type:

| Type | Identifier | Example |
|---|---|---|
| `akten` | 8-char Crockford-base32 short UUID (same as the folder name's first segment) | `7k3qxh2v` |
| `vermerk` | 8-char Crockford-base32 short UUID (same as the `vermerk.id` field) | `9pmt4az2` |
| `zakki` | full ULID (`YYYYMMDDHHMMSS-<26-char-base32>`, same as the filename) | `20260423135002-01kpxttywg6e00rgr5fpy57t8y` |
| `kadai` | full ULID (same as the filename) | `20260502153045-01kqab...` |

The `type:` field is the source of truth for kind. Removing the prefix from
`id` keeps the value identical to how it appears in the filename / folder
name and avoids duplicating type information in two places.

Filenames for `zakki`, `vermerk`, and `kadai` are the bare ULID (`<ulid>.md`). The
`YYYYMMDDHHMMSS-` prefix makes filenames lex-sort by creation time; the
Crockford-base32 ULID suffix provides per-second uniqueness. Akten use the folder
name `<short-uuid>-<slug>/` and an inner `index.md`.

The `path` field carries the document's full vault-relative path (with `.md`),
so a note's canonical location can be read straight from frontmatter without
walking the filesystem. The `filename` field is the bare stem (no `.md`):
`index` for Akten, the ULID for Zakki / Vermerk / Kadai. Both are
creation-time records — Obsidian auto-updates wikilinks on rename, but
doesn't update arbitrary frontmatter fields, so `path` and `filename` will
go stale if a note is moved or renamed manually.

Timestamp keys use flat dotted names (`created_at.utc`, `modified_at.local`, …) — same
reason as the `task.*` fields: Obsidian's Properties UI flattens nested YAML objects into
JSON strings, so dotted keys render as separate rows. **Linter only refreshes
`modified_at.utc`** on save (it natively supports a single key per concept). `*.local`
fields stay at their creation-time value; treat them as a "born-at" record, not a "last
edited" indicator. If you need fresh local-time tracking on save, that requires a custom
plugin — out of scope here.

Task notes additionally carry flat dotted-key fields in the same frontmatter block —
`task.task_id`, `task.start-date`, `task.due-date`, `task.priority`, `task.status`,
`task.icon`, `task.meta.attr`. Each one renders as its own row in Properties (Number for
priority, Date & time for the dates, Text for the rest), and Bases reads them as ordinary
string-keyed fields. See REFERENCE.md for the full task schema.

---

## Templates

Located at `<vault-root>/templates/`. All templates use Templater syntax.

| File | Hotkey | Command label (via Commander) | Purpose |
|---|---|---|---|
| `neuer-zakki.md` | `Cmd+N` | — | General note — prompts for title, lands in `zakki/YYYY/MM/DD/<id>` with `zakki` tag |
| `neuer-akten.md` | — | `Akten: Neue Akte` | Project folder — prompts for title, creates `akten/YYYY/MM/DD/<short-uuid>-<slug>/index.md` with tags `[akten, <short-uuid>]` |
| `neuer-vermerk.md` | — | `Akten: Neuer Vermerk` | Memo inside an Akte — runs in **insert mode** (matches `shinki-kadai`'s pattern). Auto-detects the parent Akte from the active file's enclosing folder; falls back to a suggester listing all Akten if none is active. Mode picker (`Title only` vs `Full document`) controls whether focus switches to the new Vermerk after creation. Lands in `akten/YYYY/MM/DD/<akte-folder>/Vermerke/<id>.md` (the `Vermerke/` subdirectory is created on first use) with tags `[vermerk, <vermerk-uuid>, <parent-akte-uuid>]` plus properties `vermerk.id: <vermerk-uuid>` and `reference.akten.id: <parent-akte-uuid>`. **Always inserts a wikilink to the new Vermerk into the parent Akte's `index.md`** under a `## Vermerke` section (created on first use, reused thereafter), regardless of which document is currently active. Searching by the Akte's UUID returns the index plus every Vermerk; searching by a Vermerk's own UUID returns just that Vermerk. |
| `shinki-kadai.md` | `Cmd+Shift+T` | `Kadai: Shinki Kadai (新規課題)` | Task note — runs in **insert mode** by default (the hotkey is bound to `templater-obsidian:templates/shinki-kadai.md`), so the active document stays open and a wikilink to the new task is dropped into it. Two creation modes: `Title only` (just title prompt) and `Full document` (also prompts an optional description, then opens the new task after the link is inserted — priority and due date can be edited later in the task file or via the Tasks plugin). Where the link goes depends on Vim mode: in **insert mode**, the link is inserted at the cursor; in **normal mode**, the link is appended under a `## Inserted Tasks` section at the end of the active document (created on first use, reused on subsequent inserts). The task file itself always lives at `kadai/YYYY/MM/DD/<id>.md`. **Context-aware label and references:** the mode picker's placeholder reflects the active document context — `Add to new Akten` (active = Akte index), `Add to new Vermerk` (active = Vermerk), `Add to new Zakki` (active = Zakki), or `Task creation` (no context). Reference fields follow the label: Akten → `reference.akten.id`; Vermerk → both `reference.vermerk.id` and `reference.akten.id` (parent); Zakki → `reference.zakki.id`; no context → no reference fields. **Standalone fallback:** invoking `Templater: Create new note from template → templates/shinki-kadai.md` (or any create-mode wrapper) skips the insert path entirely and creates the task as a standalone open file — same prompts, no reference fields, no link insertion. |
| `add-tag.md` | `Cmd+Alt+T` | — | Adds a tag to the current note's frontmatter. First shows a suggester populated from `app.metadataCache.getTags()` so existing tags fuzzy-autocomplete as you type; press `Esc` on the suggester to fall through to a free-form prompt for a brand-new tag. |

To pick any template interactively (including `neuer-akten`), use `Cmd+Shift+N`
(Templater → *Create new note from template*). To insert a template into the
current note, use `Cmd+Shift+I`.

### Custom command labels (Commander plugin)

The "Command label" column above lists names surfaced via the **Commander** plugin
(community plugin, install via Settings → Community plugins → search "Commander").
Commander exposes single-step macros that re-trigger an underlying command under a
custom palette label. They live in `dot_obsidian/plugins/cmdr/data.json` under the
`macros` array and are configured directly in source (no UI step needed):

| Macro name (palette label) | Underlying command ID |
|---|---|
| `Akten: Neue Akte` | `templater-obsidian:create-templates/neuer-akten.md` |
| `Akten: Neuer Vermerk` | `templater-obsidian:templates/neuer-vermerk.md` |
| `Kadai: Shinki Kadai (新規課題)` | `templater-obsidian:create-templates/shinki-kadai.md` |

Note: Obsidian prefixes plugin commands with the plugin name in the palette, so
the macros appear as `Commander: Akten: Neue Akte`, etc. — searching by `Akten`
or `Kadai` still surfaces them cleanly. The `Commander:` prefix is unavoidable
without writing a custom plugin.

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
`tags: [akten]`, `created_at.{utc,local}`, `modified_at.{utc,local}`). Add
subfolders or attachments inside the project folder freely; the project's
identity is the folder name and its canonical entry point is `index.md`.
Vermerke created via `Akten: Neuer Vermerk` land in a `Vermerke/`
subdirectory next to `index.md` (auto-created on first use) as
`<id>.md`, and a wikilink is appended to the index under a `## Vermerke`
section.

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
| `ui-hide-system-frontmatter.css` | Hides `id`-adjacent system frontmatter (`filename`, `path`, `type`, `created_at.*`, `modified_at.*`) from the Properties view; data stays in the file |
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
