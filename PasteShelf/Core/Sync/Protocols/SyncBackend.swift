//
//  SyncBackend.swift
//  PasteShelf
//
//  Backend-agnostic sync provider protocol.
//  Allows SyncManager to work with CloudKit, self-hosted servers, or any future backend.
//

import Foundation

// MARK: - SyncBackend Protocol

/// Backend-agnostic protocol for sync operations.
///
/// `SyncBackend` abstracts the transport layer so that `SyncManager` can push and pull
/// encrypted change sets without knowing whether the backing store is CloudKit, a
/// self-hosted REST server, or any other provider.
///
/// Implementations must be `Sendable` because `SyncManager` may call methods from
/// different isolation contexts (e.g., background tasks, network callbacks).
public protocol SyncBackend: Sendable {

    /// Check whether the backend is reachable and the user is authenticated.
    func checkAvailability() async throws -> SyncBackendStatus

    /// Perform one-time setup (create zones, register device, etc.).
    func setup() async throws

    /// Push local changes to the backend.
    ///
    /// The caller is responsible for encrypting each `SyncChange.encryptedData`
    /// before passing it here. Returns a result indicating accepted/rejected
    /// counts and any conflicts.
    func pushChanges(_ changes: [SyncChange]) async throws -> SyncPushResult

    /// Pull remote changes since the given opaque token.
    ///
    /// Pass `nil` for the initial sync. The returned `newToken` should be
    /// persisted and supplied on the next call.
    func pullChanges(sinceToken: Data?) async throws -> SyncPullResult

    /// Delete a record by its client-side entity ID.
    func deleteRecord(entityID: UUID) async throws

    /// Subscribe to real-time change notifications from the backend.
    ///
    /// The handler is called whenever another device pushes changes. The
    /// implementation decides the transport (push notifications, WebSocket, etc.).
    /// Calling this a second time replaces the previous handler.
    func subscribeToChanges(handler: @escaping @Sendable (SyncNotification) -> Void) async throws

    /// Tear down all backend state (zones, device registration, etc.).
    ///
    /// Called during a sync reset.
    func teardown() async throws
}

// MARK: - SyncBackendStatus

/// The availability state of a sync backend.
public enum SyncBackendStatus: Sendable, Equatable {
    /// Backend is reachable and user is authenticated.
    case available

    /// Backend is reachable but the user must authenticate.
    case authenticationRequired

    /// Backend is not reachable or is misconfigured.
    case unavailable(reason: String)
}

// MARK: - SyncPushResult

/// Result of pushing changes to a sync backend.
public struct SyncPushResult: Sendable {
    /// Number of changes accepted by the server.
    public let accepted: Int

    /// Conflicts detected during push.
    ///
    /// Each conflict contains the entity ID and the server's current version,
    /// allowing the client to resolve and retry.
    public let conflicts: [SyncConflict]

    /// An updated opaque token representing the server's state after this push.
    public let newToken: Data?

    /// Server timestamp at the time of processing.
    public let serverTimestamp: Date

    public init(
        accepted: Int,
        conflicts: [SyncConflict] = [],
        newToken: Data? = nil,
        serverTimestamp: Date = Date()
    ) {
        self.accepted = accepted
        self.conflicts = conflicts
        self.newToken = newToken
        self.serverTimestamp = serverTimestamp
    }
}

// MARK: - SyncConflict

/// A conflict between a local change and the server's current version.
public struct SyncConflict: Sendable {
    /// The entity that has a conflict.
    public let entityID: UUID

    /// The server's current encrypted data for this entity.
    public let serverEncryptedData: Data?

    /// When the server's version was last modified.
    public let serverTimestamp: Date

    public init(entityID: UUID, serverEncryptedData: Data?, serverTimestamp: Date) {
        self.entityID = entityID
        self.serverEncryptedData = serverEncryptedData
        self.serverTimestamp = serverTimestamp
    }
}

// MARK: - SyncPullResult

/// Result of pulling changes from a sync backend.
public struct SyncPullResult: Sendable {
    /// Remote changes since the requested token.
    public let changes: [SyncChange]

    /// An updated opaque token. Persist this and pass it on the next pull.
    public let newToken: Data?

    /// If `true`, more changes are available. Call `pullChanges` again with
    /// the `newToken` to continue.
    public let hasMore: Bool

    public init(changes: [SyncChange], newToken: Data?, hasMore: Bool = false) {
        self.changes = changes
        self.newToken = newToken
        self.hasMore = hasMore
    }
}

// MARK: - SyncNotification

/// A lightweight notification that new changes are available.
///
/// Delivered via `subscribeToChanges`. The client should call `pullChanges`
/// in response rather than expecting data in the notification itself.
public struct SyncNotification: Sendable {
    /// The type of notification.
    public let type: NotificationType

    /// An opaque token indicating the point-in-time of the notification.
    public let sinceToken: Data?

    /// Number of changes available (hint for UI).
    public let changeCount: Int

    /// The device that originated the changes (if known).
    public let sourceDeviceID: String?

    public init(
        type: NotificationType,
        sinceToken: Data? = nil,
        changeCount: Int = 0,
        sourceDeviceID: String? = nil
    ) {
        self.type = type
        self.sinceToken = sinceToken
        self.changeCount = changeCount
        self.sourceDeviceID = sourceDeviceID
    }

    /// Types of sync notifications.
    public enum NotificationType: String, Sendable {
        /// Changes are available from another device.
        case changesAvailable = "changes_available"

        /// Admin-triggered forced sync (e.g., policy update).
        case forceSync = "force_sync"

        /// This device was removed from the sync group.
        case deviceRemoved = "device_removed"

        /// Authentication has expired and must be refreshed.
        case authExpired = "auth_expired"
    }
}

// MARK: - SyncBackendType

/// Identifies which sync backend is in use.
public enum SyncBackendType: String, Sendable, Codable {
    /// Apple iCloud via CloudKit (Pro tier).
    case cloudKit = "cloudkit"

    /// Self-hosted sync server (Enterprise tier).
    case selfHosted = "self_hosted"
}
