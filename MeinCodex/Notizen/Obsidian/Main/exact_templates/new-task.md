<%*
const STATUS_ICONS = {
  "incipient":   "⏳",
  "in-progress": "🚧",
  "completed":   "✅",
  "rescinded":   "🚫",
  "aborted":     "❌"
};

const MODE_FAST = "fast";
const MODE_FULL = "full";
const mode = await tp.system.suggester(
  ["Fast — title only", "Full — title, priority, due, description"],
  [MODE_FAST, MODE_FULL],
  false,
  "Task creation"
);
if (!mode) return;

const title = await tp.system.prompt("Task title");
if (!title) return;

let priority = 0;
let dueRaw = "";
let description = "";
if (mode === MODE_FULL) {
  const priorityChoices = [];
  for (let p = 0; p <= 5; p += 0.5) priorityChoices.push(p.toFixed(1));
  const picked = await tp.system.suggester(priorityChoices, priorityChoices, false, "Priority (0–5)");
  if (picked !== null && picked !== undefined) priority = parseFloat(picked);

  dueRaw = (await tp.system.prompt("Due date (YYYY-MM-DD or YYYY-MM-DD HH:mm, empty for none)")) || "";
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
const created = `${YYYY}-${MM}-${DD} ${hh}:${mm}:${ss}`;
const startIso = `${YYYY}-${MM}-${DD}T${hh}:${mm}:${ss}`;

let dueIso = "";
if (dueRaw) {
  const m = dueRaw.match(/^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?$/);
  if (m) {
    const [, y, mo, d, H, Mi, S] = m;
    dueIso = `${y}-${mo}-${d}T${H ?? "23"}:${Mi ?? "59"}:${S ?? "59"}`;
  }
}

const ENCODING = "0123456789abcdefghjkmnpqrstvwxyz";
let t = now.getTime();
let timePart = "";
for (let i = 9; i >= 0; i--) { timePart = ENCODING.charAt(t % 32) + timePart; t = Math.floor(t / 32); }
const rand = new Uint8Array(16);
crypto.getRandomValues(rand);
let randPart = "";
for (let i = 0; i < 16; i++) randPart += ENCODING.charAt(rand[i] % 32);
const ulid = timePart + randPart;
const id = `${stamp}-${ulid}`;

const taskId = (typeof crypto !== "undefined" && crypto.randomUUID)
  ? crypto.randomUUID()
  : `${stamp}-${ulid}`;

const status = "incipient";
const icon = STATUS_ICONS[status] ?? "⏳";

const folder = `kadai/${YYYY}/${MM}/${DD}`;
if (!(await app.vault.adapter.exists(folder))) {
  await app.vault.createFolder(folder);
}
await tp.file.move(`${folder}/${id}`);

tR += `---
id: ${id}
title: ${title}
aliases:
tags:
  - task
created: ${created}
updated: ${created}
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
%>
