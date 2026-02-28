# TaskFlow Project Documentation

**Last Updated:** 2026-02-28
**Status:** MVP Complete, In Active Use

## What We Built

TaskFlow is a native macOS TODO app for developers with iCloud Drive sync between Macs.

### Current Features

- **Task Management**: Create, edit, complete, delete tasks
- **Categories**: Work and Personal (customizable)
- **Priority Levels**: High (red), Medium (orange), Low (blue)
- **Due Dates**: Optional, with visual indicators for today/overdue
- **Sorting**: By recency (default), priority, or due date
- **Grouping**: None, by category, or by date created
- **Logbook**: Completed tasks grouped by completion date (Today, Yesterday, This Week, etc.)
- **Timestamps**: Shows when tasks were created (e.g., "2h ago")
- **iCloud Sync**: Data stored in `~/Library/Mobile Documents/com~apple~CloudDocs/TaskFlow/`

### Tech Stack

| Component | Technology |
|-----------|------------|
| UI | SwiftUI |
| Data | SwiftData (SQLite) |
| Sync | iCloud Drive folder (no CloudKit) |
| Target | macOS 14.0+ (Sonoma) |
| Build Tool | xcodegen |

### Project Structure

```
TaskFlow/
├── project.yml              # xcodegen config
├── README.md                # Setup instructions
├── docs/
│   ├── PROJECT.md           # This file
│   └── plans/
│       └── 2026-02-28-taskflow-design.md  # Original design doc
└── TaskFlow/
    ├── TaskFlowApp.swift    # App entry, SwiftData container
    ├── TaskFlow.entitlements
    ├── Models/
    │   ├── TodoTask.swift   # Task model with priority enum
    │   └── Category.swift   # Category model
    ├── Views/
    │   ├── ContentView.swift       # Main split view
    │   ├── SidebarView.swift       # Navigation sidebar
    │   ├── TaskListView.swift      # Task list with sort/group
    │   ├── TaskRowView.swift       # Individual task row
    │   ├── TaskEditorView.swift    # Add/edit task sheet
    │   └── CategoryManagerView.swift # Manage categories
    └── Utilities/
        └── DefaultDataSeeder.swift  # Seeds Work/Personal categories
```

### Key Implementation Details

1. **No paid Apple Developer account needed** - Uses iCloud Drive folder sync instead of CloudKit
2. **Data location**: `~/Library/Mobile Documents/com~apple~CloudDocs/TaskFlow/TaskFlow.store`
3. **Fallback**: If iCloud Drive unavailable, stores in `~/Documents/TaskFlow/`
4. **Default categories**: Work and Personal (can add/delete any)
5. **Sort default**: Recency (newest first)

---

## North Star / Future Features

### Priority 1: Telegram Bot Integration
**Status:** Planned

Allow creating and reading todos via Telegram bot.

**Proposed approach (Option A - Local Bot):**
1. Python script running on Mac
2. Uses python-telegram-bot library
3. Shares data via JSON file in iCloud Drive folder
4. Commands: `/add <task>`, `/list`, `/done <id>`, `/today`

**Implementation notes:**
- Bot token via BotFather
- Script runs as launchd daemon or manual background process
- App needs to read from shared JSON or bot writes directly to SQLite

**Alternative approaches considered:**
- Option B: Cloud-hosted bot with Firebase (always-on, more complex)
- Option C: Inbox file that app imports on launch (simpler)

### Priority 2: Potential Enhancements
- Keyboard shortcuts (Cmd+N for new task, etc.)
- Quick add from menu bar
- Notifications/reminders for due dates
- Search/filter tasks
- Task notes/subtasks
- Archive vs delete distinction

---

## Session Continuity Notes

### For Next Claude Session

**Context:**
- User is a developer who uses this for daily todos
- Prefers simple, clean solutions over complex ones
- Has 2 Macs syncing via iCloud Drive
- Wants Telegram integration for mobile access

**Current state:**
- App is functional and in use
- Categories reduced to Work/Personal
- Sorting by recency, grouping by date working
- No known bugs

**To continue Telegram bot work:**
1. Ask user if they have a Telegram bot token
2. Recommend Option A (local Python bot)
3. Create `TaskFlow/bot/` directory with:
   - `bot.py` - Main bot script
   - `requirements.txt` - python-telegram-bot
   - `README.md` - Setup instructions
4. Decide on data sharing: JSON file vs direct SQLite access
5. Consider launchd plist for auto-start

**Build commands:**
```bash
cd /Users/nmathur/Documents/personal-projects/TaskFlow
xcodegen generate
open TaskFlow.xcodeproj
# Then Cmd+R in Xcode
```

**Data location for debugging:**
```bash
ls -la ~/Library/Mobile\ Documents/com~apple~CloudDocs/TaskFlow/
```
