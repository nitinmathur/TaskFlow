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
                ContentUnavailableView("Select a Note", systemImage: "note.text", description: Text("Choose a note or create new"))
            }
        }
    }

    private func addNote() {
        let note = Note()
        context.insert(note)
        selectedNote = note
    }
}

struct NotesListView: View {
    let notes: [Note]
    @Binding var selectedNote: Note?
    let onAdd: () -> Void
    @Environment(\.modelContext) private var context

    var body: some View {
        List(selection: $selectedNote) {
            ForEach(notes) { note in
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title.isEmpty ? "Untitled" : note.title).font(.headline)
                    Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                }
                .tag(note)
                .contextMenu { Button("Delete", role: .destructive) { context.delete(note) } }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Notes")
        .toolbar { Button(action: onAdd) { Image(systemName: "plus") } }
    }
}
