<%*
const title = await tp.system.prompt("Zakki title");
if (!title) return;

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

const uid = crypto.randomUUID().replace(/-/g, "");
const uid6 = uid.slice(0, 6);
const documentId = uid;

const folder = `zakki/${YYYY}/${MM}/${DD}`;
const path = `${folder}/${uid6}.md`;
if (!(await app.vault.adapter.exists(folder))) {
  await app.vault.createFolder(folder);
}
await tp.file.move(`${folder}/${uid6}`);

tR += `---
id: ${documentId}
path: ${path}
filename: ${uid6}
title: ${title}
type: zakki
aliases:
tags:
  - zakki
created_at.utc: "${utcIso}"
created_at.local: "${localIso}"
modified_at.utc: "${utcIso}"
modified_at.local: "${localIso}"
---

`;
%>
