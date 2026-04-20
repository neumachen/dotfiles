<%*
// Step 1: dedicated note or inline only?
const createNote = await tp.system.suggester(
    ["Yes — create a dedicated note", "No — inline task only"],
    [true, false]
);
if (createNote === null) return;

// Step 2: task title
const title = await tp.system.prompt("Task title");
if (!title) return;

const id = Math.random().toString(16).slice(2, 10);
const now = tp.date.now("YYYY-MM-DD HH:mm:ss");
const taskLine = `- [ ] ${title} #task`;

if (createNote) {
    const noteContent = `---
id: ${id}
title: ${title}
tags:
  - task
task:
  status: open
  due:
  priority:
created: ${now}
updated: ${now}
---

${taskLine}

---

## Description

## Acceptance Criteria

- [ ] 

## Notes

`;
    await app.vault.create(`zakki/${id}.md`, noteContent);
    tR += `[[${id}|${title}]]`;
} else {
    tR += taskLine;
}
%>
