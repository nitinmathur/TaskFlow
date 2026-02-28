import SwiftUI
import SwiftData

struct TaskEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.name) private var categories: [Category]

    let task: TodoTask?
    @State private var title = ""
    @State private var desc = ""
    @State private var priority = Priority.medium
    @State private var selectedCategory: Category?
    @State private var hasDueDate = false
    @State private var dueDate = Date()

    private var isEditing: Bool { task != nil }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Task" : "New Task")
                    .font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("What needs to be done?", text: $title)
                            .textFieldStyle(.plain)
                            .font(.title3)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Add details...", text: $desc, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(3...5)
                    }

                    // Category & Priority row
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Category")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("", selection: $selectedCategory) {
                                Text("None").tag(nil as Category?)
                                ForEach(categories) { cat in
                                    Text(cat.name).tag(cat as Category?)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Priority")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("", selection: $priority) {
                                ForEach(Priority.allCases, id: \.self) { p in
                                    HStack {
                                        Circle()
                                            .fill(colorFor(p))
                                            .frame(width: 8, height: 8)
                                        Text(p.label)
                                    }.tag(p)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                        }
                    }

                    // Due date
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: $hasDueDate) {
                            Text("Due Date")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .toggleStyle(.checkbox)

                        if hasDueDate {
                            DatePicker("", selection: $dueDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                if isEditing {
                    Button("Delete", role: .destructive) { deleteTask() }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Save" : "Add Task") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 420)
        .onAppear { loadTask() }
    }

    private func colorFor(_ p: Priority) -> Color {
        switch p {
        case .high: .red
        case .medium: .orange
        case .low: .blue
        }
    }

    private func loadTask() {
        guard let task else { return }
        title = task.title
        desc = task.taskDescription ?? ""
        priority = task.priority
        selectedCategory = task.category
        hasDueDate = task.dueDate != nil
        dueDate = task.dueDate ?? Date()
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        if let task {
            task.title = trimmedTitle
            task.taskDescription = desc.isEmpty ? nil : desc
            task.priority = priority
            task.category = selectedCategory
            task.dueDate = hasDueDate ? dueDate : nil
        } else {
            let newTask = TodoTask(
                title: trimmedTitle,
                taskDescription: desc.isEmpty ? nil : desc,
                category: selectedCategory,
                priority: priority,
                dueDate: hasDueDate ? dueDate : nil
            )
            context.insert(newTask)
        }
        dismiss()
    }

    private func deleteTask() {
        if let task {
            context.delete(task)
        }
        dismiss()
    }
}
