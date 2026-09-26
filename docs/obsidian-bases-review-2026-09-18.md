# Obsidian Bases review and proposed Claude Code handoff

Reviewed: 2026-09-18. This is an analysis artifact, not an implementation or deployment receipt. No vault note, template, Base, setting, theme, or plugin was edited by the reviewer.

## Scope and evidence

- Repository: `/Users/kareemh/MeinCodex/Codebasis/github.com/neumachen/dotfiles`
- Managed Obsidian source: `/Users/kareemh/MeinCodex/Codebasis/github.com/neumachen/dotfiles/MeinCodex/Notizen/Obsidian/Main`
- Live vault: `/Users/kareemh/MeinCodex/Notizen/Obsidian/Main`
- Three standalone Bases, eleven actual embedded Base blocks (four in Home; seven in six Akte notes), and the template generators were inspected. All fourteen live YAML Base documents parsed successfully in the static inventory; valid YAML alone does not establish valid Bases expressions.
- Source/live standalone Bases and creation templates matched. Home is independent vault content: its dotfiles copy is ignored by Git and chezmoi and must not be treated as deployed authority.
- The application viewer failed before returning window state. No initial viewport, rendered table, filter-menu interaction, or visual correction has been verified.
- An isolated probe of the installed Obsidian 1.13.7 formula grammar and its parser wrapper tested the exact Home and all-tasks `isOpen` and `dueSortKey` expressions. All four returned `type: invalid` and `Unable to parse formula. (position 0)`. Symbolic boolean operators, bracket property access, and `if(...)` parsed. This is engine syntax evidence, not an end-to-end rendered-app test. Installed archive: `/Applications/Obsidian.app/Contents/Resources/obsidian.asar`; SHA-256 `a52a7daf1e2460bae03de80f2816604bd16a56cd374fbe5ce8d1a9ef5604059d`. The Obsidian application itself was not launched or modified; the probe evaluated isolated parser/deserializer definitions with benign inputs and performed no writes.
- The actual view deserializer was separately probed: singular `filter` remained unrecognized view data and did not become the view's `filters`. Fix the schema and expression together. Renaming the key alone would connect an invalid formula to the view, not implement a correct open-task predicate.

## Findings

1. **Task query defects:** live `Home.md:20-21` and managed `kadai/_bases/all-tasks.base:11-12` contain rejected expression forms. Home additionally uses logically incorrect OR exclusions. Home line 50 and the task Base lines 45/59 use singular `filter`; the shipped loader consumes plural `filters` for filtering. Do not regard replacing just OR with AND as a sufficient correction.
2. **Unnecessary read-only columns:** Home and the task overview wrap Status, Due, and Priority in formulas. Native note-property columns can retain readable display names and permit property editing. Formula columns can still be filtered and sorted; the wrappers alone do not make a Base unfilterable. Formula cells are computed, not ordinary note-property editors. The existing note-body Meta Bind status control remains the constrained six-choice control; native Text is not an enum.
3. **Misleading labels and references:** `Recorded On` reads `modified_at.utc` and should mean Last edited. The task overview's Akte column displays `reference.akten.id`. All five current Kadai have that ID, but none has `reference.akten.link`. Replacing the ID column with a link-only column would make all five current cells blank. Preserve IDs and handle missing links explicitly; do not invent resolved links or silently rewrite private notes.
4. **Uneven embedded tables:** five Akte Zakki tables have modern linked titles; one legacy Zakki table has a plain title and no configured sort; one legacy task table has a plain title and technical column labels. The two legacy tables currently have zero matching child notes, so their emptiness alone is not a rendering defect. All seven parent-reference filters match the enclosing Akte ID.
5. **Template updates do not update existing embeds:** `scripts/obsidian_utils.js:82-124` detects an existing parent-scope expression and skips reinsertion. Existing embedded blocks need their own narrowly scoped correction, if authorized. Preserve custom filters, parent IDs, surrounding prose, and unrelated content.
6. **Property typing needs validation:** current source/live `types.json` does not explicitly register the relevant `task.*`, reference, or dotted timestamp properties. Do not infer the app's effective date/number typing from README examples. Validate native filters and editing with the actual values. Keep UTC system timestamp serialization intact.
7. **Column density does not make a table filterable:** fields may remain available in the Filter/Properties menus without all being visible. All five Kadai currently have priority 0 and no due date. Priority need not occupy every default task table; empty Due must remain legitimate. Start is initialized at capture and is not proof that work began.
8. **Some relationships have no parent table:** one linked Zakki and all five linked Kadai have no corresponding scoped Base in their parent Akte. The references resolve, but a reference does not itself create a parent table. This is a navigation gap, not proof of a query error. Confirm the intended parent layout before adding sections.

## Proposed column contract

These are design recommendations; pin naming remains a proposal.

| Surface | Default columns | Optional fields |
| --- | --- | --- |
| Zakki overview | Linked Title, Last edited; Pin if adopted | Tags, Akte, Created |
| Akten overview | Linked Akte, Last edited | Tags, Created |
| Kadai overview | Linked Task, Status, Due | Priority, Akte, originating Zakki, Last edited, Tags |
| Zakki within an Akte | Linked Title, Created; Pin if adopted | Last edited, Tags |
| Tasks within a Zakki/Akte | Linked Task, Status, Due | Priority, Last edited; originating Zakki only when useful in an Akte-wide table |
| Home Pinned Zakki | Linked Title, Pin | Parent Akte only if it aids recognition |
| Home Open Kadai | Linked Task, Status, Due | Full detail belongs in the task overview |
| Home Latest Zakki/Akten | Linked Title, Created | Full detail belongs in the overview |
| Home Recently Edited | Linked Title, Type, Last edited | Tags optional |

Do not display the same parent Akte/Zakki in every row of its already-scoped embedded table. Keep technical IDs for relationships and filters, not prominent display. Keep a linked human title as the primary navigation cell; a separate raw-title editor is optional, not a duplicate default column.

## Filter interaction contract

- Users can use native Filter, Sort, Properties, and view selection without editing YAML.
- Base-wide filters define kind and, for embedded child lists, exact parent scope. View filters add Open/All and optional user criteria. These are organizational boundaries, not locked permissions: Obsidian exposes both All views and This view filters.
- All in a parent table means all related children, not all vault notes.
- Open Kadai excludes completed, discarded, and abandoned; blocked remains open. Retain access to closed work through All. Avoid a separate Done property.
- Keep readable, type-correct filters for status, due date/absence, priority, tags, and parent relationships. Prefer simple filter groups over opaque formula aliases when that makes the native editor usable.
- Preserve the distinction between expression syntax (`note["task.status"]`) and serialized property IDs (`note.task.status` refers to the literal dotted property key). Verify UI-generated serialization; do not mechanically rewrite every dotted identifier as a bracket expression.
- `file.tags` includes inline and frontmatter tags. `note.tags` is the editable frontmatter property. Do not switch between them without accounting for the difference.
- Filter/view edits are saved configuration, not assumed temporary searches. A reusable `.base` embed shares its configuration; independently copied code blocks have separate configuration. Shipped save callbacks modify the containing Markdown for an inline Base and the referenced `.base` file for a file embed. Toolbar Search uses separate transient state; it must not be described as a durable filter. Confirm these interactions in the rendered app before choosing shared views for Home.
- Editing filters in a managed live `.base` can create source/target drift; a later chezmoi application can restore the source defaults. Explain which views are managed defaults and how intentional personal saved changes are retained. Do not silently introduce automatic synchronization, and do not promise persistence across deployment merely because a view survives reopening Obsidian.
- Pinning remains independent of note type, tasks, and project membership. Do not silently accept a new metadata name or pin lifecycle merely because a Bases correction is requested.

## Proposed Claude Code implementation prompt

Use this only when the user chooses to begin implementation. This document itself does not execute or authorize deployment, migrations, or live-note rewrites.

> Review and correct the existing Main vault Bases so they render reliably, support native interactive filtering, and show a small set of useful columns. Preserve the existing Zakki/Kadai/Akte model, references, creation workflow, and Tokyo Night Storm appearance. Keep the previously discussed independent Pinned Zakki direction in scope as a proposal; do not convert Zakki to tasks/projects for visibility.
>
> Work from the repository and vault paths at the top of this document. Read the root and Obsidian AGENTS instructions and current README, REFERENCE, and THEME, then refresh Git state and compare source/live files. Treat this review as dated evidence and recheck the installed app and current content. Do not reproduce private note titles or body text in reports.
>
> Investigate all three source `*/_bases/*.base` files, live Home, actual embedded Base blocks, `exact_templates/neuer-zakki.md`, `exact_templates/shinki-kadai.md`, `scripts/obsidian_utils.js`, and the relevant property typing. Correct confirmed expression/schema errors; remove unsupported word operators/null-coalescing; use a tested due-sort strategy that preserves undated tasks. Prefer explicit native filters for open statuses. Check every view, not only the first one.
>
> Apply the column and filter contracts above, adjusting them only with a concrete reason. Use native editable note fields where editing is intended and formula fields for derived/read-only output. Do not claim native Status offers the Meta Bind enum. Preserve the six existing statuses and the current distinction between open and done. Use readable labels, avoid opaque IDs as normal display, and do not fabricate active-project states or priority semantics.
>
> Source configuration belongs in the dotfiles source. Live Home and embedded tables belong to the live vault; its ignored dotfiles Home copy is not a deployment target. Before making live content changes, ensure the user's implementation request explicitly includes them. If it does, update only the identified Base blocks while preserving their scope and surrounding content. Otherwise produce an exact separate patch for review, without applying it. Do not run a broad migration or reference backfill. Missing Akte links need a documented fallback or separately approved targeted repair.
>
> Fix the template generators so new tables follow the same contract, but do not run note-creation templates as a bulk upgrade. Preserve helper idempotence and custom existing views. Prefer Base property labels, order, native widths, and row-height settings for formatting. Change CSS only if an observed rendered problem requires it; do not hide the filtering toolbar or use CSS to conceal query errors.
>
> Validate with a small non-sensitive fixture outside the live vault, then inspect the real authorized target in Obsidian. Cover all six task statuses, dated/undated tasks, distinct priorities, literal dotted fields, parent A versus parent B, legacy ID-only references, and missing/false/true pin values if pinning is adopted. Verify that changing an ordinary view filter does not remove parent scope; All restores closed children; empty results look like empty results rather than errors; title links reopen the correct note; due sorting is chronological; and displayed editors update the intended property only. Verify saved-view/filter persistence and shared-embed effects. Do not claim application verification from YAML parsing or screenshots alone.
>
> In live data, recheck the current counts instead of hardcoding them; the review snapshot had five Kadai, four incipient and one completed. Inspect every standalone view and each embedded variant in reading and live-preview modes, including narrow panes, long titles, and scrolling. Preserve existing automatic title/filename/link maintenance and watch for its effects on metadata edits. No bulk normalization, plugin installation, `chezmoi apply`, synchronization, commit, push, or deployment is implied by this prompt. Report exact changed files, evidence, and any remaining visual or interaction gaps.

## Primary capability references

- [Bases syntax](https://obsidian.md/help/bases/syntax)
- [Views and native filter controls](https://obsidian.md/help/bases/views)
- [Table view and cell behavior](https://obsidian.md/help/bases/views/table)
- [Property types](https://obsidian.md/help/properties)
