import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID = UUID()
    var title: String = ""
    var body: String = ""
    var position: Int = 0
    var folderName: String = "All Notes"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var syncVersion: Int = 1

    init(title: String = "Untitled", body: String = "", position: Int = 0, folderName: String = "All Notes") {
        self.id = UUID()
        self.title = title
        self.body = body
        self.position = position
        self.folderName = folderName
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
