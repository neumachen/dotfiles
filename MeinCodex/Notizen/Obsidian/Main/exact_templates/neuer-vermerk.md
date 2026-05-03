<%*
const VERMERKE_HEADING = "## Vermerke";
const RUN_MODE_CREATE_NEW = 0;
const isCreateMode = tp.config.run_mode === RUN_MODE_CREATE_NEW;

const AKTE_DIR_RE = /^akten\/\d{4}\/\d{2}(\/\d{2})?\/[a-z0-9]+-[a-z0-9-]+$/;

const findEnclosingAkte = (path) => {
  if (!path) return null;
  const parts = path.split("/");
  for (let i = parts.length; i >= 3; i--) {
    const candidate = parts.slice(0, i).join("/");
    if (AKTE_DIR_RE.test(candidate)) return candidate;
  }
  return null;
};

const listAkten = async () => {
  const out = [];
  const walk = async (dir, depth) => {
    if (depth > 5) return;
    const listing = await app.vault.adapter.list(dir);
    for (const sub of listing.folders) {
      if (AKTE_DIR_RE.test(sub)) {
        out.push(sub);
      } else {
        await walk(sub, depth + 1);
      }
    }
  };
  if (await app.vault.adapter.exists("akten")) await walk("akten", 1);
  return out.sort();
};

const appendLinkToSection = async (file, link, headingText) => {
  const content = await app.vault.read(file);
  const lines = content.split("\n");
  const headingIdx = lines.findIndex(l => l.trim() === headingText);
  const item = `- ${link}`;
  if (headingIdx === -1) {
    const trailing = content.endsWith("\n") ? "" : "\n";
    await app.vault.modify(file, content + trailing + "\n" + headingText + "\n\n" + item + "\n");
    return;
  }
  let sectionEnd = lines.length;
  for (let i = headingIdx + 1; i < lines.length; i++) {
    if (/^#{1,2}\s+/.test(lines[i])) { sectionEnd = i; break; }
  }
  while (sectionEnd > headingIdx + 1 && lines[sectionEnd - 1].trim() === "") sectionEnd--;
  lines.splice(sectionEnd, 0, item);
  await app.vault.modify(file, lines.join("\n"));
};

const active = isCreateMode
  ? null
  : (tp.config.active_file ?? tp.config.target_file ?? app.workspace.activeEditor?.file ?? app.workspace.getActiveFile());
let aktePath = findEnclosingAkte(active?.parent?.path ?? null);

if (!aktePath) {
  const akten = await listAkten();
  if (akten.length === 0) {
    new Notice("No Akte folders found. Create one first via 'Akten: Neue Akte'.");
    return;
  }
  const labels = akten.map(p => p.replace(/^akten\//, ""));
  aktePath = await tp.system.suggester(labels, akten, false, "Pick the Akte for this Vermerk");
  if (!aktePath) return;
}

const akteFolderName = aktePath.split("/").slice(-1)[0];

const MODE_TITLE = "title";
const MODE_FULL = "full";
let mode = MODE_FULL;
if (!isCreateMode) {
  mode = await tp.system.suggester(
    ["Title only", "Full document"],
    [MODE_TITLE, MODE_FULL],
    false,
    `Add Vermerk to ${akteFolderName}`
  );
  if (!mode) return;
}

const title = await tp.system.prompt("Vermerk title");
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

const tzMin = -now.getTimezoneOffset();
const tzSign = tzMin >= 0 ? "+" : "-";
const tzAbs = Math.abs(tzMin);
const tzOff = `${tzSign}${pad(Math.floor(tzAbs / 60))}:${pad(tzAbs % 60)}`;
const localIso = `${YYYY}-${MM}-${DD}T${hh}:${mm}:${ss}${tzOff}`;
const utcIso = now.toISOString().replace(/\.\d{3}Z$/, "Z");

const ENCODING = "0123456789abcdefghjkmnpqrstvwxyz";
let t = now.getTime();
let timePart = "";
for (let i = 9; i >= 0; i--) { timePart = ENCODING.charAt(t % 32) + timePart; t = Math.floor(t / 32); }
const rand = new Uint8Array(16);
crypto.getRandomValues(rand);
let randPart = "";
for (let i = 0; i < 16; i++) randPart += ENCODING.charAt(rand[i] % 32);
const ulidId = `${stamp}-${timePart}${randPart}`;

const vermerkUidBytes = new Uint8Array(8);
crypto.getRandomValues(vermerkUidBytes);
let vermerkUid = "";
for (let i = 0; i < 8; i++) vermerkUid += ENCODING.charAt(vermerkUidBytes[i] % 32);

const akteUid = aktePath.split("/").pop().split("-")[0];
const documentId = vermerkUid;

const vermerkeFolder = `${aktePath}/Vermerke`;
const vermerkPath = `${vermerkeFolder}/${ulidId}.md`;
if (!(await app.vault.adapter.exists(vermerkeFolder))) {
  await app.vault.createFolder(vermerkeFolder);
}

const vermerkContent = `---
id: ${documentId}
path: ${vermerkPath}
filename: ${ulidId}
title: ${title}
type: vermerk
aliases:
tags:
  - vermerk
  - ${vermerkUid}
  - ${akteUid}
vermerk.id: ${vermerkUid}
reference.akten.id: ${akteUid}
created_at.utc: "${utcIso}"
created_at.local: "${localIso}"
modified_at.utc: "${utcIso}"
modified_at.local: "${localIso}"
---

# ${title}

`;

if (isCreateMode) {
  await tp.file.move(`${vermerkeFolder}/${ulidId}`);
  tR += vermerkContent;
} else {
  await app.vault.create(vermerkPath, vermerkContent);
}

const indexPath = `${aktePath}/index.md`;
const indexFile = app.vault.getAbstractFileByPath(indexPath);
if (indexFile) {
  const link = `[[${ulidId}|${title}]]`;
  await appendLinkToSection(indexFile, link, VERMERKE_HEADING);
} else {
  new Notice(`Akte's index.md not found at ${indexPath}; link not inserted.`);
}

if (!isCreateMode && mode === MODE_FULL) {
  const newFile = app.vault.getAbstractFileByPath(vermerkPath);
  if (newFile) {
    tp.hooks.on_all_templates_executed(async () => {
      await app.workspace.getLeaf().openFile(newFile);
    });
  }
}
%>
