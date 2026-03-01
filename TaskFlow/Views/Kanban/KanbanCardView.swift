import SwiftUI

struct KanbanCardView: View {
    let task: TodoTask
    let onTap: () -> Void
    @Environment(\.modelContext) private var context
    @State private var isHovering = false

    private var priorityColor: Color {
        switch task.priority {
        case .high: .red
        case .medium: .orange
        case .low: .blue
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Priority indicator bar
            RoundedRectangle(cornerRadius: 2)
                .fill(priorityColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                // Description preview
                if let desc = task.taskDescription, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Date badges row
                HStack(spacing: 6) {
                    // Created date
                    HStack(spacing: 3) {
                        Image(systemName: "plus.circle")
                        Text(task.createdAt.formatted(date: .abbreviated, time: .omitted))
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                    // Due date badge
                    if let due = task.dueDate {
                        HStack(spacing: 3) {
                            Image(systemName: dueDateIcon(due))
                            Text(due.formatted(date: .abbreviated, time: .omitted))
                        }
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(dueDateColor(due).opacity(0.15))
                        .foregroundStyle(dueDateColor(due))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    // Checklist progress
                    if !task.checklist.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "checklist")
                            Text("\(task.checklist.filter(\.isChecked).count)/\(task.checklist.count)")
                        }
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(checklistColor.opacity(0.15))
                        .foregroundStyle(checklistColor)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)

            Spacer(minLength: 0)

            // Delete button on hover
            if isHovering {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        context.delete(task)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(6)
                .transition(.opacity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor))
                .shadow(color: .black.opacity(isHovering ? 0.12 : 0.06), radius: isHovering ? 6 : 3, y: isHovering ? 3 : 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(isHovering ? 0.1 : 0), lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onTapGesture { onTap() }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("View Details") { onTap() }
            Divider()
            Button {
                task.isArchived = true
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            Button("Delete", role: .destructive) { context.delete(task) }
        }
    }

    private func dueDateColor(_ date: Date) -> Color {
        if Calendar.current.isDateInToday(date) { return .orange }
        if date < Date() { return .red }
        return .secondary
    }

    private func dueDateIcon(_ date: Date) -> String {
        if date < Date() { return "exclamationmark.circle.fill" }
        if Calendar.current.isDateInToday(date) { return "clock.fill" }
        return "calendar"
    }

    private var checklistColor: Color {
        let items = task.checklist
        let checked = items.filter(\.isChecked).count
        if checked == items.count { return .green }
        if checked > 0 { return .blue }
        return .secondary
    }
}
