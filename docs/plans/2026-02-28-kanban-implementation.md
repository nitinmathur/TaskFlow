# Kanban Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform TaskFlow from list-based to Kanban board with drag-drop and add Notes feature.

**Architecture:** Tab-based UI with Kanban board (4 columns with drag-drop) and Notes (split view with Markdown editor). Evolve existing TodoTask model, add Note model.

**Tech Stack:** SwiftUI, SwiftData, macOS 14+

---

## Task 1: Create Column Enum

**Files:**
- Create: `TaskFlow/Models/Column.swift`

**Step 1: Create Column enum**

```swift
import Foundation

enum Column: String, Codable, CaseIterable {
    case work
    case personal
    case ideas
    case completed

    var title: String {
        switch self {
        case .work: "Work"
        case .personal: "Personal"
        case .ideas: "Ideas"
        case .completed: "Completed"
        }
    }

    var icon: String {
        switch self {
        case .work: "briefcase.fill"
        case .personal: "person.fill"
        case .ideas: "lightbulb.fill"
        case .completed: "checkmark.circle.fill"
        }
    }
}
```

**Step 2: Verify compilation**

Run: `xcodegen generate && xcodebuild -scheme TaskFlow -configuration Debug build`

**Step 3: Commit**

```bash
git add TaskFlow/Models/Column.swift
git commit -m "feat: add Column enum for Kanban columns"
```

---

## Task 2: Update TodoTask Model

**Files:**
- Modify: `TaskFlow/Models/TodoTask.swift`

**Step 1: Replace category with column and add position**

```swift
import Foundation
import SwiftData

enum Priority: Int, Codable, CaseIterable {
    case high = 0
    case medium = 1
    case low = 2

    var label: String {
        switch self {
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        }
    }
}

@Model
final class TodoTask {
    var id: UUID = UUID()
    var title: String = ""
    var taskDescription: String?
    var columnRaw: String = Column.work.rawValue
    var priorityRaw: Int = Priority.medium.rawValue
    var position: Int = 0
    var dueDate: Date?
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var completedAt: Date?

    var column: Column {
        get { Column(rawValue: columnRaw) ?? .work }
        set { columnRaw = newValue.rawValue }
    }

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    init(title: String, description: String? = nil, column: Column = .work,
         priority: Priority = .medium, dueDate: Date? = nil, position: Int = 0) {
        self.id = UUID()
        self.title = title
        self.taskDescription = description
        self.columnRaw = column.rawValue
        self.priorityRaw = priority.rawValue
        self.position = position
        self.dueDate = dueDate
        self.createdAt = Date()
    }
}
```

**Step 2: Verify compilation**

**Step 3: Commit**

```bash
git add TaskFlow/Models/TodoTask.swift
git commit -m "feat: update TodoTask with column and position fields"
```

---

## Task 3: Create Note Model

**Files:**
- Create: `TaskFlow/Models/Note.swift`

**Step 1: Create Note model**

```swift
import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(title: String = "Untitled", body: String = "") {
        self.id = UUID()
        self.title = title
        self.body = body
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

**Step 2: Verify compilation**

**Step 3: Commit**

```bash
git add TaskFlow/Models/Note.swift
git commit -m "feat: add Note model with Markdown body support"
```

---

## Task 4: Update SwiftData Schema

**Files:**
- Modify: `TaskFlow/TaskFlowApp.swift`

**Step 1: Add Note to schema, remove Category**

Update schema line:
```swift
let schema = Schema([TodoTask.self, Note.self])
```

**Step 2: Verify app launches**

**Step 3: Commit**

```bash
git add TaskFlow/TaskFlowApp.swift
git commit -m "feat: update SwiftData schema with Note, remove Category"
```

---

## Task 5: Create MainTabView

**Files:**
- Create: `TaskFlow/Views/MainTabView.swift`
- Modify: `TaskFlow/TaskFlowApp.swift`

**Step 1: Create tab container**

```swift
import SwiftUI

enum AppTab {
    case tasks, notes
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .tasks

    var body: some View {
        TabView(selection: $selectedTab) {
            KanbanBoardView()
                .tabItem {
                    Label("Tasks", systemImage: "checkmark.square")
                }
                .tag(AppTab.tasks)

            NotesSplitView()
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
                .tag(AppTab.notes)
        }
        .frame(minWidth: 900, minHeight: 500)
    }
}
```

**Step 2: Update TaskFlowApp to use MainTabView**

Replace `ContentView()` with `MainTabView()` in body.

**Step 3: Commit**

```bash
git add TaskFlow/Views/MainTabView.swift TaskFlow/TaskFlowApp.swift
git commit -m "feat: add tab-based MainTabView container"
```

---

## Task 6: Create KanbanBoardView

**Files:**
- Create: `TaskFlow/Views/Kanban/KanbanBoardView.swift`

**Step 1: Create board with 4 columns**

```swift
import SwiftUI
import SwiftData

struct KanbanBoardView: View {
    @Query private var tasks: [TodoTask]
    @State private var showCardEditor = false
    @State private var editingTask: TodoTask?
    @State private var newCardColumn: Column?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(Column.allCases, id: \.self) { column in
                KanbanColumnView(
                    column: column,
                    tasks: tasks.filter { $0.column == column }.sorted { $0.position < $1.position },
                    onAddCard: { newCardColumn = column; showCardEditor = true },
                    onEditCard: { task in editingTask = task; showCardEditor = true },
                    onMoveCard: { task, newCol in moveCard(task, to: newCol) }
                )
            }
        }
        .padding()
        .sheet(isPresented: $showCardEditor) {
            CardEditorView(task: editingTask, defaultColumn: newCardColumn ?? .work)
        }
        .onChange(of: showCardEditor) { _, isShowing in
            if !isShowing { editingTask = nil; newCardColumn = nil }
        }
    }

    private func moveCard(_ task: TodoTask, to column: Column) {
        task.column = column
        if column == .completed {
            task.isCompleted = true
            task.completedAt = Date()
        } else if task.isCompleted {
            task.isCompleted = false
            task.completedAt = nil
        }
    }
}
```

**Step 2: Commit**

```bash
mkdir -p TaskFlow/Views/Kanban
git add TaskFlow/Views/Kanban/KanbanBoardView.swift
git commit -m "feat: add KanbanBoardView with 4-column layout"
```

---

## Task 7: Create KanbanColumnView

**Files:**
- Create: `TaskFlow/Views/Kanban/KanbanColumnView.swift`

**Step 1: Create column with drop target**

```swift
import SwiftUI

struct KanbanColumnView: View {
    let column: Column
    let tasks: [TodoTask]
    let onAddCard: () -> Void
    let onEditCard: (TodoTask) -> Void
    let onMoveCard: (TodoTask, Column) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: column.icon)
                Text(column.title)
                    .font(.headline)
                Spacer()
                Text("\(tasks.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)

            // Cards
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(tasks) { task in
                        KanbanCardView(task: task, onEdit: { onEditCard(task) })
                            .draggable(task.id.uuidString)
                    }
                }
                .padding(.horizontal, 4)
            }

            // Add button (not for completed)
            if column != .completed {
                Button(action: onAddCard) {
                    Label("Add Card", systemImage: "plus")
                        .frame(maxWidth: .infinity)
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
            handleDrop(items)
        }
    }

    private func handleDrop(_ items: [String]) -> Bool {
        // Will be connected to actual task lookup in Task 9
        return true
    }
}
```

**Step 2: Commit**

```bash
git add TaskFlow/Views/Kanban/KanbanColumnView.swift
git commit -m "feat: add KanbanColumnView with drag-drop support"
```

---

## Task 8: Create KanbanCardView

**Files:**
- Create: `TaskFlow/Views/Kanban/KanbanCardView.swift`

**Step 1: Create card with priority border**

```swift
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
            // Priority border
            Rectangle()
                .fill(priorityColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                if let desc = task.taskDescription, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let due = task.dueDate {
                    HStack {
                        Image(systemName: "calendar")
                        Text(due.formatted(date: .abbreviated, time: .omitted))
                    }
                    .font(.caption2)
                    .foregroundStyle(isDueToday(due) ? .orange : .secondary)
                }
            }
            .padding(8)

            Spacer()

            if isHovering {
                Button { context.delete(task) } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(6)
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        .onTapGesture { onEdit() }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Delete", role: .destructive) { context.delete(task) }
        }
    }

    private func isDueToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}
```

**Step 2: Commit**

```bash
git add TaskFlow/Views/Kanban/KanbanCardView.swift
git commit -m "feat: add KanbanCardView with priority border"
```

---

## Task 9: Create CardEditorView

**Files:**
- Create: `TaskFlow/Views/Kanban/CardEditorView.swift`

**Step 1: Create card editor sheet**

```swift
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
            headerView
            Divider()
            formView
            Divider()
            footerView
        }
        .frame(width: 400, height: 400)
        .onAppear { loadTask() }
    }

    private var headerView: some View {
        HStack {
            Text(isEditing ? "Edit Card" : "New Card")
                .font(.headline)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    private var formView: some View {
        Form {
            TextField("Title", text: $title)
            TextField("Description", text: $desc, axis: .vertical)
                .lineLimit(3...5)
            Picker("Column", selection: $column) {
                ForEach(Column.allCases, id: \.self) { Text($0.title) }
            }
            Picker("Priority", selection: $priority) {
                ForEach(Priority.allCases, id: \.self) { Text($0.label) }
            }
            Toggle("Due Date", isOn: $hasDueDate)
            if hasDueDate {
                DatePicker("Date", selection: $dueDate, displayedComponents: .date)
            }
        }
        .formStyle(.grouped)
    }

    private var footerView: some View {
        HStack {
            if isEditing {
                Button("Delete", role: .destructive) { deleteTask() }
            }
            Spacer()
            Button("Cancel") { dismiss() }
            Button(isEditing ? "Save" : "Add") { save() }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)
        }
        .padding()
    }

    private func loadTask() {
        column = defaultColumn
        guard let task else { return }
        title = task.title
        desc = task.taskDescription ?? ""
        column = task.column
        priority = task.priority
        hasDueDate = task.dueDate != nil
        dueDate = task.dueDate ?? Date()
    }

    private func save() {
        if let task {
            task.title = title
            task.taskDescription = desc.isEmpty ? nil : desc
            task.column = column
            task.priority = priority
            task.dueDate = hasDueDate ? dueDate : nil
        } else {
            let newTask = TodoTask(title: title, description: desc.isEmpty ? nil : desc,
                                   column: column, priority: priority,
                                   dueDate: hasDueDate ? dueDate : nil)
            context.insert(newTask)
        }
        dismiss()
    }

    private func deleteTask() {
        if let task { context.delete(task) }
        dismiss()
    }
}
```

**Step 2: Commit**

```bash
git add TaskFlow/Views/Kanban/CardEditorView.swift
git commit -m "feat: add CardEditorView for creating/editing cards"
```

---

## Task 10: Create NotesSplitView

**Files:**
- Create: `TaskFlow/Views/Notes/NotesSplitView.swift`
- Create: `TaskFlow/Views/Notes/NotesListView.swift`

**Step 1: Create split view container**

```swift
import SwiftUI
import SwiftData

struct NotesSplitView: View {
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @Environment(\.modelContext) private var context
    @State private var selectedNote: Note?

    var body: some View {
        NavigationSplitView {
            NotesListView(notes: notes, selectedNote: $selectedNote, onAdd: addNote)
        } detail: {
            if let note = selectedNote {
                NoteEditorView(note: note)
            } else {
                ContentUnavailableView("Select a Note", systemImage: "note.text",
                    description: Text("Choose a note from the list or create a new one"))
            }
        }
    }

    private func addNote() {
        let note = Note()
        context.insert(note)
        selectedNote = note
    }
}
```

**Step 2: Create notes list**

```swift
import SwiftUI

struct NotesListView: View {
    let notes: [Note]
    @Binding var selectedNote: Note?
    let onAdd: () -> Void
    @Environment(\.modelContext) private var context

    var body: some View {
        List(selection: $selectedNote) {
            ForEach(notes) { note in
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .font(.headline)
                    Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(note)
                .contextMenu {
                    Button("Delete", role: .destructive) { context.delete(note) }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Notes")
        .toolbar {
            Button(action: onAdd) {
                Image(systemName: "plus")
            }
        }
    }
}
```

**Step 3: Commit**

```bash
mkdir -p TaskFlow/Views/Notes
git add TaskFlow/Views/Notes/NotesSplitView.swift TaskFlow/Views/Notes/NotesListView.swift
git commit -m "feat: add NotesSplitView and NotesListView"
```

---

## Task 11: Create NoteEditorView

**Files:**
- Create: `TaskFlow/Views/Notes/NoteEditorView.swift`

**Step 1: Create Markdown editor with auto-save**

```swift
import SwiftUI

struct NoteEditorView: View {
    @Bindable var note: Note
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Title", text: $note.title)
                .font(.title.bold())
                .textFieldStyle(.plain)
                .padding()

            Divider()

            TextEditor(text: $note.body)
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
                .padding()
        }
        .onChange(of: note.title) { _, _ in debouncedSave() }
        .onChange(of: note.body) { _, _ in debouncedSave() }
    }

    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled {
                note.updatedAt = Date()
            }
        }
    }
}
```

**Step 2: Commit**

```bash
git add TaskFlow/Views/Notes/NoteEditorView.swift
git commit -m "feat: add NoteEditorView with auto-save"
```

---

## Task 12: Delete Old Views and Cleanup

**Files:**
- Delete: `TaskFlow/Views/ContentView.swift`
- Delete: `TaskFlow/Views/SidebarView.swift`
- Delete: `TaskFlow/Views/TaskListView.swift`
- Delete: `TaskFlow/Views/TaskRowView.swift`
- Delete: `TaskFlow/Views/TaskEditorView.swift`
- Delete: `TaskFlow/Views/CategoryManagerView.swift`
- Delete: `TaskFlow/Models/Category.swift`
- Delete: `TaskFlow/Utilities/DefaultDataSeeder.swift`

**Step 1: Remove old files**

```bash
rm TaskFlow/Views/ContentView.swift
rm TaskFlow/Views/SidebarView.swift
rm TaskFlow/Views/TaskListView.swift
rm TaskFlow/Views/TaskRowView.swift
rm TaskFlow/Views/TaskEditorView.swift
rm TaskFlow/Views/CategoryManagerView.swift
rm TaskFlow/Models/Category.swift
rm TaskFlow/Utilities/DefaultDataSeeder.swift
```

**Step 2: Update TaskFlowApp.swift - remove seeder**

Remove the `.onAppear` block calling DefaultDataSeeder.

**Step 3: Verify build**

```bash
xcodegen generate && xcodebuild -scheme TaskFlow build
```

**Step 4: Commit**

```bash
git add -A
git commit -m "refactor: remove old list-based views, cleanup"
```

---

## Task 13: Wire Up Drag-Drop

**Files:**
- Modify: `TaskFlow/Views/Kanban/KanbanBoardView.swift`
- Modify: `TaskFlow/Views/Kanban/KanbanColumnView.swift`

**Step 1: Add task lookup for drop handling**

In KanbanBoardView, add method:
```swift
func findTask(by id: String) -> TodoTask? {
    tasks.first { $0.id.uuidString == id }
}
```

Pass this to columns and wire up `handleDrop` to call `onMoveCard`.

**Step 2: Test drag-drop between columns**

**Step 3: Commit**

```bash
git add TaskFlow/Views/Kanban/
git commit -m "feat: complete drag-drop wiring between columns"
```

---

## Task 14: Final Testing & Polish

**Step 1: Manual testing checklist**
- [ ] Create cards in Work/Personal/Ideas
- [ ] Drag cards between columns
- [ ] Move card to Completed (verify completedAt set)
- [ ] Move card out of Completed (verify completedAt cleared)
- [ ] Edit card (title, desc, priority, due date)
- [ ] Delete card
- [ ] Create notes
- [ ] Edit note title and body
- [ ] Verify auto-save works
- [ ] Delete note
- [ ] Verify iCloud sync between Macs

**Step 2: Final commit**

```bash
git add -A
git commit -m "feat: complete Kanban redesign with Notes"
```
