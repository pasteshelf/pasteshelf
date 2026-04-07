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
        #expect(config.organizationID == "")
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
        let a = SelfHostedSyncConfiguration(
            serverURL: URL(string: "https://sync.example.com"),
            organizationID: "acme"
        )
        let b = SelfHostedSyncConfiguration(
            serverURL: URL(string: "https://sync.example.com"),
            organizationID: "acme"
        )
        #expect(a == b)
    }

    @Test("Configurations with different org IDs are not equal")
    func unequalConfigs() {
        let a = SelfHostedSyncConfiguration(organizationID: "alpha")
        let b = SelfHostedSyncConfiguration(organizationID: "beta")
        #expect(a != b)
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
        #expect(SyncBackendStatus.available == SyncBackendStatus.available)
    }

    @Test("AuthenticationRequired status equals itself")
    func authRequiredEquality() {
        #expect(SyncBackendStatus.authenticationRequired == SyncBackendStatus.authenticationRequired)
    }

    @Test("Unavailable with same reason are equal")
    func unavailableEquality() {
        let a = SyncBackendStatus.unavailable(reason: "test")
        let b = SyncBackendStatus.unavailable(reason: "test")
        #expect(a == b)
    }

    @Test("Unavailable with different reasons are not equal")
    func unavailableInequality() {
        let a = SyncBackendStatus.unavailable(reason: "reason1")
        let b = SyncBackendStatus.unavailable(reason: "reason2")
        #expect(a != b)
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
        #expect(SyncError.certificatePinningFailed == SyncError.certificatePinningFailed)
        #expect(SyncError.authenticationTokenExpired == SyncError.authenticationTokenExpired)
        #expect(SyncError.serverConnectionFailed(message: "a") == SyncError.serverConnectionFailed(message: "a"))
        #expect(SyncError.serverConnectionFailed(message: "a") != SyncError.serverConnectionFailed(message: "b"))
        #expect(SyncError.selfHostedServerError(code: 500, message: "x") == SyncError.selfHostedServerError(
            code: 500,
            message: "x"
        ))
        #expect(SyncError.selfHostedServerError(code: 500, message: "x") != SyncError.selfHostedServerError(
            code: 404,
            message: "x"
        ))
    }
}
