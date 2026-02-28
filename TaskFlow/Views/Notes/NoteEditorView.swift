import SwiftUI

struct NoteEditorView: View {
    @Bindable var note: Note
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Title", text: $note.title).font(.title.bold()).textFieldStyle(.plain).padding()
            Divider()
            TextEditor(text: $note.body).font(.body.monospaced()).scrollContentBackground(.hidden).padding()
        }
        .onChange(of: note.title) { _, _ in debouncedSave() }
        .onChange(of: note.body) { _, _ in debouncedSave() }
    }

    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled { note.updatedAt = Date() }
        }
    }
}
