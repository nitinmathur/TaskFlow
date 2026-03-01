# External Integrations

**Analysis Date:** 2026-03-01

## APIs & External Services

**Not used**
- No remote APIs or external services integrated
- Application is fully self-contained and offline-first

## Data Storage

**Primary Database:**
- SQLite via SwiftData
  - Type: Embedded database
  - Location: `~/Library/Mobile Documents/com~apple~CloudDocs/TaskFlow/TaskFlow.store`
  - Fallback: `~/Documents/TaskFlow/TaskFlow.store`
  - Client: SwiftData ORM layer
  - Configuration: `TaskFlowApp.swift` lines 7-43
  - WAL Mode: DISABLED for iCloud Drive sync compatibility

**File Storage:**
- Local filesystem only
  - Sync metadata: `~/Library/Mobile Documents/com~apple~CloudDocs/TaskFlow/sync/`
    - Tasks: `/sync/tasks/` - JSON files per task
    - Notes: `/sync/notes/` - JSON files per note
    - Columns: `/sync/columns/` - JSON files per column
  - Strategy: File-based synchronization across devices

**Caching:**
- In-memory only via SwiftUI @State and @Published properties
- No external caching service

## Authentication & Identity

**Auth Provider:**
- None - Single-user local application
- Multi-device sync via iCloud Drive (no authentication required beyond system iCloud login)

## Monitoring & Observability

**Error Tracking:**
- None - No external error tracking service

**Logs:**
- Console output only
  - Print statements in `TaskFlowApp.swift` for initialization errors
  - Print statements in `SyncManager.swift` for debugging (optional)

## CI/CD & Deployment

**Hosting:**
- Desktop application (no server)
- Manual distribution via GitHub or direct file sharing
- No automated deployment pipeline

**CI Pipeline:**
- None - Local build only

## Environment Configuration

**Required env vars:**
- None - All configuration is hardcoded or system-provided

**Secrets location:**
- No secrets management needed
- No API keys or credentials required

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

## Sync System

**iCloud Drive Sync:**
- Framework: File-based synchronization via iCloud Drive folder
- Protocol: Custom JSON file sync with tombstone versioning
- Implementation: `Sync/SyncManager.swift` (263-796 lines)
- Mechanism:
  - Push: Local changes written as JSON to iCloud Drive folder
  - Pull: Periodic polling and file watcher for remote changes
  - Conflict Resolution: Version vector comparison (higher version wins)

**Sync Data Models:**
- `SyncableTask` - JSON-serializable task snapshot (lines 17-88)
- `SyncableNote` - JSON-serializable note snapshot (lines 90-143)
- `SyncableBoardColumn` - JSON-serializable column snapshot (lines 145-193)
- Legacy Format Support: Migration from old format (lines 195-261)

**Sync Status Tracking:**
- Location: `SyncManager.swift` lines 7-13
- States: inSync, localChanges, remoteChanges, conflict, syncing
- Published properties: `@Published var status`, `@Published var lastSyncTime`

**Sync Timing:**
- Auto-sync timer: 5-second polling interval (line 354)
- Push debounce: 3 seconds (line 280)
- Pull delay: 2 seconds (line 281)
- Tombstone cleanup: 7-day retention (line 321)

**Sync Endpoints** (File Paths)
- Tasks: `~/Library/Mobile Documents/com~apple~CloudDocs/TaskFlow/sync/tasks/{uuid}.json`
- Notes: `~/Library/Mobile Documents/com~apple~CloudDocs/TaskFlow/sync/notes/{uuid}.json`
- Columns: `~/Library/Mobile Documents/com~apple~CloudDocs/TaskFlow/sync/columns/{uuid}.json`

---

*Integration audit: 2026-03-01*
