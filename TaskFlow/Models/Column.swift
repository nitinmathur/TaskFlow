import Foundation

enum Column: String, Codable, CaseIterable {
    case work
    case personal
    case ideas
    case completed

    var title: String {
        switch self {
        case .work: "Work"
        case .personal: "Personal"
        case .ideas: "Ideas"
        case .completed: "Completed"
        }
    }

    var icon: String {
        switch self {
        case .work: "briefcase.fill"
        case .personal: "person.fill"
        case .ideas: "lightbulb.fill"
        case .completed: "checkmark.circle.fill"
        }
    }
}
