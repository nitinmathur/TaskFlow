import SwiftUI
import SwiftData

struct CardDetailView: View {
    @Bindable var task: TodoTask
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onArchive: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BoardColumn.position) private var columns: [BoardColumn]

    private var taskColumn: BoardColumn? {
        columns.first { $0.id == task.columnId }
    }

    private var priorityColor: Color {
        switch task.priority {
        case .high: .red
        case .medium: .orange
        case .low: .blue
        }
    }

    private var checklistProgress: (checked: Int, total: Int) {
        let items = task.checklist
        return (items.filter(\.isChecked).count, items.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Circle().fill(priorityColor).frame(width: 10, height: 10)
                Text(task.priority.label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.tertiary)
                }.buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(task.title)
                        .font(.title2.weight(.semibold))
                        .textSelection(.enabled)

                    // Column badge
                    if let col = taskColumn {
                        HStack {
                            Image(systemName: col.icon)
                            Text(col.name)
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(columnColor.opacity(0.15))
                        .foregroundStyle(columnColor)
                        .clipShape(Capsule())
                    }

                    // Due date
                    if let due = task.dueDate {
                        HStack {
                            Image(systemName: "calendar")
                            Text("Due: \(due.formatted(date: .long, time: .omitted))")
                        }
                        .font(.subheadline)
                        .foregroundStyle(dueDateColor(due))
                    }

                    // Description
                    if let desc = task.taskDescription, !desc.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text(desc)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Checklist
                    if !task.checklist.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            // Header with progress
                            HStack {
                                Text("Checklist")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(checklistProgress.checked)/\(checklistProgress.total)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }

                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.secondary.opacity(0.2))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.green)
                                        .frame(width: geo.size.width * progressFraction)
                                }
                            }
                            .frame(height: 4)

                            // Items
                            VStack(spacing: 8) {
                                ForEach(task.checklist) { item in
                                    ChecklistItemRow(
                                        item: item,
                                        onToggle: { toggleItem(item) }
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(.quaternary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Metadata
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Created: \(task.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        if let completed = task.completedAt {
                            Text("Completed: \(completed.formatted(date: .abbreviated, time: .shortened))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
                .padding()
            }

            Divider()

            // Actions
            HStack {
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                if let onArchive = onArchive {
                    Button {
                        onArchive()
                        dismiss()
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onEdit() }
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 420, height: 500)
    }

    private var progressFraction: CGFloat {
        guard checklistProgress.total > 0 else { return 0 }
        return CGFloat(checklistProgress.checked) / CGFloat(checklistProgress.total)
    }

    private func toggleItem(_ item: ChecklistItem) {
        var items = task.checklist
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].isChecked.toggle()
            task.checklist = items
        }
    }

    private var columnColor: Color {
        guard let col = taskColumn else { return .gray }
        switch col.icon {
        case "briefcase.fill": return .blue
        case "person.fill": return .green
        case "lightbulb.fill": return .purple
        case "checkmark.circle.fill": return .gray
        default:
            // Generate color based on position for custom columns
            let colors: [Color] = [.blue, .green, .purple, .orange, .pink, .cyan, .mint, .indigo]
            return colors[col.position % colors.count]
        }
    }

    private func dueDateColor(_ date: Date) -> Color {
        if Calendar.current.isDateInToday(date) { return .orange }
        if date < Date() { return .red }
        return .secondary
    }
}

struct ChecklistItemRow: View {
    let item: ChecklistItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(item.isChecked ? .green : .secondary)
                Text(item.text)
                    .font(.body)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
