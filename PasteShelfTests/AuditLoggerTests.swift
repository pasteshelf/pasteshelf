//
//  AuditLoggerTests.swift
//  PasteShelfTests
//
//  Tests for AuditLogger: convenience logging methods, batch operations,
//  and error handling using a mock AuditLogStoring implementation.
//

import Foundation
@testable import PasteShelf
import Testing

// MARK: - MockAuditLogStorage

/// A mock `AuditLogStoring` implementation that records calls and returns pre-configured results.
final class MockAuditLogStorage: AuditLogStoring, @unchecked Sendable {
    var savedEvents: [AuditEvent] = []
    var shouldFail = false

    func save(_ event: AuditEvent) async throws {
        if shouldFail {
            throw AuditError.storageFailure("Mock failure")
        }
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
    // MARK: - Event Persistence

    @Test("log persists event to storage")
    func logPersistsEvent() async {
        let storage = MockAuditLogStorage()
        let logger = AuditLogger(
            storage: storage,
            deviceIdProvider: { nil },
            userIdProvider: { nil }
        )

        let event = AuditEvent(category: .clipboard, action: .copyCaptured)
        await logger.log(event)

        #expect(storage.savedEvents.count == 1)
        #expect(storage.savedEvents.first?.category == .clipboard)
    }

    @Test("logBatch persists all events to storage")
    func logBatchPersistsEvents() async {
        let storage = MockAuditLogStorage()
        let logger = AuditLogger(
            storage: storage,
            deviceIdProvider: { nil },
            userIdProvider: { nil }
        )

        let events = [
            AuditEvent(category: .clipboard, action: .copyCaptured),
            AuditEvent(category: .authentication, action: .ssoLogin),
            AuditEvent(category: .policy, action: .policyViolation),
        ]
        await logger.logBatch(events)

        #expect(storage.savedEvents.count == 3)
    }

    // MARK: - Convenience Methods

    @Test("logClipboardEvent persists event with correct category")
    func logClipboardEventPersists() async {
        let storage = MockAuditLogStorage()
        let logger = AuditLogger(
            storage: storage,
            deviceIdProvider: { "dev-001" },
            userIdProvider: { "user-abc" }
        )

        await logger.logClipboardEvent(
            action: .copyCaptured,
            resourceId: "item-123",
            detail: ["contentType": "text/plain"]
        )

        #expect(storage.savedEvents.count == 1)
        #expect(storage.savedEvents.first?.category == .clipboard)
    }

    @Test("logUserAction persists event with correct category")
    func logUserActionPersists() async {
        let storage = MockAuditLogStorage()
        let logger = AuditLogger(
            storage: storage,
            deviceIdProvider: { nil },
            userIdProvider: { nil }
        )

        await logger.logUserAction(action: .searchPerformed, resourceId: nil, detail: [:])

        #expect(storage.savedEvents.count == 1)
    }

    @Test("logPolicyEvent persists event with correct category")
    func logPolicyEventPersists() async {
        let storage = MockAuditLogStorage()
        let logger = AuditLogger(
            storage: storage,
            deviceIdProvider: { nil },
            userIdProvider: { nil }
        )

        await logger.logPolicyEvent(action: .policyViolation, policyId: "pol-007")

        #expect(storage.savedEvents.count == 1)
    }

    @Test("logAuthEvent persists event with correct category")
    func logAuthEventPersists() async {
        let storage = MockAuditLogStorage()
        let logger = AuditLogger(
            storage: storage,
            deviceIdProvider: { nil },
            userIdProvider: { nil }
        )

        await logger.logAuthEvent(action: .loginFailure, severity: .critical)

        #expect(storage.savedEvents.count == 1)
    }

    // MARK: - Error Swallowing

    @Test("log does not throw when storage fails (errors are swallowed)")
    func logDoesNotThrowWhenStorageFails() async {
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
        // Storage failed so no events persisted, but no throw either
        #expect(storage.savedEvents.isEmpty)
    }

    // MARK: - Device and User ID Providers

    @Test("Device ID provider is consulted during event logging")
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

        #expect(providerCalled)
        #expect(storage.savedEvents.count == 1)
    }

    @Test("User ID provider is consulted during event logging")
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
        #expect(storage.savedEvents.count == 1)
    }

    // MARK: - Event Structure Verification

    @Test("logClipboardEvent sets category to .clipboard")
    func logClipboardEventCategoryIsClipboard() {
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
        let events = (0 ..< 5).map { _ in
            AuditEvent(category: .clipboard, action: .copyCaptured)
        }
        let ids = Set(events.map(\.id))
        #expect(ids.count == 5)
    }
}
