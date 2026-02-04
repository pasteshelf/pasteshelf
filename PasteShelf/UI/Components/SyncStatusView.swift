//
//  SyncStatusView.swift
//  PasteShelf
//
//  Compact sync status indicator for use in menu bar and panels.
//

import SwiftUI

/// Compact sync status indicator
struct SyncStatusView: View {
    // MARK: - Properties

    @ObservedObject var syncManager: SyncManager

    /// Whether to show the status label
    var showLabel: Bool = true

    /// Size of the status icon
    var iconSize: CGFloat = 16

    // MARK: - Body

    var body: some View {
        HStack(spacing: 6) {
            statusIcon
            if showLabel {
                statusLabel
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        Group {
            switch syncManager.status {
            case .syncing:
                // Animated syncing indicator
                Image(systemName: syncManager.status.symbolName)
                    .symbolEffect(.variableColor.iterative.reversing)
            default:
                Image(systemName: syncManager.status.symbolName)
            }
        }
        .font(.system(size: iconSize, weight: .medium))
        .foregroundStyle(syncManager.status.color)
    }

    // MARK: - Status Label

    @ViewBuilder
    private var statusLabel: some View {
        Text(syncManager.status.localizedDescription)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        "Sync status: \(syncManager.status.localizedDescription)"
    }
}

// MARK: - Menu Bar Sync Badge

/// Minimal sync badge for menu bar icon
struct SyncBadge: View {
    @ObservedObject var syncManager: SyncManager

    var body: some View {
        if syncManager.isEnabled {
            Circle()
                .fill(syncManager.status.color)
                .frame(width: 6, height: 6)
                .opacity(badgeOpacity)
        }
    }

    private var badgeOpacity: Double {
        switch syncManager.status {
        case .disabled, .idle:
            return 0
        case .syncing:
            return 1
        case .synced:
            return 0.7
        case .error, .offline, .waitingForAccount:
            return 1
        }
    }
}

// MARK: - Sync Status Row

/// Full sync status row with action button
struct SyncStatusRow: View {
    @ObservedObject var syncManager: SyncManager

    var body: some View {
        HStack {
            SyncStatusView(syncManager: syncManager)

            Spacer()

            if syncManager.status.canSync {
                Button(action: {
                    Task {
                        try? await syncManager.syncNow()
                    }
                }) {
                    Text("Sync Now")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            } else if case .syncing = syncManager.status {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#if DEBUG
    struct SyncStatusView_Previews: PreviewProvider {
        static var previews: some View {
            VStack(spacing: 20) {
                SyncStatusView(syncManager: SyncManager())
                SyncStatusRow(syncManager: SyncManager())
            }
            .padding()
        }
    }
#endif
