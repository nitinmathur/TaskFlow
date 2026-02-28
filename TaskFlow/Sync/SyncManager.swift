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
    var modifiedAt: Date  // Track when last modified

    init(from task: TodoTask) {
        self.id = task.id
        self.title = task.title
        self.taskDescription = task.taskDescription
        self.column = task.columnRaw
        self.priority = task.priorityRaw
        self.position = task.position
        self.dueDate = task.dueDate
        self.isCompleted = task.isCompleted
        self.createdAt = task.createdAt
        self.completedAt = task.completedAt
        self.checklist = task.checklist
        self.modifiedAt = Date()
    }

    func apply(to task: TodoTask) {
        task.title = title
        task.taskDescription = taskDescription
        task.columnRaw = column
        task.priorityRaw = priority
        task.position = position
        task.dueDate = dueDate
        task.isCompleted = isCompleted
        task.completedAt = completedAt
        task.checklist = checklist
    }
}

struct SyncableNote: Codable {
    var id: UUID
    var title: String
    var body: String
    var position: Int
    var folderName: String
    var createdAt: Date
    var updatedAt: Date
    var modifiedAt: Date

    init(from note: Note) {
        self.id = note.id
        self.title = note.title
        self.body = note.body
        self.position = note.position
        self.folderName = note.folderName
        self.createdAt = note.createdAt
        self.updatedAt = note.updatedAt
        self.modifiedAt = Date()
    }

    func apply(to note: Note) {
        note.title = title
        note.body = body
        note.position = position
        note.folderName = folderName
        note.updatedAt = updatedAt
    }
}

// MARK: - Sync Manager

@MainActor
class SyncManager: ObservableObject {
    @Published var status: SyncStatus = .inSync
    @Published var lastSyncTime: Date?
    @Published var pendingRemoteChanges: Int = 0
    @Published var countdown: Int = 0

    private let sharedURL: URL
    private let tasksURL: URL
    private let notesURL: URL
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var timer: Timer?
    private var lastLocalChange: Date?
    private let pushDebounce: TimeInterval = 60  // 1 minute
    private let pullDelay: TimeInterval = 10      // 10 seconds
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

        setupDirectories()
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
    }

    // MARK: - Auto-Sync Timer

    private func startAutoSync() {
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAndSync()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // Status changes detected here trigger actual sync in MainTabView's .onChange(of: syncManager.status)
    // When .syncing is set, MainTabView calls pushTasks/pushNotes or pullTasks/pullNotes
    private func checkAndSync() {
        let isAhead = detectLocalAhead()
        let isBehind = detectRemoteBehind()

        if isAhead && !isBehind {
            handleLocalAhead()
        } else if isBehind && !isAhead {
            handleRemoteBehind()
        } else if isAhead && isBehind {
            status = .conflict
        } else if !isAhead && !isBehind {
            status = .inSync
        }
    }

    private func detectLocalAhead() -> Bool {
        return lastLocalChange != nil
    }

    private func detectRemoteBehind() -> Bool {
        guard let lastSync = lastSyncTime else { return true }

        let fm = FileManager.default
        var hasNewer = false

        if let files = try? fm.contentsOfDirectory(at: tasksURL, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for file in files where file.pathExtension == "json" {
                if let modDate = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   modDate > lastSync {
                    hasNewer = true
                    break
                }
            }
        }

        if !hasNewer, let files = try? fm.contentsOfDirectory(at: notesURL, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for file in files where file.pathExtension == "json" {
                if let modDate = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   modDate > lastSync {
                    hasNewer = true
                    break
                }
            }
        }

        return hasNewer
    }

    private func handleLocalAhead() {
        guard let lastChange = lastLocalChange else { return }
        let elapsed = Date().timeIntervalSince(lastChange)

        if elapsed >= pushDebounce {
            status = .syncing
            lastLocalChange = nil
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

        if let taskFiles = try? fm.contentsOfDirectory(at: tasksURL, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for file in taskFiles where file.pathExtension == "json" {
                if let modDate = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   let lastSync = lastSyncTime,
                   modDate > lastSync {
                    changes += 1
                }
            }
        }

        if let noteFiles = try? fm.contentsOfDirectory(at: notesURL, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for file in noteFiles where file.pathExtension == "json" {
                if let modDate = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   let lastSync = lastSyncTime,
                   modDate > lastSync {
                    changes += 1
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
        status = .syncing
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        for task in tasks {
            let syncable = SyncableTask(from: task)
            let data = try encoder.encode(syncable)
            let fileURL = tasksURL.appendingPathComponent("\(task.id.uuidString).json")
            try data.write(to: fileURL)
        }

        // Remove deleted tasks
        let localIDs = Set(tasks.map { $0.id.uuidString })
        if let files = try? FileManager.default.contentsOfDirectory(at: tasksURL, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                let fileID = file.deletingPathExtension().lastPathComponent
                if !localIDs.contains(fileID) {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }

        lastSyncTime = Date()
        status = .inSync
    }

    func pushNotes(_ notes: [Note]) throws {
        status = .syncing
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        for note in notes {
            let syncable = SyncableNote(from: note)
            let data = try encoder.encode(syncable)
            let fileURL = notesURL.appendingPathComponent("\(note.id.uuidString).json")
            try data.write(to: fileURL)
        }

        // Remove deleted notes
        let localIDs = Set(notes.map { $0.id.uuidString })
        if let files = try? FileManager.default.contentsOfDirectory(at: notesURL, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                let fileID = file.deletingPathExtension().lastPathComponent
                if !localIDs.contains(fileID) {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }

        lastSyncTime = Date()
        status = .inSync
    }

    // MARK: - Pull (Shared → Local)

    func pullTasks(context: ModelContext, localTasks: [TodoTask]) throws -> [TodoTask] {
        status = .syncing
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var updatedTasks: [TodoTask] = []
        let localByID = Dictionary(uniqueKeysWithValues: localTasks.map { ($0.id, $0) })
        var remoteIDs = Set<UUID>()

        guard let files = try? FileManager.default.contentsOfDirectory(at: tasksURL, includingPropertiesForKeys: nil) else {
            status = .inSync
            return []
        }

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let syncable = try? decoder.decode(SyncableTask.self, from: data) else { continue }

            remoteIDs.insert(syncable.id)

            if let localTask = localByID[syncable.id] {
                // Update existing
                syncable.apply(to: localTask)
                updatedTasks.append(localTask)
            } else {
                // Create new
                let newTask = TodoTask(title: syncable.title)
                newTask.id = syncable.id
                syncable.apply(to: newTask)
                newTask.createdAt = syncable.createdAt
                context.insert(newTask)
                updatedTasks.append(newTask)
            }
        }

        // Delete tasks not in remote
        for task in localTasks where !remoteIDs.contains(task.id) {
            context.delete(task)
        }

        lastSyncTime = Date()
        pendingRemoteChanges = 0
        status = .inSync

        return updatedTasks
    }

    func pullNotes(context: ModelContext, localNotes: [Note]) throws -> [Note] {
        status = .syncing
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var updatedNotes: [Note] = []
        let localByID = Dictionary(uniqueKeysWithValues: localNotes.map { ($0.id, $0) })
        var remoteIDs = Set<UUID>()

        guard let files = try? FileManager.default.contentsOfDirectory(at: notesURL, includingPropertiesForKeys: nil) else {
            status = .inSync
            return []
        }

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let syncable = try? decoder.decode(SyncableNote.self, from: data) else { continue }

            remoteIDs.insert(syncable.id)

            if let localNote = localByID[syncable.id] {
                syncable.apply(to: localNote)
                updatedNotes.append(localNote)
            } else {
                let newNote = Note(title: syncable.title, body: syncable.body,
                                 position: syncable.position, folderName: syncable.folderName)
                newNote.id = syncable.id
                newNote.createdAt = syncable.createdAt
                newNote.updatedAt = syncable.updatedAt
                context.insert(newNote)
                updatedNotes.append(newNote)
            }
        }

        for note in localNotes where !remoteIDs.contains(note.id) {
            context.delete(note)
        }

        lastSyncTime = Date()
        pendingRemoteChanges = 0
        status = .inSync

        return updatedNotes
    }
}
