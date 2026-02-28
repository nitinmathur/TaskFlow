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
                SyncToolbarView(syncManager: syncManager)
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
