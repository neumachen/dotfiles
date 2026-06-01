<%*
const quickAddApi = app.plugins.plugins.quickadd.api;

const existingTags = Object.keys(app.metadataCache.getTags())
  .map(t => t.replace(/^#/, ""))
  .sort();

// allowCustomInput: true lets the user type a new tag and press Enter
// directly — no second prompt needed. Existing tags appear as suggestions
// while typing; if nothing matches, the typed text is returned as-is.
const tag = await quickAddApi.suggester(
  existingTags,
  existingTags,
  "Tag name — pick existing or type a new one",
  true
);

if (!tag) return;

const file = app.workspace.getActiveFile();
await app.fileManager.processFrontMatter(file, (fm) => {
  if (!fm.tags) fm.tags = [];
  if (!Array.isArray(fm.tags)) fm.tags = [fm.tags];
  const clean = tag.startsWith("#") ? tag.slice(1) : tag;
  if (!fm.tags.includes(clean)) fm.tags.push(clean);
});
%>
