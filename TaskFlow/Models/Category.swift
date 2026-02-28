import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var isDefault: Bool = false
    @Relationship(deleteRule: .nullify, inverse: \TodoTask.category)
    var tasks: [TodoTask] = []

    init(name: String, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.isDefault = isDefault
    }
}
