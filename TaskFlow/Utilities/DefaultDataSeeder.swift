import Foundation
import SwiftData

struct DefaultDataSeeder {
    static let defaultCategories = ["Work", "Personal"]

    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.isDefault })
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0

        if existingCount == 0 {
            for name in defaultCategories {
                let category = Category(name: name, isDefault: true)
                context.insert(category)
            }
            try? context.save()
        }
    }
}
