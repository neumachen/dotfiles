<%*
const KEY = "__obsidianSyncSystemFrontmatterRef";
const prev = globalThis[KEY];
if (prev) {
  try { app.vault.offref(prev); } catch (_) {}
  globalThis[KEY] = null;
}

const ref = app.vault.on("rename", async (file, oldPath) => {
  if (!file || file.extension !== "md") return;
  if (oldPath === file.path) return;
  try {
    await app.fileManager.processFrontMatter(file, (fm) => {
      if ("path" in fm)     fm.path     = file.path;
      if ("filename" in fm) fm.filename = file.basename;
    });
  } catch (_) {}
});
globalThis[KEY] = ref;
%>
