import SwiftUI
import SwiftData

enum SortOption: String, CaseIterable {
    case manual = "Manual"
    case priority = "Priority"
    case dateCreated = "Date Created"
    case dueDate = "Due Date"
}

struct KanbanBoardView: View {
    @Query private var tasks: [TodoTask]
    @Environment(\.modelContext) private var context
    @State private var showCardEditor = false
    @State private var showCardDetail = false
    @State private var editingTask: TodoTask?
    @State private var viewingTask: TodoTask?
    @State private var newCardColumn: Column?
    @State private var groupByDate = false
    @State private var sortOption: SortOption = .manual

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                // Sort picker
                HStack(spacing: 4) {
                    Text("Sort:").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }

                Spacer()

                Toggle(isOn: $groupByDate) {
                    Label("Group by Date", systemImage: "calendar")
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Board
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(Column.allCases, id: \.self) { column in
                        KanbanColumnView(
                            column: column,
                            tasks: sortedTasks(for: column),
                            allTasks: tasks,
                            groupByDate: groupByDate,
                            sortOption: sortOption,
                            onAddCard: { newCardColumn = column; showCardEditor = true },
                            onViewCard: { task in viewingTask = task; showCardDetail = true },
                            onMoveCard: { task, newCol in moveCard(task, to: newCol) },
                            onReorder: { task, direction in reorderTask(task, direction: direction) }
                        )
                    }
                }
                .padding()
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .sheet(isPresented: $showCardEditor) {
            CardEditorView(task: editingTask, defaultColumn: newCardColumn ?? .work)
        }
        .sheet(isPresented: $showCardDetail) {
            if let task = viewingTask {
                CardDetailView(
                    task: task,
                    onEdit: { editingTask = task; showCardEditor = true },
                    onDelete: { context.delete(task) }
                )
            }
        }
        .onChange(of: showCardEditor) { _, isShowing in
            if !isShowing { editingTask = nil; newCardColumn = nil }
        }
        .onChange(of: showCardDetail) { _, isShowing in
            if !isShowing { viewingTask = nil }
        }
    }

    private func sortedTasks(for column: Column) -> [TodoTask] {
        let columnTasks = tasks.filter { $0.column == column }

        switch sortOption {
        case .manual:
            return columnTasks.sorted { $0.position < $1.position }
        case .priority:
            return columnTasks.sorted { t1, t2 in
                if t1.priority.rawValue != t2.priority.rawValue {
                    return t1.priority.rawValue < t2.priority.rawValue
                }
                return t1.position < t2.position
            }
        case .dateCreated:
            return columnTasks.sorted { $0.createdAt > $1.createdAt }
        case .dueDate:
            return columnTasks.sorted { t1, t2 in
                switch (t1.dueDate, t2.dueDate) {
                case (nil, nil): return t1.position < t2.position
                case (nil, _): return false
                case (_, nil): return true
                case (let d1?, let d2?): return d1 < d2
                }
            }
        }
    }

    private func moveCard(_ task: TodoTask, to column: Column) {
        let targetTasks = tasks.filter { $0.column == column }
        task.position = (targetTasks.map(\.position).max() ?? -1) + 1
        task.column = column
        if column == .completed {
            task.isCompleted = true
            task.completedAt = Date()
        } else if task.isCompleted {
            task.isCompleted = false
            task.completedAt = nil
        }
    }

    private func reorderTask(_ task: TodoTask, direction: Int) {
        let columnTasks = tasks.filter { $0.column == task.column }.sorted { $0.position < $1.position }
        guard let currentIndex = columnTasks.firstIndex(where: { $0.id == task.id }) else { return }

        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < columnTasks.count else { return }

        let otherTask = columnTasks[newIndex]
        let tempPosition = task.position
        task.position = otherTask.position
        otherTask.position = tempPosition
    }
}
