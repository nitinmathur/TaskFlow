import SwiftUI
import SwiftData

struct SyncToolbarView: View {
    @ObservedObject var syncManager: SyncManager
    var onPush: () -> Void
    var onPull: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status badge
            statusBadge

            // Manual sync buttons
            if syncManager.status != .syncing {
                Button(action: onPush) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle")
                        Text("Push")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(syncManager.status == .syncing)

                Button(action: onPull) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                        Text("Pull")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(syncManager.status == .syncing)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            if syncManager.status == .syncing {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch syncManager.status {
        case .inSync: return .green
        case .localChanges: return .orange
        case .remoteChanges: return .blue
        case .conflict: return .red
        case .syncing: return .gray
        }
    }

    private var statusText: String {
        switch syncManager.status {
        case .inSync: return "Synced"
        case .localChanges: return "Local changes pending"
        case .remoteChanges:
            return "Remote changes available"
        case .conflict: return "Conflict detected"
        case .syncing:
            if syncManager.isPushing {
                return "Pushing to iCloud..."
            } else {
                return "Pulling from iCloud..."
            }
        }
    }
}
