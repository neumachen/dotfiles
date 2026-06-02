<%*
const utils = tp.user.obsidian_utils();

const title = await tp.system.prompt("Akten project title");
if (!title) return;

const ts = utils.getTimestamps();
const { YYYY, MM, localIso, utcIso } = ts;

const uid = crypto.randomUUID().replace(/-/g, "");
const uid6 = uid.slice(0, 6);
const documentId = uid;

const slug = utils.slugify(title);

const dirName = `${uid6}-${slug}`;
const dirPath = `akten/${YYYY}/${MM}/${dirName}`;
const path = `${dirPath}/index.md`;

if (!(await app.vault.adapter.exists(dirPath))) {
  await app.vault.createFolder(dirPath);
}

await tp.file.move(`${dirPath}/index`);

// Trailing newline geometry: this template literal ends with "# ${title}"
// (no trailing newline inside the backticks). Templater emits the newline
// that follows this file's closing percent-greater-than delimiter, which
// becomes the document's sole trailing newline. Adding another newline
// inside the literal would stack a second blank line at EOF (the original
// bug). Same pattern applies to neuer-zakki.md and shinki-kadai.md.
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

# ${title}`;
%>
