import SwiftUI
import SwiftData

struct CategoryManagerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var newName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Manage Categories")
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

            if categories.isEmpty {
                ContentUnavailableView("No Categories", systemImage: "folder",
                    description: Text("Add a category below"))
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(categories) { cat in
                        HStack {
                            Image(systemName: cat.name == "Work" ? "briefcase.fill" : "person.fill")
                                .foregroundStyle(cat.name == "Work" ? .indigo : .green)
                                .frame(width: 24)
                            Text(cat.name)
                            Spacer()
                            Button { deleteCategory(cat) } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            HStack {
                TextField("New category name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addCategory() }
                Button("Add") { addCategory() }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 320, height: 350)
    }

    private func addCategory() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let category = Category(name: name, isDefault: false)
        context.insert(category)
        newName = ""
    }

    private func deleteCategory(_ cat: Category) {
        context.delete(cat)
    }
}
