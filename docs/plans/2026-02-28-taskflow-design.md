# TaskFlow Design Document

**Date:** 2026-02-28
**Status:** Approved
**Author:** Claude (AI Assistant)

## Overview

TaskFlow is a native macOS TODO application with iCloud sync capability. It allows users to manage tasks with categories, priorities, and due dates across multiple Macs using the same Apple ID.

## Requirements

### Functional Requirements
- Add tasks with title, optional description, category, priority, and due date
- 5 predefined categories: Work, Personal, Shopping, Health, Finance
- Ability to add custom categories
- 3 priority levels: High, Medium, Low
- Mark tasks as complete (moves to Completed section)
- Permanently delete tasks
- View tasks as flat list with filter OR grouped by category
- Default sort by priority (high first)
- iCloud sync across Macs with same Apple ID

### Non-Functional Requirements
- Clean, native macOS UI
- Target: macOS 14.0+ (Sonoma)
- Personal use only (no App Store distribution)
- Offline-capable with sync when online

## Tech Stack

| Component | Technology |
|-----------|------------|
| UI Framework | SwiftUI |
| Data Persistence | SwiftData |
| Cloud Sync | CloudKit (via SwiftData) |
| Target Platform | macOS 14.0+ |

### Why This Stack?
- **SwiftUI**: Declarative, modern, beginner-friendly
- **SwiftData**: Simpler than Core Data, automatic CloudKit integration
- **CloudKit**: Free for personal use, handles sync automatically

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      TaskFlow App                        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   ┌───────────┐    ┌───────────┐    ┌───────────────┐   │
│   │  SwiftUI  │───▶│ SwiftData │───▶│ CloudKit      │   │
│   │   Views   │    │  Models   │    │ (iCloud Sync) │   │
│   └───────────┘    └───────────┘    └───────────────┘   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Data Model

### TodoTask
| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Unique identifier |
| title | String | Task title (required) |
| taskDescription | String? | Optional description |
| category | Category? | Associated category |
| priority | Priority | High, Medium, or Low |
| dueDate | Date? | Optional due date |
| isCompleted | Bool | Completion status |
| createdAt | Date | Creation timestamp |
| completedAt | Date? | When completed |

### Category
| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Unique identifier |
| name | String | Category name |
| isDefault | Bool | True for predefined categories |
| tasks | [TodoTask] | Related tasks |

### Priority Enum
- `high`
- `medium`
- `low`

## UI Design

### Layout
```
┌────────────────────────────────────────────────────────────────┐
│  TaskFlow                                    ─ □ ✕             │
├────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────────────────────────────┐   │
│  │   SIDEBAR    │  │              MAIN CONTENT             │   │
│  │              │  │                                       │   │
│  │  All Tasks   │  │  [+] Add Task        View Toggle      │   │
│  │  Today       │  │                                       │   │
│  │              │  │  ☐ High Priority Task        Work     │   │
│  │  CATEGORIES  │  │     Due: Mar 1 • High                 │   │
│  │  Work        │  │                                       │   │
│  │  Personal    │  │  ☐ Medium Task              Personal  │   │
│  │  Shopping    │  │     Optional description here...      │   │
│  │  Health      │  │     Due: Mar 5 • Medium               │   │
│  │  Finance     │  │                                       │   │
│  │  + Add new   │  │  COMPLETED                            │   │
│  │              │  │  ☑ Done task                          │   │
│  │  Completed   │  │                                       │   │
│  └──────────────┘  └──────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────┘
```

### Views
| View | Purpose |
|------|---------|
| ContentView | Main split view container |
| SidebarView | Navigation and category filter |
| TaskListView | Display tasks (flat or grouped) |
| TaskRowView | Single task row with checkbox |
| TaskEditorView | Add/edit task sheet |
| CategoryManagerView | Add/delete custom categories |

### Interactions
- Click checkbox → Mark complete → Move to Completed section
- Click task → Open edit sheet
- Right-click task → Context menu with Delete option
- Click "Add Task" → Open TaskEditorView sheet
- Sidebar selection → Filter tasks by category
- View toggle → Switch flat list / grouped view

## iCloud Sync

### Configuration
1. Enable iCloud capability in Xcode
2. Select CloudKit
3. Create container: `iCloud.com.username.taskflow`
4. SwiftData handles sync automatically via `cloudKitDatabase: .automatic`

### Sync Behavior
- Automatic sync when online
- Offline changes queue until connection restored
- Conflict resolution: last-write-wins
- No server code required

### Requirements
- Same Apple ID on both Macs
- iCloud Drive enabled
- App built and installed on both devices

## Project Structure

```
TaskFlow/
├── TaskFlowApp.swift
├── Models/
│   ├── TodoTask.swift
│   └── Category.swift
├── Views/
│   ├── ContentView.swift
│   ├── SidebarView.swift
│   ├── TaskListView.swift
│   ├── TaskRowView.swift
│   ├── TaskEditorView.swift
│   └── CategoryManagerView.swift
├── Utilities/
│   └── DefaultDataSeeder.swift
├── TaskFlow.entitlements
└── README.md
```

## Installation (Personal Use)

1. Open project in Xcode
2. Sign in with Apple ID (Xcode > Settings > Accounts)
3. Select Personal Team for signing
4. Enable iCloud capability, create container
5. Build and run on Mac #1
6. Clone/copy project to Mac #2
7. Build and run on Mac #2 with same Apple ID
8. Tasks sync automatically

## Out of Scope

- iOS/iPadOS version
- App Store distribution
- Notifications/reminders
- Task sharing with other users
- Recurring tasks
- Subtasks
- Attachments

## Success Criteria

1. Can add, edit, complete, and delete tasks
2. Tasks sync between two Macs within ~30 seconds
3. Categories can be added and deleted
4. Clean, native macOS appearance
5. App works offline with sync on reconnect
