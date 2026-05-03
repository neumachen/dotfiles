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

const folder = `zakki/${YYYY}/${MM}/${DD}`;
if (!(await app.vault.adapter.exists(folder))) {
  await app.vault.createFolder(folder);
}
let path = `${folder}/${stem}.md`;
while (await app.vault.adapter.exists(path)) {
  uid = crypto.randomUUID().replace(/-/g, "");
  uid6 = uid.slice(0, 6);
  stem = `${uid6}-${slug}`;
  path = `${folder}/${stem}.md`;
}
const documentId = uid;
await tp.file.move(`${folder}/${stem}`);

tR += `---
id: ${documentId}
path: ${path}
filename: ${stem}
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
