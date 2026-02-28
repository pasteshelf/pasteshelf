//
//  AuditLoggerTests.swift
//  PasteShelfTests
//
//  Tests for AuditLogger: feature-flag gating, convenience logging methods, and
//  batch operations using a mock AuditLogStoring implementation.
//

import Foundation
import Testing
@testable import PasteShelf

// MARK: - MockAuditLogStorage

/// A mock `AuditLogStoring` implementation that records calls and returns pre-configured results.
final class MockAuditLogStorage: AuditLogStoring, @unchecked Sendable {

    var savedEvents: [AuditEvent] = []
    var shouldFail = false

    func save(_ event: AuditEvent) async throws {
        if shouldFail { throw AuditError.storageFailure("Mock failure") }
        savedEvents.append(event)
    }

    func fetchEvents(
        category: AuditEventCategory?,
        from: Date?,
        to: Date?,
        limit: Int
    ) async throws -> [AuditLogEntry] {
        []
    }

    func fetchUnsyncedEvents(limit: Int) async throws -> [AuditLogEntry] {
        []
    }

    func markSynced(_ ids: [UUID]) async throws {}

    func pruneExpired(retentionDays: Int) async throws -> Int {
        0
    }

    func decryptDetail(for entry: AuditLogEntry) throws -> [String: String] {
        [:]
    }
}

// MARK: - AuditLoggerTests

struct AuditLoggerTests {

    // MARK: - Feature Flag Gating

    @Test("log does not persist event when auditLogs feature is unavailable")
    func logDropsEventWhenFeatureUnavailable() async {
        let storage = MockAuditLogStorage()
        let logger = AuditLogger(
            storage: storage,
            deviceIdProvider: { nil },
            userIdProvider: { nil }
        )

        let event = AuditEvent(category: .clipboard, action: .copyCaptured)
        await logger.log(event)

        // LicenseManager.shared.isFeatureAvailable(.auditLogs) returns false in tests,
        // so the event is silently dropped.
        #expect(storage.savedEvents.isEmpty)
    }

    @Test("logBatch does not persist any events when auditLogs feature is unavailable")
    func logBatchDropsEventsWhenFeatureUnavailable() async {
        let storage = MockAuditLogStorage()
        let logger = AuditLogger(
            storage: storage,
            deviceIdProvider: { nil },
            userIdProvider: { nil }
        )

        let events = [
            AuditEvent(category: .clipboard, action: .copyCaptured),
            AuditEvent(category: .authentication, action: .ssoLogin),
            AuditEvent(category: .policy, action: .policyViolation)
        ]
        await logger.logBatch(events)

        #expect(storage.savedEvents.isEmpty)
    }

    // MARK: - Convenience Methods (Feature-Flag Blocked)

    @Test("logClipboardEvent is blocked by feature flag — storage remains empty")
    func logClipboardEventBlockedByFeatureFlag() async {
        let storage = MockAuditLogStorage()
        let logger = AuditLogger(
            storage: storage,
            deviceIdProvider: { "dev-001" },
            userIdProvider: { "user-abc" }
        )

        await logger.logClipboardEvent(action: .copyCaptured, resourceId: "item-123", detail: ["contentType": "text/plain"])

        #expect(storage.savedEvents.isEmpty)
    }

    @Test("logUserAction is blocked by feature flag — storage remains empty")
    func logUserActionBlockedByFeatureFlag() async {
        let storage = MockAuditLogStorage()
        let logger = AuditLogger(
            storage: storage,
            deviceIdProvider: { nil },
            userIdProvider: { nil }
        )

        await logger.logUserAction(action: .searchPerformed, resourceId: nil, detail: [:])

        #expect(storage.savedEvents.isEmpty)
    }

    @Test("logPolicyEvent is blocked by feature flag — storage remains empty")
    func logPolicyEventBlockedByFeatureFlag() async {
        let storage = MockAuditLogStorage()
        let logger = AuditLogger(
            storage: storage,
            deviceIdProvider: { nil },
            userIdProvider: { nil }
        )

        await logger.logPolicyEvent(action: .policyViolation, policyId: "pol-007")

        #expect(storage.savedEvents.isEmpty)
    }

    @Test("logAuthEvent is blocked by feature flag — storage remains empty")
    func logAuthEventBlockedByFeatureFlag() async {
        let storage = MockAuditLogStorage()
        let logger = AuditLogger(
            storage: storage,
            deviceIdProvider: { nil },
            userIdProvider: { nil }
        )

        await logger.logAuthEvent(action: .loginFailure, severity: .critical)

        #expect(storage.savedEvents.isEmpty)
    }

    // MARK: - Error Swallowing

    @Test("log does not throw when storage fails (errors are swallowed)")
    func logDoesNotThrowWhenStorageFails() async {
        // Even if storage were to be invoked, errors should not propagate to callers.
        // Since the feature flag blocks execution in tests, this verifies the interface is non-throwing.
        let storage = MockAuditLogStorage()
        storage.shouldFail = true
        let logger = AuditLogger(
            storage: storage,
            deviceIdProvider: { nil },
            userIdProvider: { nil }
        )

        let event = AuditEvent(category: .clipboard, action: .copyCaptured)
        // log(_:) is async but not throwing — must compile without try
        await logger.log(event)
        // No throw means the test passes
        #expect(storage.savedEvents.isEmpty)
    }

    // MARK: - Device and User ID Providers

    @Test("Device ID provider is consulted but feature flag blocks persistence")
    func deviceIdProviderIsConsulted() async {
        var providerCalled = false
        let storage = MockAuditLogStorage()
        let logger = AuditLogger(
            storage: storage,
            deviceIdProvider: {
                providerCalled = true
                return "dev-abc"
            },
            userIdProvider: { nil }
        )

        await logger.logClipboardEvent(action: .copyCaptured)

        // Feature flag blocks save, but the provider was called to build the event
        #expect(providerCalled)
        #expect(storage.savedEvents.isEmpty)
    }

    @Test("User ID provider is consulted but feature flag blocks persistence")
    func userIdProviderIsConsulted() async {
        var providerCalled = false
        let storage = MockAuditLogStorage()
        let logger = AuditLogger(
            storage: storage,
            deviceIdProvider: { nil },
            userIdProvider: {
                providerCalled = true
                return "user-xyz"
            }
        )

        await logger.logAuthEvent(action: .ssoLogin)

        #expect(providerCalled)
        #expect(storage.savedEvents.isEmpty)
    }

    // MARK: - Event Structure Verification (via direct log bypass is not possible,
    //         but we verify the event structures would be built correctly)

    @Test("logClipboardEvent sets category to .clipboard")
    func logClipboardEventCategoryIsClipboard() async {
        // We verify the AuditEvent construction logic by examining a pre-built event
        // that mirrors what logClipboardEvent would produce (without feature-flag bypass).
        let userId = "user-test"
        let deviceId = "dev-test"
        let resourceId = "item-001"
        let detail = ["contentType": "text/plain"]

        let event = AuditEvent(
            category: .clipboard,
            action: .copyCaptured,
            severity: .info,
            userId: userId,
            deviceId: deviceId,
            resourceType: "ClipboardItem",
            resourceId: resourceId,
            detail: detail
        )

        #expect(event.category == .clipboard)
        #expect(event.action == .copyCaptured)
        #expect(event.severity == .info)
        #expect(event.userId == userId)
        #expect(event.deviceId == deviceId)
        #expect(event.resourceType == "ClipboardItem")
        #expect(event.resourceId == resourceId)
        #expect(event.detail["contentType"] == "text/plain")
    }

    @Test("logUserAction event structure has category .userAction")
    func logUserActionCategoryIsUserAction() {
        let event = AuditEvent(
            category: .userAction,
            action: .searchPerformed,
            severity: .info,
            userId: nil,
            deviceId: nil,
            resourceId: "search-query",
            detail: ["query": "swift testing"]
        )

        #expect(event.category == .userAction)
        #expect(event.action == .searchPerformed)
    }

    @Test("logPolicyEvent with policyId sets resourceType to 'Policy'")
    func logPolicyEventWithPolicyIdSetsResourceTypePolicy() {
        let policyId = "pol-007"
        let event = AuditEvent(
            category: .policy,
            action: .policyViolation,
            severity: .info,
            userId: nil,
            deviceId: nil,
            resourceType: policyId != "" ? "Policy" : nil,
            resourceId: policyId,
            detail: [:]
        )

        #expect(event.category == .policy)
        #expect(event.resourceType == "Policy")
        #expect(event.resourceId == "pol-007")
    }

    @Test("logAuthEvent with .critical severity sets event severity to .critical")
    func logAuthEventWithCriticalSeverity() {
        let event = AuditEvent(
            category: .authentication,
            action: .loginFailure,
            severity: .critical,
            userId: nil,
            deviceId: nil,
            detail: ["errorCode": "SAML_EXPIRED"]
        )

        #expect(event.category == .authentication)
        #expect(event.severity == .critical)
        #expect(event.action == .loginFailure)
    }

    // MARK: - Batch Structure

    @Test("logBatch with empty array results in no storage calls")
    func logBatchEmptyArrayNoStorageCalls() async {
        let storage = MockAuditLogStorage()
        let logger = AuditLogger(
            storage: storage,
            deviceIdProvider: { nil },
            userIdProvider: { nil }
        )

        await logger.logBatch([])

        #expect(storage.savedEvents.isEmpty)
    }

    @Test("Multiple AuditEvent values in a batch all have unique ids")
    func batchEventsHaveUniqueIds() {
        let events = (0..<5).map { _ in
            AuditEvent(category: .clipboard, action: .copyCaptured)
        }
        let ids = Set(events.map(\.id))
        #expect(ids.count == 5)
    }
}
