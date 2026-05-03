<%*
// Two listeners installed at vault startup:
//
//   1. vault.on("rename", ...): when a file is renamed/moved, rewrite that
//      file's `path:` and `filename:` frontmatter so the per-note system
//      fields stay aligned with the actual location. Pairs with Obsidian's
//      built-in `alwaysUpdateLinks` (which handles wikilink targets).
//
//   2. metadataCache.on("changed", ...): when the `title:` frontmatter of a
//      managed note changes (vermerk / kadai / zakki), recompute the
//      <uid6>-<slug> stem and rename the file via app.fileManager.renameFile.
//      Skips the first event per file path (which fires during the vault's
//      indexing pass at startup) so we don't mass-rename pre-existing files
//      silently — bulk migration belongs in a one-off script.
//
// Idempotent across plugin reloads via globalThis guard + app.vault.offref()
// / app.metadataCache.offref().

const RENAME_KEY = "__obsidianSyncSystemFrontmatterRenameRef";
const META_KEY = "__obsidianSyncSystemFrontmatterMetaRef";
const SEEN_KEY = "__obsidianSyncSystemFrontmatterSeenPaths";
const PENDING_KEY = "__obsidianSyncSystemFrontmatterPendingRenames";

for (const [key, off] of [[RENAME_KEY, "vault"], [META_KEY, "metadataCache"]]) {
  const prev = globalThis[key];
  if (prev) {
    try { app[off].offref(prev); } catch (_) {}
    globalThis[key] = null;
  }
}

const seen = globalThis[SEEN_KEY] = new Set();
const pending = globalThis[PENDING_KEY] = new Set();

const VERMERKE_PATH_RE = /^akten\/\d{4}\/\d{2}\/[a-z0-9]+-[a-z0-9-]+\/vermerke\//;
const KADAI_PATH_RE = /^kadai\/\d{4}\/\d{2}\/\d{2}\//;
const ZAKKI_PATH_RE = /^zakki\/\d{4}\/\d{2}\/\d{2}\//;
const UID6_RE = /^[a-f0-9]{6}$/;

const slugify = (title) => {
  let s = title
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  if (s.length > 60) {
    s = s.slice(0, 60).replace(/-+$/g, "");
    const lastDash = s.lastIndexOf("-");
    if (lastDash > 30) s = s.slice(0, lastDash);
  }
  return s || "untitled";
};

const expectedStem = (file, title) => {
  const path = file.path;
  if (!VERMERKE_PATH_RE.test(path) && !KADAI_PATH_RE.test(path) && !ZAKKI_PATH_RE.test(path)) {
    return null;
  }
  const basename = file.basename;
  const dashIdx = basename.indexOf("-");
  const uid6 = dashIdx === -1 ? basename : basename.slice(0, dashIdx);
  if (!UID6_RE.test(uid6)) return null;
  return `${uid6}-${slugify(title)}`;
};

const renameRef = app.vault.on("rename", async (file, oldPath) => {
  if (!file || file.extension !== "md") return;
  if (oldPath === file.path) return;
  if (seen.has(oldPath)) {
    seen.delete(oldPath);
    seen.add(file.path);
  }
  try {
    await app.fileManager.processFrontMatter(file, (fm) => {
      if ("path" in fm)     fm.path     = file.path;
      if ("filename" in fm) fm.filename = file.basename;
    });
  } catch (_) {}
});
globalThis[RENAME_KEY] = renameRef;

const metaRef = app.metadataCache.on("changed", async (file, _data, cache) => {
  if (!file || file.extension !== "md") return;
  if (!seen.has(file.path)) {
    seen.add(file.path);
    return;
  }
  if (pending.has(file.path)) return;
  const title = cache && cache.frontmatter && cache.frontmatter.title;
  if (typeof title !== "string" || !title.trim()) return;
  const want = expectedStem(file, title);
  if (!want || file.basename === want) return;
  const newPath = `${file.parent.path}/${want}.md`;
  if (app.vault.getAbstractFileByPath(newPath)) return;
  pending.add(file.path);
  try {
    await app.fileManager.renameFile(file, newPath);
  } catch (_) {
    pending.delete(file.path);
    return;
  }
  pending.delete(file.path);
});
globalThis[META_KEY] = metaRef;
%>
