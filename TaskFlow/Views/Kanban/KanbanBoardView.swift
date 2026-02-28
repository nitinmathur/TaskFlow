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
                    allTasks: tasks,
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
