# Codebase Structure

**Analysis Date:** 2026-03-01

## Directory Layout

```
TaskFlow/
├── TaskFlowApp.swift              # App entry point, ModelContainer setup
├── Models/                         # Data models and enums
│   ├── TodoTask.swift             # Task model with priority, checklist, sync metadata
│   ├── Note.swift                 # Note model with folder organization
│   ├── BoardColumn.swift          # Dynamic column model (replaces Column enum)
│   └── Column.swift               # Legacy enum for backward compatibility
├── Views/                          # SwiftUI presentation layer
│   ├── MainTabView.swift          # Root view, tab container, sync orchestration
│   ├── SyncToolbarView.swift      # Sync status indicator and manual sync buttons
│   ├── Kanban/                    # Task board feature
│   │   ├── KanbanBoardView.swift  # Board container, column/task management
│   │   ├── KanbanColumnView.swift # Column display and card container
│   │   ├── KanbanCardView.swift   # Task card display
│   │   ├── CardEditorView.swift   # Task creation/editing form
│   │   ├── CardDetailView.swift   # Full task detail modal
│   │   ├── ColumnHeaderView.swift # Column title and controls
│   │   └── ArchiveView.swift      # Archived tasks view
│   └── Notes/                      # Note-taking feature
│       ├── NotesSplitView.swift   # Notes container with folder list
│       ├── NoteEditorView.swift   # Note editor with markdown support
│       ├── FolderManagerView.swift# Folder management UI
│       ├── MarkdownRenderer.swift # Markdown-to-SwiftUI rendering
│       ├── MarkdownTextStorage.swift # Rich text editor with markdown syntax highlighting
│       └── MarkdownComponents.swift # Reusable markdown UI components
└── Sync/                           # Sync engine
    ├── SyncManager.swift          # Bidirectional file-based sync orchestrator
    └── ColumnMigration.swift      # Schema migration from enum to dynamic columns
```

## Directory Purposes

**TaskFlow/Models/:**
- Purpose: Define persistent data models using SwiftData with sync metadata
- Contains: 4 model files, 2 enums
- Key files:
  - `TodoTask.swift` - 72 lines, core task entity with version tracking
  - `Note.swift` - 25 lines, text note entity
  - `BoardColumn.swift` - 50 lines, dynamic column with deterministic UUID generation

**TaskFlow/Views/:**
- Purpose: SwiftUI components for all user-facing features
- Contains: 15 view files organized by feature (Kanban, Notes)
- Subdirectories: `Kanban/` (6 files), `Notes/` (6 files)

**TaskFlow/Views/Kanban/:**
- Purpose: Kanban board task management interface
- Contains: Board layout, column management, task cards, modals
- Key responsibilities: Drag-and-drop simulation via reorder buttons, column operations (add/delete/move), task filtering/sorting

**TaskFlow/Views/Notes/:**
- Purpose: Notes feature with markdown editing and folder organization
- Contains: Editor, renderer, folder manager, text storage
- Key responsibilities: Rich markdown editing, real-time preview rendering, folder-based note organization

**TaskFlow/Sync/:**
- Purpose: Data synchronization engine
- Contains: 2 files (SyncManager + migration utilities)
- Responsibilities: Push/pull operations, version vector conflict resolution, tombstone lifecycle, automatic polling

## Key File Locations

**Entry Points:**
- `TaskFlow/TaskFlowApp.swift` - App initialization, ModelContainer setup, window configuration
- `TaskFlow/Views/MainTabView.swift` - Root view, data queries, sync state machine

**Configuration:**
- `TaskFlow/TaskFlowApp.swift` - iCloud Drive or fallback folder paths, SQLite WAL mode pragma

**Core Logic:**
- `TaskFlow/Sync/SyncManager.swift` - Version-vector sync, file operations, conflict resolution
- `TaskFlow/Views/Kanban/KanbanBoardView.swift` - Board state, task/column mutations
- `TaskFlow/Views/Notes/NoteEditorView.swift` - Note editing UI, markdown support

**Testing:**
- No test files present; manual testing only

## Naming Conventions

**Files:**
- `View.swift` suffix for SwiftUI components
- Model names match data entity (TodoTask, Note, BoardColumn)
- Enum files named for enum content (Column.swift, Priority enum inside models)

**Directories:**
- Feature-based (Kanban/, Notes/)
- Layer-based (Models/, Views/, Sync/)

**Types:**
- Models: PascalCase (TodoTask, BoardColumn)
- Enums: PascalCase (Priority, Column, AppTab, SortOption, SyncStatus)
- Views: PascalCase with View suffix (KanbanBoardView, NoteEditorView)
- Properties: camelCase (isCompleted, dueDate, syncVersion)

**Functions:**
- camelCase (migrateIfNeeded, checkForRemoteChanges, pushTasks)
- Verb-prefix for actions (push, pull, sync, migrate)

## Where to Add New Code

**New Feature (e.g., Calendar View):**
- Primary code: `TaskFlow/Views/Calendar/CalendarView.swift` (create new directory)
- Models: Use existing TaskFlow/Models/TodoTask.swift (no new model needed if using existing)
- Sync: No changes if syncing same entities; if new entity, add SyncableX and push/pull methods to SyncManager
- Integration: Add tab case to `AppTab` enum in `MainTabView.swift` (line 4)
- Entry: Add TabView section in `MainTabView.swift` (line 34)

**New Model/Entity:**
- Definition: `TaskFlow/Models/NewEntity.swift` using @Model decorator
- Sync wrapper: Add `SyncableNewEntity` struct to `SyncManager.swift` with version/deletion envelope
- Migration: Update `TaskFlowApp.swift` Schema definition to include NewEntity
- Push/Pull methods: Implement `pushNewEntities()` and `pullNewEntities()` in SyncManager following existing patterns

**New Column Feature (Board functionality):**
- Implementation: `TaskFlow/Views/Kanban/NewColumnFeature.swift`
- Reuse: KanbanBoardView methods (addColumn, deleteColumn, moveColumn)
- State: Add @State variables to KanbanBoardView for feature flags/UI state

**Utilities & Helpers:**
- Shared view components: `TaskFlow/Views/Shared/ComponentName.swift` (create if doesn't exist)
- Data transformations: Extend model classes with computed properties (e.g., Task.displayPriority)
- Formatting: Implement in-model computed properties rather than separate utility classes

## Special Directories

**Sync Folder Structure (iCloud Drive/Documents):**
- Purpose: Shared state between instances
- Generated: Yes (created by SyncManager on init)
- Committed: No (ignored via .gitignore)
- Structure:
  ```
  ~/Library/Mobile Documents/com~apple~CloudDocs/TaskFlow/sync/
  ├── tasks/        # One JSON file per task, named {UUID}.json
  ├── notes/        # One JSON file per note, named {UUID}.json
  └── columns/      # One JSON file per column, named {UUID}.json
  ```

**Fallback Location:**
- Purpose: Used when iCloud Drive unavailable
- Path: `~/Documents/TaskFlow/sync/`
- Same structure as iCloud Drive path

**iCloud Drive Data Store:**
- Purpose: SwiftData local database for models
- Location: `~/Library/Mobile Documents/com~apple~CloudDocs/TaskFlow/TaskFlow.store`
- Fallback: `~/Documents/TaskFlow/TaskFlow.store`

---

*Structure analysis: 2026-03-01*
