import Foundation
import SwiftData

/// Handles migration from the hardcoded Column enum to dynamic BoardColumn model.
/// Runs on first launch to create default columns and migrate existing tasks.
@MainActor
class ColumnMigration {

    // MARK: - Public API

    /// Check if migration is needed and run it.
    /// Migration is needed when no BoardColumn entries exist.
    static func migrateIfNeeded(context: ModelContext) {
        // 1. Fetch all BoardColumn entries
        let descriptor = FetchDescriptor<BoardColumn>()
        let existingColumns: [BoardColumn]

        do {
            existingColumns = try context.fetch(descriptor)
        } catch {
            print("ColumnMigration: Failed to fetch columns: \(error)")
            return
        }

        // 2. If empty, create default columns with deterministic UUIDs
        if existingColumns.isEmpty {
            print("ColumnMigration: No columns found, creating defaults...")
            createDefaultColumns(context: context)

            // Fetch the newly created columns
            do {
                let newColumns = try context.fetch(descriptor)
                // 3. Migrate existing tasks to use columnId
                migrateTaskColumns(context: context, columns: newColumns)
            } catch {
                print("ColumnMigration: Failed to fetch new columns: \(error)")
            }

            // Save all changes
            do {
                try context.save()
                print("ColumnMigration: Migration completed successfully")
            } catch {
                print("ColumnMigration: Failed to save migration: \(error)")
            }
        } else {
            print("ColumnMigration: Columns already exist, skipping migration")
        }
    }

    // MARK: - Private Helpers

    /// Create default columns matching the old Column enum.
    /// Uses deterministic UUIDs so columns are consistent across devices.
    private static func createDefaultColumns(context: ModelContext) {
        let defaultColumns: [(name: String, icon: String, position: Int, isSystem: Bool)] = [
            ("Work", "briefcase.fill", 0, false),
            ("Personal", "person.fill", 1, false),
            ("Ideas", "lightbulb.fill", 2, false),
            ("Completed", "checkmark.circle.fill", 3, true)
        ]

        for columnDef in defaultColumns {
            let column = BoardColumn(
                defaultColumnName: columnDef.name,
                icon: columnDef.icon,
                position: columnDef.position,
                isSystem: columnDef.isSystem
            )
            context.insert(column)
            print("ColumnMigration: Created column '\(columnDef.name)' with ID \(column.id)")
        }
    }

    /// Map old columnRaw string to new columnId for all tasks.
    /// Matches columnRaw values (e.g., "work") to column names (e.g., "Work").
    private static func migrateTaskColumns(context: ModelContext, columns: [BoardColumn]) {
        // Build a lookup dictionary: lowercase column name -> column ID
        var columnLookup: [String: UUID] = [:]
        for column in columns {
            columnLookup[column.name.lowercased()] = column.id
        }

        // Fetch all tasks
        let taskDescriptor = FetchDescriptor<TodoTask>()
        let tasks: [TodoTask]

        do {
            tasks = try context.fetch(taskDescriptor)
        } catch {
            print("ColumnMigration: Failed to fetch tasks: \(error)")
            return
        }

        // Migrate each task
        var migratedCount = 0
        for task in tasks {
            // columnRaw stores lowercase values like "work", "personal", etc.
            let columnRaw = task.columnRaw.lowercased()

            if let columnId = columnLookup[columnRaw] {
                task.columnId = columnId
                migratedCount += 1
            } else {
                // Fallback to "Work" column if no match found
                if let workColumnId = columnLookup["work"] {
                    task.columnId = workColumnId
                    migratedCount += 1
                    print("ColumnMigration: Task '\(task.title)' had unknown column '\(task.columnRaw)', defaulting to Work")
                }
            }
        }

        print("ColumnMigration: Migrated \(migratedCount) tasks to use columnId")
    }
}
