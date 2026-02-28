import SwiftUI
import SwiftData
import SQLite3

@main
struct TaskFlowApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([TodoTask.self, Note.self])

        // Store in iCloud Drive folder for sync (no entitlements needed)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let iCloudDrive = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/TaskFlow")

        // Fallback to local Documents if iCloud Drive unavailable
        let storeDir = FileManager.default.fileExists(atPath: home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs").path)
            ? iCloudDrive
            : FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("TaskFlow")

        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        let storeURL = storeDir.appendingPathComponent("TaskFlow.store")

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Disable WAL mode for iCloud Drive compatibility
            // WAL creates separate -wal and -shm files that don't sync properly
            disableWALMode(at: storeURL)

            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private static func disableWALMode(at url: URL) {
        var db: OpaquePointer?
        if sqlite3_open(url.path, &db) == SQLITE_OK {
            sqlite3_exec(db, "PRAGMA journal_mode=DELETE;", nil, nil, nil)
            sqlite3_close(db)
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .frame(minWidth: 1100, minHeight: 600)
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1200, height: 700)
    }
}
