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

    var color: String {
        switch self {
        case .high: "red"
        case .medium: "orange"
        case .low: "blue"
        }
    }
}

@Model
final class TodoTask {
    var id: UUID = UUID()
    var title: String = ""
    var taskDescription: String?
    var category: Category?
    var priorityRaw: Int = Priority.medium.rawValue
    var dueDate: Date?
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var completedAt: Date?

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    init(title: String, taskDescription: String? = nil, category: Category? = nil,
         priority: Priority = .medium, dueDate: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.taskDescription = taskDescription
        self.category = category
        self.priorityRaw = priority.rawValue
        self.dueDate = dueDate
        self.createdAt = Date()
    }
}
