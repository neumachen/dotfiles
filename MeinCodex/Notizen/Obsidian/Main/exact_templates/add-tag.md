<%*
const existingTags = Object.keys(app.metadataCache.getTags())
  .map(t => t.replace(/^#/, ""))
  .sort();

let tag;
if (existingTags.length > 0) {
  tag = await tp.system.suggester(
    existingTags,
    existingTags,
    false,
    "Pick existing tag — Esc to type a new one"
  );
}

if (!tag) {
  tag = await tp.system.prompt("New tag");
}

if (!tag) return;

const file = app.workspace.getActiveFile();
await app.fileManager.processFrontMatter(file, (fm) => {
  if (!fm.tags) fm.tags = [];
  if (!Array.isArray(fm.tags)) fm.tags = [fm.tags];
  const clean = tag.startsWith("#") ? tag.slice(1) : tag;
  if (!fm.tags.includes(clean)) fm.tags.push(clean);
});
%>
