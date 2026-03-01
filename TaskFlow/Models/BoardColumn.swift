import Foundation
import SwiftData

@Model
final class BoardColumn {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "folder"
    var position: Int = 0
    var isSystem: Bool = false
    var syncVersion: Int = 1

    /// Regular initializer for user-created columns
    init(name: String, icon: String = "folder", position: Int = 0, isSystem: Bool = false) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.position = position
        self.isSystem = isSystem
    }

    /// Deterministic ID initializer for default columns
    /// Uses a predictable UUID based on column name so both Macs generate same IDs during sync
    init(defaultColumnName name: String, icon: String, position: Int, isSystem: Bool = false) {
        self.id = BoardColumn.deterministicUUID(for: name)
        self.name = name
        self.icon = icon
        self.position = position
        self.isSystem = isSystem
    }

    /// Generates a deterministic UUID based on column name
    /// This ensures default columns have consistent IDs across devices
    static func deterministicUUID(for name: String) -> UUID {
        // Use hardcoded UUIDs for the 4 default columns
        switch name.lowercased() {
        case "work":
            return UUID(uuidString: "00000001-0000-0000-0000-000000000001")!
        case "personal":
            return UUID(uuidString: "00000002-0000-0000-0000-000000000002")!
        case "ideas":
            return UUID(uuidString: "00000003-0000-0000-0000-000000000003")!
        case "completed":
            return UUID(uuidString: "00000004-0000-0000-0000-000000000004")!
        default:
            return UUID()
        }
    }
}
