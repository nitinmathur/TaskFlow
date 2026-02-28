import SwiftUI
import SwiftData

enum SortOption: String, CaseIterable {
    case recency = "Newest"
    case priority = "Priority"
    case dueDate = "Due Date"
}

enum GroupOption: String, CaseIterable {
    case none = "None"
    case category = "Category"
    case date = "Date Created"
}

struct TaskListView: View {
    let selection: SidebarSelection
    @Query private var allTasks: [TodoTask]
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var showEditor = false
    @State private var editingTask: TodoTask?
    @State private var sortBy: SortOption = .recency
    @State private var groupBy: GroupOption = .none

    private var filteredTasks: [TodoTask] {
        let cal = Calendar.current
        var tasks: [TodoTask]
        switch selection {
        case .today:
            tasks = allTasks.filter { !$0.isCompleted && $0.dueDate.map { cal.isDateInToday($0) } ?? false }
        case .thisWeek:
            let weekEnd = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: Date())) ?? Date()
            tasks = allTasks.filter { !$0.isCompleted && $0.dueDate.map { $0 < weekEnd } ?? false }
        case .all:
            tasks = allTasks.filter { !$0.isCompleted }
        case .category(let cat):
            tasks = allTasks.filter { !$0.isCompleted && $0.category?.id == cat.id }
        case .logbook:
            return allTasks.filter { $0.isCompleted }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        }
        return sortedTasks(tasks)
    }

    private func sortedTasks(_ tasks: [TodoTask]) -> [TodoTask] {
        switch sortBy {
        case .recency:
            return tasks.sorted { $0.createdAt > $1.createdAt }
        case .priority:
            return tasks.sorted { $0.priorityRaw < $1.priorityRaw }
        case .dueDate:
            return tasks.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        }
    }

    private var title: String {
        switch selection {
        case .today: "Today"
        case .thisWeek: "This Week"
        case .all: "All Active"
        case .category(let cat): cat.name
        case .logbook: "Logbook"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if filteredTasks.isEmpty {
                emptyState
            } else if selection == .logbook {
                logbookList
            } else if groupBy == .category {
                groupedByCategoryList
            } else if groupBy == .date {
                groupedByDateList
            } else {
                flatList
            }
        }
        .sheet(isPresented: $showEditor) {
            TaskEditorView(task: editingTask)
        }
        .onChange(of: editingTask) { _, new in if new != nil { showEditor = true } }
        .onChange(of: showEditor) { _, new in if !new { editingTask = nil } }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(selection == .logbook ? "No Completed Tasks" : "No Tasks",
                  systemImage: selection == .logbook ? "checkmark.circle" : "tray")
        } description: {
            Text(selection == .logbook ? "Completed tasks appear here" : "Add a task to get started")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text(title).font(.title2.bold())
            Spacer()

            if selection != .logbook {
                Menu {
                    Picker("Sort", selection: $sortBy) {
                        ForEach(SortOption.allCases, id: \.self) { Text($0.rawValue) }
                    }
                } label: {
                    Label(sortBy.rawValue, systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                }

                Menu {
                    Picker("Group", selection: $groupBy) {
                        ForEach(GroupOption.allCases, id: \.self) { Text($0.rawValue) }
                    }
                } label: {
                    Label(groupBy.rawValue, systemImage: "folder")
                        .font(.caption)
                }

                Button { editingTask = nil; showEditor = true } label: {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    private var flatList: some View {
        List {
            ForEach(filteredTasks) { task in
                TaskRowView(task: task, showTimestamp: true) { editingTask = task }
            }
        }
        .listStyle(.plain)
    }

    private var groupedByCategoryList: some View {
        List {
            ForEach(categories) { cat in
                let tasks = filteredTasks.filter { $0.category?.id == cat.id }
                if !tasks.isEmpty {
                    Section(cat.name) {
                        ForEach(tasks) { task in
                            TaskRowView(task: task, showTimestamp: true) { editingTask = task }
                        }
                    }
                }
            }
            let uncategorized = filteredTasks.filter { $0.category == nil }
            if !uncategorized.isEmpty {
                Section("Uncategorized") {
                    ForEach(uncategorized) { task in
                        TaskRowView(task: task, showTimestamp: true) { editingTask = task }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var groupedByDateList: some View {
        let grouped = Dictionary(grouping: filteredTasks) { task -> String in
            dateGroup(task.createdAt)
        }
        let order = ["Today", "Yesterday", "This Week", "This Month", "Older"]

        return List {
            ForEach(order, id: \.self) { section in
                if let tasks = grouped[section], !tasks.isEmpty {
                    Section {
                        ForEach(tasks) { task in
                            TaskRowView(task: task, showTimestamp: true) { editingTask = task }
                        }
                    } header: {
                        Text(section)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var logbookList: some View {
        let grouped = Dictionary(grouping: filteredTasks) { task -> String in
            guard let date = task.completedAt else { return "Unknown" }
            return dateGroup(date)
        }
        let order = ["Today", "Yesterday", "This Week", "This Month", "Older"]

        return List {
            ForEach(order, id: \.self) { section in
                if let tasks = grouped[section], !tasks.isEmpty {
                    Section {
                        ForEach(tasks) { task in
                            TaskRowView(task: task, showTimestamp: true) { editingTask = task }
                        }
                    } header: {
                        HStack {
                            Text(section)
                            Spacer()
                            Text("\(tasks.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func dateGroup(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        if let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()), date > weekAgo { return "This Week" }
        if let monthAgo = cal.date(byAdding: .month, value: -1, to: Date()), date > monthAgo { return "This Month" }
        return "Older"
    }
}
