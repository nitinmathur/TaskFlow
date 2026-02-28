# TaskFlow Sync Approaches

## Current Problems

1. **Deletes don't propagate** - When Mac A deletes a task, Mac B doesn't know
2. **Data loss** - Race conditions cause items to disappear
3. **No conflict resolution** - Last write wins blindly
4. **File timestamps unreliable** - iCloud doesn't preserve them accurately

## Root Cause

The current approach has no way to distinguish between:
- "This item was deleted" vs "This item doesn't exist yet"
- "This is a newer version" vs "This is an older version"

---

## Approach 1: Manifest + Tombstones

**Concept:** A single `manifest.json` file tracks what exists and what was deleted.

**Files:**
```
sync/
  manifest.json      # Source of truth for what exists
  tasks/
    {uuid}.json      # Individual task data
  notes/
    {uuid}.json      # Individual note data
```

**manifest.json structure:**
```json
{
  "version": 42,
  "lastModified": "2024-03-01T10:30:00Z",
  "lastModifiedBy": "device-uuid-abc",
  "items": {
    "task-uuid-1": { "type": "task", "modifiedAt": "...", "hash": "abc123" },
    "task-uuid-2": { "type": "task", "modifiedAt": "...", "hash": "def456" },
    "note-uuid-1": { "type": "note", "modifiedAt": "...", "hash": "ghi789" }
  },
  "tombstones": {
    "task-uuid-3": { "deletedAt": "2024-03-01T09:00:00Z", "deletedBy": "device-xyz" }
  }
}
```

**Sync Algorithm:**
1. Read remote manifest
2. Compare with local state:
   - Remote has item, local doesn't → **Pull it** (unless in local tombstones)
   - Local has item, remote doesn't → **Check remote tombstones**
     - In tombstones → Delete locally
     - Not in tombstones → Push it
   - Both have item → Compare `modifiedAt`, keep newer
3. Merge tombstones (keep deletions for 7 days, then purge)
4. Write updated manifest + push changed files

**Pros:**
- Explicit delete tracking
- Single source of truth
- Content hashes detect changes reliably

**Cons:**
- Manifest file itself can conflict (mitigate: version number + merge logic)
- Requires atomic read-modify-write of manifest

**Conflict Resolution:** If manifest versions diverge, merge them by comparing timestamps per-item.

---

## Approach 2: Operation Log (Event Sourcing)

**Concept:** Don't sync state, sync operations. Each change is an immutable event.

**Files:**
```
sync/
  ops/
    2024-03-01T10-30-00-device-abc.json  # Operation batch
    2024-03-01T10-31-00-device-xyz.json  # Another batch
  snapshot.json                           # Periodic state snapshot for fast load
```

**Operation structure:**
```json
{
  "deviceId": "device-abc",
  "timestamp": "2024-03-01T10:30:00.123Z",
  "operations": [
    { "op": "create", "type": "task", "id": "uuid-1", "data": {...} },
    { "op": "update", "type": "task", "id": "uuid-2", "data": {...} },
    { "op": "delete", "type": "task", "id": "uuid-3" }
  ]
}
```

**Sync Algorithm:**
1. List all operation files
2. Find ops newer than last processed timestamp
3. Replay all operations in timestamp order:
   - `create` → Insert if not exists
   - `update` → Update if exists (compare timestamps for conflicts)
   - `delete` → Remove item
4. Write local changes as new operation file
5. Periodically create snapshot for fast startup

**Pros:**
- **No data loss** - operations are append-only, never deleted
- Full history - can implement undo/redo
- Deletes are explicit operations
- Natural conflict handling - just replay in order

**Cons:**
- Storage grows forever (need periodic compaction)
- Rebuilding state from scratch is slow (mitigate with snapshots)
- Clock skew between devices affects ordering

**Conflict Resolution:** Operations are ordered by timestamp. If two devices edit same item at same time, later timestamp wins. Can add Lamport clocks for better ordering.

---

## Approach 3: Version Vectors + Soft Deletes

**Concept:** Each item has a version number. Deleted items are kept as "tombstones" for 7 days.

**Files:**
```
sync/
  tasks/
    {uuid}.json      # Each file has version info embedded
  notes/
    {uuid}.json
```

**Item structure:**
```json
{
  "id": "uuid-1",
  "version": 5,
  "modifiedAt": "2024-03-01T10:30:00Z",
  "modifiedBy": "device-abc",
  "isDeleted": false,
  "deletedAt": null,
  "data": {
    "title": "My Task",
    "column": "work",
    ...
  }
}
```

**Sync Algorithm:**
1. Scan all remote files
2. For each remote item:
   - Not in local → Create (unless `isDeleted`)
   - In local → Compare versions:
     - Remote version higher → Use remote
     - Local version higher → Keep local, push later
     - Same version, different data → Compare `modifiedAt`, keep newer, increment version
3. For each local item not in remote:
   - If local `modifiedAt` > last sync time → Push it (it's new)
   - If local `modifiedAt` < last sync time → Deleted remotely, mark local as deleted
4. Push all local items with changes
5. Purge items where `isDeleted=true` and `deletedAt` > 7 days ago

**Pros:**
- Simple mental model
- Version numbers prevent lost updates
- Soft deletes give 7-day recovery window
- Each item is self-contained (no central manifest)

**Cons:**
- Version conflicts possible (mitigate with device ID in version)
- More files to sync
- Need to handle "deleted remotely but modified locally" case

**Conflict Resolution:** Higher version wins. If same version, later `modifiedAt` wins. If conflict detected, can prompt user.

---

## Recommendation

**For TaskFlow, I recommend Approach 3 (Version Vectors + Soft Deletes)** because:

1. **Simplest to implement** - builds on current file-per-item approach
2. **No central manifest** - avoids manifest conflicts
3. **Soft deletes prevent data loss** - 7-day recovery window
4. **Self-healing** - each item carries its own history

**Implementation changes needed:**
1. Add `version`, `modifiedBy`, `isDeleted`, `deletedAt` to SyncableTask/SyncableNote
2. Generate unique device ID on first launch (store in UserDefaults)
3. On delete: set `isDeleted=true` instead of removing file
4. On sync: compare versions, not file timestamps
5. Background job to purge old tombstones

**Estimated effort:** ~2-3 hours to implement

---

## Quick Comparison

| Aspect | Manifest | Event Sourcing | Version Vectors |
|--------|----------|----------------|-----------------|
| Complexity | Medium | High | Low |
| Delete handling | Explicit | Explicit | Soft delete |
| Conflict resolution | Per-item timestamps | Replay order | Version comparison |
| Storage overhead | Low | High (grows) | Medium |
| Recovery from errors | Good | Excellent | Good |
| Implementation effort | Medium | High | Low |

---

Let me know which approach you'd like to implement tomorrow!
