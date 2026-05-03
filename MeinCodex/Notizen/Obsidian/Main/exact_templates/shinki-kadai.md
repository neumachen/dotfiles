<%*
const STATUS_ICONS = {
  "incipient":   "⏳",
  "in-progress": "🚧",
  "completed":   "✅",
  "rescinded":   "🚫",
  "aborted":     "❌"
};

const INSERTED_HEADING = "## Inserted Tasks";

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
      vermerkUid = cache?.frontmatter?.["vermerk.id"] ?? null;
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
const stamp = `${YYYY}${MM}${DD}${hh}${mm}${ss}`;

const tzMin = -now.getTimezoneOffset();
const tzSign = tzMin >= 0 ? "+" : "-";
const tzAbs = Math.abs(tzMin);
const tzOff = `${tzSign}${pad(Math.floor(tzAbs / 60))}:${pad(tzAbs % 60)}`;
const localIso = `${YYYY}-${MM}-${DD}T${hh}:${mm}:${ss}${tzOff}`;
const utcIso = now.toISOString().replace(/\.\d{3}Z$/, "Z");
const startIso = `${YYYY}-${MM}-${DD}T${hh}:${mm}:${ss}`;

const ENCODING = "0123456789abcdefghjkmnpqrstvwxyz";
let t = now.getTime();
let timePart = "";
for (let i = 9; i >= 0; i--) { timePart = ENCODING.charAt(t % 32) + timePart; t = Math.floor(t / 32); }
const rand = new Uint8Array(16);
crypto.getRandomValues(rand);
let randPart = "";
for (let i = 0; i < 16; i++) randPart += ENCODING.charAt(rand[i] % 32);
const ulid = timePart + randPart;
const ulidId = `${stamp}-${ulid}`;
const documentId = ulidId;

const taskId = (typeof crypto !== "undefined" && crypto.randomUUID)
  ? crypto.randomUUID()
  : `${stamp}-${ulid}`;

const status = "incipient";
const icon = STATUS_ICONS[status] ?? "⏳";

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
const taskPath = `${folder}/${ulidId}.md`;
if (!(await app.vault.adapter.exists(folder))) {
  await app.vault.createFolder(folder);
}

const taskContent = `---
id: ${documentId}
path: ${taskPath}
filename: ${ulidId}
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
task.icon: "${icon}"
task.meta.attr: ""
---

# ${icon} ${title}

## Description

${description}

## Subtasks

- [ ] #task 

## Notes

-
`;

if (isCreateMode) {
  await tp.file.move(`${folder}/${ulidId}`);
  tR += taskContent;
  return;
}

const newFile = await app.vault.create(taskPath, taskContent);

const link = app.fileManager.generateMarkdownLink(newFile, active.path, "", title);

const editorEl = app.workspace.activeEditor?.editor?.cm?.dom;
const inVimNormalMode = !!editorEl?.querySelector(".cm-fat-cursor");

if (inVimNormalMode) {
  const content = await app.vault.read(active);
  const lines = content.split("\n");
  const headingIdx = lines.findIndex(l => l.trim() === INSERTED_HEADING);
  const item = `- ${link}`;

  if (headingIdx === -1) {
    const trailing = content.endsWith("\n") ? "" : "\n";
    await app.vault.modify(active, content + trailing + "\n" + INSERTED_HEADING + "\n\n" + item + "\n");
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
