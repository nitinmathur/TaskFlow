# Sync Implementation Plan - Version Vectors + Soft Deletes

## Project Context

**App:** TaskFlow - macOS Kanban task manager with Notes
**Tech:** SwiftUI + SwiftData + iCloud Drive (file-based sync)
**Goal:** Reliable sync between two Macs without data loss

## Current State

### What Works
- Manual Push/Pull buttons work
- File-per-item JSON storage in iCloud Drive
- Basic auto-sync timer (but unreliable)

### What's Broken
- **Deletes don't propagate** - Delete on Mac A, item stays on Mac B
- **Data loss** - Items disappear during sync
- **Root cause:** No way to distinguish "deleted" vs "doesn't exist yet"

### Current Sync Location
```
~/Library/Mobile Documents/com~apple~CloudDocs/TaskFlow/sync/
  tasks/
    {uuid}.json
  notes/
    {uuid}.json
```

---

## Chosen Solution: Version Vectors + Soft Deletes

### Key Concepts

1. **Version Number** - Each item has a version that increments on every change
2. **Soft Delete** - "Delete" sets `isDeleted: true` instead of removing file
3. **Tombstone** - Deleted items kept for 7 days, then purged
4. **No Conflicts** - User only edits one Mac at a time (assumption confirmed)

### New JSON Structure

**Current (broken):**
```json
{
  "id": "uuid",
  "title": "Task title",
  "column": "work",
  ...
  "modifiedAt": "2024-03-01T10:00:00Z"
}
```

**New (reliable):**
```json
{
  "id": "uuid",
  "version": 3,
  "isDeleted": false,
  "deletedAt": null,
  "data": {
    "title": "Task title",
    "column": "work",
    ...
  }
}
```

---

## Files to Modify

### 1. SyncManager.swift
**Path:** `TaskFlow/Sync/SyncManager.swift`

**Changes needed:**
- Update `SyncableTask` struct - add version, isDeleted, deletedAt
- Update `SyncableNote` struct - add version, isDeleted, deletedAt
- Change `pushTasks()` - increment version, handle soft deletes
- Change `pullTasks()` - compare versions, respect isDeleted flag
- Add `purgeOldTombstones()` - cleanup files older than 7 days
- Remove timestamp-based change detection (use versions instead)

### 2. TodoTask.swift
**Path:** `TaskFlow/Models/TodoTask.swift`

**Changes needed:**
- Add `syncVersion: Int` property (stored in SwiftData)
- Version starts at 1, increments on each save

### 3. Note.swift
**Path:** `TaskFlow/Models/Note.swift`

**Changes needed:**
- Add `syncVersion: Int` property
- Same versioning logic as TodoTask

### 4. MainTabView.swift
**Path:** `TaskFlow/Views/MainTabView.swift`

**Changes needed:**
- Simplify sync triggers
- Remove hash-based change detection
- Trust version numbers instead

---

## Implementation Details

### Step 1: Update SyncableTask Struct

**Current code (around line 17-57 in SyncManager.swift):**
```swift
struct SyncableTask: Codable {
    var id: UUID
    var title: String
    var taskDescription: String?
    var column: String
    var priority: Int
    var position: Int
    var dueDate: Date?
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var checklist: [ChecklistItem]
    var modifiedAt: Date
    // ...
}
```

**New code:**
```swift
struct SyncableTask: Codable {
    var id: UUID
    var version: Int
    var isDeleted: Bool
    var deletedAt: Date?
    var data: TaskData?

    struct TaskData: Codable {
        var title: String
        var taskDescription: String?
        var column: String
        var priority: Int
        var position: Int
        var dueDate: Date?
        var isCompleted: Bool
        var createdAt: Date
        var completedAt: Date?
        var checklist: [ChecklistItem]
    }

    init(from task: TodoTask, version: Int) {
        self.id = task.id
        self.version = version
        self.isDeleted = false
        self.deletedAt = nil
        self.data = TaskData(
            title: task.title,
            taskDescription: task.taskDescription,
            column: task.columnRaw,
            priority: task.priorityRaw,
            position: task.position,
            dueDate: task.dueDate,
            isCompleted: task.isCompleted,
            createdAt: task.createdAt,
            completedAt: task.completedAt,
            checklist: task.checklist
        )
    }

    // Tombstone constructor
    static func tombstone(id: UUID, version: Int) -> SyncableTask {
        var task = SyncableTask()
        task.id = id
        task.version = version
        task.isDeleted = true
        task.deletedAt = Date()
        task.data = nil
        return task
    }

    func apply(to task: TodoTask) {
        guard let data = data else { return }
        task.title = data.title
        task.taskDescription = data.taskDescription
        task.columnRaw = data.column
        task.priorityRaw = data.priority
        task.position = data.position
        task.dueDate = data.dueDate
        task.isCompleted = data.isCompleted
        task.completedAt = data.completedAt
        task.checklist = data.checklist
    }
}
```

### Step 2: Update SyncableNote (same pattern)

```swift
struct SyncableNote: Codable {
    var id: UUID
    var version: Int
    var isDeleted: Bool
    var deletedAt: Date?
    var data: NoteData?

    struct NoteData: Codable {
        var title: String
        var body: String
        var position: Int
        var folderName: String
        var createdAt: Date
        var updatedAt: Date
    }

    init(from note: Note, version: Int) {
        self.id = note.id
        self.version = version
        self.isDeleted = false
        self.deletedAt = nil
        self.data = NoteData(
            title: note.title,
            body: note.body,
            position: note.position,
            folderName: note.folderName,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt
        )
    }

    static func tombstone(id: UUID, version: Int) -> SyncableNote {
        var note = SyncableNote()
        note.id = id
        note.version = version
        note.isDeleted = true
        note.deletedAt = Date()
        note.data = nil
        return note
    }

    func apply(to note: Note) {
        guard let data = data else { return }
        note.title = data.title
        note.body = data.body
        note.position = data.position
        note.folderName = data.folderName
        note.updatedAt = data.updatedAt
    }
}
```

### Step 3: Add syncVersion to Models

**TodoTask.swift - add property:**
```swift
@Model
final class TodoTask {
    // ... existing properties ...
    var syncVersion: Int = 1  // ADD THIS

    // In init(), add:
    self.syncVersion = 1
}
```

**Note.swift - add property:**
```swift
@Model
final class Note {
    // ... existing properties ...
    var syncVersion: Int = 1  // ADD THIS

    // In init(), add:
    self.syncVersion = 1
}
```

### Step 4: New Pull Algorithm

```swift
func pullTasks(context: ModelContext, localTasks: [TodoTask]) throws -> [TodoTask] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    var updatedTasks: [TodoTask] = []
    let localByID = Dictionary(uniqueKeysWithValues: localTasks.map { ($0.id, $0) })
    var processedIDs = Set<UUID>()

    // 1. Read all remote files
    guard let files = try? FileManager.default.contentsOfDirectory(at: tasksURL, includingPropertiesForKeys: nil) else {
        return []
    }

    for file in files where file.pathExtension == "json" {
        guard let data = try? Data(contentsOf: file),
              let remote = try? decoder.decode(SyncableTask.self, from: data) else { continue }

        processedIDs.insert(remote.id)

        if remote.isDeleted {
            // Remote says deleted - remove local if exists
            if let localTask = localByID[remote.id] {
                context.delete(localTask)
            }
            // Keep tombstone file (cleanup job will remove after 7 days)
        } else if let localTask = localByID[remote.id] {
            // Both have it - compare versions
            if remote.version > localTask.syncVersion {
                // Remote is newer - update local
                remote.apply(to: localTask)
                localTask.syncVersion = remote.version
                updatedTasks.append(localTask)
            }
            // else: local is same or newer, will push later
        } else {
            // Remote has it, local doesn't - create local
            guard let taskData = remote.data else { continue }
            let newTask = TodoTask(title: taskData.title)
            newTask.id = remote.id
            newTask.syncVersion = remote.version
            remote.apply(to: newTask)
            newTask.createdAt = taskData.createdAt
            context.insert(newTask)
            updatedTasks.append(newTask)
        }
    }

    lastSyncTime = Date()
    return updatedTasks
}
```

### Step 5: New Push Algorithm

```swift
func pushTasks(_ tasks: [TodoTask]) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = .prettyPrinted

    let localIDs = Set(tasks.map { $0.id })

    // 1. Push all local tasks
    for task in tasks {
        task.syncVersion += 1  // Increment version on push
        let syncable = SyncableTask(from: task, version: task.syncVersion)
        let data = try encoder.encode(syncable)
        let fileURL = tasksURL.appendingPathComponent("\(task.id.uuidString).json")
        try data.write(to: fileURL)
    }

    // 2. Find remote files not in local - these were deleted locally
    if let files = try? FileManager.default.contentsOfDirectory(at: tasksURL, includingPropertiesForKeys: nil) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for file in files where file.pathExtension == "json" {
            let fileID = UUID(uuidString: file.deletingPathExtension().lastPathComponent)
            guard let id = fileID, !localIDs.contains(id) else { continue }

            // Read existing file to get current version
            if let data = try? Data(contentsOf: file),
               let existing = try? decoder.decode(SyncableTask.self, from: data) {

                if !existing.isDeleted {
                    // Not yet marked deleted - create tombstone
                    let tombstone = SyncableTask.tombstone(id: id, version: existing.version + 1)
                    let tombstoneData = try encoder.encode(tombstone)
                    try tombstoneData.write(to: file)
                }
                // else: already a tombstone, leave it
            }
        }
    }

    lastSyncTime = Date()
}
```

### Step 6: Tombstone Cleanup

```swift
func purgeOldTombstones() {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago

    for url in [tasksURL, notesURL] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { continue }

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file) else { continue }

            // Try to decode as task or note
            if let task = try? decoder.decode(SyncableTask.self, from: data),
               task.isDeleted,
               let deletedAt = task.deletedAt,
               deletedAt < cutoff {
                try? FileManager.default.removeItem(at: file)
            } else if let note = try? decoder.decode(SyncableNote.self, from: data),
                      note.isDeleted,
                      let deletedAt = note.deletedAt,
                      deletedAt < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
```

---

## Simplified Sync Flow

### On App Launch
```
1. purgeOldTombstones()     // Clean up tombstones > 7 days
2. pullTasks()              // Get remote changes
3. pullNotes()
4. pushTasks()              // Send local changes
5. pushNotes()
```

### On Local Change (create/edit)
```
1. SwiftData auto-saves to local DB
2. Timer fires (every 10-15 seconds)
3. pushTasks() / pushNotes()
```

### On Local Delete
```
1. Remove from local SwiftData DB
2. On next push, remote file becomes tombstone
```

### Remove These (No Longer Needed)
- Hash-based change detection
- `detectLocalAhead()` / `detectRemoteBehind()`
- Complex status state machine
- File modification date checking

### Simplified Status
```swift
enum SyncStatus {
    case idle           // Not syncing
    case syncing        // Currently pushing/pulling
    case error(String)  // Something went wrong
}
```

---

## Migration: Handle Old Format Files

When reading files, check if it's old format (no `version` field):

```swift
func readTaskFile(_ file: URL) -> SyncableTask? {
    guard let data = try? Data(contentsOf: file) else { return nil }

    // Try new format first
    if let task = try? decoder.decode(SyncableTask.self, from: data) {
        return task
    }

    // Fallback: old format - migrate it
    if let oldTask = try? decoder.decode(OldSyncableTask.self, from: data) {
        return SyncableTask(
            id: oldTask.id,
            version: 1,  // Start at version 1
            isDeleted: false,
            deletedAt: nil,
            data: TaskData(from: oldTask)
        )
    }

    return nil
}
```

---

## Testing Checklist

After implementation, test these scenarios:

### Basic Sync
- [ ] Create task on Mac A → Push → Pull on Mac B → Task appears
- [ ] Edit task on Mac A → Push → Pull on Mac B → Edit appears
- [ ] Create note on Mac A → Push → Pull on Mac B → Note appears

### Delete Sync (THE MAIN FIX)
- [ ] Delete task on Mac A → Push → Pull on Mac B → Task disappears
- [ ] Delete note on Mac A → Push → Pull on Mac B → Note disappears
- [ ] Verify tombstone file exists in sync folder (isDeleted: true)

### Version Handling
- [ ] Edit same task on Mac A twice → Version increments each time
- [ ] Mac B pulls → Gets latest version, not intermediate

### Tombstone Cleanup
- [ ] Create task, delete it, wait 7+ days (or mock time)
- [ ] Run purge → File actually removed from sync folder

### Edge Cases
- [ ] Fresh Mac B with empty local DB → Pulls all remote items
- [ ] Mac A offline, makes changes → Comes online → Pushes successfully
- [ ] Deleted items don't reappear after multiple sync cycles

---

## Summary

**What changes:**
1. JSON structure: wrap data in `data` field, add `version`, `isDeleted`, `deletedAt`
2. Models: add `syncVersion` property to TodoTask and Note
3. Delete = write tombstone (don't remove file)
4. Sync compares versions (not timestamps)
5. Cleanup job removes tombstones after 7 days

**What stays same:**
- File-per-item in iCloud Drive
- Same sync folder location
- Push/Pull button UI
- Auto-sync timer

**Expected result:**
- No more data loss
- Deletes propagate reliably
- Simple, predictable sync behavior

---

## Quick Start for Next Session

```
1. Read this file: docs/SYNC_IMPLEMENTATION_PLAN.md
2. Read current code: TaskFlow/Sync/SyncManager.swift
3. Start with Step 1: Update SyncableTask struct
4. Work through steps 2-6
5. Test using checklist above
```
