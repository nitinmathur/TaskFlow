# Coding Conventions

**Analysis Date:** 2026-03-01

## Naming Patterns

**Files:**
- PascalCase for all Swift files: `TodoTask.swift`, `KanbanBoardView.swift`, `SyncManager.swift`
- Descriptive names reflecting purpose/functionality
- View files use "View" suffix: `NoteEditorView.swift`, `CardDetailView.swift`, `ColumnHeaderView.swift`
- Model files organized in Models directory without suffix
- Manager classes use "Manager" suffix: `SyncManager.swift`

**Functions:**
- camelCase for all functions: `setupDirectories()`, `checkForRemoteChanges()`, `debouncedSave()`
- Action methods use verb-first pattern: `addItem()`, `loadTask()`, `saveRename()`, `markLocalChange()`
- Private helper functions prefixed with `private func`: `private func handleLocalAhead()`
- Static utility functions when appropriate: `static func tombstone(id:version:)`
- Internal functions use `private` access modifier by default

**Variables:**
- camelCase for properties: `isEditing`, `dueDate`, `selectedTab`, `groupByDate`
- Boolean properties start with `is` or `has`: `isCompleted`, `isArchived`, `hasDueDate`, `canMoveLeft`
- Binding/State variables use `$` prefix when modified: `$sortOption`, `$note.title`, `$editorConfig`
- Computed properties marked with `private var` when internal: `private var archivedTasksCount`
- Private state uses `@State private`: `@State private var isEditing = false`

**Types:**
- PascalCase for all type names: `TodoTask`, `BoardColumn`, `SyncManager`, `Priority`
- Enum cases use lowercase: `.work`, `.medium`, `.high`, `timeInterval`
- Struct names for data models: `ChecklistItem`, `CardEditorConfig`, `SyncableTask`
- Class names for managers and complex types: `SyncManager`, `Note`, `TodoTask`

## Code Style

**Formatting:**
- 4-space indentation (default Xcode setting)
- Line breaks after opening braces in SwiftUI views
- Trailing commas in multi-line collections
- Consistent spacing around operators: `x + y`, `isSelected ? color : .clear`

**Linting:**
- No external linting tool detected
- Xcode default code completion and formatting used
- Type inference used liberally: `let task = TodoTask(title: "New")`

## Import Organization

**Order:**
1. Foundation-level frameworks: `import Foundation`
2. Apple frameworks: `import SwiftUI`, `import SwiftData`, `import AppKit`
3. System frameworks: `import SQLite3`, `import Combine`

**Example from files:**
```swift
import Foundation
import SwiftData

// or

import SwiftUI
import SwiftData

// or

import Foundation
import SwiftData
import Combine
```

**Path Aliases:**
- No custom path aliases detected
- Direct file references used throughout
- Same-module references without prefixes

## Error Handling

**Patterns:**
- Try-catch with `do { try ... } catch { print(...) }` pattern in initialization
- Silent failures with `try?` where error recovery isn't required: `try? FileManager.default.createDirectory(...)`
- Throws declared in function signatures: `func pushTasks(_ tasks: [TodoTask]) throws`
- Print statements used for error logging (not a dedicated logging framework): `print("ModelContainer Error: \(error)")`
- Guard with optional binding for non-optional unwrapping: `guard let columnId = selectedColumnId else { return }`
- Optional chaining avoided when possible, prefer explicit unwrapping with guard
- Errors propagated up call stack via throws pattern in SyncManager

**Example:**
```swift
// From SyncManager
try? FileManager.default.createDirectory(at: tasksURL, withIntermediateDirectories: true)

// From TaskFlowApp
do {
    let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
    disableWALMode(at: storeURL)
    return container
} catch {
    print("ModelContainer Error: \(error)")
    fatalError("Could not create ModelContainer: \(error)")
}

// In views
guard let columnId = selectedColumnId else { return }
```

## Logging

**Framework:** `print()` function (console output)

**Patterns:**
- Diagnostic prints in initialization: `print("ModelContainer Error: \(error)")`
- Error descriptions included: `print("Error Description: \(error.localizedDescription)")`
- SwiftData-specific errors logged separately: `print("SwiftData Error: \(swiftDataError)")`
- No log levels (Info, Debug, Warning) differentiated
- Limited logging in business logic, mostly in setup/sync operations

## Comments

**When to Comment:**
- Section markers using `// MARK: - Section Name` for major code sections
- Complex algorithm explanations: "Find position before the 'Completed' column..."
- Sync-specific logic documented inline: "// Both have it - compare versions"
- Status transitions explained: "// Status changes detected here trigger actual sync..."
- Workarounds documented: "// Disable WAL mode for iCloud Drive compatibility"

**JSDoc/TSDoc:**
- Not used (Swift doesn't have JSDoc standard)
- Inline comments preferred for complex logic
- Method signatures are self-documenting via parameter labels

## Function Design

**Size:**
- Most functions 5-30 lines
- Longer functions acceptable for complex logic: `pullTasks()` is ~60 lines but clearly structured
- Private helper functions kept short: `addItem()` is 3 lines, `loadTask()` is 9 lines

**Parameters:**
- Explicit parameter labels: `func reorderTask(_ task: TodoTask, direction: Int, in column: BoardColumn)`
- Closures passed as trailing closures: `onAddCard: { ... }`
- Default parameters used: `func init(title: String = "Untitled", ...)`
- Multiple parameters organized by logical grouping

**Return Values:**
- Single return values preferred
- Tuples used sparingly, struct wrappers preferred
- Arrays returned for collections: `func pullTasks(...) -> [TodoTask]`
- Bool for simple predicates: `func detectLocalAhead() -> Bool`
- Void for mutation-based operations: `func markLocalChange()`

## Module Design

**Exports:**
- All public types exposed at module level (no internal/private modules)
- Models in Models directory: `TodoTask.swift`, `Note.swift`, `BoardColumn.swift`
- Views organized by feature in Views directory: `Views/Kanban/`, `Views/Notes/`
- Single class per file: One model class per Swift file
- Supporting types (enums, structs) in same file as primary type

**Barrel Files:**
- Not used
- Each file imported directly: `import TodoTask`
- No aggregated imports detected

## MARK Comments

**Standard sections:**
- `// MARK: - Model Setup`
- `// MARK: - Sync Status`
- `// MARK: - Add Column Button`
- `// MARK: - Column Management`
- `// MARK: - Task Sorting & Filtering`
- `// MARK: - Card Actions`
- `// MARK: - File Watcher`
- `// MARK: - Push (Local → Shared)`
- `// MARK: - Pull (Shared → Local)`
- `// MARK: - Tombstone Cleanup`
- `// MARK: - Auto-Sync Timer`

## Property Wrappers

**Common patterns:**
- `@State private var` for view local state
- `@Bindable var` for mutable model binding: `@Bindable var note: Note`
- `@Query` for SwiftData queries: `@Query private var tasks: [TodoTask]`
- `@Environment` for SwiftUI environment access: `@Environment(\.modelContext)`
- `@StateObject` for observable objects: `@StateObject private var syncManager = SyncManager()`
- `@Published` for observable properties in classes: `@Published var status: SyncStatus`

---

*Convention analysis: 2026-03-01*
