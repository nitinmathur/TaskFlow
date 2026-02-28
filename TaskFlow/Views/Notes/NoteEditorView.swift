import SwiftUI
import AppKit

struct NoteEditorView: View {
    @Bindable var note: Note
    @State private var isEditing = false
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with title and toggle
            HStack {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.title.bold())
                Spacer()
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()

            Divider()

            if isEditing {
                EditModeView(note: note, onSave: debouncedSave)
            } else {
                PreviewModeView(note: note)
            }
        }
    }

    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled { note.updatedAt = Date() }
        }
    }
}

// MARK: - Edit Mode

struct EditModeView: View {
    @Bindable var note: Note
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Title field
            TextField("Title", text: $note.title)
                .font(.headline)
                .textFieldStyle(.plain)
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))

            Divider()
            FormattingToolbar(text: $note.body)
            Divider()
            MarkdownTextEditor(text: $note.body)
                .padding()
        }
        .onChange(of: note.title) { _, _ in onSave() }
        .onChange(of: note.body) { _, _ in onSave() }
    }
}

// MARK: - Preview Mode

struct PreviewModeView: View {
    let note: Note

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MarkdownRenderer(text: note.body)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
