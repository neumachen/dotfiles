# Obsidian Theme — Tokyo Night Storm

> Canonical reference for the visual identity of this vault.
> Treat this file as load-bearing context: read it before suggesting any
> visual change, and prefer the precedence ladder below over edits to
> Obsidian's defaults.

## Overview

The vault runs a **single, self-contained theme** authored in-repo:

- **Theme identifier (folder name + `cssTheme` value + manifest `name`):** `tokyo-night-storm`
- **Display name (used in this doc and headings):** Tokyo Night Storm
- **Location (chezmoi source):**
  `dot_obsidian/themes/tokyo-night-storm/theme.css`
- **Selected by:** `dot_obsidian/appearance.json` → `cssTheme: "tokyo-night-storm"`
- **Accent color (Obsidian chrome):** `#7aa2f7` in `appearance.json` → `accentColor`
- **Mode:** Dark (`theme: "obsidian"` in `appearance.json`)

All visual definitions live in `theme.css`. CSS snippets in
`dot_obsidian/snippets/` sit on top of the theme for **layout** tweaks only
(frontmatter muting, table borders, tab compactness, status-bar layout) —
they do not redefine palette colors.

There is no separate "Minimal Theme Settings" or third-party theme involved
anymore; the previous Minimal + Ayu Dark setup was removed when this theme
was authored on 2026-05-12.

## Chezmoi source vs rendered target

Every file referenced below lives twice:

| Role | Path |
|---|---|
| Chezmoi source (authoritative, edit here) | `~/MeinCodex/Codebasis/github.com/neumachen/dotfiles/MeinCodex/Notizen/Obsidian/Main/dot_obsidian/` |
| Rendered target (what Obsidian reads) | `~/MeinCodex/Notizen/Obsidian/Main/.obsidian/` |

`chezmoi apply` copies source → target. The target is **not** a symlink, so
runtime edits Obsidian makes can drift from source until `chezmoi re-add`
captures them.

## File map

All paths are relative to the chezmoi source root
(`.../dot_obsidian/`). The rendered target uses the same paths under
`.obsidian/`.

| File | Role |
|---|---|
| `themes/tokyo-night-storm/theme.css` | Palette tokens, semantic-variable mappings, per-component styling. **All color decisions live here.** |
| `themes/tokyo-night-storm/manifest.json` | Theme metadata (`name`, `version`). The `name` matches the folder name (`tokyo-night-storm`); both must equal the `cssTheme` value in `appearance.json`. |
| `appearance.json` | Selects the active theme, base mode, accent color, base font size, and the enabled-snippets list. |
| `community-plugins.json` | Array of enabled community plugin ids. Includes `shiki-highlighter` (the syntax-highlighting source of truth) and `obsidian-style-settings`. |
| `plugins/shiki-highlighter/manifest.json` | Shiki Highlighter plugin manifest (source-tracked). |
| `plugins/shiki-highlighter/data.json` | Shiki configuration — selects the **Tokyo Night Storm** custom theme for dark mode and points `customThemeFolder` at `.obsidian/shiki-themes`. Source-tracked so the theme choice persists across machines. **All code-block syntax colors come from here, not from `theme.css`.** |
| `shiki-themes/tokyo-night-storm.json` *(rendered target only — fetched by chezmoi)* | VS Code TextMate theme file used by Shiki for Tokyo Night Storm. **Not committed to source.** Declared in [`.chezmoiexternal.toml`](../../../../../.chezmoiexternal.toml) at the repo root; `chezmoi apply` downloads it from `enkia/tokyo-night-vscode-theme` (master branch, 48h refresh) into `.obsidian/shiki-themes/tokyo-night-storm.json`. To upgrade, run `chezmoi update`. |
| `plugins/obsidian-style-settings/manifest.json` | Style Settings plugin manifest (source-tracked). |
| `plugins/obsidian-style-settings/data.json` | **Target only today** — Style Settings UI overrides are not committed to source. Run `chezmoi re-add` after tweaking via UI to persist across machines. |
| `snippets/editor-frontmatter.css` | Mutes the frontmatter block visually (color/opacity). Layout only. |
| `snippets/editor-tables.css` | Table borders + alternating rows. Layout only. |
| `snippets/ui-compact-tab-header.css` | Tighter tab bar. Layout only. |
| `snippets/ui-hide-system-frontmatter.css` | Hides system-managed frontmatter rows from Properties. |
| `snippets/ui-statusbar-tweaks.css` | Status-bar layout tweaks. |
| `snippets/plugin-mysnippets.css` | MySnippets status-bar menu styling. |
| `snippets/ui-default-style-settings.css` | **Disabled.** A Style Settings shim for the *default* Obsidian theme. Inert under Tokyo Night Storm; kept on disk for reference. |

Disabled-but-present snippets (`editor-external-links`, `editor-internal-links`,
`plugin-calendar`, `plugin-task-wrapper-tweaks`, `ui-hover-preview-tweaks`,
`ui-list-items-compact`, `ui-new-empty-tab-tweaks`, `print-dark-pdf-export`) are
parked for future use and have no effect today.

## Precedence ladder

When two rules collide, higher entries win:

1. **Shiki Highlighter** — inside fenced code blocks only. Shiki injects
   inline `style="color: …"` on each token, which wins over any CSS rule.
   Configured via `plugins/shiki-highlighter/data.json`. Does not affect
   anything outside `pre > code`.
2. **Enabled CSS snippets** (`snippets/*.css` listed in `appearance.json` →
   `enabledCssSnippets`). Last loaded; highest CSS source-order specificity
   among same-specificity selectors. Use sparingly — prefer changing the
   theme for color, snippets for layout.
3. **Style Settings overrides** (Settings → Style Settings). Stored in
   `plugins/obsidian-style-settings/data.json`. Override the `--tn-*`
   tokens and any other variable declared in a `/* @settings */` block.
4. **Tokyo Night Storm theme** (`themes/tokyo-night-storm/theme.css`):
   - First the `--tn-*` palette tokens are defined.
   - Then they are mapped to Obsidian's semantic variables.
   - Then per-component selectors apply.
5. **Obsidian core defaults** — anything not overridden falls back here.

## Palette tokens

Defined under `.theme-dark` in `theme.css`. A parallel `.theme-light` block
provides safe fallbacks if the user toggles to light mode.

| Token | Dark hex | Light hex | Role |
|---|---|---|---|
| `--tn-bg` | `#24283b` | `#d5d6db` | Primary background |
| `--tn-bg-alt` | `#1f2335` | `#cbccd1` | Secondary background (sidebars, code) |
| `--tn-bg-highlight` | `#292e42` | `#dfe0e5` | Line highlight, hover surfaces |
| `--tn-bg-popup` | `#1d202f` | `#cbccd1` | Modals, suggester, popovers |
| `--tn-fg` | `#c0caf5` | `#343b58` | Normal text |
| `--tn-fg-dim` | `#a9b1d6` | `#565a6e` | Muted text |
| `--tn-fg-faint` | `#565f89` | `#9699a3` | Faint text, comments, blockquote body |
| `--tn-blue` | `#7aa2f7` | `#34548a` | Accent, internal links, h2 |
| `--tn-cyan` | `#7dcfff` | `#0f4b6e` | External links, tags, h3 |
| `--tn-purple` | `#bb9af7` | `#5a3e8e` | h1, blockquote border, keywords |
| `--tn-magenta` | `#ff007c` | `#a8124b` | Callout `example`, syntax `important` |
| `--tn-green` | `#9ece6a` | `#33635c` | Strings, success, h4 |
| `--tn-yellow` | `#e0af68` | `#8f5e15` | Warning, h5 |
| `--tn-orange` | `#ff9e64` | `#965027` | Numbers, callout `bug`, h6 |
| `--tn-red` | `#f7768e` | `#8c4351` | Errors, unresolved links |
| `--tn-line` | `#3b4261` | `#a8aecb` | Borders, dividers, table cell borders |
| `--tn-selection` | `rgba(40,52,87,0.85)` | `rgba(122,162,247,0.28)` | Text selection background |
| `--tn-highlight` | `rgba(224,175,104,0.32)` | `rgba(143,94,21,0.22)` | `==highlighted text==` background |

All tokens are also exposed in the `theme.css` `/* @settings */` schema, so
Settings → Style Settings → tokyo-night-storm shows color pickers for each.

## Quick lookup table

Find what you want to change; the row tells you the variable, where it's
set, and which selectors consume it. Source paths are relative to
`dot_obsidian/`. "Both" means the rule applies in both live-preview and
reading mode unless otherwise noted.

| Concern | Obsidian variable | Primary selector(s) | Source file | Mode | Notes |
|---|---|---|---|---|---|
| App background | `--background-primary` | `.app-container`, page body | `themes/tokyo-night-storm/theme.css` § *Surfaces* | Both | Backed by `--tn-bg`. |
| Secondary surface | `--background-secondary`, `--background-secondary-alt` | sidebars, file explorer pane, tab bar | § *Surfaces* | Both | Backed by `--tn-bg-alt` / `--tn-bg-popup`. |
| Hover surface | `--background-modifier-hover` | any hoverable row | § *Surfaces* | Both | Backed by `--tn-bg-highlight`. |
| Border / divider | `--background-modifier-border`, `--divider-color` | pane borders, hr | § *Surfaces*, § *Status bar* | Both | Backed by `--tn-line`. |
| Main text | `--text-normal` | body text | § *Text & Links* | Both | Backed by `--tn-fg`. |
| Muted text | `--text-muted` | secondary copy, metadata | § *Text & Links* | Both | `--tn-fg-dim`. |
| Faint text | `--text-faint` | very secondary copy, frontmatter | § *Text & Links* | Both | `--tn-fg-faint`. |
| Accent (in-text) | `--text-accent`, `--text-accent-hover` | accent text uses | § *Text & Links* | Both | `--tn-blue` / `--tn-cyan`. |
| Accent (interactive chrome) | `--interactive-accent`, `accentColor` in `appearance.json` | buttons, toggles, OS-level accents | `appearance.json`, § *Text & Links* | Both | The `appearance.json` value drives macOS title-bar and some Obsidian-chrome surfaces; the CSS variable drives in-app buttons. Keep both in sync. |
| Internal link | `--link-color`, `--link-color-hover` | `.internal-link`, `.cm-hmd-internal-link` | § *Text & Links* | Both | `--tn-blue`; hover flips to `--tn-cyan`. |
| External link | `--link-external-color` | `.external-link`, `.cm-link` | § *Text & Links* | Both | `--tn-cyan`. |
| Unresolved link | `--link-unresolved-color`, `--link-unresolved-opacity` | `.is-unresolved` | § *Text & Links* | Both | Dashed underline, `--tn-red`. |
| h1 | `--h1-color` | `.markdown-rendered h1`, `.HyperMD-header-1` | § *Headings* | Both | `--tn-purple`. |
| h2 | `--h2-color` | `.markdown-rendered h2`, `.HyperMD-header-2` | § *Headings* | Both | `--tn-blue`. |
| h3 | `--h3-color` | `.markdown-rendered h3`, `.HyperMD-header-3` | § *Headings* | Both | `--tn-cyan`. |
| h4 | `--h4-color` | `.markdown-rendered h4`, `.HyperMD-header-4` | § *Headings* | Both | `--tn-green`. |
| h5 | `--h5-color` | `.markdown-rendered h5`, `.HyperMD-header-5` | § *Headings* | Both | `--tn-yellow`. |
| h6 | `--h6-color` | `.markdown-rendered h6`, `.HyperMD-header-6` | § *Headings* | Both | `--tn-orange`. |
| Tag pill | `--tag-color`, `--tag-background`, `--tag-border-color` | `.tag` | § *Tags* | Both | Cyan text, faint-cyan fill, hairline border. |
| Highlight | `--text-highlight-bg`, `--text-highlight-bg-active` | `==text==`, search-active highlight | § *Text & Links* | Both | Warm-yellow alpha (`--tn-highlight`). |
| Selection | `--text-selection` | text-selection background | § *Text & Links* | Both | `--tn-selection`. |
| Inline code | `--code-inline-background`, `--code-inline-color` | `code` (excluding `pre code`), `.cm-inline-code` | § *Code* | Both | Lighter surface (`--tn-bg-highlight` = `#292e42`) with orange text (`--tn-orange`) so inline code visibly pops off the page; rounded, slight bold. The theme owns inline code styling — Shiki does not touch it. |
| Code block (container) | `--code-background`, `--code-normal` | `pre`, `.markdown-rendered pre`, `.HyperMD-codeblock-bg` | § *Code* | Both | Sits on `--tn-bg-alt` (`#1f2335`), bordered with `--tn-line`. Inner `pre code` resets to transparent so Shiki's token colors show through. |
| Code syntax (tokens inside fenced blocks) | *(none — Shiki injects inline `<span style="color: ...">`)* | `.shiki`, `.shiki .line span` | `plugins/shiki-highlighter/data.json` (target) — not in chezmoi source until `chezmoi re-add` | Both | **Owned by the Shiki Highlighter community plugin** (`shiki-highlighter` by mProjectsCode). Configure dark/light theme in Settings → Shiki Highlighter. Tokyo Night Storm is bundled with the plugin. The theme intentionally does **not** define `.token.*` / `.cm-*` / `.tok-*` rules to avoid fighting Shiki. |
| Blockquote | `--blockquote-color`, `--blockquote-border-color`, `--blockquote-border-thickness` | `blockquote`, `.cm-blockquote` | § *Blockquotes* | Both | `--tn-fg-dim` body, `--tn-purple` border. |
| Callout — note/info/todo | `--callout-note`, `--callout-info`, `--callout-todo` | `.callout[data-callout="..."]` | § *Callouts* | Both | Blue (`--tn-blue` RGB). |
| Callout — abstract/summary/tldr | `--callout-abstract`, `--callout-summary`, `--callout-tldr` | as above | § *Callouts* | Both | Purple. |
| Callout — tip/hint/important/success/check/done | `--callout-tip`, `--callout-hint`, `--callout-important`, `--callout-success`, `--callout-check`, `--callout-done` | as above | § *Callouts* | Both | Green. |
| Callout — question/help/faq | `--callout-question`, `--callout-help`, `--callout-faq` | as above | § *Callouts* | Both | Cyan. |
| Callout — warning/caution/attention | `--callout-warning`, `--callout-caution`, `--callout-attention` | as above | § *Callouts* | Both | Yellow. |
| Callout — failure/fail/missing/danger/error | as listed | as above | § *Callouts* | Both | Red. |
| Callout — bug | `--callout-bug` | as above | § *Callouts* | Both | Orange. |
| Callout — example | `--callout-example` | as above | § *Callouts* | Both | Magenta. |
| Callout — quote/cite | `--callout-quote`, `--callout-cite` | as above | § *Callouts* | Both | Faint (`--tn-fg-faint`). |
| Sidebar background | `--background-secondary` | side panes | § *Surfaces* | Both | Same as alt surface. |
| File explorer (item) | `--nav-item-color`, `--nav-item-color-hover` | `.nav-file-title` | § *Navigation* | Both | Dim → fg on hover. |
| File explorer (active file) | `--nav-item-background-active`, `--nav-file-title-color-active` | `.nav-file-title.is-active` | § *Navigation* | Both | Translucent blue fill, blue text, bold. |
| File explorer indent guide | `--nav-indentation-guide-color` | `.nav-indentation-guide-line` | § *Navigation* | Both | `--tn-line`. |
| Tab bar | `--tab-background`, `--tab-background-active`, `--tab-text-color*`, `--tab-outline-color` | `.workspace-tab-header` | § *Tabs & Title Bar* | — | Active tab fg = `--tn-fg`; inactive tabs = `--tn-fg-faint`. Layout from `ui-compact-tab-header.css`. |
| Title bar | `--titlebar-background`, `--titlebar-text-color`, `--titlebar-text-color-focused` | OS title bar / Obsidian header | § *Tabs & Title Bar* | — | Backed by `--tn-bg-alt`. |
| Status bar | `--status-bar-background`, `--status-bar-text-color`, `--status-bar-border-color` | `.status-bar` | § *Status bar* | — | Layout extras from `ui-statusbar-tweaks.css`. |
| Table border | `--table-border-color`, `--table-header-background`, `--table-row-alt-background`, `--table-row-background-hover` | `.markdown-rendered table` | § *Tables* + `editor-tables.css` snippet | Both | Snippet adds alternating rows; theme owns colors. |
| Checkbox | `--checkbox-color`, `--checkbox-border-color`, `--checkbox-marker-color`, `--checkbox-radius` | `.task-list-item-checkbox` | § *Checkboxes & Lists* | Both | Blue when checked. |
| Checklist done text | `--checklist-done-color`, `--checklist-done-decoration` | `.task-list-item.is-checked` | § *Checkboxes & Lists* | Both | Faint + strike-through. |
| Modal / suggester | `--background-secondary-alt`, `--background-modifier-border` | `.modal`, `.suggestion-container`, `.prompt` | § *Modal / suggester* | Both | Popup bg = `--tn-bg-popup`. |
| Scrollbar | `--scrollbar-bg`, `--scrollbar-thumb-bg`, `--scrollbar-active-thumb-bg` | platform scrollbars | § *Status bar / minor chrome* | Both | Transparent track, soft alpha thumb. |
| Graph view | `--graph-line`, `--graph-node`, `--graph-node-tag`, `--graph-node-attachment`, `--graph-node-unresolved`, `--graph-node-focused`, `--graph-text` | Graph plugin canvas | § *Graph view* | — | Graph core plugin is disabled today; values are ready if you enable it. |
| Tag pane (sidebar) | `.tag-pane-tag-text` (selector) | tag pane list | § *Plugin-specific overrides* | — | Forces cyan to match in-text tag color. |
| Properties view (frontmatter) | `.metadata-property-key`, `.metadata-property-value` | Properties pane | § *Plugin-specific overrides* | — | Key = dim, value = fg. `ui-hide-system-frontmatter.css` hides system rows separately. |
| Frontmatter color (in source view) | `.cm-hmd-frontmatter` | live-preview source | § *Plugin-specific overrides* + `editor-frontmatter.css` snippet | Editor | Theme picks the color; the snippet handles fold/opacity behavior. |
| Status bar accent | `--text-accent` (cascades through chrome) | `.status-bar`, mode pills | § *Text & Links* | — | Style Settings can override globally. |
| OS-level chrome accent | `accentColor` field | macOS title bar coloring, some Obsidian chrome | `appearance.json` | — | Distinct from `--interactive-accent`; keep both = `#7aa2f7`. |

### Section headers in `theme.css`

The theme file uses `/* === Name === */` banners. Sections in source order:

1. *Palette tokens*
2. *Surfaces*
3. *Text & Links*
4. *Headings*
5. *Code* (inline code styling + fenced-block container — token colors are owned by Shiki, not by the theme)
6. *Callouts*
7. *Tags*
8. *Tables*
9. *Blockquotes*
10. *Navigation* (sidebars + file explorer)
11. *Tabs & Title Bar*
12. *Checkboxes & Lists*
13. *Graph view*
14. *Status bar / minor chrome*
15. *Modal / suggester*
16. *Plugin-specific overrides*

The lookup table column "Source file" references these by name.

## How to change a color

1. Find the row in the quick-lookup table for the concern you want to change.
2. Open the listed source file in the chezmoi source path.
   - For palette-level changes, edit the matching `--tn-*` token in the
     `.theme-dark` (and optionally `.theme-light`) blocks at the top of
     `theme.css`. Every variable that uses that token will follow.
   - For one-off changes that should not affect everything keyed to that
     token, edit the corresponding semantic variable mapping in the
     section the lookup table points to.
   - Selector-level styling tweaks (border radius, font weight, etc.)
     belong in the same per-component section.
3. Preview, then apply through chezmoi:
   ```sh
   chezmoi diff --no-pager
   # close Obsidian
   chezmoi apply --no-pager --remove
   ```
4. Reopen Obsidian and confirm the change. `--no-pager` is required —
   `PAGER=cat` does not fully bypass chezmoi's pager.

To experiment without editing files, use Settings → Style Settings →
tokyo-night-storm; every `--tn-*` token is exposed as a color picker. To
make Style Settings changes durable, run
`chezmoi re-add ~/MeinCodex/Notizen/Obsidian/Main/.obsidian/plugins/obsidian-style-settings/data.json`
afterward.

## Editor vs reading mode

Obsidian renders markdown in two surfaces; both must look the same.

- **Live-preview / source view** uses CodeMirror classes: `.cm-*`,
  `.HyperMD-header-*`, `.HyperMD-codeblock`, `.cm-hmd-internal-link`,
  `.cm-link`, `.cm-blockquote`, `.cm-hmd-frontmatter`. Anything inside
  `.markdown-source-view`.
- **Reading mode** uses plain HTML inside `.markdown-rendered` (and
  `.markdown-preview-view`): `h1`–`h6`, `blockquote`, `code`, `pre`,
  `.internal-link`, `.external-link`, `.tag`.

Most rules in `theme.css` target both at once (`pre, .HyperMD-codeblock,
.markdown-rendered pre`). When adding a rule, check whether each mode
needs its own selector or whether a shared CSS variable will cascade
correctly to both.

## Snippet inventory

| Snippet | Status | Selector scope | Palette? |
|---|---|---|---|
| `editor-frontmatter.css` | Enabled | `.cm-hmd-frontmatter`, frontmatter region | No (layout / opacity) |
| `editor-tables.css` | Enabled | `.markdown-rendered table`, `.cm-table` | No (border / alt rows) |
| `ui-compact-tab-header.css` | Enabled | `.workspace-tab-header*` | No (height, padding) |
| `ui-hide-system-frontmatter.css` | Enabled | `.metadata-property[data-property-key="..."]` | No (display: none) |
| `ui-statusbar-tweaks.css` | Enabled | `.status-bar*` | No (layout) |
| `plugin-mysnippets.css` | Enabled | MySnippets status-bar menu | No (layout) |
| `ui-default-style-settings.css` | Disabled | `obsidian-default-theme` (Style Settings shim) | Yes — but inert under the new theme |

None of the enabled snippets redefine palette colors today. If a future
snippet does, document it here so the precedence ladder stays accurate.

## How to extend or replace

To **swap to a different Tokyo Night flavor** (Night ~`#1a1b26`, Day ~`#e1e2e7`),
change only the `--tn-bg*` and `--tn-fg*` tokens in `theme.css`. The
semantic mappings under `/* === Surfaces === */` and below do not need to
change.

To **fork a new theme** (e.g., for a different vault), copy
`themes/tokyo-night-storm/` to a new folder, rename the folder + the
`name` field in `manifest.json` to match, then point `appearance.json`
`cssTheme` at the new folder name. Anything previously written against
the `--tn-*` tokens will still resolve.

To **layer per-vault tweaks without editing the theme**, prefer:

- a new snippet under `dot_obsidian/snippets/` and adding it to
  `enabledCssSnippets` in `appearance.json`, or
- Style Settings overrides captured via `chezmoi re-add`.

## AI-context note

This file is the canonical theme reference for the vault. Future agents
(human or AI) should:

1. Read this file before answering questions about visual settings or
   suggesting CSS changes.
2. Consult the precedence ladder before choosing where to put an override
   — palette tokens, semantic mapping, per-component selector, or snippet.
3. Use the quick-lookup table to locate the source-of-truth file for a
   concern instead of grepping the rendered target. The rendered
   `.obsidian/themes/tokyo-night-storm/theme.css` is a copy; **edit the
   chezmoi source**.
4. Treat the rendered target as authoritative only when reading runtime
   state Obsidian wrote there (Style Settings data, workspace.json, etc.)
   — those files are intentionally not in chezmoi source.
