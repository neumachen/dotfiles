<%*
const id = Math.random().toString(16).slice(2, 10);
const title = await tp.system.prompt("Meeting title");
if (!title) return;
const now = tp.date.now("YYYY-MM-DD HH:mm:ss");
const dateStr = tp.date.now("YYYY-MM-DD");
await tp.file.move("zakki/" + id);
tR += `---
id: ${id}
title: ${title}
created: ${now}
updated: ${now}
tags:
  - zakki
  - meeting
---

# ${title}

**Date**: ${dateStr}
**Attendees**:

## Agenda

-

## Notes

-

## Action Items

- [ ]
- [ ]

---

**Tips**: Link to projects: \`[[Project Name]]\`
`;
%>
