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
const stamp = `${YYYY}${MM}${DD}${hh}${mm}${ss}`;
const created = `${YYYY}-${MM}-${DD} ${hh}:${mm}:${ss}`;

const ENCODING = "0123456789abcdefghjkmnpqrstvwxyz";
let t = now.getTime();
let timePart = "";
for (let i = 9; i >= 0; i--) {
  timePart = ENCODING.charAt(t % 32) + timePart;
  t = Math.floor(t / 32);
}
const rand = new Uint8Array(16);
crypto.getRandomValues(rand);
let randPart = "";
for (let i = 0; i < 16; i++) randPart += ENCODING.charAt(rand[i] % 32);
const ulid = timePart + randPart;

const id = `${stamp}-${ulid}`;
const folder = `zakki/${YYYY}/${MM}/${DD}`;
if (!(await app.vault.adapter.exists(folder))) {
  await app.vault.createFolder(folder);
}
await tp.file.move(`${folder}/${id}`);

tR += `---
id: ${id}
title: ${title}
aliases:
tags:
  - zakki
created: ${created}
updated: ${created}
---

`;
%>
