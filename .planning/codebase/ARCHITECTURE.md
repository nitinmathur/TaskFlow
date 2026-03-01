# Architecture

**Analysis Date:** 2026-03-01

## Pattern Overview

**Overall:** Model-View with State Management and File-Based Sync

**Key Characteristics:**
- **Declarative UI:** SwiftUI with reactive data bindings via `@Query` and `@State`
- **Persistent Data:** SwiftData models stored locally with iCloud Drive or document folder fallback
- **Decentralized Sync:** File-based version-vector sync between local database and iCloud Drive JSON files
- **Tab-based Architecture:** Two primary features (Tasks/Kanban and Notes) through tabbed interface
- **Deferred Sync Operations:** Status-driven sync flow where MainTabView orchestrates pull/push operations

## Layers

**Presentation Layer (Views):**
- Purpose: Display data and handle user interactions
- Location: `TaskFlow/Views/`
- Contains: SwiftUI components for Kanban board, notes editor, sync toolbar
- Depends on: SwiftData models, SyncManager
- Used by: App entry point via MainTabView

**Model Layer:**
- Purpose: Define data structures and persistence models
- Location: `TaskFlow/Models/`
- Contains: SwiftData models (`TodoTask`, `Note`, `BoardColumn`), enums (`Priority`, `Column`), value types (`ChecklistItem`)
- Depends on: Foundation, SwiftData
- Used by: Views, SyncManager, ColumnMigration

**Sync Layer:**
- Purpose: Coordinate bidirectional sync between local database and shared file storage
- Location: `TaskFlow/Sync/`
- Contains: `SyncManager` (orchestrator), `ColumnMigration` (data migration)
- Depends on: Foundation, Combine, SwiftData models
- Used by: MainTabView

**Application Layer:**
- Purpose: Configure app lifecycle and initialize persistence
- Location: `TaskFlow/TaskFlowApp.swift`
- Contains: ModelContainer setup, iCloud Drive or fallback document folder configuration
- Depends on: SwiftUI, SwiftData
- Used by: System entry point

## Data Flow

**Local Data Creation/Modification:**

1. User interacts with view (e.g., creates task, edits note)
2. SwiftUI binding updates SwiftData model in-memory
3. SwiftData persists change to local store (Tasks/Notes tables)
4. MainTabView detects change via data hash in `onChange` modifier
5. SyncManager marked as `.localChanges`
6. Debounce timer expires (3 seconds), status changes to `.syncing`
7. MainTabView calls `pushTasks()`, `pushNotes()`, `pushColumns()` on SyncManager

**Remote File Detection:**

1. FileWatcher monitors iCloud Drive sync folder
2. When files appear/update, `checkForRemoteChanges()` counts new JSON files
3. If changes detected and status is `.inSync`, set to `.remoteChanges` with countdown
4. After 2-second pull delay, status changes to `.syncing`
5. MainTabView calls `pullTasks()`, `pullNotes()`, `pullColumns()` on SyncManager

**Push Operation (Local → Shared):**

1. For each local item, increment `syncVersion` and write JSON to shared folder
2. For remote files not in local set, read existing version and create tombstone
3. Clear `lastLocalChange` to stop pushing
4. Set status to `.inSync`

**Pull Operation (Shared → Local):**

1. For each JSON file in shared folder:
   - If marked deleted and local exists, delete local
   - If both exist, compare versions: higher remote version updates local
   - If only remote exists, create new local item with remote version
2. New format tries first, legacy format attempts conversion if needed
3. Clear `pendingRemoteChanges`, set status to `.inSync`

**State Management:**

- **SyncStatus enum:** `inSync`, `localChanges`, `remoteChanges`, `conflict`, `syncing`
- **Tracking:** Data hash computed from tasks, notes, columns on each update
- **Debouncing:** 3-second push delay after changes stop, 2-second pull delay for remote detection
- **Version Vectors:** Each entity tracked with `syncVersion` Int; higher version wins during merge
- **Tombstones:** Deleted items marked with `isDeleted=true`, `deletedAt` timestamp; cleaned up after 7 days

## Key Abstractions

**SyncableTask/SyncableNote/SyncableBoardColumn:**
- Purpose: JSON-serializable versions of models with metadata (version, deletion flags)
- Examples: `SyncManager.swift` lines 17-193
- Pattern: Wrapper struct that separates persistence serialization from business model

**Sync Envelope Pattern:**
- Purpose: Each syncable item wraps data + metadata (version, deleted, deletedAt)
- Structure: `{ id, version, isDeleted, deletedAt, data: {...} }`
- Enables: Version conflict resolution, tombstone tracking, legacy format support

**Column ID Migration:**
- Purpose: Migrate from hardcoded enum-based columns to dynamic BoardColumn models
- Examples: `ColumnMigration.swift` (lines 7-116), `TodoTask.swift` (columnId vs columnRaw)
- Pattern: Lazy initialization on first launch, deterministic UUID generation for sync consistency

**Priority and Column Enums:**
- Purpose: Strongly-typed options with computed properties
- Examples: `Priority` enum with label property, `Column` enum with icon/title
- Pattern: Enums used for validation and UI presentation

## Entry Points

**App Launch:**
- Location: `TaskFlowApp.swift`
- Triggers: System app launch
- Responsibilities: Initialize ModelContainer with schema, configure iCloud or local store, disable SQLite WAL mode for file sync compatibility, set minimum window size

**Main UI Initialization:**
- Location: `MainTabView.swift`
- Triggers: App body Scene renders
- Responsibilities: Query all data, initialize SyncManager, set up data change detection via hash, manage tab selection, trigger column migration on first appearance

**Sync Loop Trigger:**
- Location: `SyncManager.startAutoSync()` (line 352)
- Triggers: 5-second timer and file watcher events
- Responsibilities: Poll for local/remote changes, manage sync status state machine, debounce operations

## Error Handling

**Strategy:** Silent failures with logging; no user-facing sync error dialogs

**Patterns:**
- FileManager operations wrapped in `try?` with fallback behavior (e.g., fallback from iCloud to Documents)
- JSON decode failures handled with legacy format fallback and format conversion
- ModelContext save errors logged but not propagated; sync continues
- Push/pull operations fail silently; next poll cycle retries

**Examples:**
- iCloud Drive unavailable: `TaskFlowApp.swift` lines 14-17 (fallback to Documents)
- Decode failure: `SyncManager.swift` lines 588-596 (legacy format migration)
- WAL mode pragma fails silently: `TaskFlowApp.swift` lines 46-52

## Cross-Cutting Concerns

**Logging:** Print statements to console; no logging framework integrated
- Sync status changes logged in SyncManager
- Migration events logged in ColumnMigration
- Container errors logged in TaskFlowApp

**Validation:** Field-level constraints in models
- Task title required (default empty string, validated on save)
- Note title/body optional
- Column position unique per context (maintained by views)

**Authentication:** Not applicable; local-only application

**State Persistence:** SwiftData automatic persistence on model mutations; no explicit save calls needed except in ColumnMigration.migrateIfNeeded()

---

*Architecture analysis: 2026-03-01*
