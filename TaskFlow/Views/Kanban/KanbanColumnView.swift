import SwiftUI

struct KanbanColumnView: View {
    let column: Column
    let tasks: [TodoTask]
    let allTasks: [TodoTask]
    let onAddCard: () -> Void
    let onEditCard: (TodoTask) -> Void
    let onMoveCard: (TodoTask, Column) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: column.icon)
                Text(column.title).font(.headline)
                Spacer()
                Text("\(tasks.count)").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(tasks) { task in
                        KanbanCardView(task: task, onEdit: { onEditCard(task) })
                            .draggable(task.id.uuidString)
                    }
                }
                .padding(.horizontal, 4)
            }

            if column != .completed {
                Button(action: onAddCard) {
                    Label("Add Card", systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(8)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .frame(width: 260)
        .padding(8)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .dropDestination(for: String.self) { items, _ in
            guard let taskIdString = items.first,
                  let taskId = UUID(uuidString: taskIdString),
                  let task = allTasks.first(where: { $0.id == taskId }) else { return false }
            onMoveCard(task, column)
            return true
        }
    }
}
