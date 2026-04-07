//
//  CloudKitSyncBackend.swift
//  PasteShelf
//
//  Adapter that wraps CloudKitProvider to conform to the SyncBackend protocol.
//  This allows SyncManager to use CloudKit through the backend-agnostic interface.
//

import CloudKit
import Foundation
import os.log

// MARK: - CloudKitSyncBackend

/// Wraps the existing `CloudKitProvider` to satisfy the `SyncBackend` protocol.
///
/// This adapter translates between the CloudKit-specific types used internally
/// by `CloudKitProvider` (e.g., `CKServerChangeToken`, `CKRecord.ID`) and the
/// opaque `Data` tokens expected by `SyncBackend`.
final class CloudKitSyncBackend: SyncBackend {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(provider: CloudKitProvider = CloudKitProvider()) {
        self.provider = provider
    }

    // MARK: Internal

    // MARK: - Token Serialization

    /// Serialize a `CKServerChangeToken` to opaque `Data` for the backend-agnostic interface.
    static func serializeChangeToken(_ token: CKServerChangeToken) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    /// Deserialize `Data` back to a `CKServerChangeToken`.
    static func deserializeChangeToken(_ data: Data) -> CKServerChangeToken? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    // MARK: - SyncBackend Protocol

    func checkAvailability() async throws -> SyncBackendStatus {
        do {
            let status = try await provider.checkAccountStatus()
            switch status {
            case .available:
                return .available
            case .noAccount:
                return .authenticationRequired
            case .restricted:
                return .unavailable(reason: "iCloud access is restricted")
            case .couldNotDetermine,
                 .temporarilyUnavailable:
                return .unavailable(reason: "iCloud is temporarily unavailable")
            @unknown default:
                return .unavailable(reason: "Unknown iCloud status")
            }
        } catch {
            return .unavailable(reason: error.localizedDescription)
        }
    }

    func setup() async throws {
        try await provider.setupZone()
        try await provider.subscribeToChanges()
        logger.info("CloudKit zone and subscription set up")
    }

    func pushChanges(_ changes: [SyncChange]) async throws -> SyncPushResult {
        try await provider.pushChanges(changes)

        // CloudKitProvider doesn't return conflict details directly —
        // conflicts surface as CKError.serverRecordChanged and are thrown.
        // If we reach here, all changes were accepted.
        return SyncPushResult(
            accepted: changes.count,
            conflicts: [],
            newToken: nil,
            serverTimestamp: Date()
        )
    }

    func pullChanges(sinceToken: Data?) async throws -> SyncPullResult {
        let ckToken = sinceToken.flatMap { Self.deserializeChangeToken($0) }

        let result = try await provider.pullChanges(since: ckToken)

        let newTokenData = result.newToken.flatMap { Self.serializeChangeToken($0) }

        return SyncPullResult(
            changes: result.changes,
            newToken: newTokenData,
            hasMore: false // CloudKitProvider handles pagination internally
        )
    }

    func deleteRecord(entityID: UUID) async throws {
        let recordID = CKRecord.ID(
            recordName: entityID.uuidString,
            zoneID: provider.zoneID
        )
        try await provider.deleteRecord(withID: recordID)
    }

    func subscribeToChanges(handler: @escaping @Sendable (SyncNotification) -> Void) async throws {
        // CloudKit uses silent push notifications for change subscriptions.
        // The subscription is set up in `setup()`. The actual notification
        // handling is done via AppDelegate / UNUserNotificationCenter, which
        // posts a Combine notification that SyncManager observes.
        //
        // For the SyncBackend interface we register the handler but the
        // actual wiring is handled externally via NotificationCenter.
        try await provider.subscribeToChanges()
        logger.debug("CloudKit change subscription active (notifications handled via AppDelegate)")
    }

    func teardown() async throws {
        try await provider.reset()
        logger.info("CloudKit sync data reset")
    }

    // MARK: Private

    private let provider: CloudKitProvider
    private let logger = Logger(subsystem: "com.pasteshelf", category: "cloudkit-backend")
}
