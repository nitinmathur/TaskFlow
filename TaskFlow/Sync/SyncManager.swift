import Foundation
import SwiftData
import Combine

// MARK: - Sync Status

enum SyncStatus: Equatable {
    case inSync
    case localChanges
    case remoteChanges
    case conflict
    case syncing
}

// MARK: - Syncable JSON Models

struct SyncableTask: Codable {
    var id: UUID
    var version: Int
    var isDeleted: Bool
    var deletedAt: Date?
    var data: TaskData?

    struct TaskData: Codable {
        var title: String
        var taskDescription: String?
        var column: String
        var priority: Int
        var position: Int
        var dueDate: Date?
        var isCompleted: Bool
        var createdAt: Date
        var completedAt: Date?
        var checklist: [ChecklistItem]
        var isArchived: Bool
        var columnId: UUID?
    }

    // Memberwise init for migration and tombstones
    init(id: UUID, version: Int, isDeleted: Bool, deletedAt: Date?, data: TaskData?) {
        self.id = id
        self.version = version
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.data = data
    }

    init(from task: TodoTask, version: Int) {
        self.id = task.id
        self.version = version
        self.isDeleted = false
        self.deletedAt = nil
        self.data = TaskData(
            title: task.title,
            taskDescription: task.taskDescription,
            column: task.columnRaw,
            priority: task.priorityRaw,
            position: task.position,
            dueDate: task.dueDate,
            isCompleted: task.isCompleted,
            createdAt: task.createdAt,
            completedAt: task.completedAt,
            checklist: task.checklist,
            isArchived: task.isArchived,
            columnId: task.columnId
        )
    }

    // Tombstone constructor for deleted items
    static func tombstone(id: UUID, version: Int) -> SyncableTask {
        SyncableTask(id: id, version: version, isDeleted: true, deletedAt: Date(), data: nil)
    }

    func apply(to task: TodoTask) {
        guard let data = data else { return }
        task.title = data.title
        task.taskDescription = data.taskDescription
        task.columnRaw = data.column
        task.priorityRaw = data.priority
        task.position = data.position
        task.dueDate = data.dueDate
        task.isCompleted = data.isCompleted
        task.completedAt = data.completedAt
        task.checklist = data.checklist
        task.isArchived = data.isArchived
        task.columnId = data.columnId
    }
}

struct SyncableNote: Codable {
    var id: UUID
    var version: Int
    var isDeleted: Bool
    var deletedAt: Date?
    var data: NoteData?

    struct NoteData: Codable {
        var title: String
        var body: String
        var position: Int
        var folderName: String
        var createdAt: Date
        var updatedAt: Date
    }

    // Memberwise init for migration and tombstones
    init(id: UUID, version: Int, isDeleted: Bool, deletedAt: Date?, data: NoteData?) {
        self.id = id
        self.version = version
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.data = data
    }

    init(from note: Note, version: Int) {
        self.id = note.id
        self.version = version
        self.isDeleted = false
        self.deletedAt = nil
        self.data = NoteData(
            title: note.title,
            body: note.body,
            position: note.position,
            folderName: note.folderName,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt
        )
    }

    // Tombstone constructor for deleted items
    static func tombstone(id: UUID, version: Int) -> SyncableNote {
        SyncableNote(id: id, version: version, isDeleted: true, deletedAt: Date(), data: nil)
    }

    func apply(to note: Note) {
        guard let data = data else { return }
        note.title = data.title
        note.body = data.body
        note.position = data.position
        note.folderName = data.folderName
        note.updatedAt = data.updatedAt
    }
}

struct SyncableBoardColumn: Codable {
    var id: UUID
    var version: Int
    var isDeleted: Bool
    var deletedAt: Date?
    var data: ColumnData?

    struct ColumnData: Codable {
        var name: String
        var icon: String
        var position: Int
        var isSystem: Bool
    }

    // Memberwise init for migration and tombstones
    init(id: UUID, version: Int, isDeleted: Bool, deletedAt: Date?, data: ColumnData?) {
        self.id = id
        self.version = version
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.data = data
    }

    init(from column: BoardColumn, version: Int) {
        self.id = column.id
        self.version = version
        self.isDeleted = false
        self.deletedAt = nil
        self.data = ColumnData(
            name: column.name,
            icon: column.icon,
            position: column.position,
            isSystem: column.isSystem
        )
    }

    // Tombstone constructor for deleted items
    static func tombstone(id: UUID, version: Int) -> SyncableBoardColumn {
        SyncableBoardColumn(id: id, version: version, isDeleted: true, deletedAt: Date(), data: nil)
    }

    func apply(to column: BoardColumn) {
        guard let data = data else { return }
        column.name = data.name
        column.icon = data.icon
        column.position = data.position
        column.isSystem = data.isSystem
    }
}

// MARK: - Legacy Format Support (for migration)

private struct LegacySyncableTask: Codable {
    var id: UUID
    var title: String
    var taskDescription: String?
    var column: String
    var priority: Int
    var position: Int
    var dueDate: Date?
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var checklist: [ChecklistItem]
    var modifiedAt: Date

    func toNew() -> SyncableTask {
        SyncableTask(
            id: id,
            version: 1,
            isDeleted: false,
            deletedAt: nil,
            data: SyncableTask.TaskData(
                title: title,
                taskDescription: taskDescription,
                column: column,
                priority: priority,
                position: position,
                dueDate: dueDate,
                isCompleted: isCompleted,
                createdAt: createdAt,
                completedAt: completedAt,
                checklist: checklist,
                isArchived: false,
                columnId: nil
            )
        )
    }
}

private struct LegacySyncableNote: Codable {
    var id: UUID
    var title: String
    var body: String
    var position: Int
    var folderName: String
    var createdAt: Date
    var updatedAt: Date
    var modifiedAt: Date

    func toNew() -> SyncableNote {
        SyncableNote(
            id: id,
            version: 1,
            isDeleted: false,
            deletedAt: nil,
            data: SyncableNote.NoteData(
                title: title,
                body: body,
                position: position,
                folderName: folderName,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        )
    }
}

// MARK: - Sync Manager

@MainActor
class SyncManager: ObservableObject {
    @Published var status: SyncStatus = .inSync
    @Published var lastSyncTime: Date?
    @Published var pendingRemoteChanges: Int = 0
    @Published var countdown: Int = 0
    @Published var isPushing: Bool = false

    private let sharedURL: URL
    private let tasksURL: URL
    private let notesURL: URL
    private let columnsURL: URL
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var timer: Timer?
    private var lastLocalChange: Date?
    private let pushDebounce: TimeInterval = 3   // 3 seconds - push quickly after changes stop
    private let pullDelay: TimeInterval = 2      // 2 seconds - pull quickly when remote changes detected
    private var pullCountdownDate: Date?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let iCloudBase = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")

        if FileManager.default.fileExists(atPath: iCloudBase.path) {
            sharedURL = iCloudBase.appendingPathComponent("TaskFlow/sync")
        } else {
            sharedURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("TaskFlow/sync")
        }

        tasksURL = sharedURL.appendingPathComponent("tasks")
        notesURL = sharedURL.appendingPathComponent("notes")
        columnsURL = sharedURL.appendingPathComponent("columns")

        setupDirectories()
        purgeOldTombstones()  // Clean up tombstones > 7 days old
        startFileWatcher()
        startAutoSync()
    }

    deinit {
        fileWatcher?.cancel()
        timer?.invalidate()
    }

    private func setupDirectories() {
        try? FileManager.default.createDirectory(at: tasksURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: notesURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: columnsURL, withIntermediateDirectories: true)
    }

    // MARK: - Tombstone Cleanup

    func purgeOldTombstones() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago

        for url in [tasksURL, notesURL, columnsURL] {
            guard let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { continue }

            for file in files where file.pathExtension == "json" {
                guard let data = try? Data(contentsOf: file) else { continue }

                // Try to decode as task, note, or column and check if it's an old tombstone
                if let task = try? decoder.decode(SyncableTask.self, from: data),
                   task.isDeleted,
                   let deletedAt = task.deletedAt,
                   deletedAt < cutoff {
                    try? FileManager.default.removeItem(at: file)
                } else if let note = try? decoder.decode(SyncableNote.self, from: data),
                          note.isDeleted,
                          let deletedAt = note.deletedAt,
                          deletedAt < cutoff {
                    try? FileManager.default.removeItem(at: file)
                } else if let column = try? decoder.decode(SyncableBoardColumn.self, from: data),
                          column.isDeleted,
                          let deletedAt = column.deletedAt,
                          deletedAt < cutoff {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }

    // MARK: - Auto-Sync Timer

    private func startAutoSync() {
        // Poll every 5 seconds for both local and remote changes
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // Always check for remote changes (iCloud file watcher is unreliable)
                self?.checkForRemoteChanges()
                self?.checkAndSync()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // Status changes detected here trigger actual sync in MainTabView's .onChange(of: syncManager.status)
    // When .syncing is set, MainTabView calls pushTasks/pushNotes or pullTasks/pullNotes
    // Version vectors handle conflicts automatically - higher version wins
    private func checkAndSync() {
        // Only auto-push when local changes exist and debounce period has passed
        if detectLocalAhead() {
            handleLocalAhead()
        } else if pendingRemoteChanges > 0 {
            // Remote changes detected by file watcher
            handleRemoteBehind()
        } else if status != .syncing {
            status = .inSync
        }
    }

    public func detectLocalAhead() -> Bool {
        return lastLocalChange != nil
    }

    private func handleLocalAhead() {
        guard let lastChange = lastLocalChange else { return }
        let elapsed = Date().timeIntervalSince(lastChange)

        if elapsed >= pushDebounce {
            status = .syncing
        } else {
            status = .localChanges
        }
    }

    private func handleRemoteBehind() {
        if pullCountdownDate == nil {
            pullCountdownDate = Date().addingTimeInterval(pullDelay)
            status = .remoteChanges
        }

        if let countdownDate = pullCountdownDate {
            let remaining = countdownDate.timeIntervalSinceNow
            countdown = max(0, Int(ceil(remaining)))

            if remaining <= 0 {
                status = .syncing
                pullCountdownDate = nil
            }
        }
    }

    func markLocalChange() {
        lastLocalChange = Date()
        status = .localChanges
    }

    // Called by MainTabView to update tracked data
    private var lastTasksHash: Int = 0
    private var lastNotesHash: Int = 0

    func updateTrackedData(tasksHash: Int, notesHash: Int) {
        if tasksHash != lastTasksHash || notesHash != lastNotesHash {
            lastTasksHash = tasksHash
            lastNotesHash = notesHash
            markLocalChange()
        }
    }

    // MARK: - File Watcher

    private func startFileWatcher() {
        let fd = open(sharedURL.path, O_EVTONLY)
        guard fd >= 0 else { return }

        fileWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )

        fileWatcher?.setEventHandler { [weak self] in
            self?.checkForRemoteChanges()
        }

        fileWatcher?.setCancelHandler {
            close(fd)
        }

        fileWatcher?.resume()
    }

    func checkForRemoteChanges() {
        // Count files that are newer than last sync
        var changes = 0
        let fm = FileManager.default

        // Use a reference time - if no last sync, use 1 hour ago to catch recent changes
        let referenceTime = lastSyncTime ?? Date().addingTimeInterval(-3600)

        for url in [tasksURL, notesURL, columnsURL] {
            if let files = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey]) {
                for file in files where file.pathExtension == "json" {
                    if let modDate = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                       modDate > referenceTime {
                        changes += 1
                    }
                }
            }
        }

        pendingRemoteChanges = changes
        if changes > 0 && status == .inSync {
            status = .remoteChanges
        }
    }

    // MARK: - Push (Local → Shared)

    func pushTasks(_ tasks: [TodoTask]) throws {
        isPushing = true
        status = .syncing
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let localIDs = Set(tasks.map { $0.id })

        // 1. Push all local tasks (increment version)
        for task in tasks {
            task.syncVersion += 1
            let syncable = SyncableTask(from: task, version: task.syncVersion)
            let data = try encoder.encode(syncable)
            let fileURL = tasksURL.appendingPathComponent("\(task.id.uuidString).json")
            try data.write(to: fileURL)
        }

        // 2. Find remote files not in local - these were deleted locally, create tombstones
        if let files = try? FileManager.default.contentsOfDirectory(at: tasksURL, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                guard let fileID = UUID(uuidString: file.deletingPathExtension().lastPathComponent),
                      !localIDs.contains(fileID) else { continue }

                // Read existing file to get current version
                if let data = try? Data(contentsOf: file),
                   let existing = try? decoder.decode(SyncableTask.self, from: data) {
                    if !existing.isDeleted {
                        // Not yet marked deleted - create tombstone
                        let tombstone = SyncableTask.tombstone(id: fileID, version: existing.version + 1)
                        let tombstoneData = try encoder.encode(tombstone)
                        try tombstoneData.write(to: file)
                    }
                    // else: already a tombstone, leave it
                }
            }
        }

        lastSyncTime = Date()
        lastLocalChange = nil
        status = .inSync
    }

    func pushNotes(_ notes: [Note]) throws {
        isPushing = true
        status = .syncing
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let localIDs = Set(notes.map { $0.id })

        // 1. Push all local notes (increment version)
        for note in notes {
            note.syncVersion += 1
            let syncable = SyncableNote(from: note, version: note.syncVersion)
            let data = try encoder.encode(syncable)
            let fileURL = notesURL.appendingPathComponent("\(note.id.uuidString).json")
            try data.write(to: fileURL)
        }

        // 2. Find remote files not in local - these were deleted locally, create tombstones
        if let files = try? FileManager.default.contentsOfDirectory(at: notesURL, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                guard let fileID = UUID(uuidString: file.deletingPathExtension().lastPathComponent),
                      !localIDs.contains(fileID) else { continue }

                // Read existing file to get current version
                if let data = try? Data(contentsOf: file),
                   let existing = try? decoder.decode(SyncableNote.self, from: data) {
                    if !existing.isDeleted {
                        // Not yet marked deleted - create tombstone
                        let tombstone = SyncableNote.tombstone(id: fileID, version: existing.version + 1)
                        let tombstoneData = try encoder.encode(tombstone)
                        try tombstoneData.write(to: file)
                    }
                    // else: already a tombstone, leave it
                }
            }
        }

        lastSyncTime = Date()
        lastLocalChange = nil
        status = .inSync
    }

    // MARK: - Pull (Shared → Local)

    func pullTasks(context: ModelContext, localTasks: [TodoTask]) throws -> [TodoTask] {
        isPushing = false
        status = .syncing
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var updatedTasks: [TodoTask] = []
        let localByID = Dictionary(uniqueKeysWithValues: localTasks.map { ($0.id, $0) })

        guard let files = try? FileManager.default.contentsOfDirectory(at: tasksURL, includingPropertiesForKeys: nil) else {
            status = .inSync
            return []
        }

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file) else { continue }

            // Try new format first, then legacy format
            let remote: SyncableTask
            if let newFormat = try? decoder.decode(SyncableTask.self, from: data) {
                remote = newFormat
            } else if let legacy = try? decoder.decode(LegacySyncableTask.self, from: data) {
                remote = legacy.toNew()
            } else {
                continue
            }

            if remote.isDeleted {
                // Remote says deleted - remove local if exists
                if let localTask = localByID[remote.id] {
                    context.delete(localTask)
                }
                // Keep tombstone file (cleanup job will remove after 7 days)
            } else if let localTask = localByID[remote.id] {
                // Both have it - compare versions
                if remote.version > localTask.syncVersion {
                    // Remote is newer - update local
                    remote.apply(to: localTask)
                    localTask.syncVersion = remote.version
                    updatedTasks.append(localTask)
                }
                // else: local is same or newer, will push later
            } else {
                // Remote has it, local doesn't - create local
                guard let taskData = remote.data else { continue }
                let newTask = TodoTask(title: taskData.title)
                newTask.id = remote.id
                newTask.syncVersion = remote.version
                remote.apply(to: newTask)
                newTask.createdAt = taskData.createdAt
                context.insert(newTask)
                updatedTasks.append(newTask)
            }
        }

        lastSyncTime = Date()
        pendingRemoteChanges = 0
        status = .inSync

        return updatedTasks
    }

    func pullNotes(context: ModelContext, localNotes: [Note]) throws -> [Note] {
        isPushing = false
        status = .syncing
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var updatedNotes: [Note] = []
        let localByID = Dictionary(uniqueKeysWithValues: localNotes.map { ($0.id, $0) })

        guard let files = try? FileManager.default.contentsOfDirectory(at: notesURL, includingPropertiesForKeys: nil) else {
            status = .inSync
            return []
        }

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file) else { continue }

            // Try new format first, then legacy format
            let remote: SyncableNote
            if let newFormat = try? decoder.decode(SyncableNote.self, from: data) {
                remote = newFormat
            } else if let legacy = try? decoder.decode(LegacySyncableNote.self, from: data) {
                remote = legacy.toNew()
            } else {
                continue
            }

            if remote.isDeleted {
                // Remote says deleted - remove local if exists
                if let localNote = localByID[remote.id] {
                    context.delete(localNote)
                }
                // Keep tombstone file (cleanup job will remove after 7 days)
            } else if let localNote = localByID[remote.id] {
                // Both have it - compare versions
                if remote.version > localNote.syncVersion {
                    // Remote is newer - update local
                    remote.apply(to: localNote)
                    localNote.syncVersion = remote.version
                    updatedNotes.append(localNote)
                }
                // else: local is same or newer, will push later
            } else {
                // Remote has it, local doesn't - create local
                guard let noteData = remote.data else { continue }
                let newNote = Note(title: noteData.title, body: noteData.body,
                                 position: noteData.position, folderName: noteData.folderName)
                newNote.id = remote.id
                newNote.syncVersion = remote.version
                newNote.createdAt = noteData.createdAt
                newNote.updatedAt = noteData.updatedAt
                context.insert(newNote)
                updatedNotes.append(newNote)
            }
        }

        lastSyncTime = Date()
        pendingRemoteChanges = 0
        status = .inSync

        return updatedNotes
    }

    func pushColumns(_ columns: [BoardColumn]) throws {
        isPushing = true
        status = .syncing
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let localIDs = Set(columns.map { $0.id })

        // 1. Push all local columns (increment version)
        for column in columns {
            column.syncVersion += 1
            let syncable = SyncableBoardColumn(from: column, version: column.syncVersion)
            let data = try encoder.encode(syncable)
            let fileURL = columnsURL.appendingPathComponent("\(column.id.uuidString).json")
            try data.write(to: fileURL)
        }

        // 2. Find remote files not in local - these were deleted locally, create tombstones
        if let files = try? FileManager.default.contentsOfDirectory(at: columnsURL, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                guard let fileID = UUID(uuidString: file.deletingPathExtension().lastPathComponent),
                      !localIDs.contains(fileID) else { continue }

                // Read existing file to get current version
                if let data = try? Data(contentsOf: file),
                   let existing = try? decoder.decode(SyncableBoardColumn.self, from: data) {
                    if !existing.isDeleted {
                        // Not yet marked deleted - create tombstone
                        let tombstone = SyncableBoardColumn.tombstone(id: fileID, version: existing.version + 1)
                        let tombstoneData = try encoder.encode(tombstone)
                        try tombstoneData.write(to: file)
                    }
                    // else: already a tombstone, leave it
                }
            }
        }

        lastSyncTime = Date()
        lastLocalChange = nil
        status = .inSync
    }

    func pullColumns(context: ModelContext, localColumns: [BoardColumn]) throws -> [BoardColumn] {
        isPushing = false
        status = .syncing
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var updatedColumns: [BoardColumn] = []
        let localByID = Dictionary(uniqueKeysWithValues: localColumns.map { ($0.id, $0) })

        guard let files = try? FileManager.default.contentsOfDirectory(at: columnsURL, includingPropertiesForKeys: nil) else {
            status = .inSync
            return []
        }

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file) else { continue }

            guard let remote = try? decoder.decode(SyncableBoardColumn.self, from: data) else {
                continue
            }

            if remote.isDeleted {
                // Remote says deleted - remove local if exists
                if let localColumn = localByID[remote.id] {
                    context.delete(localColumn)
                }
                // Keep tombstone file (cleanup job will remove after 7 days)
            } else if let localColumn = localByID[remote.id] {
                // Both have it - compare versions
                if remote.version > localColumn.syncVersion {
                    // Remote is newer - update local
                    remote.apply(to: localColumn)
                    localColumn.syncVersion = remote.version
                    updatedColumns.append(localColumn)
                }
                // else: local is same or newer, will push later
            } else {
                // Remote has it, local doesn't - create local
                guard let columnData = remote.data else { continue }
                let newColumn = BoardColumn(name: columnData.name, icon: columnData.icon,
                                           position: columnData.position, isSystem: columnData.isSystem)
                newColumn.id = remote.id
                newColumn.syncVersion = remote.version
                context.insert(newColumn)
                updatedColumns.append(newColumn)
            }
        }

        lastSyncTime = Date()
        pendingRemoteChanges = 0
        status = .inSync

        return updatedColumns
    }
}
