import SwiftUI
import SwiftData

enum NoteSortOption: String, CaseIterable {
    case manual = "Manual"
    case updated = "Last Updated"
    case created = "Date Created"
    case title = "Title"
}

struct NotesSplitView: View {
    @Query private var notes: [Note]
    @Environment(\.modelContext) private var context
    @State private var selectedNote: Note?
    @State private var selectedFolder = "All Notes"
    @State private var sortOption: NoteSortOption = .manual
    @State private var showFolderManager = false

    private var folders: [String] {
        var unique = Set(notes.map(\.folderName))
        unique.insert("All Notes")
        return Array(unique).sorted { f1, f2 in
            if f1 == "All Notes" { return true }
            if f2 == "All Notes" { return false }
            return f1 < f2
        }
    }

    private func noteCount(for folder: String) -> Int {
        if folder == "All Notes" {
            return notes.count
        }
        return notes.filter { $0.folderName == folder }.count
    }

    private var filteredNotes: [Note] {
        if selectedFolder == "All Notes" {
            return notes
        }
        return notes.filter { $0.folderName == selectedFolder }
    }

    private var sortedNotes: [Note] {
        switch sortOption {
        case .manual:
            return filteredNotes.sorted { $0.position < $1.position }
        case .updated:
            return filteredNotes.sorted { $0.updatedAt > $1.updatedAt }
        case .created:
            return filteredNotes.sorted { $0.createdAt > $1.createdAt }
        case .title:
            return filteredNotes.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        }
    }

    var body: some View {
        NavigationSplitView {
            // Folder sidebar
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Folders")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                // Folders list
                List(folders, id: \.self, selection: $selectedFolder) { folder in
                    HStack {
                        Image(systemName: folder == "All Notes" ? "tray.full" : "folder")
                            .foregroundStyle(folder == selectedFolder ? .blue : .secondary)
                            .frame(width: 20)
                        Text(folder)
                        Spacer()
                        Text("\(noteCount(for: folder))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(folder)
                }
                .listStyle(.sidebar)

                Divider()

                // Manage Folders button
                Button(action: { showFolderManager = true }) {
                    HStack {
                        Image(systemName: "folder.badge.gearshape")
                            .foregroundStyle(.blue)
                        Text("Manage Folders")
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(Color.blue.opacity(0.08))
            }
            .navigationTitle("Notes")
        } content: {
            // Notes list
            NotesListView(
                notes: sortedNotes,
                selectedNote: $selectedNote,
                sortOption: $sortOption,
                selectedFolder: selectedFolder,
                onAdd: addNote,
                onReorder: reorderNote
            )
        } detail: {
            // Note detail
            if let note = selectedNote {
                NoteEditorView(note: note)
            } else {
                ContentUnavailableView {
                    Label("Select a Note", systemImage: "note.text")
                } description: {
                    Text("Choose a note from the sidebar or create a new one")
                } actions: {
                    Button(action: addNote) {
                        Label("New Note", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .sheet(isPresented: $showFolderManager) {
            FolderManagerView()
        }
    }

    private func addNote() {
        let maxPosition = notes.map(\.position).max() ?? -1
        let note = Note(position: maxPosition + 1)
        // Assign folder if not "All Notes"
        if selectedFolder != "All Notes" {
            note.folderName = selectedFolder
        }
        context.insert(note)
        selectedNote = note
    }

    private func reorderNote(_ note: Note, direction: Int) {
        let sorted = sortedNotes.sorted { $0.position < $1.position }
        guard let currentIndex = sorted.firstIndex(where: { $0.id == note.id }) else { return }

        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < sorted.count else { return }

        let otherNote = sorted[newIndex]
        let tempPosition = note.position
        note.position = otherNote.position
        otherNote.position = tempPosition
    }
}

struct NotesListView: View {
    let notes: [Note]
    @Binding var selectedNote: Note?
    @Binding var sortOption: NoteSortOption
    let selectedFolder: String
    let onAdd: () -> Void
    let onReorder: (Note, Int) -> Void
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(spacing: 0) {
            // New Note button
            Button(action: onAdd) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                    Text("New Note")
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .background(Color.blue.opacity(0.08))

            // Sort picker
            HStack {
                Text("Sort:").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $sortOption) {
                    ForEach(NoteSortOption.allCases, id: \.self) { Text($0.rawValue) }
                }
                .labelsHidden()
                .controlSize(.small)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Notes list
            if notes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No Notes Yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(selectedFolder == "All Notes" ? "Create your first note" : "No notes in this folder")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedNote) {
                    ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title.isEmpty ? "Untitled" : note.title)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                HStack {
                                    // Show folder if viewing "All Notes"
                                    if selectedFolder == "All Notes" && note.folderName != "All Notes" {
                                        Image(systemName: "folder")
                                            .font(.caption2)
                                        Text(note.folderName)
                                        Text("•")
                                    }
                                    Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    if !note.body.isEmpty {
                                        Text("•")
                                        Text(note.body.prefix(20) + (note.body.count > 20 ? "..." : ""))
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            }

                            Spacer()

                            // Reorder buttons (only in manual mode)
                            if sortOption == .manual {
                                VStack(spacing: 0) {
                                    Button { onReorder(note, -1) } label: {
                                        Image(systemName: "chevron.up")
                                            .font(.caption2)
                                            .frame(width: 18, height: 14)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(index == 0)
                                    .opacity(index == 0 ? 0.3 : 1)

                                    Button { onReorder(note, 1) } label: {
                                        Image(systemName: "chevron.down")
                                            .font(.caption2)
                                            .frame(width: 18, height: 14)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(index == notes.count - 1)
                                    .opacity(index == notes.count - 1 ? 0.3 : 1)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                        .tag(note)
                        .contextMenu {
                            if sortOption == .manual {
                                Button("Move to Top") {
                                    moveToTop(note)
                                }
                                Button("Move to Bottom") {
                                    moveToBottom(note)
                                }
                                Divider()
                            }
                            Button("Delete", role: .destructive) {
                                if selectedNote == note { selectedNote = nil }
                                context.delete(note)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .navigationTitle(selectedFolder)
    }

    private func moveToTop(_ note: Note) {
        let minPosition = notes.map(\.position).min() ?? 0
        note.position = minPosition - 1
    }

    private func moveToBottom(_ note: Note) {
        let maxPosition = notes.map(\.position).max() ?? 0
        note.position = maxPosition + 1
    }
}
