# TaskFlow Enhancements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add dynamic columns, archive section, and WYSIWYG notes editor while preserving sync compatibility.

**Architecture:** New BoardColumn SwiftData model for columns, isArchived flag on tasks, NSTextStorage subclass for live markdown rendering.

**Tech Stack:** SwiftUI, SwiftData, AppKit (NSTextView/NSTextStorage)

---

## Phase 1: Dynamic Columns

### Task 1: Create BoardColumn Model

**Files:**
- Create: `TaskFlow/Models/BoardColumn.swift`

**Steps:**

1. Create the model file:

```swift
import Foundation
import SwiftData

@Model
final class BoardColumn {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "folder"
    var position: Int = 0
    var isSystem: Bool = false
    var syncVersion: Int = 1

    init(name: String, icon: String, position: Int, isSystem: Bool = false) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.position = position
        self.isSystem = isSystem
    }

    // Deterministic ID for default columns (ensures sync compatibility)
    init(defaultColumn: String, name: String, icon: String, position: Int, isSystem: Bool = false) {
        self.id = UUID(uuidString: "00000000-0000-0000-0000-\(defaultColumn.padding(toLength: 12, withPad: "0", startingAt: 0))")!
        self.name = name
        self.icon = icon
        self.position = position
        self.isSystem = isSystem
    }
}
```

2. Commit: `git add TaskFlow/Models/BoardColumn.swift && git commit -m "feat: add BoardColumn model"`

---

### Task 2: Update TodoTask Model

**Files:**
- Modify: `TaskFlow/Models/TodoTask.swift`

**Steps:**

1. Add new properties to TodoTask:

```swift
// Add after checklistData property:
var isArchived: Bool = false
var columnId: UUID?

// Add computed property for backward compatibility:
var boardColumn: BoardColumn? {
    // This will be set via relationship or lookup
    nil
}
```

2. Commit: `git commit -am "feat: add isArchived and columnId to TodoTask"`

---

### Task 3: Add Column Sync Support

**Files:**
- Modify: `TaskFlow/Sync/SyncManager.swift`

**Steps:**

1. Add SyncableBoardColumn struct after SyncableNote:

```swift
struct SyncableBoardColumn: Codable {
    var id: UUID
    var version: Int
    var isDeleted: Bool
    var deletedAt: Date?
    var data: ColumnData?

    struct ColumnData: Codable {
        var name: String
        var icon: String
        var position: Int
        var isSystem: Bool
    }

    init(id: UUID, version: Int, isDeleted: Bool, deletedAt: Date?, data: ColumnData?) {
        self.id = id
        self.version = version
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.data = data
    }

    init(from column: BoardColumn, version: Int) {
        self.id = column.id
        self.version = version
        self.isDeleted = false
        self.deletedAt = nil
        self.data = ColumnData(
            name: column.name,
            icon: column.icon,
            position: column.position,
            isSystem: column.isSystem
        )
    }

    static func tombstone(id: UUID, version: Int) -> SyncableBoardColumn {
        SyncableBoardColumn(id: id, version: version, isDeleted: true, deletedAt: Date(), data: nil)
    }

    func apply(to column: BoardColumn) {
        guard let data = data else { return }
        column.name = data.name
        column.icon = data.icon
        column.position = data.position
        column.isSystem = data.isSystem
    }
}
```

2. Add columnsURL property and setup in SyncManager:

```swift
// Add property:
private let columnsURL: URL

// In init(), after notesURL:
columnsURL = sharedURL.appendingPathComponent("columns")

// In setupDirectories():
try? FileManager.default.createDirectory(at: columnsURL, withIntermediateDirectories: true)
```

3. Add pushColumns and pullColumns methods (same pattern as tasks/notes)

4. Commit: `git commit -am "feat: add column sync support"`

---

### Task 4: Update SyncableTask for New Fields

**Files:**
- Modify: `TaskFlow/Sync/SyncManager.swift`

**Steps:**

1. Add to SyncableTask.TaskData:

```swift
var isArchived: Bool
var columnId: UUID?
```

2. Update init(from task:) and apply(to:) methods

3. Update LegacySyncableTask.toNew() to provide defaults

4. Commit: `git commit -am "feat: add isArchived and columnId to task sync"`

---

### Task 5: Create Column Migration Helper

**Files:**
- Create: `TaskFlow/Sync/ColumnMigration.swift`

**Steps:**

1. Create migration that runs on first launch:
- Check if BoardColumn table empty
- Create default columns with deterministic UUIDs
- Migrate existing tasks from columnRaw to columnId

2. Commit: `git commit -am "feat: add column migration helper"`

---

### Task 6: Update KanbanBoardView for Dynamic Columns

**Files:**
- Modify: `TaskFlow/Views/Kanban/KanbanBoardView.swift`

**Steps:**

1. Replace `Column.allCases` with `@Query` for BoardColumn
2. Add "+" button for new column
3. Update column iteration to use BoardColumn model

4. Commit: `git commit -am "feat: update kanban board for dynamic columns"`

---

### Task 7: Add Column Management UI

**Files:**
- Create: `TaskFlow/Views/Kanban/ColumnHeaderView.swift`

**Steps:**

1. Create column header with context menu (rename, delete, reorder)
2. Add popover for adding new columns

3. Commit: `git commit -am "feat: add column management UI"`

---

## Phase 2: Archive Section

### Task 8: Create Archive View

**Files:**
- Create: `TaskFlow/Views/Kanban/ArchiveView.swift`

**Steps:**

1. Create sheet showing archived tasks with restore/delete actions

2. Commit: `git commit -am "feat: add archive view"`

---

### Task 9: Add Archive Button to Toolbar

**Files:**
- Modify: `TaskFlow/Views/Kanban/KanbanBoardView.swift`

**Steps:**

1. Add archive button with badge count
2. Add sheet presentation for ArchiveView
3. Add context menu "Archive" option to cards

4. Commit: `git commit -am "feat: add archive button and card archiving"`

---

## Phase 3: WYSIWYG Notes Editor

### Task 10: Create MarkdownTextStorage

**Files:**
- Create: `TaskFlow/Views/Notes/MarkdownTextStorage.swift`

**Steps:**

1. Create NSTextStorage subclass that:
- Parses markdown patterns (bold, italic, headers, lists)
- Applies display attributes (hiding syntax, applying styles)
- Preserves underlying markdown string

2. Commit: `git commit -am "feat: add MarkdownTextStorage for live rendering"`

---

### Task 11: Update Note Editor to Use New Storage

**Files:**
- Modify: `TaskFlow/Views/Notes/MarkdownComponents.swift`

**Steps:**

1. Replace MarkdownTextEditor with new WYSIWYG version using MarkdownTextStorage
2. Update FormattingToolbar to work on text selection (not append)

3. Commit: `git commit -am "feat: integrate WYSIWYG editor"`

---

### Task 12: Add Keyboard Shortcuts

**Files:**
- Modify: `TaskFlow/Views/Notes/MarkdownComponents.swift`

**Steps:**

1. Add Cmd+B (bold), Cmd+I (italic), Cmd+Shift+H (heading)

2. Commit: `git commit -am "feat: add formatting keyboard shortcuts"`

---

## Phase 4: Integration & Testing

### Task 13: Update App Schema

**Files:**
- Modify: `TaskFlow/TaskFlowApp.swift`

**Steps:**

1. Add BoardColumn to SwiftData schema
2. Call migration on app launch

3. Commit: `git commit -am "feat: register BoardColumn in app schema"`

---

### Task 14: Manual Testing Checklist

- [ ] Create new column, verify appears
- [ ] Delete custom column, verify removed
- [ ] Rename column, verify change persists
- [ ] Archive task, verify disappears from board
- [ ] Restore archived task, verify returns
- [ ] Bold text in notes, verify displays correctly
- [ ] Sync: Push from Mac A, pull on Mac B, verify columns sync
- [ ] Sync: Archive on Mac A, pull on Mac B, verify task archived

---

## Execution Order

1. Tasks 1-5 (column model + sync)
2. Task 13 (app schema - needed before UI)
3. Tasks 6-7 (column UI)
4. Tasks 8-9 (archive)
5. Tasks 10-12 (WYSIWYG)
6. Task 14 (testing)
