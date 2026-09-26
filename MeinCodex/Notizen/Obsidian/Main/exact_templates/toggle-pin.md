<%*
// Toggle the `pinned` frontmatter property on the active note.
// `pinned: true` lists a Zakki in the Home dashboard's Pinned section while
// it stays an ordinary Zakki. Unpinning writes `pinned: false` so the
// checkbox stays visible in the Properties panel. Type declared as
// `checkbox` in dot_obsidian/types.json. Bound to Cmd+Alt+P (hotkeys.json,
// Templater insert-mode hotkey like add-tag.md). Produces no text.
const file = tp.config.target_file ?? app.workspace.getActiveFile();
if (!file) { new Notice("No active note to pin."); return; }

let pinned = false;
await app.fileManager.processFrontMatter(file, (fm) => {
  pinned = fm.pinned !== true;
  fm.pinned = pinned;
});

const fm = app.metadataCache.getFileCache(file)?.frontmatter;
const label = fm?.title ?? file.basename;
const hint = fm?.type === "zakki"
  ? ""
  : "\nOnly Zakki appear in the Home dashboard's pinned section.";
new Notice((pinned ? `Pinned: ${label}` : `Unpinned: ${label}`) + hint);
%>
