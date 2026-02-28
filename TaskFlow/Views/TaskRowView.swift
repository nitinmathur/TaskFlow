import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: TodoTask
    @Environment(\.modelContext) private var context
    var showTimestamp: Bool
    var onTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button { toggleComplete() } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : priorityColor.opacity(0.7))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .fontWeight(.medium)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                HStack(spacing: 8) {
                    // Priority dot
                    HStack(spacing: 4) {
                        Circle().fill(priorityColor).frame(width: 6, height: 6)
                        Text(task.priority.label)
                    }

                    if let date = task.dueDate {
                        Text("•")
                        Label(formatDueDate(date), systemImage: "calendar")
                            .foregroundStyle(isOverdue(date) ? .red : isDueToday(date) ? .orange : .secondary)
                    }

                    if showTimestamp {
                        Text("•")
                        if task.isCompleted, let completed = task.completedAt {
                            Text("Done \(timeAgo(completed))")
                                .foregroundStyle(.green)
                        } else {
                            Text(timeAgo(task.createdAt))
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let cat = task.category {
                Text(cat.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(cat.name == "Work" ? Color.indigo.opacity(0.15) : Color.green.opacity(0.15))
                    .foregroundStyle(cat.name == "Work" ? .indigo : .green)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu {
            if !task.isCompleted {
                Button { toggleComplete() } label: {
                    Label("Complete", systemImage: "checkmark.circle")
                }
            }
            Button("Delete", role: .destructive) { context.delete(task) }
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case .high: .red
        case .medium: .orange
        case .low: .blue
        }
    }

    private func toggleComplete() {
        withAnimation(.easeInOut(duration: 0.2)) {
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? Date() : nil
        }
    }

    private func isOverdue(_ date: Date) -> Bool {
        date < Calendar.current.startOfDay(for: Date())
    }

    private func isDueToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    private func formatDueDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
