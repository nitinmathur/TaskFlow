import SwiftUI
import SwiftData

enum SidebarSelection: Hashable {
    case today, thisWeek, all
    case category(Category)
    case logbook
}

struct ContentView: View {
    @State private var selection: SidebarSelection = .all

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            TaskListView(selection: selection)
        }
        .frame(minWidth: 700, minHeight: 400)
    }
}
