# TaskFlow Kanban Redesign

**Date:** 2026-02-28
**Status:** Approved

## Overview

Redesign TaskFlow from list-based to Kanban-style board with Notes feature.

## Requirements

- **Kanban board**: 4 columns (Work | Personal | Ideas | Completed)
- **Cards**: Title, description (visible), due date, priority (colored border)
- **Drag-drop**: Move cards between columns, reorder within
- **Tab UI**: Tasks tab (Kanban) | Notes tab
- **Notes**: Title + Markdown body with checkbox support
- **Sync**: iCloud Drive (existing)

## Data Model

### TodoTask (modified)
| Field | Type | Change |
|-------|------|--------|
| column | Column enum | Replaces category |
| position | Int | New: ordering within column |
| Others | - | Unchanged |

### Column enum
`work`, `personal`, `ideas`, `completed`

### Note (new)
| Field | Type |
|-------|------|
| id | UUID |
| title | String |
| body | String (Markdown) |
| createdAt | Date |
| updatedAt | Date |

### Migration
- Work category → work column
- Personal category → personal column
- Others → ideas column
- Delete Category model

## UI Design

### Main Layout
```
┌─────────────────────────────────────────┐
│  [📋 Tasks]  [📝 Notes]       TaskFlow  │
├─────────────────────────────────────────┤
│  Tab content (Kanban or Notes)          │
└─────────────────────────────────────────┘
```

### Kanban Card
```
┌────────────────────────┐
┃▌ Title                 │  ← Priority color border
┃▌ Description preview   │  ← 2 lines max
│  Due: Mar 1        [×] │  ← Delete on hover
└────────────────────────┘
```

Priority colors: High=red, Medium=orange, Low=blue

### Notes Tab
Split view: Note list (left) | Editor (right)

## Interactions

**Kanban:**
- Drag card → Move between columns
- Drop on Completed → Sets completedAt
- [+] in column → New card in that column
- Click card → Edit sheet
- [×] or right-click → Delete with confirm

**Notes:**
- Click note → Opens in editor
- Auto-save on edit (debounced)
- Markdown with checkboxes: `- [ ] item`

## File Structure

```
TaskFlow/
├── Models/
│   ├── TodoTask.swift    # Modified
│   ├── Column.swift      # New
│   └── Note.swift        # New
├── Views/
│   ├── MainTabView.swift
│   ├── Kanban/
│   │   ├── KanbanBoardView.swift
│   │   ├── KanbanColumnView.swift
│   │   ├── KanbanCardView.swift
│   │   └── CardEditorView.swift
│   └── Notes/
│       ├── NotesListView.swift
│       ├── NoteEditorView.swift
│       └── NotesSplitView.swift
└── Utilities/
    └── DefaultDataSeeder.swift
```

## Out of Scope

- Tags on notes
- Attachments
- Folders for notes
- Recurring tasks
