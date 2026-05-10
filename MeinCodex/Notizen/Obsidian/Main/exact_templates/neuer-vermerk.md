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

// Bases code block scoped to the parent Akte. Bracket notation handles the
// flat dotted property name; YAML single-quotes wrap the expression so the
// inner brackets and double-quoted value parse as a single scalar. The
// `titleLink` formula renders the title as a clickable link to the row's
// underlying file via `file.asLink(...)`.
const buildVermerkBaseBlock = (akteUid) => [
  "```base",
  "filters:",
  "  and:",
  "    - file.hasTag(\"vermerk\")",
  `    - 'note["reference.akten.id"] == "${akteUid}"'`,
  "formulas:",
  "  titleLink: 'file.asLink(title)'",
  "properties:",
  "  formula.titleLink:",
  "    displayName: Title",
  "views:",
  "  - type: table",
  "    name: Vermerke",
  "    order:",
  "      - formula.titleLink",
  "      - created_at.utc",
  "    sort:",
  "      - { property: created_at.utc, direction: DESC }",
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

// In CREATE_NEW mode Templater opens the new (temp) file before running the
// template, so app.workspace.getActiveFile() returns that new file rather
// than the Akte the user triggered from. Scan all open leaves for an Akte
// and use it before falling back to the picker.
const findAkteFromOpenLeaves = (excludePath) => {
  let found = null;
  app.workspace.iterateAllLeaves(leaf => {
    if (found) return;
    const f = leaf.view?.file;
    if (!f) return;
    if (excludePath && f.path === excludePath) return;
    const p = findEnclosingAkte(f.parent?.path ?? null);
    if (p) found = p;
  });
  return found;
};

const active = (
  tp.config.active_file
  ?? tp.config.target_file
  ?? app.workspace.activeEditor?.file
  ?? app.workspace.getActiveFile()
);
let aktePath = findEnclosingAkte(active?.parent?.path ?? null)
  ?? findAkteFromOpenLeaves(active?.path);

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

const akteUid = aktePath.split("/").pop().split("-")[0];

// Fetch the Akte's title from its index.md frontmatter
const akteIndexPath = `${aktePath}/index.md`;
const akteIndexFile = app.vault.getAbstractFileByPath(akteIndexPath);
let akteTitle = "";
if (akteIndexFile) {
  const akteCache = app.metadataCache.getFileCache(akteIndexFile);
  akteTitle = akteCache?.frontmatter?.title ?? "";
}
const akteLink = `[[${akteIndexPath}|${akteTitle || akteUid}]]`;

const vermerkeFolder = `${aktePath}/vermerke`;
if (!(await app.vault.adapter.exists(vermerkeFolder))) {
  await app.vault.createFolder(vermerkeFolder);
}
let vermerkPath = `${vermerkeFolder}/${stem}.md`;
while (await app.vault.adapter.exists(vermerkPath)) {
  uid = crypto.randomUUID().replace(/-/g, "");
  uid6 = uid.slice(0, 6);
  stem = `${uid6}-${slug}`;
  vermerkPath = `${vermerkeFolder}/${stem}.md`;
}
const documentId = uid;

const vermerkContent = `---
id: ${documentId}
path: ${vermerkPath}
filename: ${stem}
title: ${title}
type: vermerk
aliases:
tags:
  - vermerk
  - ${akteUid}
reference.akten.id: ${akteUid}
reference.akten.title: "${akteTitle}"
reference.akten.link: "${akteLink}"
created_at.utc: "${utcIso}"
created_at.local: "${localIso}"
modified_at.utc: "${utcIso}"
modified_at.local: "${localIso}"
---

# ${title}

`;

if (isCreateMode) {
  await tp.file.move(`${vermerkeFolder}/${stem}`);
  tR += vermerkContent;
} else {
  await app.vault.create(vermerkPath, vermerkContent);
}

const indexPath = `${aktePath}/index.md`;
const indexFile = app.vault.getAbstractFileByPath(indexPath);
if (indexFile) {
  const baseBlock = buildVermerkBaseBlock(akteUid);
  await insertBaseBlockIntoSection(indexFile, baseBlock, VERMERKE_HEADING, "reference.akten.id", akteUid);
} else {
  new Notice(`Akte's index.md not found at ${indexPath}; Bases view not inserted.`);
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
