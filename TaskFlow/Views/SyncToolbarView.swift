import SwiftUI
import SwiftData

struct SyncToolbarView: View {
    @ObservedObject var syncManager: SyncManager

    var body: some View {
        statusBadge
    }

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
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
        case .inSync: .green
        case .localChanges: .orange
        case .remoteChanges: .blue
        case .conflict: .red
        case .syncing: .gray
        }
    }

    private var statusText: String {
        switch syncManager.status {
        case .inSync: return "Synced"
        case .localChanges: return "Syncing soon..."
        case .remoteChanges:
            let count = syncManager.countdown
            return "Updates - pulling in \(count)s"
        case .conflict: return "Conflict"
        case .syncing: return "Syncing..."
        }
    }
}

