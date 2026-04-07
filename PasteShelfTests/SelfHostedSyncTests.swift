//
//  SelfHostedSyncTests.swift
//  PasteShelfTests
//
//  Unit tests for self-hosted sync: configuration model, protocol types,
//  backend status, and error handling.
//

import Foundation
@testable import PasteShelf
import Testing

// MARK: - SelfHostedSyncConfigurationTests

struct SelfHostedSyncConfigurationTests {
    // MARK: - Initialization

    @Test("Default configuration has no server URL and is disabled")
    func defaultInit() {
        let config = SelfHostedSyncConfiguration()
        #expect(config.serverURL == nil)
        #expect(config.organizationID.isEmpty)
        #expect(config.apiKey == nil)
        #expect(config.isEnabled == false)
        #expect(config.certificatePinningEnabled == false)
        #expect(config.pinnedCertificateData == nil)
    }

    @Test("Empty sentinel matches default initialization")
    func emptySentinel() {
        let empty = SelfHostedSyncConfiguration.empty
        let manual = SelfHostedSyncConfiguration()
        #expect(empty == manual)
    }

    @Test("Configuration with URL and org ID is considered configured")
    func isConfigured() {
        let config = SelfHostedSyncConfiguration(
            serverURL: URL(string: "https://sync.example.com"),
            organizationID: "acme-corp"
        )
        #expect(config.isConfigured == true)
    }

    @Test("Configuration without URL is not configured")
    func notConfiguredWithoutURL() {
        let config = SelfHostedSyncConfiguration(
            serverURL: nil,
            organizationID: "acme-corp"
        )
        #expect(config.isConfigured == false)
    }

    @Test("Configuration with empty org ID is not configured")
    func notConfiguredWithEmptyOrg() {
        let config = SelfHostedSyncConfiguration(
            serverURL: URL(string: "https://sync.example.com"),
            organizationID: ""
        )
        #expect(config.isConfigured == false)
    }

    // MARK: - Codable

    @Test("Configuration round-trips through JSON encoding/decoding")
    func codableRoundTrip() throws {
        let original = SelfHostedSyncConfiguration(
            serverURL: URL(string: "https://sync.example.com"),
            organizationID: "acme-corp",
            apiKey: "ps_test_key_123",
            isEnabled: true,
            certificatePinningEnabled: true,
            pinnedCertificateData: Data([0x01, 0x02, 0x03])
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SelfHostedSyncConfiguration.self, from: data)

        #expect(decoded == original)
    }

    // MARK: - Equatable

    @Test("Configurations with same values are equal")
    func equalConfigs() {
        let config1 = SelfHostedSyncConfiguration(
            serverURL: URL(string: "https://sync.example.com"),
            organizationID: "acme"
        )
        let config2 = SelfHostedSyncConfiguration(
            serverURL: URL(string: "https://sync.example.com"),
            organizationID: "acme"
        )
        #expect(config1 == config2)
    }

    @Test("Configurations with different org IDs are not equal")
    func unequalConfigs() {
        let config1 = SelfHostedSyncConfiguration(organizationID: "alpha")
        let config2 = SelfHostedSyncConfiguration(organizationID: "beta")
        #expect(config1 != config2)
    }
}

// MARK: - SyncBackendTypeTests

struct SyncBackendTypeTests {
    @Test("CloudKit backend type has correct raw value")
    func cloudKitRawValue() {
        #expect(SyncBackendType.cloudKit.rawValue == "cloudkit")
    }

    @Test("SelfHosted backend type has correct raw value")
    func selfHostedRawValue() {
        #expect(SyncBackendType.selfHosted.rawValue == "self_hosted")
    }

    @Test("Backend type round-trips through Codable")
    func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(SyncBackendType.selfHosted)
        let decoded = try JSONDecoder().decode(SyncBackendType.self, from: data)
        #expect(decoded == .selfHosted)
    }
}

// MARK: - SyncBackendStatusTests

struct SyncBackendStatusTests {
    @Test("Available status equals itself")
    func availableEquality() {
        let status1 = SyncBackendStatus.available
        let status2 = SyncBackendStatus.available
        #expect(status1 == status2)
    }

    @Test("AuthenticationRequired status equals itself")
    func authRequiredEquality() {
        let status1 = SyncBackendStatus.authenticationRequired
        let status2 = SyncBackendStatus.authenticationRequired
        #expect(status1 == status2)
    }

    @Test("Unavailable with same reason are equal")
    func unavailableEquality() {
        let status1 = SyncBackendStatus.unavailable(reason: "test")
        let status2 = SyncBackendStatus.unavailable(reason: "test")
        #expect(status1 == status2)
    }

    @Test("Unavailable with different reasons are not equal")
    func unavailableInequality() {
        let status1 = SyncBackendStatus.unavailable(reason: "reason1")
        let status2 = SyncBackendStatus.unavailable(reason: "reason2")
        #expect(status1 != status2)
    }

    @Test("Available and AuthenticationRequired are not equal")
    func differentStatusesNotEqual() {
        #expect(SyncBackendStatus.available != SyncBackendStatus.authenticationRequired)
    }
}

// MARK: - SyncPushResultTests

struct SyncPushResultTests {
    @Test("Push result initializes with defaults")
    func defaultInit() {
        let result = SyncPushResult(accepted: 5)
        #expect(result.accepted == 5)
        #expect(result.conflicts.isEmpty)
        #expect(result.newToken == nil)
    }

    @Test("Push result with conflicts")
    func withConflicts() {
        let conflict = SyncConflict(
            entityID: UUID(),
            serverEncryptedData: Data([0x01]),
            serverTimestamp: Date()
        )
        let result = SyncPushResult(accepted: 3, conflicts: [conflict])
        #expect(result.accepted == 3)
        #expect(result.conflicts.count == 1)
    }
}

// MARK: - SyncPullResultTests

struct SyncPullResultTests {
    @Test("Pull result with no changes and no more data")
    func emptyPull() {
        let result = SyncPullResult(changes: [], newToken: nil)
        #expect(result.changes.isEmpty)
        #expect(result.newToken == nil)
        #expect(result.hasMore == false)
    }

    @Test("Pull result hasMore indicates pagination")
    func hasMorePagination() {
        let result = SyncPullResult(changes: [], newToken: Data("42".utf8), hasMore: true)
        #expect(result.hasMore == true)
        #expect(result.newToken != nil)
    }
}

// MARK: - SyncNotificationTests

struct SyncNotificationTests {
    @Test("Notification types have correct raw values")
    func notificationTypeRawValues() {
        #expect(SyncNotification.NotificationType.changesAvailable.rawValue == "changes_available")
        #expect(SyncNotification.NotificationType.forceSync.rawValue == "force_sync")
        #expect(SyncNotification.NotificationType.deviceRemoved.rawValue == "device_removed")
        #expect(SyncNotification.NotificationType.authExpired.rawValue == "auth_expired")
    }

    @Test("Notification initializes with defaults")
    func defaultInit() {
        let notification = SyncNotification(type: .changesAvailable)
        #expect(notification.changeCount == 0)
        #expect(notification.sourceDeviceID == nil)
        #expect(notification.sinceToken == nil)
    }

    @Test("Notification with all fields populated")
    func fullInit() {
        let notification = SyncNotification(
            type: .changesAvailable,
            sinceToken: Data("token".utf8),
            changeCount: 5,
            sourceDeviceID: "device-123"
        )
        #expect(notification.type == .changesAvailable)
        #expect(notification.changeCount == 5)
        #expect(notification.sourceDeviceID == "device-123")
    }
}

// MARK: - SyncErrorSelfHostedTests

struct SyncErrorSelfHostedTests {
    @Test("serverConnectionFailed error has localized description")
    func serverConnectionFailedDescription() {
        let error = SyncError.serverConnectionFailed(message: "timeout")
        #expect(error.errorDescription?.contains("timeout") == true)
    }

    @Test("certificatePinningFailed error has localized description")
    func certificatePinningFailedDescription() {
        let error = SyncError.certificatePinningFailed
        #expect(error.errorDescription != nil)
    }

    @Test("authenticationTokenExpired error has localized description")
    func authTokenExpiredDescription() {
        let error = SyncError.authenticationTokenExpired
        #expect(error.errorDescription != nil)
    }

    @Test("selfHostedServerError includes code and message")
    func selfHostedServerErrorDescription() {
        let error = SyncError.selfHostedServerError(code: 500, message: "internal error")
        #expect(error.errorDescription?.contains("500") == true)
        #expect(error.errorDescription?.contains("internal error") == true)
    }

    @Test("serverConnectionFailed has recovery suggestion")
    func serverConnectionRecovery() {
        let error = SyncError.serverConnectionFailed(message: "test")
        #expect(error.recoverySuggestion != nil)
    }

    @Test("certificatePinningFailed has recovery suggestion")
    func certPinningRecovery() {
        let error = SyncError.certificatePinningFailed
        #expect(error.recoverySuggestion != nil)
    }

    @Test("Self-hosted error equality")
    func errorEquality() {
        let certPinning1 = SyncError.certificatePinningFailed
        let certPinning2 = SyncError.certificatePinningFailed
        #expect(certPinning1 == certPinning2)
        let tokenExpired1 = SyncError.authenticationTokenExpired
        let tokenExpired2 = SyncError.authenticationTokenExpired
        #expect(tokenExpired1 == tokenExpired2)
        let connFailA1 = SyncError.serverConnectionFailed(message: "a")
        let connFailA2 = SyncError.serverConnectionFailed(message: "a")
        #expect(connFailA1 == connFailA2)
        let connFailB = SyncError.serverConnectionFailed(message: "b")
        #expect(connFailA1 != connFailB)
        let serverErr500a = SyncError.selfHostedServerError(code: 500, message: "x")
        let serverErr500b = SyncError.selfHostedServerError(code: 500, message: "x")
        #expect(serverErr500a == serverErr500b)
        let serverErr404 = SyncError.selfHostedServerError(code: 404, message: "x")
        #expect(serverErr500a != serverErr404)
    }
}
