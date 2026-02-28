# Auto-Sync + Notes Folders Design

**Date:** 2026-02-28
**Status:** Approved

## Overview

Two features to improve TaskFlow:
1. **Auto-sync** - Replace manual Push/Pull with automatic background sync
2. **Notes folders** - Organize notes into custom folders (flat structure)

## Feature 1: Auto-Sync

### Goals
- Eliminate manual Push/Pull buttons
- Sync happens automatically in background
- Clear visual feedback on sync status
- No simultaneous edit conflicts (single-user, two Macs)

### State Machine

```
Synced (green "Synced")
  → detects local changes → LocalAhead (yellow "Syncing...")
  → after 1 min idle → Pushing
  → success → Synced

Synced (green "Synced")
  → detects remote changes → RemoteAhead (blue "Updates available - pulling in Xs")
  → after 10 sec countdown → Pulling
  → success → Synced
```

### Timer Logic

- Single Timer fires every 15 seconds
- Compares local SwiftData modification times vs shared JSON file timestamps
- Detects three states:
  - **Ahead**: local has changes not in shared files
  - **Behind**: shared files have changes not in local
  - **Synced**: both match

### Push Logic (Local Ahead)

1. User makes changes → state becomes LocalAhead
2. Track "last local change" timestamp
3. Wait 60 seconds after last change (debounce)
4. Push all tasks/notes to shared JSON files
5. State → Synced

### Pull Logic (Remote Behind)

1. Timer detects remote files changed → RemoteAhead
2. Show countdown: "Updates available - pulling in 10s"
3. After 10 seconds, auto-pull
4. Merge remote JSON → local SwiftData
5. State → Synced

### UI Changes

**Remove:**
- Push/Pull buttons

**Keep:**
- Status badge (top-right of MainTabView)

**New status displays:**
- 🟢 "Synced" - everything in sync
- 🟡 "Syncing..." - pushing or pulling in progress
- 🔵 "Updates available - pulling in 5s" - countdown before auto-pull

### Conflict Avoidance

**Assumption:** User does not edit on both Macs simultaneously (same Apple ID, single user).

**Protection:**
- Push only happens if local is ahead (not behind)
- If behind, must pull first
- Timer detects state every 15 seconds, catches conflicts early

## Feature 2: Notes Folders

### Goals
- Organize notes into custom folders
- Flat structure (no nesting)
- Default "All Notes" folder for uncategorized notes

### Data Model

**Note model change:**
```swift
@Model
final class Note {
    // ... existing fields
    var folderName: String = "All Notes"  // NEW
}
```

**No separate Folder model** - folders are just unique strings extracted from notes.

### Folder Behavior

**Default folder:**
- "All Notes" - all new notes start here
- Always visible in sidebar (even if empty)

**Custom folders:**
- User creates via "+ New Folder" button
- Prompts for folder name
- Folders appear when they contain notes

**Folder operations:**
- **Create**: "+ New Folder" button → prompt for name
- **Rename**: Right-click folder → Rename
- **Delete**: Right-click folder → Delete
  - Only allowed if folder is empty
  - Show alert if folder has notes: "Move or delete notes first"
- **Move note**: Drag note to folder in sidebar

### Sidebar Structure

```
Notes (Title)
  [+ New Note]
  Sort: [Manual ▼]
  ─────────────────
  📂 All Notes (3)
  📂 Learning (5)
  📂 Work (2)
  ─────────────────
  [+ New Folder]
```

**Folder list logic:**
- Extract unique folder names: `Set(notes.map(\.folderName))`
- Always show "All Notes" first
- Sort custom folders alphabetically
- Show note count per folder

**Folder selection:**
- Click folder → filters notes to that folder
- Maintains existing sort options (Manual, Updated, Created, Title)
- Manual reordering is per-folder

### Sync Integration

**JSON format:**
```json
{
  "id": "uuid",
  "title": "My Note",
  "body": "...",
  "folderName": "Learning",
  "position": 0,
  ...
}
```

No schema changes needed - folderName is just another field.

## Implementation Notes

### Auto-Sync Changes
- Modify `SyncManager` to add timer and state machine
- Remove Push/Pull buttons from `SyncToolbarView`
- Update status badge to show countdown
- Add 1-minute debounce tracking

### Folders Changes
- Add `folderName` field to `Note` model
- Update `NotesSplitView` to show folder list in sidebar
- Add folder management UI (create, rename, delete)
- Add drag-to-folder support
- Update sync to include folderName in JSON

## Success Criteria

### Auto-Sync
- ✅ Timer runs every 15 seconds
- ✅ Local changes auto-push after 1 minute idle
- ✅ Remote changes auto-pull after 10 second countdown
- ✅ Status badge shows clear sync state
- ✅ No more manual Push/Pull buttons

### Folders
- ✅ Notes can be moved to custom folders
- ✅ "All Notes" default folder always visible
- ✅ Can create, rename folders
- ✅ Can't delete folders with notes
- ✅ Folders sync across Macs
- ✅ Note counts show per folder
