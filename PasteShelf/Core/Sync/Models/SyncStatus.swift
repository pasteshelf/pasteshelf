//
//  SyncStatus.swift
//  PasteShelf
//
//  Sync status representations and helpers.
//

import Foundation
import SwiftUI

// MARK: - SyncStatus Extensions

public extension SyncStatus {
    /// Human-readable description of the sync status
    var localizedDescription: String {
        switch self {
        case .disabled:
            return String(localized: "Sync disabled")
        case .idle:
            return String(localized: "Ready to sync")
        case let .syncing(progress):
            if progress > 0 {
                return String(localized: "Syncing... \(Int(progress * 100))%")
            }
            return String(localized: "Syncing...")
        case let .synced(lastSync):
            return String(localized: "Last synced \(lastSync.formatted(.relative(presentation: .named)))")
        case .error:
            return String(localized: "Sync error")
        case .offline:
            return String(localized: "Offline - changes queued")
        case .waitingForAccount:
            return String(localized: "Waiting for iCloud account")
        }
    }

    /// SF Symbol name for this status
    var symbolName: String {
        switch self {
        case .disabled:
            "icloud.slash"
        case .idle:
            "icloud"
        case .syncing:
            "arrow.triangle.2.circlepath.icloud"
        case .synced:
            "checkmark.icloud"
        case .error:
            "exclamationmark.icloud"
        case .offline:
            "icloud.slash"
        case .waitingForAccount:
            "person.icloud"
        }
    }

    /// Color associated with this status
    var color: Color {
        switch self {
        case .disabled,
             .waitingForAccount:
            .secondary
        case .idle:
            .primary
        case .syncing:
            .blue
        case .synced:
            .green
        case .error:
            .red
        case .offline:
            .orange
        }
    }

    /// Whether sync is currently active
    var isActive: Bool {
        switch self {
        case .syncing:
            true
        default:
            false
        }
    }

    /// Whether the user can trigger a manual sync
    var canSync: Bool {
        switch self {
        case .idle,
             .synced,
             .error:
            true
        default:
            false
        }
    }
}

// MARK: - ItemSyncState Extensions

public extension ItemSyncState {
    /// Human-readable description
    var localizedDescription: String {
        switch self {
        case .pending:
            String(localized: "Pending sync")
        case .synced:
            String(localized: "Synced")
        case .conflicted:
            String(localized: "Conflict")
        case .deleted:
            String(localized: "Deleted")
        }
    }

    /// SF Symbol name for this state
    var symbolName: String {
        switch self {
        case .pending:
            "arrow.up.circle"
        case .synced:
            "checkmark.circle"
        case .conflicted:
            "exclamationmark.triangle"
        case .deleted:
            "trash.circle"
        }
    }

    /// Color for this state
    var color: Color {
        switch self {
        case .pending:
            .blue
        case .synced:
            .green
        case .conflicted:
            .orange
        case .deleted:
            .red
        }
    }
}
