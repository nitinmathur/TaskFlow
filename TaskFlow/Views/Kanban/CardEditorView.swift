import SwiftUI
import SwiftData

struct CardEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let task: TodoTask?
    let defaultColumn: Column
    @State private var title = ""
    @State private var desc = ""
    @State private var column: Column = .work
    @State private var priority: Priority = .medium
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    private var isEditing: Bool { task != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "Edit Card" : "New Card").font(.headline)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain)
            }.padding()
            Divider()
            Form {
                TextField("Title", text: $title)
                TextField("Description", text: $desc, axis: .vertical).lineLimit(3...5)
                Picker("Column", selection: $column) { ForEach(Column.allCases, id: \.self) { Text($0.title) } }
                Picker("Priority", selection: $priority) { ForEach(Priority.allCases, id: \.self) { Text($0.label) } }
                Toggle("Due Date", isOn: $hasDueDate)
                if hasDueDate { DatePicker("Date", selection: $dueDate, displayedComponents: .date) }
            }.formStyle(.grouped)
            Divider()
            HStack {
                if isEditing { Button("Delete", role: .destructive) { if let task { context.delete(task) }; dismiss() } }
                Spacer()
                Button("Cancel") { dismiss() }
                Button(isEditing ? "Save" : "Add") { save() }.buttonStyle(.borderedProminent).disabled(title.isEmpty)
            }.padding()
        }
        .frame(width: 400, height: 400)
        .onAppear { loadTask() }
    }

    private func loadTask() {
        column = defaultColumn
        guard let task else { return }
        title = task.title; desc = task.taskDescription ?? ""; column = task.column
        priority = task.priority; hasDueDate = task.dueDate != nil; dueDate = task.dueDate ?? Date()
    }

    private func save() {
        if let task {
            task.title = title; task.taskDescription = desc.isEmpty ? nil : desc
            task.column = column; task.priority = priority; task.dueDate = hasDueDate ? dueDate : nil
        } else {
            context.insert(TodoTask(title: title, description: desc.isEmpty ? nil : desc, column: column, priority: priority, dueDate: hasDueDate ? dueDate : nil))
        }
        dismiss()
    }
}
