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

const ENCODING = "0123456789abcdefghjkmnpqrstvwxyz";

const uidBytes = new Uint8Array(8);
crypto.getRandomValues(uidBytes);
let uid = "";
for (let i = 0; i < 8; i++) uid += ENCODING.charAt(uidBytes[i] % 32);

let t = now.getTime();
let timePart = "";
for (let i = 9; i >= 0; i--) {
  timePart = ENCODING.charAt(t % 32) + timePart;
  t = Math.floor(t / 32);
}
const ulidRand = new Uint8Array(16);
crypto.getRandomValues(ulidRand);
let randPart = "";
for (let i = 0; i < 16; i++) randPart += ENCODING.charAt(ulidRand[i] % 32);
const noteId = `${YYYY}${MM}${DD}${hh}${mm}${ss}-${timePart}${randPart}`;

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

const dirName = `${uid}-${slug}`;
const dirPath = `akten/${YYYY}/${MM}/${DD}/${dirName}`;

if (!(await app.vault.adapter.exists(dirPath))) {
  await app.vault.createFolder(dirPath);
}

await tp.file.move(`${dirPath}/index`);

tR += `---
id: ${noteId}
title: ${title}
type: akten
aliases:
tags:
  - akten
  - ${uid}
created_at.utc: "${utcIso}"
created_at.local: "${localIso}"
modified_at.utc: "${utcIso}"
modified_at.local: "${localIso}"
---

# ${title}

`;
%>
