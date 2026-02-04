//
//  SyncStatus.swift
//  PasteShelf
//
//  Sync status representations and helpers.
//

import Foundation
import SwiftUI

// MARK: - SyncStatus Extensions

extension SyncStatus {
    /// Human-readable description of the sync status
    public var localizedDescription: String {
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
    public var symbolName: String {
        switch self {
        case .disabled:
            return "icloud.slash"
        case .idle:
            return "icloud"
        case .syncing:
            return "arrow.triangle.2.circlepath.icloud"
        case .synced:
            return "checkmark.icloud"
        case .error:
            return "exclamationmark.icloud"
        case .offline:
            return "icloud.slash"
        case .waitingForAccount:
            return "person.icloud"
        }
    }

    /// Color associated with this status
    public var color: Color {
        switch self {
        case .disabled, .waitingForAccount:
            return .secondary
        case .idle:
            return .primary
        case .syncing:
            return .blue
        case .synced:
            return .green
        case .error:
            return .red
        case .offline:
            return .orange
        }
    }

    /// Whether sync is currently active
    public var isActive: Bool {
        switch self {
        case .syncing:
            return true
        default:
            return false
        }
    }

    /// Whether the user can trigger a manual sync
    public var canSync: Bool {
        switch self {
        case .idle, .synced, .error:
            return true
        default:
            return false
        }
    }
}

// MARK: - ItemSyncState Extensions

extension ItemSyncState {
    /// Human-readable description
    public var localizedDescription: String {
        switch self {
        case .pending:
            return String(localized: "Pending sync")
        case .synced:
            return String(localized: "Synced")
        case .conflicted:
            return String(localized: "Conflict")
        case .deleted:
            return String(localized: "Deleted")
        }
    }

    /// SF Symbol name for this state
    public var symbolName: String {
        switch self {
        case .pending:
            return "arrow.up.circle"
        case .synced:
            return "checkmark.circle"
        case .conflicted:
            return "exclamationmark.triangle"
        case .deleted:
            return "trash.circle"
        }
    }

    /// Color for this state
    public var color: Color {
        switch self {
        case .pending:
            return .blue
        case .synced:
            return .green
        case .conflicted:
            return .orange
        case .deleted:
            return .red
        }
    }
}
