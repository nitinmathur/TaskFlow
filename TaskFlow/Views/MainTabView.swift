import SwiftUI

enum AppTab {
    case tasks, notes
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .tasks

    var body: some View {
        TabView(selection: $selectedTab) {
            KanbanBoardView()
                .tabItem {
                    Label("Tasks", systemImage: "checkmark.square")
                }
                .tag(AppTab.tasks)

            NotesSplitView()
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
                .tag(AppTab.notes)
        }
        .frame(minWidth: 900, minHeight: 500)
    }
}
