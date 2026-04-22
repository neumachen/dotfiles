<%*
const id = Math.random().toString(16).slice(2, 10);
const title = await tp.system.prompt("Zakki title");
if (!title) return;
await tp.file.move("zakki/" + id);
tR += `---
id: ${id}
title: ${title}
aliases:
tags:
  - zakki
created: ${tp.date.now("YYYY-MM-DD HH:mm:ss")}
updated: ${tp.date.now("YYYY-MM-DD HH:mm:ss")}
---

`;
%>
