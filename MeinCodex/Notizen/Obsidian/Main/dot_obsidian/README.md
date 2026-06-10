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
├── akten/          project folders, filed by creation month under YYYY/MM/
│   └── YYYY/MM/<uuid6>-<slug>/index.md
│                   (folder uses 6-hex-char UUID prefix; full UUID in frontmatter `id`)
│                   (see "Akten Project Folders" below)
├── assets/         attachments (images, PDFs, files)
├── kadai/          task notes — file-per-task with `task:` frontmatter, filed by creation date
│   └── YYYY/MM/DD/ created on demand by the new-task template
├── scripts/        Templater user scripts — shared helpers exposed via tp.user
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
id:               <full-uuidv4-hex>             — 32-char hex UUIDv4 (no hyphens), set at creation
path:             <vault-relative file path including .md>
filename:         <bare filename stem, without .md>   — first 6 hex chars of `id` for
                                                       zakki / kadai; `index` for Akten
                                                       (folder uses the 6-hex prefix
                                                       instead)
title:            human-readable title
type:             akten | zakki | kadai            — document kind, set by template
aliases:
tags:                                            — `<type>` (akten / zakki) auto-added;
                                                   `task` for kadai (Tasks plugin filter);
                                                   Zakki linked to an Akte also tag the
                                                   parent Akte's UUID6 for `#<akte-uuid6>`
                                                   cross-doc search; user-added tags
                                                   accumulate alongside
created_at.utc:   "YYYY-MM-DDTHH:mm:ssZ"        — set at creation, never updated
created_at.local: "YYYY-MM-DDTHH:mm:ss±HH:MM"   — local wall-clock + offset at creation
modified_at.utc:  "YYYY-MM-DDTHH:mm:ssZ"        — auto-maintained by Linter on every save
modified_at.local:"YYYY-MM-DDTHH:mm:ss±HH:MM"   — set at creation; not refreshed on save (see below)
---
```

### Document ID

Every note's `id` is a full 32-char hex UUIDv4 (hyphens stripped), generated
via `crypto.randomUUID()` at creation. Identical schema across types:

| Type | `id` | Filename / folder prefix | Example |
|---|---|---|---|
| `akten` | full UUID | first 6 hex chars + `-<slug>` (folder name) | folder `f47ac1-q3-tax-review/index.md`, `id: f47ac10b58cc4372a5670e02b2c3d479` |
| `zakki` | full UUID | first 6 hex chars + `-<slug>` (filename) | `9c2a8d-coffee-shop-thoughts.md`, `id: 9c2a8d11ef4a4b9aa2cb35bf12d8e0c5` |
| `kadai` | full UUID | first 6 hex chars + `-<slug>` (filename) | `3b1d6f-fix-failing-build.md`, `id: 3b1d6f7e88d9498aa6c2d5fe04a91e7c` |

Why short filenames: 32-char folder/filenames are noisy in the file
explorer and tab bar; the 6-hex prefix is enough for collision-free
naming inside a single date folder (16M-space, dozens of notes per day
worst case). The full UUID stays in frontmatter `id` as the canonical
identifier — anything that needs to disambiguate beyond the filename
reads `id` directly.

Zakki, Kadai, and Akten all append a sanitized title slug after the
6-hex prefix (`<uid6>-<slug>`) so the file explorer is readable. Slug
sanitization is identical across types: NFD-fold to ASCII, lowercase,
non-`[a-z0-9]` runs collapsed to `-`, trimmed, truncated to 60 chars
on a `-` boundary, falls back to `untitled` if empty. Akten encode the
slug in the folder name (the `index.md` itself keeps its bare `index`
filename); the other two encode it in the file basename.

The `type:` field is the source of truth for document kind. Time
ordering for Zakki / Kadai comes from the `YYYY/MM/DD/` parent folder
plus `created_at.utc`; the random UUID filename is unsortable and that's
fine.

The `path` field carries the document's full vault-relative path (with `.md`),
so a note's canonical location can be read straight from frontmatter without
walking the filesystem. The `filename` field is the bare stem (no `.md`):
`index` for Akten, `<uid6>-<slug>` for Zakki / Kadai. Both fields
stay in sync with the file's actual location via the
**`mein-codex-sync`** local plugin (see [Local Plugins](#local-plugins) below),
which installs **two** vault-wide listeners at vault open:

1. **`vault.on("rename", ...)`** — when a file is renamed/moved (by the
   user, by Obsidian's link-update side effects, or by listener #2),
   rewrite that file's `path:` and `filename:` frontmatter via
   `app.fileManager.processFrontMatter`.
2. **`metadataCache.on("changed", ...)`** — when the `title:`
   frontmatter of a managed note (Kadai under `kadai/YYYY/MM/DD/`,
   Zakki under `zakki/YYYY/MM/DD/`) changes, recompute
   `<uid6>-<slug>` from the new title and rename
   the file via `app.fileManager.renameFile`. The first metadata-changed
   event per file is treated as the indexing pass and skipped, so
   pre-existing legacy files are NOT mass-renamed at startup — bulk
   migration goes through the one-off scripts in
   `~/MeinCodex/Codekiste/obsidian/scripts/one-off/`.

Listeners are registered via the plugin's `this.registerEvent(...)`,
so Obsidian disposes them automatically on plugin unload/reload — no
`globalThis` bookkeeping required (the previous Templater-startup
implementation kept its own `offref` guards because nothing else
managed the listener lifetime).

Obsidian's built-in `alwaysUpdateLinks` setting rewrites wikilink
targets in tandem with the rename, so the link graph and per-note
frontmatter both follow. Caveat: only in-Obsidian renames fire the
events — renames done outside Obsidian (e.g., via shell) leave both
wikilinks and frontmatter stale.

**Coupling note for Bases authors:** the `path:` frontmatter field can
go stale if the sync plugin isn't running or if a file is renamed
outside Obsidian. When writing Bases filters or formulas that need a
note's location, prefer computing it dynamically from `file.path`
rather than reading the stored `path:` field — `file.path` is sourced
from Obsidian's file-tree at query time and is always current. Existing
Bases under `*/_bases/` already do this (none read `note["path"]`); the
stored `path:` field is kept for human readability in the Properties
UI and for shell/grep workflows, not for query correctness.

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

### Cross-document References

Every cross-document reference (child note pointing back at a parent) follows
a consistent two-field shape:

| Key | Value | Visible in Properties UI |
|---|---|---|
| `reference.<type>.id`   | uid6 for Akten, full 32-char UUID for Zakki | No — hidden by `ui-hide-system-frontmatter.css`; Bases queries still read it |
| `reference.<type>.link` | `"[[<vault-path>|<parent-title>]]"` wikilink alias | Yes — the clickable surface |

Both fields are written together, the `.id` always immediately above the
`.link`. Templates that emit references (`neuer-zakki.md`, `shinki-kadai.md`)
populate both at creation. Concrete shapes:

| Source → target | Fields written |
|---|---|
| Zakki → Akte    | `reference.akten.id` + `reference.akten.link` |
| Kadai → Akte    | `reference.akten.id` + `reference.akten.link` |
| Kadai → Zakki   | `reference.zakki.id` + `reference.zakki.link` (and, if the Zakki itself links to an Akte, both `reference.akten.*` lines propagate) |

The two-field shape is what lets the Properties UI stay readable (no raw
hashes cluttering the view) while Bases / shell queries / migration scripts
can keep filtering on the stable `.id`. Backfill for pre-existing references
that only carry the `.id` lives in
`~/MeinCodex/Codekiste/obsidian/scripts/one-off/migrate-add-reference-links.py`.

---

## Templates

Located at `<vault-root>/templates/`. All templates use Templater syntax.

| File | Hotkey | Command label (via Commander) | Purpose |
|---|---|---|---|
| `neuer-zakki.md` | `Cmd+N` | — | General note — prompts for title, lands in `zakki/YYYY/MM/DD/<uuid6>-<slug>.md` with tags `[zakki]`. Frontmatter `id` is the full 32-char UUID; filename uses the 6-hex prefix plus a sanitized title slug (slug rules identical to `neuer-akten.md`). **Akte-aware:** if an Akte's `index.md` is open in another pane when the template fires, the new Zakki is treated as a child of that Akte — its frontmatter gets `reference.akten.id` and `reference.akten.link` and the parent Akte's UUID6 is appended to `tags`. The `id` field is hidden from the Properties UI by `ui-hide-system-frontmatter.css` (Bases queries still see it); only the link surfaces. The Akte's `index.md` also gets a Bases code block inserted under a `## Zakki` section (created on first use, reused thereafter) scoped to that Akte's UUID6, so the index shows a live table of its Zakki children. Without an Akte in context, the Zakki is created standalone with no back-reference. |
| `neuer-akten.md` | — | `Akten: Neue Akte` | Project folder — prompts for title, creates `akten/YYYY/MM/<uuid6>-<slug>/index.md` with tags `[akten]`. Folder name uses the first 6 hex chars of the UUID; the full 32-char UUID lives in frontmatter `id`. |
| `shinki-kadai.md` | `Cmd+Shift+T` | `Kadai: Shinki Kadai (新規課題)` | Task note — runs in **insert mode** by default (the hotkey is bound to `templater-obsidian:templates/shinki-kadai.md`), so the active document stays open and a wikilink to the new task is dropped into it. Two creation modes: `Title only` (just title prompt) and `Full document` (also prompts an optional description, then opens the new task after the link is inserted — priority and due date can be edited later in the task file or via the Tasks plugin). Where the link goes depends on Vim mode: in **insert mode**, the link is inserted at the cursor; in **normal mode**, the link is appended under a `## Inserted Tasks` section at the end of the active document (created on first use, reused on subsequent inserts). The task file itself always lives at `kadai/YYYY/MM/DD/<uuid6>-<slug>.md` (slug rules match `neuer-akten.md`). The task body's `## Status` section embeds two `meta-bind` widgets: an `INPUT[inlineSelect(...):task.status]` dropdown constrained to the 6 canonical options (`incipient`, `in-progress`, `completed`, `discarded`, `blocked`, `abandoned`) and a derived `VIEW` field rendering `☑ Done` / `☐ Not done` based on whether `task.status` is `completed` or `discarded`. Status defaults to `incipient` at creation; change it via the dropdown. **Context-aware label and references:** the mode picker's placeholder reflects the active document context — `Add to new Akten` (active = Akte index), `Add to new Zakki` (active = Zakki), or `Task creation` (no context). Reference fields follow the label: Akten → `reference.akten.id`; Zakki → `reference.zakki.id`, plus `reference.akten.id` if the Zakki itself is linked to an Akte; no context → no reference fields. **Standalone fallback:** invoking `Templater: Create new note from template → templates/shinki-kadai.md` (or any create-mode wrapper) skips the insert path entirely and creates the task as a standalone open file — same prompts, no reference fields, no link insertion. |
| `add-tag.md` | `Cmd+Alt+T` | — | Adds a tag to the current note's frontmatter. First shows a suggester populated from `app.metadataCache.getTags()` so existing tags fuzzy-autocomplete as you type; press `Esc` on the suggester to fall through to a free-form prompt for a brand-new tag. Guarded against a missing QuickAdd dependency: if the QuickAdd plugin is disabled, the template surfaces a `Notice` and returns instead of throwing. |

The vault-wide rename + title-driven file-rename listeners that previously lived
in a `sync-system-frontmatter.md` Templater startup template now ship as the
[`mein-codex-sync` local plugin](#local-plugins) — listener semantics are
identical, but the Plugin lifecycle owns cleanup on reload.

All three creation templates (`neuer-akten`, `neuer-zakki`, `shinki-kadai`) and
`add-tag` share helpers (`slugify`, timestamp bundle, section/Bases-block
helpers) via `tp.user.obsidian_utils()` — defined once in
[`scripts/obsidian_utils.js`](#shared-templater-helpers) and exposed by
Templater's `user_scripts_folder` setting (`scripts`).

To pick any template interactively (including `neuer-akten`), use `Cmd+Shift+N`
(Templater → *Create new note from template*). To insert a template into the
current note, use `Cmd+Shift+I`.

### Shared Templater helpers

Vault-relative path: `scripts/obsidian_utils.js`. Templater discovers it via
the `user_scripts_folder: "scripts"` setting in
`dot_obsidian/plugins/templater-obsidian/data.json` and exposes it as
`tp.user.obsidian_utils()`. The module returns a helper object with:

| Helper | Purpose |
|---|---|
| `slugify(title)` | NFD-fold to ASCII, lowercase, collapse non-`[a-z0-9]` to `-`, truncate to 60 chars on a `-` boundary, fall back to `untitled`. The single source of truth for filename slug rules. |
| `getTimestamps()` | Returns `{ YYYY, MM, DD, hh, mm, ss, localIso, utcIso, startIso }` from a single `new Date()` call — covers every frontmatter timestamp this vault writes. |
| `sectionHasBaseScope(lines, headingIdx, sectionEnd, refKey, refValue)` | Detects whether a section already contains a ` ```base ` block scoped to a given `note["<refKey>"] == "<refValue>"` filter — used to make Bases-block insertion idempotent. |
| `insertBaseBlockIntoSection(app, file, baseBlock, headingText, refKey, refValue)` | Inserts a Bases block under `headingText`, idempotently. Section end is detected with `/^#{1,6}\s+/`, so H3+ subheadings under the section heading correctly terminate the section instead of being absorbed. |
| `expectedStem(file, title)` | Recomputes the `<uid6>-<slug>` stem for a managed Kadai / Zakki file. Reused by the sync plugin (which keeps its own copy because Obsidian plugins can't `require()` a vault-relative `.js`). |
| `AKTE_DIR_RE`, `KADAI_PATH_RE`, `ZAKKI_PATH_RE`, `UID6_RE` | The path-shape regexes. Centralized so they can't drift between consumers. |

Editing rules: keep `slugify`, `expectedStem`, and the path regexes
byte-identical between `scripts/obsidian_utils.js` and
`dot_obsidian/plugins/mein-codex-sync/main.js`. The plugin reproduces them
because the Obsidian plugin loader can't pull in vault-relative `.js` modules.

### Custom command labels (Commander plugin)

The "Command label" column above lists names surfaced via the **Commander** plugin
(community plugin, install via Settings → Community plugins → search "Commander").
Commander exposes single-step macros that re-trigger an underlying command under a
custom palette label. They live in `dot_obsidian/plugins/cmdr/data.json` under the
`macros` array and are configured directly in source (no UI step needed):

| Macro name (palette label) | Underlying command ID |
|---|---|
| `Akten: Neue Akte` | `templater-obsidian:create-templates/neuer-akten.md` |
| `Kadai: Shinki Kadai (新規課題)` | `templater-obsidian:create-templates/shinki-kadai.md` |

Note: Obsidian prefixes plugin commands with the plugin name in the palette, so
the macros appear as `Commander: Akten: Neue Akte`, etc. — searching by `Akten`
or `Kadai` still surfaces them cleanly. The `Commander:` prefix is unavoidable
without writing a custom plugin.

---

## Akten Project Folders

Each project under `akten/` is a folder containing `index.md`, never a flat note.
Projects are filed by creation month under `YYYY/MM/` (one fewer level of nesting
than `zakki/` and `kadai/` because Akten are coarser-grained — at most a handful
per month rather than many per day). Creation/update timestamps live only in the
`index.md` frontmatter — not in the directory name.

Path format:

    akten/YYYY/MM/<uuid6>-<title-slug>/index.md

- `YYYY/MM` — local creation year/month, zero-padded.
- `<uuid6>` — first 6 hex chars of the full UUIDv4 stored in `id`
  (e.g. `f47ac1` from `f47ac10b58cc4372a5670e02b2c3d479`). Short enough
  to keep folder names readable; full UUID in frontmatter for canonical
  identity. Random, not sortable; ordering by creation time isn't
  needed since the `YYYY/MM/` path already groups by month.
- `<title-slug>` — title NFD-folded to ASCII, lowercased, non-`[a-z0-9]` → `-`,
  runs collapsed, trimmed, truncated to 60 chars on a `-` boundary; falls back
  to `untitled` if empty.

`index.md` carries the standard note frontmatter (`id`, `title`, `aliases`,
empty `tags:`, `created_at.{utc,local}`, `modified_at.{utc,local}`). Add
subfolders or attachments inside the project folder freely; the project's
identity is the folder name and its canonical entry point is `index.md`.
Zakki created with an Akte in context (via `Cmd+N` while an Akte's
`index.md` is open in another pane) land in the regular
`zakki/YYYY/MM/DD/` tree, but their frontmatter carries
`reference.akten.id` back to the parent Akte. The Akte's `index.md`
gets a Bases code block inserted under a `## Zakki` section
(auto-created on first use) scoped to that Akte's UUID6, so the index
shows a live table of its Zakki children.

Examples:
- `akten/2026/05/f47ac1-q3-tax-review-fy26/index.md`
- `akten/2026/05/9c2a8d-migration-postgres-aurora/index.md`
- `akten/2026/05/3b1d6f-arger-mit-dem-vermieter/index.md`

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
| `obsidian-doubleshift` | Double-Shift → Quick Switcher |
| `table-editor-obsidian` | Tab/Enter navigation in markdown tables |
| `nldates-obsidian` | Natural language date autocomplete via `@` trigger |
| `omnisearch` | Replaces built-in search — vault-wide and in-file, Vim navigation |
| `obsidian-style-settings` | UI controls for `/* @settings */` blocks in CSS snippets and themes |
| `shiki-highlighter` | Replaces Obsidian's built-in Prism syntax highlighter with Shiki (the highlighter VS Code uses). Bundles Tokyo Night Storm — see `THEME.md` |
| `mysnippets-plugin` | CSS snippet manager in status bar |
| `obsidian-editor-shortcuts` | VS Code-style editor shortcuts |
| `obsidian-plugin-update-tracker` | Checks for plugin updates every 30 minutes |
| `settings-search` | Search bar inside Obsidian Settings |
| `tag-wrangler` | Rename, merge, search tags from tag pane |
| `homepage` | Opens `Welcome.md` on startup |
| `calendar` | Calendar widget in right sidebar |
| `templater-obsidian` | Template engine — powers all note creation flows |
| `obsidian-tasks-plugin` | Cross-vault task tracking — global filter: `#task` |
| `obsidian-meta-bind-plugin` | Inline property widgets — provides the `task.status` dropdown and derived done indicator in Kadai files. `excludedFolders: ["templates"]` keeps backticked widget syntax inert inside template source files. JS view fields are disabled (`enableJs: false`); current widgets only need math-mode `VIEW` and `INPUT[inlineSelect]`. **Important**: when binding to a flat YAML key with a literal dot (`task.status`, `created_at.utc`, etc.), use bracket notation: `INPUT[...:["task.status"]]` and `{["task.status"]}` inside view expressions. Unbracketed `task.status` is interpreted as nested-object access and silently fails to bind. |

### Local Plugins

Local plugins live under `dot_obsidian/plugins/<id>/` alongside the
community plugins, but their `main.js` is authored in this repository
rather than downloaded from the Obsidian community store. The
`.gitignore` and `.chezmoiignore` `plugins/**/main.js` wildcards each
carry an explicit `!`-negation for every local plugin's `main.js` so
the source ships with `chezmoi apply`.

| Plugin ID | Purpose |
|---|---|
| `mein-codex-sync` | Installs two vault-wide listeners at vault open: (1) `vault.on("rename", ...)` — rewrites each note's `path:` / `filename:` frontmatter after any rename or move; (2) `metadataCache.on("changed", ...)` — when `title:` changes on a managed Kadai / Zakki note, recomputes `<uid6>-<slug>` and renames the file via `app.fileManager.renameFile` (which triggers `alwaysUpdateLinks` to fix wikilinks vault-wide). The first metadata-changed event per file is treated as the indexing pass and skipped, so legacy bare-`<uid6>.md` files are NOT mass-renamed silently at startup. Listeners are owned by the Plugin lifecycle via `this.registerEvent(...)`, so cleanup on unload/reload is automatic — no `globalThis` bookkeeping. **Editing rule:** `slugify`, `expectedStem`, and the `KADAI_PATH_RE` / `ZAKKI_PATH_RE` / `UID6_RE` constants are duplicated verbatim in `scripts/obsidian_utils.js` (the tp.user helper module). Obsidian plugins can't `require()` vault-relative `.js` files, so both copies must stay in sync. |

---

## Appearance

- **Theme:** Tokyo Night Storm (in-repo theme — see [`THEME.md`](THEME.md))
- **Accent:** `#7aa2f7` (Tokyo Night Storm blue)
- **Base font size:** 16px
- **Mode:** Dark

The theme is a self-contained `theme.css` at
`dot_obsidian/themes/tokyo-night-storm/`, version-controlled with the rest of
the vault config. `THEME.md` documents the palette tokens, semantic-variable
mappings, and per-component selectors — consult it before changing any
visual setting.

### Active CSS Snippets

| File | Purpose |
|---|---|
| `editor-frontmatter.css` | Subdued frontmatter styling |
| `editor-tables.css` | Table borders, alternating rows |
| `plugin-mysnippets.css` | MySnippets status bar menu tweaks |
| `ui-compact-tab-header.css` | Compact tab bar |
| `ui-hide-system-frontmatter.css` | Hides `id`-adjacent system frontmatter (`filename`, `path`, `type`, `created_at.*`, `modified_at.*`, `reference.akten.id`, `reference.zakki.id`) from the Properties view; data stays in the file. `reference.akten.link` is deliberately *not* hidden — it's the user-visible clickable back-reference to the parent Akte. |
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

## Web Clipper Templates

[Obsidian Web Clipper](https://github.com/obsidianmd/obsidian-clipper) is a
browser extension, **not** an Obsidian plugin. Its templates live in the
extension's own browser storage, not in this vault. The JSON files under
`dot_obsidian/web-clipper-templates/` are version-controlled **archives** —
they are not loaded by Obsidian or by any plugin, and they are not wired into
Chezmoi's apply path beyond being rendered into the vault as inert files.

To restore on a new machine: open the Web Clipper extension → click the cog
(Settings) → **Templates** → **Import** → pick the JSON file from this folder.

| File | Purpose |
|---|---|
| `default.json` | Catch-all template (empty `triggers`). Writes clipped notes to `clips/<second-level-domain>/<full-domain>/<title|safe_name>.md`, with `title`, `url`, `site`, `domain`, `tags: clip`, and `created_at.utc` properties. `behavior: overwrite` — re-clipping a page with the same title replaces the existing file rather than producing a `Foo 1.md` sibling. |

The destination path is derived from the clipped page's domain. The
second-level label is extracted with the regex
`^(?:.*\.)?([^.]+)\.[^.]+$`, which is **not** public-suffix-aware on
purpose — it just takes the label immediately before the TLD. Worked example:

```
https://docs.github.com/en/actions
  domain  -> docs.github.com
  SLD     -> github
  note    -> clips/github/docs.github.com/<title|safe_name>.md
```

### `reorg-web-clippings.py`

The one-off script
[`MeinCodex/Codekiste/obsidian/scripts/one-off/reorg-web-clippings.py`](../../../../Codekiste/obsidian/scripts/one-off/reorg-web-clippings.py)
runs two phases against `clips/`:

1. **Reorg** — backfills the layout above for clippings created before this
   template existed. Reads each note's domain from frontmatter (`domain:`,
   then `url:`, then `source:`), applies the identical SLD regex, and moves
   files into the correct `<sld>/<full-domain>/` leaf.
2. **Dedupe** — within each leaf directory, groups files by canonical URL
   (fragments and tracking params like `utm_*`, `fbclid`, `ref`, `gclid`
   stripped; `http`/`https` collapsed; query keys sorted). For any group with
   more than one file, picks a winner by (largest body, newest
   `created_at.utc`, newest mtime, shortest filename — in that order) and
   moves the losers to `clips/_duplicates/<sld>/<full-domain>/` so nothing is
   ever deleted.

It is dry-run by default — pass `--apply` to actually move files. It never
rewrites file contents. Use `--skip-reorg` or `--skip-dedupe` to run only
one phase.

Template `behavior: overwrite` (above) handles the *future* dedupe case —
re-clipping a page with the same title replaces in place. This script
handles the *historical* dedupe case — duplicates that already accumulated
under the old `behavior: create` regime.

---

## See Also

- [`THEME.md`](THEME.md) — Tokyo Night Storm theme architecture, palette tokens, variable map, and quick-lookup table
- `REFERENCE.md` — keyboard shortcuts and service accounts
- `web-clipper-templates/` — archival Obsidian Web Clipper template exports (manual import)
