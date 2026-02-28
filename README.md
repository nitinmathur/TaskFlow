# TaskFlow

A native macOS Kanban-style task manager with Notes, built with SwiftUI and SwiftData.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)

## Features

### Kanban Board (Tasks Tab)
- **4 Columns**: Work, Personal, Ideas, Completed
- **Drag & Drop**: Move cards between columns
- **Priority Levels**: High (red), Medium (orange), Low (blue) - colored border
- **Due Dates**: Visual indicators for overdue/due-today
- **Checklists**: Sub-items with progress tracking (toggleable in preview)
- **Sorting**: Manual (default), Priority, Date Created, Due Date
- **Grouping**: Optional grouping by creation date
- **Manual Reorder**: Up/down arrows to arrange cards

### Notes Tab
- **Markdown Support**: Bold, italic, code, links, lists, checkboxes, quotes
- **Formatting Toolbar**: Quick insert buttons for markdown
- **Preview/Edit Modes**: View rendered markdown or edit raw text
- **Sorting**: Manual (default), Last Updated, Date Created, Title
- **Auto-save**: Changes saved with debounce

### Sync
- **iCloud Drive**: Syncs across Macs automatically
- **No Apple Developer Account Required**: Uses iCloud Drive folder
- **Location**: `~/Library/Mobile Documents/com~apple~CloudDocs/TaskFlow/`

## Screenshots

```
┌─────────────────────────────────────────────────────────────┐
│  [Tasks]  [Notes]                              TaskFlow     │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │💼 Work    │ │👤 Personal│ │💡 Ideas   │ │✓ Completed│      │
│  ├──────────┤ ├──────────┤ ├──────────┤ ├──────────┤       │
│  │┃▌Task 1  │ │┃▌Task 2  │ │┃▌Task 3  │ │          │       │
│  │┃▌...     │ │         │ │         │ │          │       │
│  │+ Add Card│ │+ Add Card│ │+ Add Card│ │          │       │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘       │
└─────────────────────────────────────────────────────────────┘
```

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Installation

```bash
# 1. Clone/copy project
cd /path/to/TaskFlow

# 2. Install xcodegen (if needed)
brew install xcodegen

# 3. Generate Xcode project
xcodegen generate

# 4. Open and run
open TaskFlow.xcodeproj
# Press Cmd+R in Xcode
```

### Sync Setup (Multiple Macs)

1. Enable iCloud Drive: System Settings → Apple ID → iCloud → iCloud Drive
2. Install TaskFlow on each Mac using steps above
3. Data syncs automatically via iCloud Drive

## Usage

### Tasks

| Action | How |
|--------|-----|
| Create card | Click "+ Add Card" in column |
| View card | Click card → opens preview |
| Edit card | Click "Edit" in preview |
| Check item | Click checklist item in preview |
| Move card | Drag to another column |
| Reorder | ↑↓ arrows (Manual sort) |
| Complete | Drag to "Completed" column |
| Delete | Hover → ✕, or right-click |

### Notes

| Action | How |
|--------|-----|
| Create | Click "+ New Note" |
| Edit | Click "Edit" button |
| Format | Use toolbar in edit mode |
| Preview | Click "Done" |
| Reorder | ↑↓ arrows (Manual sort) |
| Delete | Right-click → Delete |

## Project Structure

```
TaskFlow/
├── TaskFlowApp.swift           # App entry, SwiftData setup
├── Models/
│   ├── Column.swift            # Kanban columns enum
│   ├── TodoTask.swift          # Task model + checklist
│   └── Note.swift              # Note model
├── Views/
│   ├── MainTabView.swift       # Tab container
│   ├── Kanban/
│   │   ├── KanbanBoardView.swift
│   │   ├── KanbanColumnView.swift
│   │   ├── KanbanCardView.swift
│   │   ├── CardDetailView.swift
│   │   └── CardEditorView.swift
│   └── Notes/
│       ├── NotesSplitView.swift
│       ├── NoteEditorView.swift
│       ├── MarkdownComponents.swift
│       └── MarkdownRenderer.swift
├── project.yml                 # XcodeGen config
└── docs/
    └── PROJECT.md              # Full documentation
```

## Troubleshooting

**Data not syncing?**
```bash
# Check data folder exists
ls ~/Library/Mobile\ Documents/com~apple~CloudDocs/TaskFlow/
```
- Ensure iCloud Drive is enabled and synced
- Wait 30-60 seconds for initial sync

**Build errors?**
```bash
xcodegen generate  # Regenerate project
# In Xcode: Cmd+Shift+K (clean), then Cmd+R
```

**Reset data (if corrupted)?**
```bash
rm -rf ~/Library/Mobile\ Documents/com~apple~CloudDocs/TaskFlow/
# Restart app - creates fresh database
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| UI | SwiftUI |
| Data | SwiftData (SQLite) |
| Sync | iCloud Drive folder |
| SQLite Mode | DELETE (WAL disabled for sync) |
| Target | macOS 14.0+ |

## License

MIT License
