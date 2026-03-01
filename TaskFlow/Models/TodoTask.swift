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

struct ChecklistItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var text: String
    var isChecked: Bool = false
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
    var checklistData: Data?
    var isArchived: Bool = false
    var columnId: UUID?

    var column: Column {
        get { Column(rawValue: columnRaw) ?? .work }
        set { columnRaw = newValue.rawValue }
    }

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var checklist: [ChecklistItem] {
        get {
            guard let data = checklistData else { return [] }
            return (try? JSONDecoder().decode([ChecklistItem].self, from: data)) ?? []
        }
        set {
            checklistData = try? JSONEncoder().encode(newValue)
        }
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
