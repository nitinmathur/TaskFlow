# Auto-Sync + Notes Folders Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace manual Push/Pull with automatic background sync and add folder organization to Notes

**Architecture:** Timer-based sync checks every 15s with 1-min push debounce and 10s pull countdown. Folders stored as string field on Note model with dynamic sidebar generation.

**Tech Stack:** SwiftUI, SwiftData, Combine (Timer)

---

## Task 1: Add folderName to Note Model

**Files:**
- Modify: `TaskFlow/Models/Note.swift`

**Step 1: Add folderName field**

```swift
@Model
final class Note {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var position: Int = 0
    var folderName: String = "All Notes"  // NEW
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(title: String = "Untitled", body: String = "", position: Int = 0, folderName: String = "All Notes") {
        self.id = UUID()
        self.title = title
        self.body = body
        self.position = position
        self.folderName = folderName
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

**Step 2: Commit**

```bash
git add TaskFlow/Models/Note.swift
git commit -m "feat: add folderName field to Note model"
```

---

## Task 2: Update SyncableNote with folderName

**Files:**
- Modify: `TaskFlow/Sync/SyncManager.swift`

**Step 1: Add folderName to SyncableNote**

```swift
struct SyncableNote: Codable {
    var id: UUID
    var title: String
    var body: String
    var position: Int
    var folderName: String  // NEW
    var createdAt: Date
    var updatedAt: Date
    var modifiedAt: Date

    init(from note: Note) {
        self.id = note.id
        self.title = note.title
        self.body = note.body
        self.position = note.position
        self.folderName = note.folderName  // NEW
        self.createdAt = note.createdAt
        self.updatedAt = note.updatedAt
        self.modifiedAt = Date()
    }

    func apply(to note: Note) {
        note.title = title
        note.body = body
        note.position = position
        note.folderName = folderName  // NEW
        note.updatedAt = updatedAt
    }
}
```

**Step 2: Commit**

```bash
git add TaskFlow/Sync/SyncManager.swift
git commit -m "feat: sync folderName in notes"
```

---

## Task 3: Convert to Auto-Sync with Timer

**Files:**
- Modify: `TaskFlow/Sync/SyncManager.swift`

**Step 1: Add timer and debounce state**

Add to SyncManager class:

```swift
@Published var countdown: Int = 0
private var timer: Timer?
private var lastLocalChange: Date?
private let pushDebounce: TimeInterval = 60  // 1 minute
private let pullDelay: TimeInterval = 10      // 10 seconds
private var pullCountdownDate: Date?
```

**Step 2: Start timer in init**

```swift
init() {
    // ... existing code ...
    startAutoSync()
}

private func startAutoSync() {
    timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
        Task { @MainActor in
            self?.checkAndSync()
        }
    }
}
```

**Step 3: Implement checkAndSync**

```swift
private func checkAndSync() {
    // Detect state
    let isAhead = detectLocalAhead()
    let isBehind = detectRemoteBehind()

    if isAhead && !isBehind {
        handleLocalAhead()
    } else if isBehind && !isAhead {
        handleRemoteBehind()
    } else if !isAhead && !isBehind {
        status = .inSync
    }
}

private func detectLocalAhead() -> Bool {
    // Check if local has changes
    return lastLocalChange != nil
}

private func detectRemoteBehind() -> Bool {
    // Check if remote files newer than lastSyncTime
    guard let lastSync = lastSyncTime else { return true }

    let fm = FileManager.default
    var hasNewer = false

    if let files = try? fm.contentsOfDirectory(at: tasksURL, includingPropertiesForKeys: [.contentModificationDateKey]) {
        for file in files where file.pathExtension == "json" {
            if let modDate = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               modDate > lastSync {
                hasNewer = true
                break
            }
        }
    }

    return hasNewer
}

private func handleLocalAhead() {
    guard let lastChange = lastLocalChange else { return }
    let elapsed = Date().timeIntervalSince(lastChange)

    if elapsed >= pushDebounce {
        status = .syncing
        // Push will be called externally
    } else {
        status = .localChanges
    }
}

private func handleRemoteBehind() {
    if pullCountdownDate == nil {
        pullCountdownDate = Date().addingTimeInterval(pullDelay)
        status = .remoteChanges
    }

    if let countdownDate = pullCountdownDate {
        let remaining = countdownDate.timeIntervalSinceNow
        countdown = max(0, Int(ceil(remaining)))

        if remaining <= 0 {
            status = .syncing
            pullCountdownDate = nil
            // Pull will be called externally
        }
    }
}

func markLocalChange() {
    lastLocalChange = Date()
}
```

**Step 4: Commit**

```bash
git add TaskFlow/Sync/SyncManager.swift
git commit -m "feat: add timer-based auto-sync logic"
```

---

## Task 4: Update Status Display

**Files:**
- Modify: `TaskFlow/Views/SyncToolbarView.swift`

**Step 1: Update to show countdown**

```swift
private var statusText: String {
    switch syncManager.status {
    case .inSync: "Synced"
    case .localChanges: "Syncing soon..."
    case .remoteChanges:
        let count = syncManager.countdown
        return "Updates - pulling in \(count)s"
    case .conflict: "Conflict"
    case .syncing: "Syncing..."
    }
}
```

**Step 2: Remove Push/Pull buttons**

Delete the Button views, keep only statusBadge.

**Step 3: Commit**

```bash
git add TaskFlow/Views/SyncToolbarView.swift
git commit -m "feat: update sync toolbar for auto-sync"
```

---

## Task 5: Wire Auto-Sync in MainTabView

**Files:**
- Modify: `TaskFlow/Views/MainTabView.swift`

**Step 1: Add onChange handlers**

```swift
var body: some View {
    VStack(spacing: 0) {
        HStack {
            Spacer()
            SyncToolbarView(syncManager: syncManager)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))

        Divider()

        TabView(selection: $selectedTab) {
            KanbanBoardView()
                .tabItem { Label("Tasks", systemImage: "checkmark.square") }
                .tag(AppTab.tasks)

            NotesSplitView()
                .tabItem { Label("Notes", systemImage: "note.text") }
                .tag(AppTab.notes)
        }
    }
    .frame(minWidth: 900, minHeight: 500)
    .onAppear { syncManager.checkForRemoteChanges() }
    .onChange(of: tasks) { _, _ in
        syncManager.markLocalChange()
    }
    .onChange(of: notes) { _, _ in
        syncManager.markLocalChange()
    }
    .onChange(of: syncManager.status) { _, newStatus in
        if newStatus == .syncing {
            if syncManager.detectLocalAhead() {
                pushChanges()
            } else {
                pullChanges()
            }
        }
    }
}
```

**Step 2: Commit**

```bash
git add TaskFlow/Views/MainTabView.swift
git commit -m "feat: wire auto-sync triggers"
```

---

## Task 6: Create Folder Management View

**Files:**
- Create: `TaskFlow/Views/Notes/FolderManagerView.swift`

**Step 1: Create FolderManagerView**

```swift
import SwiftUI
import SwiftData

struct FolderManagerView: View {
    @Query private var notes: [Note]
    @Environment(\.dismiss) private var dismiss
    @State private var newFolderName = ""
    @State private var editingFolder: String?
    @State private var editName = ""

    private var folders: [String] {
        var unique = Set(notes.map(\.folderName))
        unique.insert("All Notes")
        return Array(unique).sorted { f1, f2 in
            if f1 == "All Notes" { return true }
            if f2 == "All Notes" { return false }
            return f1 < f2
        }
    }

    private func noteCount(for folder: String) -> Int {
        notes.filter { $0.folderName == folder }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Manage Folders").font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }.padding()

            Divider()

            List {
                ForEach(folders, id: \.self) { folder in
                    HStack {
                        if editingFolder == folder {
                            TextField("Folder name", text: $editName)
                                .textFieldStyle(.plain)
                        } else {
                            Text(folder)
                            Spacer()
                            Text("\(noteCount(for: folder))").foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        if folder != "All Notes" {
                            Button("Rename") {
                                editingFolder = folder
                                editName = folder
                            }
                            Button("Delete", role: .destructive) {
                                deleteFolder(folder)
                            }
                        }
                    }
                }
            }

            Divider()

            HStack {
                TextField("New folder name", text: $newFolderName)
                Button("Add") { addFolder() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newFolderName.isEmpty)
            }.padding()
        }
        .frame(width: 300, height: 400)
    }

    private func addFolder() {
        // Folder created when first note added
        newFolderName = ""
        dismiss()
    }

    private func deleteFolder(_ folder: String) {
        let count = noteCount(for: folder)
        if count > 0 {
            // Show alert - implement in parent
        }
    }
}
```

**Step 2: Commit**

```bash
git add TaskFlow/Views/Notes/FolderManagerView.swift
xcodegen generate
git add TaskFlow.xcodeproj
git commit -m "feat: add folder management view"
```

---

## Task 7: Update NotesSplitView with Folders

**Files:**
- Modify: `TaskFlow/Views/Notes/NotesSplitView.swift`

**Step 1: Add folder sidebar**

Replace NotesListView body with folder-aware version - see full implementation in next step.

**Step 2: Add folder filtering**

Add `@State private var selectedFolder: String = "All Notes"` and filter notes by folder.

**Step 3: Commit**

```bash
git add TaskFlow/Views/Notes/NotesSplitView.swift
git commit -m "feat: add folder sidebar to notes"
```

---

## Final Steps

**Regenerate project:**
```bash
xcodegen generate
```

**Build and test:**
```bash
open TaskFlow.xcodeproj
# Cmd+R in Xcode
```

**Test checklist:**
- Create note, wait 1 min, check shared folder has JSON
- Edit on Mac B, wait 10s, see pull on Mac A
- Create folder, move note, verify syncs
- Try delete folder with notes (should fail)
