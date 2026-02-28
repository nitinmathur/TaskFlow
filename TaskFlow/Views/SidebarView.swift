import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selection: SidebarSelection
    @Query(sort: \Category.name) private var categories: [Category]
    @Query private var tasks: [TodoTask]
    @State private var showCategoryManager = false

    private var todayCount: Int {
        let cal = Calendar.current
        return tasks.filter { !$0.isCompleted && $0.dueDate.map { cal.isDateInToday($0) } ?? false }.count
    }

    private var thisWeekCount: Int {
        let cal = Calendar.current
        guard let weekEnd = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: Date())) else { return 0 }
        return tasks.filter { !$0.isCompleted && $0.dueDate.map { $0 < weekEnd } ?? false }.count
    }

    private var activeCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }

    var body: some View {
        List(selection: $selection) {
            Section("Schedule") {
                Label {
                    HStack {
                        Text("Today")
                        Spacer()
                        if todayCount > 0 {
                            Text("\(todayCount)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                } icon: {
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(.orange)
                }
                .tag(SidebarSelection.today)

                Label {
                    HStack {
                        Text("This Week")
                        Spacer()
                        if thisWeekCount > 0 {
                            Text("\(thisWeekCount)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundStyle(.blue)
                }
                .tag(SidebarSelection.thisWeek)

                Label {
                    HStack {
                        Text("All Active")
                        Spacer()
                        if activeCount > 0 {
                            Text("\(activeCount)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                } icon: {
                    Image(systemName: "tray.full.fill")
                        .foregroundStyle(.gray)
                }
                .tag(SidebarSelection.all)
            }

            Section("Categories") {
                ForEach(categories) { cat in
                    let count = tasks.filter { !$0.isCompleted && $0.category?.id == cat.id }.count
                    Label {
                        HStack {
                            Text(cat.name)
                            Spacer()
                            if count > 0 {
                                Text("\(count)")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    } icon: {
                        Image(systemName: iconFor(cat.name))
                            .foregroundStyle(colorFor(cat.name))
                    }
                    .tag(SidebarSelection.category(cat))
                }
                Button { showCategoryManager = true } label: {
                    Label("Manage...", systemImage: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Label {
                    Text("Logbook")
                } icon: {
                    Image(systemName: "book.closed.fill")
                        .foregroundStyle(.brown)
                }
                .tag(SidebarSelection.logbook)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("TaskFlow")
        .sheet(isPresented: $showCategoryManager) {
            CategoryManagerView()
        }
    }

    private func iconFor(_ name: String) -> String {
        switch name.lowercased() {
        case "work": "briefcase.fill"
        case "personal": "person.fill"
        default: "folder.fill"
        }
    }

    private func colorFor(_ name: String) -> Color {
        switch name.lowercased() {
        case "work": .indigo
        case "personal": .green
        default: .gray
        }
    }
}
