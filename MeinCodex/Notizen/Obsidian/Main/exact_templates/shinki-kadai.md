<%*
const utils = tp.user.obsidian_utils();

// Canonical task status enum (matches the meta-bind dropdown rendered in
// the task body). Lowercase kebab — keeps values stable for grep / Bases /
// shell scripts. Done semantics: only `completed` and `discarded` count as
// done — see meta-bind VIEW expression below.
const STATUS_OPTIONS = ["incipient", "in-progress", "completed", "discarded", "blocked", "abandoned"];
const DEFAULT_STATUS = "incipient";

const TASKS_HEADING = "## Tasks";

// When inserting a task into a parent doc (Akte index, Zakki), emit
// a Bases code block scoped to that parent's id instead of a wikilink. One
// block per scope; re-running the template with the same scope is a no-op.
// Bracket notation is required because property names with literal dots
// (e.g. `reference.akten.id`) are otherwise parsed as nested-object access
// and resolve to nothing. YAML single-quotes wrap the expression so the
// inner brackets and double-quoted value parse as a single scalar. The
// `titleLink` formula renders the title as a clickable link to the row's
// underlying file via `file.asLink(...)`.
const buildTaskBaseBlock = (refKey, refValue, scopeLabel) => [
  "```base",
  "filters:",
  "  and:",
  "    - file.hasTag(\"task\")",
  `    - 'note["${refKey}"] == "${refValue}"'`,
  "formulas:",
  "  titleLink: 'file.asLink(title)'",
  "properties:",
  "  formula.titleLink:",
  "    displayName: Title",
  "views:",
  "  - type: table",
  `    name: Tasks — ${scopeLabel}`,
  "    order:",
  "      - formula.titleLink",
  "      - task.status",
  "      - task.priority",
  "      - task.due-date",
  "    sort:",
  "      - { property: task.due-date, direction: ASC }",
  "```",
].join("\n");

const RUN_MODE_CREATE_NEW = 0;
const isCreateMode = tp.config.run_mode === RUN_MODE_CREATE_NEW;

const active = isCreateMode
  ? null
  : (tp.config.active_file ?? tp.config.target_file ?? app.workspace.activeEditor?.file ?? app.workspace.getActiveFile());

let context = null;
let akteUid = null;
let zakkiUid = null;
let akteLink = null;
let zakkiLink = null;

const buildLink = (path, title, fallback) => `[[${path}|${title || fallback}]]`;

const resolveAkteLinkByUid = (uid) => {
  const folders = app.vault.getAllLoadedFiles().filter(f =>
    f.children && /^akten\/\d{4}\/\d{2}(\/\d{2})?\/[a-z0-9]+-[a-z0-9-]+$/.test(f.path)
  );
  const hit = folders.find(f => f.path.split("/").pop().split("-")[0] === uid);
  if (!hit) return null;
  const indexPath = `${hit.path}/index.md`;
  const indexFile = app.vault.getAbstractFileByPath(indexPath);
  if (!indexFile) return null;
  const t = app.metadataCache.getFileCache(indexFile)?.frontmatter?.title ?? "";
  return buildLink(indexPath, t, uid);
};

if (active) {
  const ap = active.path;
  const akteMatch = ap.match(/^akten\/\d{4}\/\d{2}(?:\/\d{2})?\/([a-z0-9]+)-[a-z0-9-]+\//);
  if (akteMatch && active.basename === "index") {
    akteUid = akteMatch[1];
    context = "akten";
    const t = app.metadataCache.getFileCache(active)?.frontmatter?.title ?? "";
    akteLink = buildLink(ap, t, akteUid);
  } else if (ap.startsWith("zakki/")) {
    context = "zakki";
    const cache = app.metadataCache.getFileCache(active);
    zakkiUid = cache?.frontmatter?.id ?? null;
    const zakkiTitle = cache?.frontmatter?.title ?? "";
    if (zakkiUid) zakkiLink = buildLink(ap, zakkiTitle, zakkiUid.slice(0, 6));
    const akteRef = cache?.frontmatter?.["reference.akten.id"];
    if (akteRef) {
      akteUid = String(akteRef);
      const cachedAkteLink = cache?.frontmatter?.["reference.akten.link"];
      akteLink = cachedAkteLink ? String(cachedAkteLink) : resolveAkteLinkByUid(akteUid);
    }
  }
}

const contextLabel = context === "akten" ? "Add to new Akten"
                   : context === "zakki" ? "Add to new Zakki"
                   : "Task creation";

const MODE_TITLE = "title";
const MODE_FULL = "full";
const mode = await tp.system.suggester(
  ["Title only", "Full document"],
  [MODE_TITLE, MODE_FULL],
  false,
  contextLabel
);
if (!mode) return;

const title = await tp.system.prompt("Task title");
if (!title) return;

const priority = 0;
const dueIso = "";
let description = "";
if (mode === MODE_FULL) {
  description = (await tp.system.prompt("Description (optional)")) || "";
}

const { YYYY, MM, DD, localIso, utcIso, startIso } = utils.getTimestamps();

const slug = utils.slugify(title);

let uid = crypto.randomUUID().replace(/-/g, "");
let uid6 = uid.slice(0, 6);
let stem = `${uid6}-${slug}`;

const taskId = crypto.randomUUID();
const status = DEFAULT_STATUS;

const refLines = [];
if (context === "akten") {
  refLines.push(`reference.akten.id: ${akteUid}`);
  if (akteLink) refLines.push(`reference.akten.link: "${akteLink}"`);
} else if (context === "zakki") {
  if (zakkiUid) {
    refLines.push(`reference.zakki.id: ${zakkiUid}`);
    if (zakkiLink) refLines.push(`reference.zakki.link: "${zakkiLink}"`);
  } else {
    new Notice("Active Zakki has no `id` in frontmatter; reference.zakki.id will be empty.");
  }
  if (akteUid) {
    refLines.push(`reference.akten.id: ${akteUid}`);
    if (akteLink) refLines.push(`reference.akten.link: "${akteLink}"`);
  }
}
const refBlock = refLines.length ? refLines.join("\n") + "\n" : "";

const folder = `kadai/${YYYY}/${MM}/${DD}`;
if (!(await app.vault.adapter.exists(folder))) {
  await app.vault.createFolder(folder);
}
let taskPath = `${folder}/${stem}.md`;
while (await app.vault.adapter.exists(taskPath)) {
  uid = crypto.randomUUID().replace(/-/g, "");
  uid6 = uid.slice(0, 6);
  stem = `${uid6}-${slug}`;
  taskPath = `${folder}/${stem}.md`;
}
const documentId = uid;

// meta-bind widgets (rendered when the kadai file is viewed; the
// `templates/` folder is excluded in meta-bind's settings, so the
// backticked syntax stays as raw text inside this template).
//
// Status dropdown: constrained to the canonical 6 options. Editing
// the dropdown rewrites `task.status` in frontmatter.
//
// Done indicator: VIEW field evaluating a math expression — renders
// as "☑ Done" when status is completed or discarded, "☐ Not done"
// otherwise. Read-only (derived from status; the dropdown is the
// single source of truth). Plain-text rendering, no JS required.
//
// Why ["task.status"] (bracket notation) instead of task.status:
// meta-bind treats a literal dot in a bind target as nested-object
// access — `target.task.status` would resolve to target["task"]["status"],
// which fails because `task` is not a sub-object here. Using bracket
// notation with the quoted full key tells meta-bind to read the flat
// dotted property name verbatim from frontmatter.
const statusOpts = STATUS_OPTIONS.map(o => `option(${o})`).join(", ");
const statusWidget = "`INPUT[inlineSelect(" + statusOpts + "):[\"task.status\"]]`";
const doneWidget = "`VIEW[(({[\"task.status\"]} == \"completed\") or ({[\"task.status\"]} == \"discarded\")) ? \"☑ Done\" : \"☐ Not done\"]`";

// Trailing newline geometry: see neuer-akten.md. The `taskContent` literal
// (used directly as a new file's content via app.vault.create or appended
// to tR) ends with `-\n` after the `## Notes` bullet — only one trailing
// newline so the file's last bytes are `\n-\n` (the bullet line terminated
// by a single \n). In tR-mode, Templater's post-block newline supplies the
// final EOF newline; in create-mode (app.vault.create), the file is
// written verbatim and the single trailing \n keeps the file POSIX-clean.
const taskContent = `---
id: ${documentId}
path: ${taskPath}
filename: ${stem}
title: ${title}
type: kadai
aliases:
tags:
  - task
${refBlock}created_at.utc: "${utcIso}"
created_at.local: "${localIso}"
modified_at.utc: "${utcIso}"
modified_at.local: "${localIso}"
task.task_id: ${taskId}
task.start-date: ${startIso}
task.due-date: ${dueIso}
task.priority: ${priority}
task.status: ${status}
task.meta.attr: ""
---

# ${title}

## Status

- ${statusWidget}
- ${doneWidget}

## Description

${description}

## Subtasks

- [ ] #task 

## Notes

-
`;

if (isCreateMode) {
  await tp.file.move(`${folder}/${stem}`);
  // Strip the lone trailing newline so Templater's post-block newline is
  // the document's sole EOF marker (matches neuer-akten/neuer-zakki).
  tR += taskContent.replace(/\n$/, "");
  return;
}

const newFile = await app.vault.create(taskPath, taskContent);

const link = app.fileManager.generateMarkdownLink(newFile, active.path, "", title);

let refKey = null, refValue = null, scopeLabel = null;
if (context === "akten") {
  refKey = "reference.akten.id";
  refValue = akteUid;
  scopeLabel = "Akte";
} else if (context === "zakki") {
  if (zakkiUid) {
    refKey = "reference.zakki.id";
    refValue = zakkiUid;
    scopeLabel = "Zakki";
  } else if (akteUid) {
    refKey = "reference.akten.id";
    refValue = akteUid;
    scopeLabel = "Akte";
  }
}
const baseBlock = (refKey && refValue) ? buildTaskBaseBlock(refKey, refValue, scopeLabel) : null;

const editorEl = app.workspace.activeEditor?.editor?.cm?.dom;
const inVimNormalMode = !!editorEl?.querySelector(".cm-fat-cursor");

// Base blocks always land under ## Tasks (idempotent — re-running
// on a parent that already has the block is a no-op). Cursor position is
// irrelevant for the base path. Only the wikilink fallback respects the
// vim/non-vim split: vim appends under the section, non-vim drops at cursor.
if (baseBlock) {
  await utils.insertBaseBlockIntoSection(app, active, baseBlock, TASKS_HEADING, refKey, refValue);
} else if (inVimNormalMode) {
  const content = await app.vault.read(active);
  const lines = content.split("\n");
  const headingIdx = lines.findIndex(l => l.trim() === TASKS_HEADING);
  const item = `- ${link}`;

  if (headingIdx === -1) {
    const trailing = content.endsWith("\n") ? "" : "\n";
    await app.vault.modify(active, content + trailing + "\n" + TASKS_HEADING + "\n\n" + item + "\n");
  } else {
    // Match any heading level (H1..H6) so H3+ subheadings under ## Tasks
    // terminate the section instead of being absorbed into it. Mirrors the
    // shared insertBaseBlockIntoSection scan.
    let sectionEnd = lines.length;
    for (let i = headingIdx + 1; i < lines.length; i++) {
      if (/^#{1,6}\s+/.test(lines[i])) { sectionEnd = i; break; }
    }
    while (sectionEnd > headingIdx + 1 && lines[sectionEnd - 1].trim() === "") sectionEnd--;
    lines.splice(sectionEnd, 0, item);
    await app.vault.modify(active, lines.join("\n"));
  }
} else {
  tR += link;
}

if (mode === MODE_FULL) {
  tp.hooks.on_all_templates_executed(async () => {
    await app.workspace.getLeaf().openFile(newFile);
  });
}
%>
