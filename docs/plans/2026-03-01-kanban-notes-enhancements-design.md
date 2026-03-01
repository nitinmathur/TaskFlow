# TaskFlow Enhancements Design

**Date:** 2026-03-01
**Status:** Approved

## Overview

Three enhancements to TaskFlow:
1. Dynamic Kanban columns (add/remove swimlanes)
2. Archive section for parking tasks
3. WYSIWYG notes editor

**Hard Constraint:** All features must be sync-compatible with the existing version vectors + soft deletes system.

---

## Feature 1: Dynamic Columns

### Data Model

```swift
@Model
final class BoardColumn {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "folder"
    var position: Int = 0
    var isSystem: Bool = false  // true for "Completed" - can't delete
    var syncVersion: Int = 1
}
```

Default columns on first launch:
- Work (position 0)
- Personal (position 1)
- Ideas (position 2)
- Completed (position 3, isSystem=true)

### TodoTask Changes

```swift
// Add to TodoTask:
var columnId: UUID?  // Reference to BoardColumn (replaces columnRaw enum)
```

### UI

**Add Column:**
- "+" button after last column
- Popover with name field and icon picker
- New column inserted before "Completed"

**Column Header Context Menu:**
- Rename column
- Change icon
- Delete column (disabled for system columns)
- Move left / Move right

**Constraints:**
- "Completed" column always last, cannot be deleted/renamed
- Deleting column with tasks shows warning

---

## Feature 2: Archive Section

### Data Model

```swift
// Add to TodoTask:
var isArchived: Bool = false
```

### UI

**Toolbar:**
- "Archive" button with badge (count of archived items)
- Click opens archive sheet

**Archive Sheet:**
- List of archived tasks
- Shows: title, original column, archived date
- Actions: "Restore" (back to original column), "Delete permanently"
- Search/filter support

**Archiving:**
- Right-click card → "Archive"

---

## Feature 3: WYSIWYG Notes Editor

### Architecture

- **Storage:** Markdown string (unchanged - sync compatible)
- **Display:** Markdown → NSAttributedString conversion
- **Editing:** Attributed string → Markdown on save

### Behavior

**Toolbar (works on selected text):**
- Bold: Wraps in `**`
- Italic: Wraps in `_`
- Heading: Adds `## ` at line start
- Bullet list: Adds `- ` at line start
- Checkbox: Adds `- [ ] ` at line start

**Live Rendering:**
- Markdown syntax hidden, styling applied visually
- `**bold**` displays as bold text
- `## Heading` displays as large text

**Keyboard Shortcuts:**
- Cmd+B: Bold
- Cmd+I: Italic
- Cmd+Shift+H: Heading

### Implementation

Custom `NSTextStorage` subclass that:
1. Parses markdown in real-time
2. Applies temporary display attributes
3. Keeps underlying string as plain markdown

Same technique as Typora, Bear, MacDown.

---

## Sync Integration

### New Sync Folder

```
~/Library/Mobile Documents/com~apple~CloudDocs/TaskFlow/sync/
  columns/           # NEW
    {uuid}.json
```

### SyncableBoardColumn

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
}
```

### SyncableTask.TaskData Updates

```swift
struct TaskData: Codable {
    // ... existing fields ...
    var isArchived: Bool   // NEW
    var columnId: UUID?    // NEW (replaces column string)
}
```

### Migration Strategy

On first launch after update:
1. Create default BoardColumn entries with deterministic UUIDs
2. Migrate existing tasks: `columnRaw` string → `columnId` UUID
3. Push columns to sync folder

Deterministic UUIDs ensure both Macs create identical IDs for default columns.

### Sync Order

1. Pull columns (so task references are valid)
2. Pull tasks
3. Pull notes
4. Push columns
5. Push tasks
6. Push notes

### Legacy Format

`LegacySyncableTask` handles old format:
- Missing `isArchived` → default `false`
- Missing `columnId` → lookup by old `column` string

---

## Summary

| Feature | Sync Impact | Complexity |
|---------|-------------|------------|
| Dynamic Columns | New SyncableBoardColumn | Medium |
| Archive | Add field to TaskData | Low |
| WYSIWYG Editor | None (markdown storage) | Medium |

All features preserve sync compatibility.
