import SwiftUI
import SwiftData

enum SortOption: String, CaseIterable {
    case manual = "Manual"
    case priority = "Priority"
    case dateCreated = "Date Created"
    case dueDate = "Due Date"
}

// Helper for sheet presentation - now uses BoardColumn
struct CardEditorConfig: Identifiable {
    let id = UUID()
    let task: TodoTask?
    let column: BoardColumn
}

struct CardDetailConfig: Identifiable {
    let id = UUID()
    let task: TodoTask
}

struct KanbanBoardView: View {
    @Query private var tasks: [TodoTask]
    @Query(sort: \BoardColumn.position) private var columns: [BoardColumn]
    @Environment(\.modelContext) private var context
    @State private var editorConfig: CardEditorConfig?
    @State private var detailConfig: CardDetailConfig?
    @State private var groupByDate = false
    @State private var sortOption: SortOption = .manual
    @State private var showAddColumnPopover = false
    @State private var showArchive = false

    private var archivedTasksCount: Int {
        tasks.filter { $0.isArchived }.count
    }

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

                // Archive button
                Button {
                    showArchive = true
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .overlay(alignment: .topTrailing) {
                    if archivedTasksCount > 0 {
                        Text("\(archivedTasksCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -8)
                    }
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
                    ForEach(columns) { column in
                        KanbanColumnView(
                            column: column,
                            tasks: sortedTasks(for: column),
                            allTasks: tasks,
                            groupByDate: groupByDate,
                            sortOption: sortOption,
                            onAddCard: { editorConfig = CardEditorConfig(task: nil, column: column) },
                            onViewCard: { task in detailConfig = CardDetailConfig(task: task) },
                            onMoveCard: { task, newCol in moveCard(task, to: newCol) },
                            onReorder: { task, direction in reorderTask(task, direction: direction, in: column) },
                            onDeleteColumn: { deleteColumn(column) },
                            onMoveColumnLeft: { moveColumn(column, direction: -1) },
                            onMoveColumnRight: { moveColumn(column, direction: 1) },
                            canMoveLeft: canMoveColumn(column, direction: -1),
                            canMoveRight: canMoveColumn(column, direction: 1)
                        )
                    }

                    // Add Column Button
                    addColumnButton
                }
                .padding()
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .sheet(item: $editorConfig) { config in
            CardEditorView(task: config.task, defaultColumn: config.column, allColumns: columns)
        }
        .sheet(item: $detailConfig) { config in
            CardDetailView(
                task: config.task,
                onEdit: {
                    if let column = columns.first(where: { $0.id == config.task.columnId }) {
                        editorConfig = CardEditorConfig(task: config.task, column: column)
                    } else if let firstColumn = columns.first {
                        editorConfig = CardEditorConfig(task: config.task, column: firstColumn)
                    }
                },
                onDelete: { context.delete(config.task) },
                onArchive: { config.task.isArchived = true }
            )
        }
        .sheet(isPresented: $showArchive) {
            ArchiveView()
        }
    }

    // MARK: - Add Column Button

    private var addColumnButton: some View {
        Button {
            showAddColumnPopover = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Add Column")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .frame(width: 100)
            .frame(minHeight: 400)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundStyle(.secondary.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showAddColumnPopover) {
            AddColumnPopover(isPresented: $showAddColumnPopover) { name, icon in
                addColumn(name: name, icon: icon)
            }
        }
    }

    // MARK: - Column Management

    private func addColumn(name: String, icon: String) {
        // Find position before the "Completed" column (system column)
        // If no system column, add at the end
        let systemColumnPosition = columns.first(where: { $0.isSystem })?.position ?? columns.count
        let newPosition = systemColumnPosition

        // Shift system column(s) to make room
        for column in columns where column.position >= newPosition {
            column.position += 1
        }

        let newColumn = BoardColumn(name: name, icon: icon, position: newPosition, isSystem: false)
        context.insert(newColumn)
    }

    private func deleteColumn(_ column: BoardColumn) {
        guard !column.isSystem else { return }

        // Archive all tasks from this column (instead of moving to another column)
        let columnTasks = tasks.filter { $0.columnId == column.id && !$0.isArchived }
        for task in columnTasks {
            task.isArchived = true
        }

        // Adjust positions of remaining columns
        let deletedPosition = column.position
        for col in columns where col.position > deletedPosition {
            col.position -= 1
        }

        context.delete(column)
    }

    private func moveColumn(_ column: BoardColumn, direction: Int) {
        guard !column.isSystem else { return }

        let newPosition = column.position + direction
        guard newPosition >= 0 && newPosition < columns.count else { return }

        // Find the column at the target position
        guard let targetColumn = columns.first(where: { $0.position == newPosition }) else { return }

        // Don't allow moving past the system column
        if targetColumn.isSystem { return }

        // Swap positions
        let tempPosition = column.position
        column.position = targetColumn.position
        targetColumn.position = tempPosition
    }

    private func canMoveColumn(_ column: BoardColumn, direction: Int) -> Bool {
        guard !column.isSystem else { return false }

        let newPosition = column.position + direction
        guard newPosition >= 0 && newPosition < columns.count else { return false }

        // Check if target position has a system column
        if let targetColumn = columns.first(where: { $0.position == newPosition }) {
            return !targetColumn.isSystem
        }

        return true
    }

    // MARK: - Task Sorting & Filtering

    private func sortedTasks(for column: BoardColumn) -> [TodoTask] {
        let columnTasks = tasks.filter { $0.columnId == column.id && !$0.isArchived }

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

    // MARK: - Card Actions

    private func moveCard(_ task: TodoTask, to column: BoardColumn) {
        let targetTasks = tasks.filter { $0.columnId == column.id }
        task.position = (targetTasks.map(\.position).max() ?? -1) + 1
        task.columnId = column.id

        // Handle completion status based on isSystem flag (system column = completed)
        if column.isSystem {
            task.isCompleted = true
            task.completedAt = Date()
        } else if task.isCompleted {
            task.isCompleted = false
            task.completedAt = nil
        }
    }

    private func reorderTask(_ task: TodoTask, direction: Int, in column: BoardColumn) {
        let columnTasks = tasks.filter { $0.columnId == column.id }.sorted { $0.position < $1.position }
        guard let currentIndex = columnTasks.firstIndex(where: { $0.id == task.id }) else { return }

        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < columnTasks.count else { return }

        let otherTask = columnTasks[newIndex]
        let tempPosition = task.position
        task.position = otherTask.position
        otherTask.position = tempPosition
    }
}
