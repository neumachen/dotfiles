# OBSIDIAN CONFIGURATION KNOWLEDGE BASE

## OVERVIEW

Managed configuration, templates, and local automation for the existing Main vault.

## STRUCTURE

```text
Main/
├── dot_obsidian/       # Runtime .obsidian configuration
├── exact_templates/   # Runtime templates/; Templater Markdown
├── scripts/           # Templater user-script helpers
├── akten/_bases/      # Project/record overview
├── zakki/_bases/      # General-note overview
└── kadai/_bases/      # Task views
```

## WHERE TO LOOK

| Task | Location | Notes |
| --- | --- | --- |
| Vault conventions | `Main/dot_obsidian/README.md` | Identity, paths, references, template and plugin behavior |
| User workflow | `Main/dot_obsidian/REFERENCE.md` | Shortcuts and task/property reference; check against source |
| Appearance ownership | `Main/dot_obsidian/THEME.md` | Theme, snippet, and Shiki precedence; read before visual changes |
| App and key settings | `Main/dot_obsidian/{app,hotkeys,types}.json` | General settings, key bindings, and property types |
| Plugin configuration | `Main/dot_obsidian/community-plugins.json`, `Main/dot_obsidian/plugins/*/data.json` | Enabled plugin IDs and individual settings |
| Creation and tagging | `Main/exact_templates/` | `neuer-akten.md`, `neuer-zakki.md`, `shinki-kadai.md`, `add-tag.md`, `toggle-pin.md` |
| Shared helper API | `Main/scripts/obsidian_utils.js` | Called as `tp.user.obsidian_utils()` |
| Rename synchronization | `Main/dot_obsidian/plugins/mein-codex-sync/main.js` | Plugin lifecycle owns rename and metadata listeners |
| Persistent views | `Main/{akten,zakki,kadai}/_bases/*.base` | Filters, formulas, and table columns |
| Web Clipper recipe | `Main/dot_obsidian/web-clipper-templates/default.json` | Source recipe; existence alone does not establish browser import |

## LOCAL CONVENTIONS

- `Main/dot_obsidian` maps to the vault's `.obsidian`; the README's symlink
  description is not proof of the host's current filesystem layout.
- Templater directives such as `<%* ... %>` in `Main/exact_templates/*.md`
  execute in Obsidian. They are distinct from chezmoi's `.tmpl` rendering.
  `Main/dot_obsidian/plugins/templater-obsidian/data.json` sets folders to `templates`
  and `scripts`, with no startup templates.
- Akten use `akten/YYYY/MM/<uid6>-<slug>/index.md`; Zakki and Kadai use
  `<kind>/YYYY/MM/DD/<uid6>-<slug>.md`. Full IDs remain in frontmatter.
- Keep `slugify`, `expectedStem`, `KADAI_PATH_RE`, `ZAKKI_PATH_RE`, and
  `UID6_RE` synchronized between the helper and local plugin. Both source
  comments and README require this deliberate duplication.
- Flat dotted frontmatter keys require bracket access: `note["task.status"]`
  in Bases and `["task.status"]` in Meta Bind. Preserve reference-ID and
  wikilink pairs when changing contextual creation templates.
- Task statuses are `incipient`, `in-progress`, `completed`, `discarded`,
  `blocked`, `abandoned`. The template's done widget counts completed and
  discarded; the open-task Base additionally excludes abandoned.
- The vault's `Home.md` dashboard is vault-git content, ignored by this repo
  and by chezmoi; there is no source copy. Edit the live file in the vault.
- Bases (Obsidian 1.13): view-level filters use `filters:`; a `filter:` key
  is silently ignored. There is no `??` operator (use `if()`), and embedded
  blocks render every row unless the view sets `limit:`.
- `pinned` (checkbox, declared in `types.json`) marks a Zakki for the
  dashboard's Pinned section; `toggle-pin.md` (`Cmd+Alt+P`) flips it.

## CROSS-FILE CHECKS

- Repository-root `.gitignore` and `.chezmoiignore` describe the managed
  boundary. Preserve the explicit `mein-codex-sync/main.js` exception to
  generic plugin bundle exclusions.
- `../../../dot_local/bin/executable_obsidian-plugin-sync` re-adds tracked
  plugin manifests/settings. Its watcher is
  `../../../private_Library/LaunchAgents/com.neumachen.obsidian-plugin-sync.plist.tmpl`.
  Inspect both when changing settings synchronization behavior.
- Read actual templates and JSON when README/REFERENCE examples disagree;
  some prose predates the current task creation and timestamp fields.
- For helper/plugin edits, use `node --check` on the changed `.js` files.
  Template Markdown requires Templater-aware validation; Node syntax checks
  alone cannot establish correct Obsidian behavior.
