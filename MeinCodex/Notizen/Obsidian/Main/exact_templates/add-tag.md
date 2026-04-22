<%*
const tag = await tp.system.prompt("Add tag");
if (tag) {
    const file = app.workspace.getActiveFile();
    await app.fileManager.processFrontMatter(file, (fm) => {
        if (!fm.tags) {
            fm.tags = [];
        }
        if (!Array.isArray(fm.tags)) {
            fm.tags = [fm.tags];
        }
        const clean = tag.startsWith("#") ? tag.slice(1) : tag;
        if (!fm.tags.includes(clean)) {
            fm.tags.push(clean);
        }
    });
}
%>
