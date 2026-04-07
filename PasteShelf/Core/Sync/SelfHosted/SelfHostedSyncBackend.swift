//
//  SelfHostedSyncBackend.swift
//  PasteShelf
//
//  Sync backend for self-hosted enterprise sync servers.
//  Implements SyncBackend using REST API + WebSocket notifications.
//

import Foundation
import os.log

// MARK: - SelfHostedSyncBackend

/// Sync backend that communicates with a self-hosted PasteShelf sync server.
///
/// This is the Enterprise alternative to `CloudKitSyncBackend`. All data is
/// E2E encrypted client-side before being sent to the server — the server
/// stores only opaque encrypted blobs (zero-knowledge architecture).
///
/// Communication uses:
/// - **REST API** for push/pull/auth operations
/// - **WebSocket** for real-time change notifications
final class SelfHostedSyncBackend: SyncBackend {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(configuration: SelfHostedSyncConfiguration) {
        self.configuration = configuration

        // Create cert pinning delegate if enabled
        let sessionDelegate: URLSessionDelegate? = if configuration.certificatePinningEnabled {
            CertificatePinningDelegate(configuration: configuration)
        } else {
            nil
        }

        self.apiClient = SelfHostedAPIClient(configuration: configuration, urlSessionDelegate: sessionDelegate)
        self.webSocketClient = SelfHostedWebSocketClient(configuration: configuration)

        // Use a stable device ID (persisted in UserDefaults)
        self.deviceID = Self.resolveDeviceID()
        self.deviceName = Host.current().localizedName ?? "Mac"
    }

    // MARK: Internal

    // MARK: - SyncBackend Protocol

    func checkAvailability() async throws -> SyncBackendStatus {
        guard self.configuration.serverURL != nil else {
            return .unavailable(reason: "No server URL configured")
        }

        do {
            let health = try await apiClient.healthCheck()
            if health.status == "ok" || health.status == "degraded" {
                if self.configuration.apiKey != nil {
                    return .available
                }
                return .authenticationRequired
            }
            return .unavailable(reason: "Server status: \(health.status)")
        } catch {
            return .unavailable(reason: error.localizedDescription)
        }
    }

    func setup() async throws {
        self.logger.info("Setting up self-hosted sync backend")

        // Register device with the sync server
        _ = try await self.apiClient.registerDevice(
            deviceID: self.deviceID,
            deviceName: self.deviceName,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        )

        self.logger.info("Device registered with self-hosted server: \(self.deviceID)")
    }

    func pushChanges(_ changes: [SyncChange]) async throws -> SyncPushResult {
        self.logger.info("Pushing \(changes.count) changes to self-hosted server")

        // Convert SyncChange to API payloads
        let payloads = changes.map { change -> SyncChangePayload in
            SyncChangePayload(
                entityID: change.entityID,
                entityType: change.entityType.rawValue,
                encryptedData: change.encryptedData?.base64EncodedString(),
                contentHash: nil,
                isDeleted: change.isDeletion,
                clientVersion: nil
            )
        }

        let result = try await apiClient.pushChanges(payloads, deviceID: self.deviceID)

        // Convert API conflicts to SyncConflict
        let conflicts = result.conflicts.map { conflict -> SyncConflict in
            SyncConflict(
                entityID: conflict.entityID,
                serverEncryptedData: conflict.serverEncryptedData.flatMap { Data(base64Encoded: $0) },
                serverTimestamp: result.serverTimestamp
            )
        }

        return SyncPushResult(
            accepted: result.accepted,
            conflicts: conflicts,
            newToken: nil,
            serverTimestamp: result.serverTimestamp
        )
    }

    func pullChanges(sinceToken: Data?) async throws -> SyncPullResult {
        self.logger.info("Pulling changes from self-hosted server")

        // Convert opaque Data token to string
        let tokenString = sinceToken.flatMap { String(data: $0, encoding: .utf8) }

        let result = try await apiClient.pullChanges(since: tokenString)

        // Convert API changes to SyncChange
        let syncChanges: [SyncChange] = result.changes.map { apiChange in
            let changeType: SyncChange.ChangeType = switch apiChange.changeType {
            case "insert":
                .remoteInsert
            case "update":
                .remoteUpdate
            case "delete":
                .remoteDelete
            default:
                .remoteUpdate
            }

            let entityType = SyncChange.EntityType(rawValue: apiChange.entityType) ?? .clipboardItem

            return SyncChange(
                changeType: changeType,
                entityType: entityType,
                entityID: apiChange.entityID,
                serverTimestamp: apiChange.timestamp,
                encryptedData: apiChange.encryptedData.flatMap { Data(base64Encoded: $0) }
            )
        }

        // Convert new token string to opaque Data
        let newTokenData = result.newToken.data(using: .utf8)

        return SyncPullResult(
            changes: syncChanges,
            newToken: newTokenData,
            hasMore: result.hasMore
        )
    }

    func deleteRecord(entityID: UUID) async throws {
        self.logger.info("Deleting record \(entityID) on self-hosted server")

        // Push a deletion change
        let payload = SyncChangePayload(
            entityID: entityID,
            entityType: SyncChange.EntityType.clipboardItem.rawValue,
            encryptedData: nil,
            contentHash: nil,
            isDeleted: true,
            clientVersion: nil
        )
        _ = try await self.apiClient.pushChanges([payload], deviceID: self.deviceID)
    }

    func subscribeToChanges(handler: @escaping @Sendable (SyncNotification) -> Void) async throws {
        self.logger.info("Subscribing to self-hosted sync notifications")
        self.notificationHandler = handler

        // Set up WebSocket notification handling
        self.webSocketClient.onNotification = { [weak self] wsNotification in
            guard let self else {
                return
            }

            let notificationType: SyncNotification.NotificationType
            switch wsNotification.type {
            case "changes_available":
                notificationType = .changesAvailable
            case "force_sync":
                notificationType = .forceSync
            case "device_removed":
                notificationType = .deviceRemoved
            case "auth_expired":
                notificationType = .authExpired
            default:
                return
            }

            let notification = SyncNotification(
                type: notificationType,
                changeCount: wsNotification.changeCount ?? 0,
                sourceDeviceID: wsNotification.deviceID
            )
            handler(notification)
        }

        // Connect WebSocket if we have an API key (used as token for WS auth)
        if let apiKey = configuration.apiKey {
            self.webSocketClient.connect(token: apiKey, deviceID: self.deviceID)
        }
    }

    func teardown() async throws {
        self.logger.info("Tearing down self-hosted sync backend")

        // Disconnect WebSocket
        self.webSocketClient.disconnect()

        // Unregister device
        do {
            try await self.apiClient.removeDevice(deviceID: self.deviceID)
        } catch {
            self.logger.warning("Failed to unregister device: \(error.localizedDescription)")
        }
    }

    // MARK: Private

    // MARK: - Device ID

    private static let deviceIDKey = "com.pasteshelf.selfhosted.deviceID"

    private let configuration: SelfHostedSyncConfiguration
    private let apiClient: SelfHostedAPIClient
    private let webSocketClient: SelfHostedWebSocketClient
    private let logger = Logger(subsystem: "com.pasteshelf", category: "self-hosted-backend")

    /// Device identifier for this client (persisted across launches).
    private let deviceID: String

    /// Human-readable device name.
    private let deviceName: String

    /// Handler for incoming sync notifications.
    private var notificationHandler: (@Sendable (SyncNotification) -> Void)?

    /// Get or create a stable device identifier persisted in UserDefaults.
    private static func resolveDeviceID() -> String {
        if let existing = UserDefaults.standard.string(forKey: deviceIDKey) {
            return existing
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: self.deviceIDKey)
        return newID
    }
}
