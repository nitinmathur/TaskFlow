import SwiftUI

struct KanbanColumnView: View {
    @Bindable var column: BoardColumn
    let tasks: [TodoTask]
    let allTasks: [TodoTask]
    let groupByDate: Bool
    let sortOption: SortOption
    let onAddCard: () -> Void
    let onViewCard: (TodoTask) -> Void
    let onMoveCard: (TodoTask, BoardColumn) -> Void
    let onReorder: (TodoTask, Int) -> Void
    var onDeleteColumn: () -> Void = {}
    var onMoveColumnLeft: () -> Void = {}
    var onMoveColumnRight: () -> Void = {}
    var canMoveLeft: Bool = false
    var canMoveRight: Bool = false

    // Color based on column icon or position
    private var columnColor: Color {
        switch column.icon {
        case "briefcase.fill": return .blue
        case "person.fill": return .green
        case "lightbulb.fill": return .purple
        case "checkmark.circle.fill": return .gray
        default:
            // Generate color based on position for custom columns
            let colors: [Color] = [.blue, .green, .purple, .orange, .pink, .cyan, .mint, .indigo]
            return colors[column.position % colors.count]
        }
    }

    // Group tasks by creation date
    private var groupedTasks: [(String, [TodoTask])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: tasks) { task -> String in
            if calendar.isDateInToday(task.createdAt) {
                return "Today"
            } else if calendar.isDateInYesterday(task.createdAt) {
                return "Yesterday"
            } else if calendar.isDate(task.createdAt, equalTo: Date(), toGranularity: .weekOfYear) {
                return "This Week"
            } else {
                return task.createdAt.formatted(.dateTime.month(.wide).year())
            }
        }

        let order = ["Today", "Yesterday", "This Week"]
        return grouped.sorted { g1, g2 in
            let idx1 = order.firstIndex(of: g1.key) ?? Int.max
            let idx2 = order.firstIndex(of: g2.key) ?? Int.max
            if idx1 != Int.max || idx2 != Int.max {
                return idx1 < idx2
            }
            return (g1.value.first?.createdAt ?? .distantPast) > (g2.value.first?.createdAt ?? .distantPast)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Column Header
            ColumnHeaderView(
                column: column,
                taskCount: tasks.count,
                onDelete: onDeleteColumn,
                onMoveLeft: onMoveColumnLeft,
                onMoveRight: onMoveColumnRight,
                canMoveLeft: canMoveLeft,
                canMoveRight: canMoveRight
            )

            // Cards
            ScrollView {
                LazyVStack(spacing: 10) {
                    if groupByDate {
                        ForEach(groupedTasks, id: \.0) { group in
                            HStack {
                                Text(group.0)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(group.1.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, group.0 == groupedTasks.first?.0 ? 0 : 8)

                            ForEach(Array(group.1.enumerated()), id: \.element.id) { index, task in
                                cardRow(task: task, index: index, total: group.1.count)
                            }
                        }
                    } else {
                        ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                            cardRow(task: task, index: index, total: tasks.count)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

            // Add Button (hide for system/completed columns)
            if !column.isSystem {
                Button(action: onAddCard) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(columnColor)
                        Text("Add Card")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 10)
                .background(columnColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 280)
        .frame(minHeight: 400)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let taskIdString = items.first,
                  let taskId = UUID(uuidString: taskIdString),
                  let task = allTasks.first(where: { $0.id == taskId }) else { return false }
            onMoveCard(task, column)
            return true
        }
    }

    @ViewBuilder
    private func cardRow(task: TodoTask, index: Int, total: Int) -> some View {
        HStack(spacing: 4) {
            KanbanCardView(task: task, onTap: { onViewCard(task) })
                .draggable(task.id.uuidString)

            // Reorder buttons (only in manual mode)
            if sortOption == .manual {
                VStack(spacing: 2) {
                    Button {
                        onReorder(task, -1)
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.caption2)
                            .frame(width: 20, height: 16)
                    }
                    .buttonStyle(.plain)
                    .disabled(index == 0)
                    .opacity(index == 0 ? 0.3 : 1)

                    Button {
                        onReorder(task, 1)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .frame(width: 20, height: 16)
                    }
                    .buttonStyle(.plain)
                    .disabled(index == total - 1)
                    .opacity(index == total - 1 ? 0.3 : 1)
                }
                .padding(2)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}
