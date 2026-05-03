<%*
const title = await tp.system.prompt("Akten project title");
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

const dirName = `${uid6}-${slug}`;
const dirPath = `akten/${YYYY}/${MM}/${dirName}`;
const path = `${dirPath}/index.md`;

if (!(await app.vault.adapter.exists(dirPath))) {
  await app.vault.createFolder(dirPath);
}

await tp.file.move(`${dirPath}/index`);

tR += `---
id: ${documentId}
path: ${path}
filename: index
title: ${title}
type: akten
aliases:
tags:
  - akten
created_at.utc: "${utcIso}"
created_at.local: "${localIso}"
modified_at.utc: "${utcIso}"
modified_at.local: "${localIso}"
---

# ${title}

`;
%>
