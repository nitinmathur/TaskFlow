import SwiftUI

struct KanbanCardView: View {
    let task: TodoTask
    let onEdit: () -> Void
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
            Rectangle().fill(priorityColor).frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title).font(.subheadline.weight(.medium)).lineLimit(2)
                if let desc = task.taskDescription, !desc.isEmpty {
                    Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                if let due = task.dueDate {
                    HStack {
                        Image(systemName: "calendar")
                        Text(due.formatted(date: .abbreviated, time: .omitted))
                    }
                    .font(.caption2)
                    .foregroundStyle(Calendar.current.isDateInToday(due) ? .orange : .secondary)
                }
            }
            .padding(8)
            Spacer()
            if isHovering {
                Button { context.delete(task) } label: {
                    Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).padding(6)
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        .onTapGesture { onEdit() }
        .onHover { isHovering = $0 }
        .contextMenu { Button("Delete", role: .destructive) { context.delete(task) } }
    }
}
