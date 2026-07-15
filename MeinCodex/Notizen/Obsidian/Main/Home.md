# Home

## 📋 Open Tasks (Kadai)

```base
filters:
  and:
    - file.hasTag("task")
    - 'note["type"] == "kadai"'
formulas:
  titleLink: 'file.asLink(title)'
  dueDate: 'note["task.due-date"]'
  taskStatus: 'note["task.status"]'
  taskPriority: 'note["task.priority"]'
  recordedOn: 'note["modified_at.utc"]'
  dueSortKey: 'note["task.due-date"] ?? "9999-12-31"'
  isOpen: 'note["task.status"] != "completed" and note["task.status"] != "discarded" and note["task.status"] != "abandoned"'
properties:
  formula.titleLink:
    displayName: Task
  formula.taskStatus:
    displayName: Status
  formula.dueDate:
    displayName: Due
  formula.recordedOn:
    displayName: Recorded On
  formula.taskPriority:
    displayName: Priority
  file.tags:
    displayName: Tags
views:
  - type: table
    name: Open By Due
    order:
      - formula.titleLink
      - formula.taskStatus
      - formula.dueDate
      - formula.recordedOn
      - formula.taskPriority
      - file.tags
    sort:
      - property: formula.dueSortKey
        direction: ASC
      - property: formula.recordedOn
        direction: DESC
    filter: formula.isOpen
```

## 🗒️ Latest Zakki

```base
filters:
  and:
    - file.hasTag("zakki")
formulas:
  titleLink: 'file.asLink(title)'
  createdOn: 'note["created_at.utc"]'
  recordedOn: 'note["modified_at.utc"]'
properties:
  formula.titleLink:
    displayName: Title
  formula.createdOn:
    displayName: Created
  formula.recordedOn:
    displayName: Recorded On
  file.tags:
    displayName: Tags
views:
  - type: table
    name: Latest
    order:
      - formula.titleLink
      - formula.createdOn
      - formula.recordedOn
      - file.tags
    sort:
      - property: formula.createdOn
        direction: DESC
```

## 📁 Latest Akten

```base
filters:
  and:
    - file.hasTag("akten")
formulas:
  titleLink: 'file.asLink(title)'
  createdOn: 'note["created_at.utc"]'
  recordedOn: 'note["modified_at.utc"]'
properties:
  formula.titleLink:
    displayName: Title
  formula.createdOn:
    displayName: Created
  formula.recordedOn:
    displayName: Recorded On
  file.tags:
    displayName: Tags
views:
  - type: table
    name: Latest
    order:
      - formula.titleLink
      - formula.createdOn
      - formula.recordedOn
      - file.tags
    sort:
      - property: formula.createdOn
        direction: DESC
```

## ✏️ Recently Edited

```base
filters:
  or:
    - file.hasTag("akten")
    - file.hasTag("zakki")
    - file.hasTag("task")
formulas:
  titleLink: 'file.asLink(title)'
  docType: 'note["type"]'
  recordedOn: 'note["modified_at.utc"]'
properties:
  formula.titleLink:
    displayName: Title
  formula.docType:
    displayName: Type
  formula.recordedOn:
    displayName: Recorded On
  file.tags:
    displayName: Tags
views:
  - type: table
    name: Recently Edited
    limit: 15
    order:
      - formula.titleLink
      - formula.docType
      - formula.recordedOn
      - file.tags
    sort:
      - property: formula.recordedOn
        direction: DESC
```
