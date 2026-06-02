<%*
// QuickAdd provides the only suggester this template needs (Templater's
// own suggester has no "type a new value" affordance). If QuickAdd is
// disabled or uninstalled, fall through to a Notice rather than throwing
// a ReferenceError on the missing `.api` property.
const quickAddApi = app.plugins.plugins?.quickadd?.api;
if (!quickAddApi) { new Notice("QuickAdd is not enabled."); return; }

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
