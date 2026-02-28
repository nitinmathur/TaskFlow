# TaskFlow Project Documentation

**Last Updated:** 2026-02-28
**Status:** v2.0 - Kanban Redesign Complete

## Overview

TaskFlow is a native macOS Kanban-style task manager with Notes, built with SwiftUI and SwiftData. Syncs across Macs via iCloud Drive without requiring a paid Apple Developer account.

## Current Features (v2.0)

### Kanban Board
| Feature | Description |
|---------|-------------|
| 4 Columns | Work, Personal, Ideas, Completed |
| Drag & Drop | Move cards between columns |
| Priority | High (red), Medium (orange), Low (blue) borders |
| Due Dates | Visual indicators for overdue/today |
| Checklists | Sub-items per card with progress bar |
| Sorting | Manual, Priority, Date Created, Due Date |
| Grouping | Optional by creation date |
| Reorder | Up/down arrows in Manual mode |

### Notes
| Feature | Description |
|---------|-------------|
| Markdown | Bold, italic, code, links, lists, checkboxes, quotes |
| Toolbar | Quick-insert formatting buttons |
| Preview/Edit | Toggle between rendered and raw views |
| Sorting | Manual, Last Updated, Date Created, Title |
| Auto-save | Debounced saves on edit |

### Sync
- iCloud Drive folder: `~/Library/Mobile Documents/com~apple~CloudDocs/TaskFlow/`
- SQLite with DELETE journal mode (WAL disabled for sync compatibility)
- No CloudKit/paid developer account required

## Tech Stack

| Component | Technology |
|-----------|------------|
| UI Framework | SwiftUI |
| Persistence | SwiftData (SQLite) |
| Sync | iCloud Drive folder |
| Build Tool | XcodeGen |
| Target | macOS 14.0+ (Sonoma) |
| Swift | 5.9+ |

## Architecture

### Data Models

**TodoTask**
```swift
@Model class TodoTask {
    var id: UUID
    var title: String
    var taskDescription: String?
    var columnRaw: String        // Column enum raw value
    var priorityRaw: Int         // Priority enum raw value
    var position: Int            // Manual ordering
    var dueDate: Date?
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var checklistData: Data?     // JSON-encoded [ChecklistItem]
}
```

**Note**
```swift
@Model class Note {
    var id: UUID
    var title: String
    var body: String             // Markdown content
    var position: Int            // Manual ordering
    var createdAt: Date
    var updatedAt: Date
}
```

**ChecklistItem** (Codable, stored as JSON)
```swift
struct ChecklistItem: Codable, Identifiable {
    var id: UUID
    var text: String
    var isChecked: Bool
}
```

### Project Structure

```
TaskFlow/
├── project.yml                    # XcodeGen configuration
├── README.md                      # Setup instructions
├── docs/
│   ├── PROJECT.md                 # This file
│   └── plans/
│       └── 2026-02-28-kanban-redesign.md
└── TaskFlow/
    ├── TaskFlowApp.swift          # Entry point, SwiftData container
    ├── Models/
    │   ├── Column.swift           # work, personal, ideas, completed
    │   ├── TodoTask.swift         # Task + ChecklistItem
    │   └── Note.swift             # Note model
    └── Views/
        ├── MainTabView.swift      # Tab container (Tasks/Notes)
        ├── Kanban/
        │   ├── KanbanBoardView.swift    # Board with 4 columns
        │   ├── KanbanColumnView.swift   # Single column + drop target
        │   ├── KanbanCardView.swift     # Card with priority border
        │   ├── CardDetailView.swift     # Read-only preview + checklist
        │   └── CardEditorView.swift     # Create/edit form
        └── Notes/
            ├── NotesSplitView.swift     # Split view + list
            ├── NoteEditorView.swift     # Edit/preview toggle
            ├── MarkdownComponents.swift # Toolbar + NSTextView
            └── MarkdownRenderer.swift   # Markdown → AttributedString
```

## Key Implementation Details

### iCloud Sync Without CloudKit
```swift
// Store in iCloud Drive folder (no entitlements needed)
let iCloudDrive = home.appendingPathComponent(
    "Library/Mobile Documents/com~apple~CloudDocs/TaskFlow"
)

// Disable WAL mode for iCloud compatibility
sqlite3_exec(db, "PRAGMA journal_mode=DELETE;", nil, nil, nil)
```

### Checklist as JSON
```swift
var checklist: [ChecklistItem] {
    get {
        guard let data = checklistData else { return [] }
        return (try? JSONDecoder().decode([ChecklistItem].self, from: data)) ?? []
    }
    set {
        checklistData = try? JSONEncoder().encode(newValue)
    }
}
```

### Markdown Rendering
- Uses `AttributedString` with regex pattern matching
- Supports: `**bold**`, `_italic_`, `` `code` ``, `[link](url)`, `~~strike~~`
- Block elements: headings, lists, checkboxes, quotes, code blocks

### Manual Ordering
- `position` field on both TodoTask and Note
- Swap positions when reordering via up/down buttons
- New items get `maxPosition + 1`

## Build & Run

```bash
# Generate Xcode project
cd /path/to/TaskFlow
xcodegen generate

# Open and build
open TaskFlow.xcodeproj
# Cmd+R in Xcode
```

## Data Location

```bash
# Database file
~/Library/Mobile Documents/com~apple~CloudDocs/TaskFlow/TaskFlow.store

# Fallback (if iCloud unavailable)
~/Documents/TaskFlow/TaskFlow.store
```

---

## Future Enhancements

### Priority 1: Telegram Bot
- Local Python bot for mobile task capture
- Commands: `/add`, `/list`, `/done`, `/today`
- Shares data via JSON in iCloud Drive

### Priority 2: Nice to Have
- [ ] Keyboard shortcuts (Cmd+N, etc.)
- [ ] Menu bar quick add
- [ ] Due date notifications
- [ ] Search/filter
- [ ] Tags/labels
- [ ] Export to Markdown
- [ ] Archive vs delete

---

## Session Continuity

### Context for Future Sessions
- User is a developer using this for daily task management
- Has 2 Macs syncing via iCloud Drive
- Prefers simple, clean solutions
- Kanban redesign completed 2026-02-28

### Current State
- All features working
- Manual ordering for tasks and notes
- Checklist with toggle in preview
- Markdown notes with preview/edit modes
- No known bugs

### Quick Commands
```bash
# Build
cd /Users/nmathur/Documents/personal-projects/TaskFlow
xcodegen generate && open TaskFlow.xcodeproj

# Check data
ls -la ~/Library/Mobile\ Documents/com~apple~CloudDocs/TaskFlow/

# Reset data (if needed)
rm -rf ~/Library/Mobile\ Documents/com~apple~CloudDocs/TaskFlow/
```
