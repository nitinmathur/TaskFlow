# TaskFlow Sync Approaches

## Assumptions

- **No simultaneous writes** - User only edits on one Mac at a time
- **Sequential workflow** - Edit on Mac A → sync → edit on Mac B → sync
- This greatly simplifies sync - no conflict resolution needed!

## Current Problems

1. **Deletes don't propagate** - When Mac A deletes a task, Mac B doesn't know
2. **Can't distinguish** "item was deleted" vs "item doesn't exist yet"
3. **File timestamps unreliable** - iCloud doesn't preserve them accurately

---

## Approach 1: Manifest + Tombstones

**Concept:** A single `manifest.json` tracks what exists and what was deleted.

### Files Structure
```
sync/
  manifest.json      # Source of truth
  tasks/
    {uuid}.json
  notes/
    {uuid}.json
```

### manifest.json
```json
{
  "lastSync": "2024-03-01T10:30:00Z",
  "items": {
    "task-uuid-1": { "hash": "abc123" },
    "task-uuid-2": { "hash": "def456" }
  },
  "deleted": {
    "task-uuid-3": "2024-03-01T09:00:00Z"
  }
}
```

### Example: Delete Propagation

**Scenario:** You delete "Buy groceries" task on Mac A. Mac B should remove it too.

```
BEFORE (both Macs):
  manifest.json: { items: { "task-1": {...} } }
  tasks/task-1.json: { title: "Buy groceries" }

MAC A: User deletes task
  1. Remove tasks/task-1.json
  2. Update manifest.json:
     {
       items: {},
       deleted: { "task-1": "2024-03-01T10:00:00Z" }
     }
  3. iCloud syncs files to cloud

MAC B: App opens, pulls changes
  1. Read manifest.json - sees task-1 in "deleted"
  2. Local has task-1 → DELETE IT
  3. Result: Task gone on Mac B too ✓
```

### Example: New Item Sync

**Scenario:** You create "Call mom" task on Mac A. Mac B should get it.

```
MAC A: User creates task
  1. Create tasks/task-2.json: { title: "Call mom" }
  2. Update manifest.json:
     { items: { "task-2": { hash: "xyz" } } }
  3. iCloud syncs

MAC B: App opens
  1. Read manifest.json - sees task-2 in items
  2. Local doesn't have task-2 → PULL IT
  3. Check: task-2 not in local "deleted" list
  4. Create local task from tasks/task-2.json ✓
```

### Pros/Cons
- ✅ Explicit delete tracking
- ✅ Single source of truth
- ❌ Manifest file can get out of sync with actual files

---

## Approach 2: Operation Log (Event Sourcing)

**Concept:** Record every action as an event. Replay events to build state.

### Files Structure
```
sync/
  ops/
    001-2024-03-01T10-30-00.json
    002-2024-03-01T10-35-00.json
```

### Operation File
```json
{
  "timestamp": "2024-03-01T10:30:00Z",
  "ops": [
    { "action": "create", "type": "task", "id": "task-1", "data": {"title": "Buy groceries"} },
    { "action": "update", "type": "task", "id": "task-2", "data": {"title": "Call mom (updated)"} },
    { "action": "delete", "type": "task", "id": "task-3" }
  ]
}
```

### Example: Delete Propagation

**Scenario:** You delete "Buy groceries" task on Mac A.

```
MAC A: User deletes task
  1. Create new op file: 005-2024-03-01T14-00-00.json
     { ops: [{ action: "delete", type: "task", id: "task-1" }] }
  2. iCloud syncs op file

MAC B: App opens
  1. List all op files, find new one (005-...)
  2. Read op: delete task-1
  3. Execute: DELETE task-1 from local DB ✓
```

### Example: Full Replay

**Scenario:** Mac B is brand new, needs all data.

```
Op files in cloud:
  001: [create task-1 "Buy groceries"]
  002: [create task-2 "Call mom"]
  003: [update task-1 "Buy groceries today"]
  004: [create note-1 "Shopping list"]
  005: [delete task-1]

MAC B: Fresh start, replay all
  001 → Create task-1
  002 → Create task-2
  003 → Update task-1
  004 → Create note-1
  005 → Delete task-1

Final state: task-2, note-1 (task-1 was created then deleted) ✓
```

### Pros/Cons
- ✅ Complete history - can undo anything
- ✅ Delete is explicit action
- ✅ Never lose data - ops are append-only
- ❌ Storage grows forever
- ❌ Slow startup (must replay all ops)

---

## Approach 3: Version Vectors + Soft Deletes ⭐ RECOMMENDED

**Concept:** Each item has version number. "Delete" = mark as deleted, keep file for 7 days.

### Files Structure
```
sync/
  tasks/
    task-1.json
    task-2.json
    task-3.json  ← deleted but kept as tombstone
  notes/
    note-1.json
```

### Item Structure
```json
{
  "id": "task-1",
  "version": 3,
  "isDeleted": false,
  "deletedAt": null,
  "data": {
    "title": "Buy groceries",
    "column": "work",
    "priority": 1
  }
}
```

### Deleted Item (Tombstone)
```json
{
  "id": "task-3",
  "version": 5,
  "isDeleted": true,
  "deletedAt": "2024-03-01T10:00:00Z",
  "data": null
}
```

### Example: Delete Propagation

**Scenario:** You delete "Buy groceries" task on Mac A.

```
BEFORE:
  tasks/task-1.json: { id: "task-1", version: 3, isDeleted: false, data: {...} }

MAC A: User deletes task
  1. DON'T delete the file!
  2. Update tasks/task-1.json:
     { id: "task-1", version: 4, isDeleted: true, deletedAt: "2024-03-01T10:00:00Z", data: null }
  3. iCloud syncs the updated file

MAC B: App opens, scans files
  1. Read tasks/task-1.json
  2. See isDeleted: true
  3. If local has task-1 → DELETE from local DB
  4. Don't show deleted items in UI ✓
```

### Example: New Item Sync

**Scenario:** Create "Call mom" on Mac A, sync to Mac B.

```
MAC A: User creates task
  1. Create tasks/task-2.json:
     { id: "task-2", version: 1, isDeleted: false, data: { title: "Call mom" } }
  2. iCloud syncs

MAC B: App opens
  1. Scan sync/tasks/ folder
  2. Find task-2.json (new file)
  3. isDeleted: false → CREATE in local DB ✓
```

### Example: Edit Sync

**Scenario:** Edit task title on Mac A, sync to Mac B.

```
BEFORE:
  tasks/task-1.json: { version: 2, data: { title: "Buy groceries" } }

MAC A: User edits title
  1. Update tasks/task-1.json:
     { version: 3, data: { title: "Buy groceries TODAY" } }
  2. iCloud syncs

MAC B: App opens
  1. Read task-1.json → version 3
  2. Local task-1 has version 2
  3. Remote version higher → UPDATE local with remote data ✓
```

### Example: Accidental Recovery

**Scenario:** You accidentally delete a task on Mac A, realize mistake within 7 days.

```
Day 1: Delete task on Mac A
  tasks/task-1.json: { isDeleted: true, deletedAt: "2024-03-01" }

Day 3: "Oh no, I need that task!"
  Option A: Manually edit JSON file, set isDeleted: false
  Option B: App could have "Recently Deleted" view (like Photos app)

Day 8: Cleanup job runs
  deletedAt is > 7 days ago → Actually delete file
```

### Sync Algorithm (Simple Version)

```
ON APP LAUNCH:
  1. Scan all files in sync/tasks/ and sync/notes/

  2. For each remote file:
     - If isDeleted AND local has it → Delete local
     - If isDeleted AND local doesn't have it → Skip
     - If NOT deleted AND local doesn't have it → Create local
     - If NOT deleted AND local has it:
         - Remote version > local version → Update local
         - Remote version <= local version → Keep local (push later)

  3. For each local item not in remote:
     - Create remote file with version: 1

ON LOCAL CHANGE:
  1. Increment version
  2. Write to sync file

ON LOCAL DELETE:
  1. Set isDeleted: true, deletedAt: now
  2. Increment version
  3. Write to sync file (don't delete file!)
```

### Pros/Cons
- ✅ Simple - builds on current approach
- ✅ Soft deletes = 7-day safety net
- ✅ No central manifest to conflict
- ✅ Each file is self-contained
- ❌ Deleted files take space for 7 days (minimal)

---

## Recommendation

**Approach 3 (Version Vectors + Soft Deletes)** because:

1. **Simplest change** from current code
2. **No simultaneous writes** means version comparison is trivial
3. **Soft deletes prevent accidents** - 7 day recovery window
4. **Self-healing** - each file carries its own truth

### Implementation Checklist

```
□ Add fields to SyncableTask/SyncableNote:
  - version: Int (start at 1, increment on each save)
  - isDeleted: Bool
  - deletedAt: Date?

□ Change delete behavior:
  - Don't remove file
  - Set isDeleted: true, increment version

□ Change pull logic:
  - Check isDeleted flag
  - Compare versions, higher wins

□ Add cleanup job:
  - On app launch, remove files where deletedAt > 7 days ago
```

---

## Questions for Tomorrow

1. Do you want a "Recently Deleted" UI to recover items? Or just manual JSON editing?
2. Should edits on Mac B while Mac A has unpushed changes show a warning?
3. 7-day tombstone retention - good? Or longer/shorter?

Sleep well! 🌙
