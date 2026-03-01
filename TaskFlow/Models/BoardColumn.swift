import Foundation
import SwiftData
import CryptoKit

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

    /// Generates a deterministic UUID based on column name using SHA256
    /// This ensures default columns have consistent IDs across devices
    static func deterministicUUID(for name: String) -> UUID {
        let namespace = "com.taskflow.column."
        let combined = namespace + name.lowercased()

        // Use SHA256 for deterministic hashing
        let hash = SHA256.hash(data: Data(combined.utf8))
        let hashBytes = Array(hash)

        // Take first 16 bytes of hash for UUID
        var uuidBytes = Array(hashBytes.prefix(16))

        // Set version 5 bits (name-based UUID)
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x50
        // Set variant bits (RFC 4122)
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        ))
    }
}
