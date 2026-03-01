import SwiftUI
import SwiftData

struct CardEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allTasks: [TodoTask]
    let task: TodoTask?
    let defaultColumn: BoardColumn
    let allColumns: [BoardColumn]
    @State private var title = ""
    @State private var desc = ""
    @State private var selectedColumnId: UUID?
    @State private var priority: Priority = .medium
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var checklist: [ChecklistItem] = []
    @State private var newItemText = ""
    private var isEditing: Bool { task != nil }

    private var selectedColumn: BoardColumn? {
        allColumns.first { $0.id == selectedColumnId }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Card" : "New Card").font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }.padding()

            Divider()

            // Form
            ScrollView {
                VStack(spacing: 16) {
                    // Basic fields
                    GroupBox("Details") {
                        VStack(spacing: 12) {
                            TextField("Title", text: $title)
                                .textFieldStyle(.plain)
                            Divider()
                            TextField("Description", text: $desc, axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.plain)
                        }
                        .padding(8)
                    }

                    // Settings
                    GroupBox("Settings") {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Column")
                                Spacer()
                                Picker("", selection: $selectedColumnId) {
                                    ForEach(allColumns.filter { !$0.isSystem }) { col in
                                        Text(col.name).tag(col.id as UUID?)
                                    }
                                }.labelsHidden().frame(width: 120)
                            }
                            Divider()
                            HStack {
                                Text("Priority")
                                Spacer()
                                Picker("", selection: $priority) {
                                    ForEach(Priority.allCases, id: \.self) { Text($0.label) }
                                }.labelsHidden().frame(width: 120)
                            }
                            Divider()
                            Toggle("Due Date", isOn: $hasDueDate)
                            if hasDueDate {
                                DatePicker("", selection: $dueDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                        }
                        .padding(8)
                    }

                    // Checklist
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            // Existing items
                            ForEach($checklist) { $item in
                                HStack {
                                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(item.isChecked ? .green : .secondary)
                                    TextField("Item", text: $item.text)
                                        .textFieldStyle(.plain)
                                    Button {
                                        checklist.removeAll { $0.id == item.id }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            // Add new item
                            HStack {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.blue)
                                TextField("Add item...", text: $newItemText)
                                    .textFieldStyle(.plain)
                                    .onSubmit { addItem() }
                                if !newItemText.isEmpty {
                                    Button("Add") { addItem() }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                }
                            }
                        }
                        .padding(8)
                    } label: {
                        Label("Checklist", systemImage: "checklist")
                    }
                }
                .padding()
            }

            Divider()

            // Actions
            HStack {
                if isEditing {
                    Button("Delete", role: .destructive) {
                        if let task { context.delete(task) }
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button(isEditing ? "Save" : "Add") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.isEmpty)
            }.padding()
        }
        .frame(width: 420, height: 520)
        .onAppear { loadTask() }
    }

    private func addItem() {
        guard !newItemText.isEmpty else { return }
        checklist.append(ChecklistItem(text: newItemText))
        newItemText = ""
    }

    private func loadTask() {
        selectedColumnId = defaultColumn.id
        guard let task else { return }
        title = task.title
        desc = task.taskDescription ?? ""
        selectedColumnId = task.columnId ?? defaultColumn.id
        priority = task.priority
        hasDueDate = task.dueDate != nil
        dueDate = task.dueDate ?? Date()
        checklist = task.checklist
    }

    private func save() {
        guard let columnId = selectedColumnId else { return }

        if let task {
            task.title = title
            task.taskDescription = desc.isEmpty ? nil : desc
            task.columnId = columnId
            task.priority = priority
            task.dueDate = hasDueDate ? dueDate : nil
            task.checklist = checklist
        } else {
            // Calculate position for new task
            let columnTasks = allTasks.filter { $0.columnId == columnId }
            let maxPosition = columnTasks.map(\.position).max() ?? -1

            let newTask = TodoTask(
                title: title,
                description: desc.isEmpty ? nil : desc,
                priority: priority,
                dueDate: hasDueDate ? dueDate : nil,
                position: maxPosition + 1
            )
            newTask.columnId = columnId
            newTask.checklist = checklist
            context.insert(newTask)
        }
        dismiss()
    }
}
