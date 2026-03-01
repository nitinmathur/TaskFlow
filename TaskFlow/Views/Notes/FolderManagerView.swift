import SwiftUI
import SwiftData

struct FolderManagerView: View {
    @Query private var notes: [Note]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var newFolderName = ""
    @State private var editingFolder: String?
    @State private var editName = ""
    @State private var showDeleteAlert = false
    @State private var folderToDelete: String?

    @AppStorage("customFolders") private var customFoldersData: Data = Data()

    private var customFolders: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: customFoldersData)) ?? []
        }
    }

    private func saveCustomFolders(_ folders: Set<String>) {
        customFoldersData = (try? JSONEncoder().encode(folders)) ?? Data()
    }

    private var folders: [String] {
        var unique = Set(notes.map(\.folderName))
        unique.formUnion(customFolders)
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
                    let count = noteCount(for: folder)
                    let canDelete = folder != "All Notes" && count == 0

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
                            Image(systemName: folder == "All Notes" ? "tray.full" : "folder")
                                .foregroundStyle(folder == "All Notes" ? .blue : .secondary)
                            Text(folder)
                            Spacer()
                            Text("\(count)").foregroundStyle(.secondary)
                            if folder != "All Notes" {
                                Button {
                                    if canDelete {
                                        deleteFolder(folder)
                                    } else {
                                        folderToDelete = folder
                                        showDeleteAlert = true
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(canDelete ? .red : .secondary.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                                .help(canDelete ? "Delete empty folder" : "Has notes - cannot delete")
                            }
                        }
                    }
                    .contextMenu {
                        if folder != "All Notes" {
                            Button("Rename") {
                                editingFolder = folder
                                editName = folder
                            }
                            Button("Delete", role: .destructive) {
                                if count > 0 {
                                    folderToDelete = folder
                                    showDeleteAlert = true
                                } else {
                                    deleteFolder(folder)
                                }
                            }
                            .disabled(count > 0)
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
        .alert("Cannot Delete Folder", isPresented: $showDeleteAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let folder = folderToDelete {
                Text("'\(folder)' contains \(noteCount(for: folder)) note(s). Move or delete the notes first.")
            }
        }
    }

    private func addFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed != "All Notes",
              !folders.contains(trimmed) else {
            newFolderName = ""
            return
        }

        var updated = customFolders
        updated.insert(trimmed)
        saveCustomFolders(updated)
        newFolderName = ""
    }

    private func deleteFolder(_ folder: String) {
        // Only delete empty folders
        guard noteCount(for: folder) == 0 else { return }

        // Remove from custom folders
        var updated = customFolders
        updated.remove(folder)
        saveCustomFolders(updated)
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
