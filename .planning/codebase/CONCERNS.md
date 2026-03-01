# Codebase Concerns

**Analysis Date:** 2026-03-01

## Tech Debt

**SwiftData Auto-save Gaps:**
- Issue: Push/pull operations modify task/note objects directly via `remote.apply(to: task)` but changes aren't explicitly saved to the database
- Files: `TaskFlow/Sync/SyncManager.swift` (lines 608-609, 670-671, 773)
- Impact: Sync pulls may not persist properly if app crashes immediately after sync completes
- Fix approach: Call `try? context.save()` after pull operations complete to guarantee persistence

**Checklist Serialization Fragility:**
- Issue: Checklist items stored as JSON-encoded Data in `checklistData`, decoded fresh on every access via computed property
- Files: `TaskFlow/Models/TodoTask.swift` (lines 51-59)
- Impact: High GC pressure on large checklists, potential data loss if JSONEncoder/Decoder fails silently
- Fix approach: Cache decoded checklist in memory or use SwiftData relationships instead of JSON encoding

**Expensive Hash Computation for Sync Detection:**
- Issue: `dataHash` computed property iterates ALL tasks/notes/columns every 5 seconds regardless of actual changes
- Files: `TaskFlow/Views/MainTabView.swift` (lines 68-99)
- Impact: Memory and CPU spikes even when idle, scales poorly with data volume (O(n) operation every poll cycle)
- Fix approach: Replace with dirty flag tracking on individual model changes instead of full data rehashing

**Manual Error Handling with Silent Failures:**
- Issue: All sync operations catch errors with `catch { print(...) }` and continue without user notification
- Files: `TaskFlow/Views/MainTabView.swift` (lines 102-118), `TaskFlow/Sync/ColumnMigration.swift` (multiple)
- Impact: Users unaware of failed pushes/pulls, data loss perception
- Fix approach: Propagate critical errors to UI (error state in SyncManager), distinguish recoverable vs fatal

## Known Bugs

**Array Index Crashes on Empty Collections:**
- Symptoms: App crashes if no columns exist or FileManager returns empty array
- Files:
  - `TaskFlow/TaskFlowApp.swift` (line 17): `urls(...)[0]` - crashes if DocumentDirectory not found
  - `TaskFlow/Sync/SyncManager.swift` (line 291): Same pattern
  - `TaskFlow/Views/Kanban/KanbanBoardView.swift` (line 126): `columns.first` used but no fallback if ALL columns empty after deletion
- Trigger: Delete all custom columns, then force sync/restart
- Workaround: None - app will crash
- Fix: Use `.first` with guard/default instead of direct indexing

**File Path Race Condition in SyncManager:**
- Symptoms: Duplicate or corrupted sync files if local change detected while push in progress
- Files: `TaskFlow/Sync/SyncManager.swift` (lines 479-522)
- Cause: `isPushing` flag set but `lastLocalChange` can be set while push is running, causing double-write
- Fix approach: Lock changes during push, or queue changes for next cycle

**Column ID Migration Silently Fails for Unknown Columns:**
- Symptoms: Tasks with unrecognized columnRaw values default to "Work" without warning
- Files: `TaskFlow/Sync/ColumnMigration.swift` (lines 104-110)
- Impact: Data loss of task column assignments if column names change
- Fix: Preserve unknown column values instead of dropping

## Security Considerations

**iCloud Path Hardcoded:**
- Risk: App assumes specific iCloud structure; if Apple changes path, sync breaks silently
- Files: `TaskFlow/Sync/SyncManager.swift` (line 286)
- Current mitigation: Fallback to Documents folder
- Recommendations: Log actual path used, validate folder exists on startup

**No Encryption Between Devices:**
- Risk: Sync files stored in iCloud Drive as plain JSON; metadata visible to Apple
- Impact: Task contents, notes, folder names unencrypted
- Current mitigation: None - relies on iCloud's transport encryption
- Recommendations: Document this limitation in README, optionally add field-level encryption for notes

**Unchecked UUID Parsing:**
- Risk: File names parsed as UUIDs without validation before decode
- Files: `TaskFlow/Sync/SyncManager.swift` (lines 502, 547, 719)
- Impact: Malformed filename crashes app
- Fix: Add try/catch around UUID parsing

## Performance Bottlenecks

**File-Based Sync Doesn't Scale:**
- Problem: Every remote check loads ALL files from disk into memory (5-second poll cycle)
- Files: `TaskFlow/Sync/SyncManager.swift` (lines 452-475, 318-348)
- Cause: No indexing or change tracking - linear scan of directory
- Current capacity: Works fine for <1000 tasks. Beyond that, sync becomes slow.
- Limit: ~5000 items before noticeable lag (each poll touches entire dataset)
- Scaling path: Implement change log file or watch only modification times, not file contents

**Regex Compilation on Every Render:**
- Problem: Markdown patterns compile regex fresh on every text edit keystroke
- Files: `TaskFlow/Views/Notes/MarkdownTextStorage.swift` (lines 223, 245)
- Cause: NSRegularExpression(pattern:) called in processEditing() → every keystroke
- Current capacity: Smooth for <10KB documents
- Limit: ~100KB document becomes sluggish
- Improvement path: Cache compiled regex patterns at class level

**Full-Text Reprocessing on Any Change:**
- Problem: `applyMarkdownStyling()` called after every single character edit, recalculates all styling
- Files: `TaskFlow/Views/Notes/MarkdownTextStorage.swift` (lines 58-81)
- Cause: No delta processing, always full document
- Impact: Large notes become laggy during rapid typing
- Fix: Only re-style affected line ranges, not entire document

**Drag-Drop Card Reordering Has O(n²) Complexity:**
- Problem: Moving card fetches all tasks, then sorts entire column
- Files: `TaskFlow/Views/Kanban/KanbanColumnView.swift` (line 130-132)
- Impact: Janky animations with 100+ cards
- Fix: Use insertion point tracking instead of full sort

## Fragile Areas

**Column Model During Transition:**
- Files: `TaskFlow/Models/Column.swift`, `TaskFlow/Models/BoardColumn.swift`, migration code
- Why fragile: Legacy enum `Column` still used in `TodoTask.columnRaw`, but UI also expects `BoardColumn.id`. Mismatch possible during migration.
- Safe modification: Never rely on columnRaw value after first sync - always use columnId instead. Test migration with existing data.
- Test coverage: No unit tests for ColumnMigration edge cases (empty columns, duplicate names)

**Sync Version Tracking Conflict Resolution:**
- Files: `TaskFlow/Sync/SyncManager.swift` (lines 605-612, 668-674)
- Why fragile: Simple version > version wins, but doesn't handle simultaneous edits on different fields
- Example: User A changes title (v2), User B changes due date (v2) - one change always lost
- Safe modification: Document that last-write-wins only, don't assume complex merging
- Actual fix needed: Implement per-field versioning or last-modified-at timestamps

**TextViewCoordinator Memory Leak:**
- Files: `TaskFlow/Views/Notes/MarkdownComponents.swift` (line 8)
- Why fragile: `weak var textView` could become nil mid-operation, causing silent formatting failures
- Safe modification: Always check textView != nil at operation start
- Test coverage: No testing of formatter when textView is deallocated

**Folder Storage in UserDefaults:**
- Files: `TaskFlow/Views/Notes/NotesSplitView.swift` (line 18)
- Why fragile: Custom folders stored as JSON-encoded Set in UserDefaults, prone to corruption if Set serialization fails
- Safe modification: Add error handling for decode failures, validate folder names
- Better approach: Store in SwiftData as Folder entities with relationships

## Scaling Limits

**iCloud Sync Doesn't Handle Large Datasets:**
- Current capacity: Works smoothly with <5000 items
- Limit: 10k+ items causes polling lag (5-sec scan of 10k files)
- Scaling path: Implement batch processing, change log, or migrate to CloudKit

**Markdown Rendering Performance:**
- Current capacity: Smooth editing with <50KB notes
- Limit: 500KB+ notes become slow during typing
- Scaling path: Use NSAttributedString caching, incremental rendering

**Memory Growth with Archive:**
- Problem: Archived tasks never cleaned up, just marked `isArchived = true`
- Files: `TaskFlow/Views/Kanban/ArchiveView.swift`, sync system
- Limit: Archive with 10k+ items causes noticeable slowdown
- Scaling path: Implement periodic pruning of items archived >90 days

## Dependencies at Risk

**No SwiftData Relationship Modeling:**
- Risk: Tasks reference BoardColumn by UUID only, no true relationship defined
- Impact: Orphaned tasks if column deleted improperly, cascading deletes not automatic
- Migration plan: Convert to @Relationship(deleteRule: .cascade) on TodoTask.columnId
- Urgency: High - data integrity issue

**Apple's iCloud Drive Sync Unreliable:**
- Risk: FileSystemObject watcher documented as unreliable; comment in code admits this
- Files: `TaskFlow/Sync/SyncManager.swift` (line 356)
- Impact: Current workaround is 5-sec poll, but actual changes may be missed
- Migration plan: Consider migration to CloudKit for reliable sync

## Missing Critical Features

**No Conflict Resolution UI:**
- Problem: Comment in code says "conflict detected" but app does nothing
- Files: `TaskFlow/Views/MainTabView.swift` (line 61-62)
- Blocks: Multi-device editing scenarios
- Fix: Implement conflict UI showing both versions, let user choose

**No Data Validation on Decode:**
- Problem: Invalid task/note JSON from sync silently skipped with `continue`
- Files: `TaskFlow/Sync/SyncManager.swift` (lines 594-595, 656-657)
- Blocks: Detection of sync file corruption
- Fix: Log and count decode failures, alert user if > threshold

**No Sync Status Indicator in Notes Tab:**
- Problem: SyncToolbarView only shown in MainTabView, but sync happens in background
- Impact: Notes tab syncs without user awareness of progress
- Fix: Show mini status indicator in Notes view too

## Test Coverage Gaps

**No Tests for Sync Conflict Scenarios:**
- What's not tested: Push while remote changed, pull while local changed simultaneously
- Files: `TaskFlow/Sync/SyncManager.swift` (lines 571-631, 633-694)
- Risk: Race conditions undetected
- Priority: High

**No Tests for Column Migration Edge Cases:**
- What's not tested: Migrate with 0 columns, duplicate column names, missing Work column
- Files: `TaskFlow/Sync/ColumnMigration.swift`
- Risk: Silent failures during first launch on certain configs
- Priority: High

**No Tests for Large Dataset Performance:**
- What's not tested: Sync with 1000+ items, rendering 500KB+ notes
- Files: `TaskFlow/Sync/SyncManager.swift`, `TaskFlow/Views/Notes/MarkdownTextStorage.swift`
- Risk: Performance degradation undetected
- Priority: Medium

**No Tests for Markdown Rendering Correctness:**
- What's not tested: Nested formatting, malformed markdown, special characters
- Files: `TaskFlow/Views/Notes/MarkdownRenderer.swift`, `TaskFlow/Views/Notes/MarkdownTextStorage.swift`
- Risk: Rendering bugs visible only with certain inputs
- Priority: Medium

**No Tests for Model Persistence:**
- What's not tested: Checklist serialization/deserialization, task→sync→task round-trip
- Files: `TaskFlow/Models/TodoTask.swift`, `TaskFlow/Sync/SyncManager.swift`
- Risk: Data corruption undetected
- Priority: High

---

*Concerns audit: 2026-03-01*
