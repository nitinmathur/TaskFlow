# Technology Stack

**Analysis Date:** 2026-03-01

## Languages

**Primary:**
- Swift 5.0+ - All application code, UI, data models, and sync logic

**Secondary:**
- YAML - Project configuration via XcodeGen (`project.yml`)

## Runtime

**Environment:**
- macOS 14.0+ (Sonoma)

**Build System:**
- Xcode 15+
- XcodeGen - Project generation from YAML configuration

## Frameworks

**Core UI:**
- SwiftUI - Modern declarative UI framework
  - Location: `TaskFlow/Views/` - All view hierarchies
  - Features: Drag & drop, tab navigation, markdown rendering

**Data Persistence:**
- SwiftData - Modern ORM for Swift
  - Location: `TaskFlow/Models/` - Data models
  - Files: `TaskFlowApp.swift` - ModelContainer configuration
  - Features: Type-safe queries, automatic change tracking
  - Database: SQLite with WAL disabled for iCloud Drive compatibility

**System Framework:**
- AppKit - macOS-specific APIs
  - Used in: `MarkdownRenderer.swift` for native color handling

## Key Dependencies

**Core:**
- SwiftData - ORM and data persistence model
- SwiftUI - UI framework (built-in)
- Foundation - Standard library utilities
- Combine - Reactive framework for state management

**Database:**
- SQLite3 - Direct access via C-level APIs
  - Purpose: WAL mode management in `TaskFlowApp.swift`
  - Configuration: Journal mode set to DELETE for iCloud Drive sync

## Configuration

**Environment:**
- No .env file needed - purely macOS app with no external API requirements
- iCloud Drive configuration via `UIFileSharingEnabled` (implicit)

**Build Configuration:**
- `project.yml` - XcodeGen configuration
  - Bundle ID: `com.nmathur.taskflow`
  - Deployment Target: macOS 14.0
  - Code Signing: Automatic
  - App Category: Productivity

**Xcode Project:**
- `TaskFlow.xcodeproj/project.pbxproj` - Generated project file (via XcodeGen)
  - SWIFT_VERSION: 5.0
  - MACOSX_DEPLOYMENT_TARGET: 14.0
  - INFOPLIST_KEY_LSApplicationCategoryType: public.app-category.productivity

## Platform Requirements

**Development:**
- macOS 14.0+
- Xcode 15+
- XcodeGen (installable via Homebrew: `brew install xcodegen`)

**Production:**
- macOS 14.0+
- iCloud Drive enabled for sync functionality (optional - app works offline locally)
- No additional runtime dependencies or SDKs required

## Storage Strategy

**Local Storage:**
- Primary: `~/Library/Mobile Documents/com~apple~CloudDocs/TaskFlow/`
  - Contains: SQLite database file (`TaskFlow.store`)
  - Format: SQLite3
  - Journal Mode: DELETE (not WAL) for iCloud Drive compatibility

**Fallback:**
- `~/Documents/TaskFlow/` if iCloud Drive unavailable
- Automatic directory creation on app startup

---

*Stack analysis: 2026-03-01*
