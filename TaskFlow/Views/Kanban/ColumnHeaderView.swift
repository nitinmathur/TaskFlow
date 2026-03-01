import SwiftUI

struct ColumnHeaderView: View {
    @Bindable var column: BoardColumn
    var taskCount: Int
    var onDelete: () -> Void
    var onMoveLeft: () -> Void
    var onMoveRight: () -> Void
    var canMoveLeft: Bool
    var canMoveRight: Bool

    @State private var isRenaming = false
    @State private var editedName = ""
    @State private var isChangingIcon = false

    // Color based on column icon or position
    private var columnColor: Color {
        switch column.icon {
        case "briefcase.fill": return .blue
        case "person.fill": return .green
        case "lightbulb.fill": return .purple
        case "checkmark.circle.fill": return .gray
        default:
            let colors: [Color] = [.blue, .green, .purple, .orange, .pink, .cyan, .mint, .indigo]
            return colors[column.position % colors.count]
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: column.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(columnColor)

            if isRenaming {
                TextField("Column Name", text: $editedName)
                    .textFieldStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .onSubmit { saveRename() }
                    .onExitCommand { cancelRename() }
            } else {
                Text(column.name)
                    .font(.subheadline.weight(.semibold))
            }

            Spacer()

            Text("\(taskCount)")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(columnColor.opacity(0.15))
                .foregroundStyle(columnColor)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                startRename()
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .disabled(column.isSystem)

            Button {
                isChangingIcon = true
            } label: {
                Label("Change Icon", systemImage: "photo")
            }
            .disabled(column.isSystem)

            Divider()

            Button {
                onMoveLeft()
            } label: {
                Label("Move Left", systemImage: "arrow.left")
            }
            .disabled(!canMoveLeft || column.isSystem)

            Button {
                onMoveRight()
            } label: {
                Label("Move Right", systemImage: "arrow.right")
            }
            .disabled(!canMoveRight || column.isSystem)

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(column.isSystem)
        }
        .popover(isPresented: $isChangingIcon) {
            IconPickerView(selectedIcon: column.icon) { newIcon in
                column.icon = newIcon
                isChangingIcon = false
            }
        }
    }

    private func startRename() {
        editedName = column.name
        isRenaming = true
    }

    private func saveRename() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            column.name = trimmed
        }
        isRenaming = false
    }

    private func cancelRename() {
        isRenaming = false
    }
}

// MARK: - Icon Picker View

struct IconPickerView: View {
    let selectedIcon: String
    let onSelect: (String) -> Void

    private let icons = ["folder", "star", "flag", "tag", "bookmark", "heart", "bolt", "flame"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Icon")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 4), spacing: 8) {
                ForEach(icons, id: \.self) { icon in
                    Button {
                        onSelect(icon)
                    } label: {
                        Image(systemName: icon)
                            .font(.title2)
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedIcon == icon ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .frame(width: 220)
    }
}

// MARK: - Add Column Popover

struct AddColumnPopover: View {
    @Binding var isPresented: Bool
    var onCreate: (String, String) -> Void

    @State private var name = ""
    @State private var selectedIcon = "folder"

    private let icons = ["folder", "star", "flag", "tag", "bookmark", "heart", "bolt", "flame"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Column")
                .font(.headline)

            // Name field
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Column name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // Icon picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Icon")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(36)), count: 4), spacing: 6) {
                    ForEach(icons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.body)
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color(nsColor: .controlBackgroundColor))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(selectedIcon == icon ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                Spacer()
                Button("Create") {
                    onCreate(name, selectedIcon)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 200)
    }
}
