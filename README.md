# TaskFlow

A native macOS TODO app for developers with iCloud Drive sync.

## Features

- Tasks with title, notes, category, priority, due date
- Sort by recency, priority, or due date
- Group by category or date created
- Logbook for completed tasks (grouped by completion date)
- Syncs between Macs via iCloud Drive

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15+
- xcodegen (`brew install xcodegen`)
- Same Apple ID on all Macs (for sync)

## Installation

### First Mac

```bash
# Clone/copy project
cd /Users/nmathur/Documents/personal-projects/TaskFlow

# Generate Xcode project
xcodegen generate

# Open in Xcode
open TaskFlow.xcodeproj
```

In Xcode:
1. Select **TaskFlow** target
2. Go to **Signing & Capabilities**
3. Select your **Personal Team**
4. Press **Cmd+R** to build and run

### Second Mac (Sync Setup)

1. **Copy the project** to your second Mac:
   - Via AirDrop, USB drive, or git
   - Or store in iCloud Drive/Dropbox for automatic sync

2. **Install xcodegen** (if not installed):
   ```bash
   brew install xcodegen
   ```

3. **Build the app**:
   ```bash
   cd /path/to/TaskFlow
   xcodegen generate
   open TaskFlow.xcodeproj
   ```

4. In Xcode: Select Personal Team, then **Cmd+R**

5. **Verify sync**: Tasks should appear automatically (may take a few seconds)

### Sync Requirements

- Both Macs signed into the **same Apple ID**
- **iCloud Drive** enabled on both Macs
- Data syncs via: `~/Library/Mobile Documents/com~apple~CloudDocs/TaskFlow/`

## Usage

| Action | How |
|--------|-----|
| Add task | Click **+** button |
| Complete task | Click the circle checkbox |
| Edit task | Click on the task row |
| Delete task | Right-click → Delete, or Edit → Delete |
| Sort tasks | Use **Sort** dropdown (Newest/Priority/Due Date) |
| Group tasks | Use **Group** dropdown (None/Category/Date) |
| Manage categories | Sidebar → Manage... |

## Project Structure

```
TaskFlow/
├── project.yml          # xcodegen config
├── README.md
├── docs/
│   └── PROJECT.md       # Full documentation & roadmap
└── TaskFlow/
    ├── TaskFlowApp.swift
    ├── Models/
    ├── Views/
    └── Utilities/
```

## Troubleshooting

**Tasks not syncing?**
- Ensure iCloud Drive is enabled: System Settings → Apple ID → iCloud → iCloud Drive
- Check data exists: `ls ~/Library/Mobile\ Documents/com~apple~CloudDocs/TaskFlow/`
- May take 30-60 seconds for initial sync

**Build errors?**
- Regenerate project: `xcodegen generate`
- Clean build: Cmd+Shift+K, then Cmd+R

**Provisioning profile errors?**
- This app doesn't use CloudKit, so Personal Team should work
- If issues persist, check Signing & Capabilities in Xcode

## Future Plans

- Telegram bot integration for mobile access
- See `docs/PROJECT.md` for full roadmap
