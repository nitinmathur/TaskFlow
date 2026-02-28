import SwiftUI
import SwiftData

struct FolderManagerView: View {
    @Query private var notes: [Note]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var newFolderName = ""
    @State private var editingFolder: String?
    @State private var editName = ""

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
        notes.filter { $0.folderName == folder }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Manage Folders").font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }.padding()

            Divider()

            List {
                ForEach(folders, id: \.self) { folder in
                    HStack {
                        if editingFolder == folder {
                            TextField("Folder name", text: $editName)
                                .textFieldStyle(.plain)
                                .onSubmit { saveRename(from: folder) }
                            Button("Save") { saveRename(from: folder) }
                                .buttonStyle(.borderless)
                            Button("Cancel") {
                                editingFolder = nil
                                editName = ""
                            }
                            .buttonStyle(.borderless)
                        } else {
                            Text(folder)
                            Spacer()
                            Text("\(noteCount(for: folder))").foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        if folder != "All Notes" {
                            Button("Rename") {
                                editingFolder = folder
                                editName = folder
                            }
                            Button("Delete", role: .destructive) {
                                deleteFolder(folder)
                            }
                        }
                    }
                }
            }

            Divider()

            HStack {
                TextField("New folder name", text: $newFolderName)
                Button("Add") { addFolder() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newFolderName.isEmpty)
            }.padding()
        }
        .frame(width: 300, height: 400)
    }

    private func addFolder() {
        // Folder created when first note added
        newFolderName = ""
        dismiss()
    }

    private func deleteFolder(_ folder: String) {
        let count = noteCount(for: folder)
        if count > 0 {
            // Show alert - implement in parent
        }
    }

    private func saveRename(from oldName: String) {
        let trimmed = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed != "All Notes",
              trimmed != oldName,
              !folders.contains(trimmed) else {
            editingFolder = nil
            return
        }

        // Update all notes with old folder name
        notes.filter { $0.folderName == oldName }.forEach {
            $0.folderName = trimmed
        }

        editingFolder = nil
        editName = ""
    }
}
