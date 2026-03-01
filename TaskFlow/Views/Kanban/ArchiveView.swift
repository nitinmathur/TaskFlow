import SwiftUI
import SwiftData

struct ArchiveView: View {
    @Query(filter: #Predicate<TodoTask> { $0.isArchived })
    private var archivedTasks: [TodoTask]
    @Query(sort: \BoardColumn.position) private var columns: [BoardColumn]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var taskToDelete: TodoTask?
    @State private var showDeleteConfirmation = false

    private var filteredTasks: [TodoTask] {
        if searchText.isEmpty {
            return archivedTasks.sorted { $0.createdAt > $1.createdAt }
        }
        return archivedTasks
            .filter { $0.title.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func columnName(for task: TodoTask) -> String {
        if let columnId = task.columnId,
           let column = columns.first(where: { $0.id == columnId }) {
            return column.name
        }
        return task.column.rawValue.capitalized
    }

    private func columnIcon(for task: TodoTask) -> String {
        if let columnId = task.columnId,
           let column = columns.first(where: { $0.id == columnId }) {
            return column.icon
        }
        return "folder"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Archived Tasks")
                    .font(.headline)
                Spacer()
                Text("\(archivedTasks.count) task\(archivedTasks.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search archived tasks...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Content
            if filteredTasks.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
        .frame(width: 500, height: 550)
        .confirmationDialog(
            "Delete Task Permanently?",
            isPresented: $showDeleteConfirmation,
            presenting: taskToDelete
        ) { task in
            Button("Delete Permanently", role: .destructive) {
                context.delete(task)
                taskToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                taskToDelete = nil
            }
        } message: { task in
            Text("This will permanently delete \"\(task.title)\". This action cannot be undone.")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            if searchText.isEmpty {
                Text("No Archived Tasks")
                    .font(.title3.weight(.medium))
                Text("Completed tasks that you archive will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("No Results")
                    .font(.title3.weight(.medium))
                Text("No archived tasks match \"\(searchText)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Task List

    private var taskList: some View {
        List {
            ForEach(filteredTasks) { task in
                ArchivedTaskRow(
                    task: task,
                    columnName: columnName(for: task),
                    columnIcon: columnIcon(for: task),
                    onRestore: { restoreTask(task) },
                    onDelete: {
                        taskToDelete = task
                        showDeleteConfirmation = true
                    }
                )
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Actions

    private func restoreTask(_ task: TodoTask) {
        task.isArchived = false
    }
}

// MARK: - Archived Task Row

struct ArchivedTaskRow: View {
    let task: TodoTask
    let columnName: String
    let columnIcon: String
    let onRestore: () -> Void
    let onDelete: () -> Void

    private var priorityColor: Color {
        switch task.priority {
        case .high: .red
        case .medium: .orange
        case .low: .blue
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)

            // Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // Original column
                    HStack(spacing: 4) {
                        Image(systemName: columnIcon)
                        Text(columnName)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // Created date
                    if let completedAt = task.completedAt {
                        Text("Completed \(completedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button {
                    onRestore()
                } label: {
                    Label("Restore", systemImage: "arrow.uturn.backward")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ArchiveView()
        .modelContainer(for: [TodoTask.self, BoardColumn.self], inMemory: true)
}
