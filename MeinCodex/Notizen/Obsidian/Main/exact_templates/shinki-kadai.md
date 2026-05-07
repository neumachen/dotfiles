<%*
// Canonical task status enum (matches the meta-bind dropdown rendered in
// the task body). Lowercase kebab — keeps values stable for grep / Bases /
// shell scripts. Done semantics: only `completed` and `discarded` count as
// done — see meta-bind VIEW expression below.
const STATUS_OPTIONS = ["incipient", "in-progress", "completed", "discarded", "blocked", "abandoned"];
const DEFAULT_STATUS = "incipient";

const TASKS_HEADING = "## Tasks";

// When inserting a task into a parent doc (Akte index, Vermerk, Zakki), emit
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

const sectionHasBaseScope = (lines, headingIdx, sectionEnd, refKey, refValue) => {
  const target = `note["${refKey}"] == "${refValue}"`;
  let inBase = false;
  for (let i = headingIdx + 1; i < sectionEnd; i++) {
    const trimmed = lines[i].trim();
    if (!inBase && /^```base\b/.test(trimmed)) { inBase = true; continue; }
    if (inBase && trimmed === "```") { inBase = false; continue; }
    if (inBase && lines[i].includes(target)) return true;
  }
  return false;
};

const insertBaseBlockIntoSection = async (file, baseBlock, headingText, refKey, refValue) => {
  const content = await app.vault.read(file);
  const lines = content.split("\n");
  const headingIdx = lines.findIndex(l => l.trim() === headingText);
  if (headingIdx === -1) {
    const trailing = content.endsWith("\n") ? "" : "\n";
    await app.vault.modify(file, content + trailing + "\n" + headingText + "\n\n" + baseBlock + "\n");
    return;
  }
  let sectionEnd = lines.length;
  for (let i = headingIdx + 1; i < lines.length; i++) {
    if (/^#{1,2}\s+/.test(lines[i])) { sectionEnd = i; break; }
  }
  if (sectionHasBaseScope(lines, headingIdx, sectionEnd, refKey, refValue)) return;
  while (sectionEnd > headingIdx + 1 && lines[sectionEnd - 1].trim() === "") sectionEnd--;
  lines.splice(sectionEnd, 0, "", ...baseBlock.split("\n"));
  await app.vault.modify(file, lines.join("\n"));
};

const RUN_MODE_CREATE_NEW = 0;
const isCreateMode = tp.config.run_mode === RUN_MODE_CREATE_NEW;

const active = isCreateMode
  ? null
  : (tp.config.active_file ?? tp.config.target_file ?? app.workspace.activeEditor?.file ?? app.workspace.getActiveFile());

let context = null;
let akteUid = null;
let vermerkUid = null;
let zakkiId = null;
if (active) {
  const ap = active.path;
  const akteMatch = ap.match(/^akten\/\d{4}\/\d{2}(?:\/\d{2})?\/([a-z0-9]+)-[a-z0-9-]+\//);
  if (akteMatch) {
    akteUid = akteMatch[1];
    if (active.basename === "index") {
      context = "akten";
    } else {
      context = "vermerk";
      const cache = app.metadataCache.getFileCache(active);
      vermerkUid = cache?.frontmatter?.id ?? null;
    }
  } else if (ap.startsWith("zakki/")) {
    context = "zakki";
    zakkiId = active.basename;
  }
}

const contextLabel = context === "akten" ? "Add to new Akten"
                   : context === "vermerk" ? "Add to new Vermerk"
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

const now = new Date();
const pad = n => String(n).padStart(2, "0");
const YYYY = now.getFullYear();
const MM = pad(now.getMonth() + 1);
const DD = pad(now.getDate());
const hh = pad(now.getHours());
const mm = pad(now.getMinutes());
const ss = pad(now.getSeconds());

const tzMin = -now.getTimezoneOffset();
const tzSign = tzMin >= 0 ? "+" : "-";
const tzAbs = Math.abs(tzMin);
const tzOff = `${tzSign}${pad(Math.floor(tzAbs / 60))}:${pad(tzAbs % 60)}`;
const localIso = `${YYYY}-${MM}-${DD}T${hh}:${mm}:${ss}${tzOff}`;
const utcIso = now.toISOString().replace(/\.\d{3}Z$/, "Z");
const startIso = `${YYYY}-${MM}-${DD}T${hh}:${mm}:${ss}`;

let slug = title
  .normalize("NFD")
  .replace(/[̀-ͯ]/g, "")
  .toLowerCase()
  .replace(/[^a-z0-9]+/g, "-")
  .replace(/^-+|-+$/g, "");
if (slug.length > 60) {
  slug = slug.slice(0, 60).replace(/-+$/g, "");
  const lastDash = slug.lastIndexOf("-");
  if (lastDash > 30) slug = slug.slice(0, lastDash);
}
if (!slug) slug = "untitled";

let uid = crypto.randomUUID().replace(/-/g, "");
let uid6 = uid.slice(0, 6);
let stem = `${uid6}-${slug}`;

const taskId = crypto.randomUUID();
const status = DEFAULT_STATUS;

const refLines = [];
if (context === "akten") {
  refLines.push(`reference.akten.id: ${akteUid}`);
} else if (context === "vermerk") {
  if (vermerkUid) {
    refLines.push(`reference.vermerk.id: ${vermerkUid}`);
  } else {
    new Notice("Active Vermerk has no `vermerk.id` in frontmatter; only the parent Akte will be referenced.");
  }
  refLines.push(`reference.akten.id: ${akteUid}`);
} else if (context === "zakki") {
  refLines.push(`reference.zakki.id: ${zakkiId}`);
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
  tR += taskContent;
  return;
}

const newFile = await app.vault.create(taskPath, taskContent);

const link = app.fileManager.generateMarkdownLink(newFile, active.path, "", title);

let refKey = null, refValue = null, scopeLabel = null;
if (context === "akten") {
  refKey = "reference.akten.id";
  refValue = akteUid;
  scopeLabel = "Akte";
} else if (context === "vermerk") {
  if (vermerkUid) {
    refKey = "reference.vermerk.id";
    refValue = vermerkUid;
    scopeLabel = "Vermerk";
  } else {
    refKey = "reference.akten.id";
    refValue = akteUid;
    scopeLabel = "Akte";
  }
} else if (context === "zakki") {
  refKey = "reference.zakki.id";
  refValue = zakkiId;
  scopeLabel = "Zakki";
}
const baseBlock = (refKey && refValue) ? buildTaskBaseBlock(refKey, refValue, scopeLabel) : null;

const editorEl = app.workspace.activeEditor?.editor?.cm?.dom;
const inVimNormalMode = !!editorEl?.querySelector(".cm-fat-cursor");

// Base blocks always land under ## Tasks (idempotent — re-running
// on a parent that already has the block is a no-op). Cursor position is
// irrelevant for the base path. Only the wikilink fallback respects the
// vim/non-vim split: vim appends under the section, non-vim drops at cursor.
if (baseBlock) {
  await insertBaseBlockIntoSection(active, baseBlock, TASKS_HEADING, refKey, refValue);
} else if (inVimNormalMode) {
  const content = await app.vault.read(active);
  const lines = content.split("\n");
  const headingIdx = lines.findIndex(l => l.trim() === TASKS_HEADING);
  const item = `- ${link}`;

  if (headingIdx === -1) {
    const trailing = content.endsWith("\n") ? "" : "\n";
    await app.vault.modify(active, content + trailing + "\n" + TASKS_HEADING + "\n\n" + item + "\n");
  } else {
    let sectionEnd = lines.length;
    for (let i = headingIdx + 1; i < lines.length; i++) {
      if (/^#{1,2}\s+/.test(lines[i])) { sectionEnd = i; break; }
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
