import SwiftUI
import SwiftData

enum AppTab {
    case tasks, notes
}

struct MainTabView: View {
    @Environment(\.modelContext) private var context
    @Query private var tasks: [TodoTask]
    @Query private var notes: [Note]
    @State private var selectedTab: AppTab = .tasks
    @StateObject private var syncManager = SyncManager()

    var body: some View {
        VStack(spacing: 0) {
            // Sync toolbar at top
            HStack {
                Spacer()
                SyncToolbarView(
                    syncManager: syncManager,
                    onPush: { pushChanges() },
                    onPull: { pullChanges() }
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Tab content
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
        .onAppear {
            // Run column migration on first launch (creates default columns)
            ColumnMigration.migrateIfNeeded(context: context)
            syncManager.checkForRemoteChanges()
        }
        // Track data changes using computed hash
        .onChange(of: tasksHash) { _, newHash in
            syncManager.updateTrackedData(tasksHash: newHash, notesHash: notesHash)
        }
        .onChange(of: notesHash) { _, newHash in
            syncManager.updateTrackedData(tasksHash: tasksHash, notesHash: newHash)
        }
        .onChange(of: syncManager.status) { _, newStatus in
            if newStatus == .syncing {
                if syncManager.detectLocalAhead() {
                    pushChanges()
                } else {
                    pullChanges()
                }
            } else if newStatus == .conflict {
                print("Sync conflict detected - manual intervention required")
            }
        }
    }

    // Computed properties for tracking changes
    private var tasksHash: Int {
        var hasher = Hasher()
        for task in tasks {
            hasher.combine(task.id)
            hasher.combine(task.title)
            hasher.combine(task.taskDescription)
            hasher.combine(task.columnId)
            hasher.combine(task.priority.rawValue)
            hasher.combine(task.position)
            hasher.combine(task.isCompleted)
            hasher.combine(task.checklist.count)
        }
        return hasher.finalize()
    }

    private var notesHash: Int {
        var hasher = Hasher()
        for note in notes {
            hasher.combine(note.id)
            hasher.combine(note.title)
            hasher.combine(note.body)
            hasher.combine(note.position)
            hasher.combine(note.folderName)
        }
        return hasher.finalize()
    }

    private func pushChanges() {
        do {
            try syncManager.pushTasks(tasks)
            try syncManager.pushNotes(notes)
        } catch {
            print("Push error: \(error)")
        }
    }

    private func pullChanges() {
        do {
            _ = try syncManager.pullTasks(context: context, localTasks: tasks)
            _ = try syncManager.pullNotes(context: context, localNotes: notes)
        } catch {
            print("Pull error: \(error)")
        }
    }
}
