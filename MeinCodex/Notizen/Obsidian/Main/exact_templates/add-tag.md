<%*
const NEW_TAG_SENTINEL = "＋ New tag…";

const existingTags = Object.keys(app.metadataCache.getTags())
  .map(t => t.replace(/^#/, ""))
  .sort();

const choices = [NEW_TAG_SENTINEL, ...existingTags];

const selected = await tp.system.suggester(
  choices,
  choices,
  false,
  "Pick a tag or select ＋ to create a new one"
);

if (!selected) return;

let tag;
if (selected === NEW_TAG_SENTINEL) {
  tag = await tp.system.prompt("New tag", "");
} else {
  tag = selected;
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
