// swiftlint:disable file_length
//
//  AuditEventModelTests.swift
//  PasteShelfTests
//
//  Tests for audit domain models: AuditEventCategory, AuditEventSeverity, AuditAction,
//  AuditEvent, AuditRetentionConfiguration, and AuditLogDisplayItem.
//

import CoreData
import Foundation
@testable import PasteShelf
import Testing

// MARK: - Test Helpers

private func makeInMemoryEntry(
    id: UUID = UUID(),
    timestamp: Date = Date(),
    category: AuditEventCategory = .clipboard,
    action: AuditAction = .copyCaptured,
    severity: AuditEventSeverity = .info,
    userId: String? = nil,
    deviceId: String? = nil,
    resourceType: String? = nil,
    resourceId: String? = nil
) -> AuditLogEntry {
    let controller = PersistenceController(inMemory: true)
    let context = controller.container.viewContext
    let entry = AuditLogEntry(context: context)
    entry.id = id
    entry.timestamp = timestamp
    entry.eventCategory = category.rawValue
    entry.action = action.rawValue
    entry.severity = severity.rawValue
    entry.userId = userId
    entry.deviceId = deviceId
    entry.resourceType = resourceType
    entry.resourceId = resourceId
    entry.isSynced = false
    entry.encryptedDetail = nil
    return entry
}

// MARK: - AuditEventCategoryTests

struct AuditEventCategoryTests {
    // MARK: Raw Values

    @Test("AuditEventCategory.clipboard raw value is 'clipboard'")
    func clipboardRawValue() {
        #expect(AuditEventCategory.clipboard.rawValue == "clipboard")
    }

    @Test("AuditEventCategory.userAction raw value is 'user'")
    func userActionRawValue() {
        #expect(AuditEventCategory.userAction.rawValue == "user")
    }

    @Test("AuditEventCategory.policy raw value is 'policy'")
    func policyRawValue() {
        #expect(AuditEventCategory.policy.rawValue == "policy")
    }

    @Test("AuditEventCategory.authentication raw value is 'authentication'")
    func authenticationRawValue() {
        #expect(AuditEventCategory.authentication.rawValue == "authentication")
    }

    // MARK: CaseIterable

    @Test("AuditEventCategory.allCases contains exactly 5 cases")
    func allCasesContainsFiveCases() {
        #expect(AuditEventCategory.allCases.count == 5)
    }

    @Test("AuditEventCategory.allCases contains clipboard, userAction, policy, authentication, and compliance")
    func allCasesContainsExpectedValues() {
        let cases = AuditEventCategory.allCases
        #expect(cases.contains(.clipboard))
        #expect(cases.contains(.userAction))
        #expect(cases.contains(.policy))
        #expect(cases.contains(.authentication))
        #expect(cases.contains(.compliance))
    }

    // MARK: Codable Round-trip

    @Test("AuditEventCategory.clipboard survives Codable round-trip")
    func clipboardCodableRoundTrip() throws {
        let original = AuditEventCategory.clipboard
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AuditEventCategory.self, from: data)
        #expect(decoded == original)
    }

    @Test("AuditEventCategory.userAction survives Codable round-trip")
    func userActionCodableRoundTrip() throws {
        let original = AuditEventCategory.userAction
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AuditEventCategory.self, from: data)
        #expect(decoded == original)
    }

    @Test("AuditEventCategory.policy survives Codable round-trip")
    func policyCodableRoundTrip() throws {
        let original = AuditEventCategory.policy
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AuditEventCategory.self, from: data)
        #expect(decoded == original)
    }

    @Test("AuditEventCategory.authentication survives Codable round-trip")
    func authenticationCodableRoundTrip() throws {
        let original = AuditEventCategory.authentication
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AuditEventCategory.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: - AuditEventSeverityTests

struct AuditEventSeverityTests {
    // MARK: Raw Values

    @Test("AuditEventSeverity.info raw value is 'info'")
    func infoRawValue() {
        #expect(AuditEventSeverity.info.rawValue == "info")
    }

    @Test("AuditEventSeverity.warning raw value is 'warning'")
    func warningRawValue() {
        #expect(AuditEventSeverity.warning.rawValue == "warning")
    }

    @Test("AuditEventSeverity.critical raw value is 'critical'")
    func criticalRawValue() {
        #expect(AuditEventSeverity.critical.rawValue == "critical")
    }

    // MARK: Codable Round-trip

    @Test("AuditEventSeverity.info survives Codable round-trip")
    func infoCodableRoundTrip() throws {
        let original = AuditEventSeverity.info
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AuditEventSeverity.self, from: data)
        #expect(decoded == original)
    }

    @Test("AuditEventSeverity.warning survives Codable round-trip")
    func warningCodableRoundTrip() throws {
        let original = AuditEventSeverity.warning
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AuditEventSeverity.self, from: data)
        #expect(decoded == original)
    }

    @Test("AuditEventSeverity.critical survives Codable round-trip")
    func criticalCodableRoundTrip() throws {
        let original = AuditEventSeverity.critical
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AuditEventSeverity.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: - AuditActionTests

struct AuditActionTests {
    // MARK: Raw Values (Sampling)

    @Test("AuditAction.copyCaptured raw value is 'copy_captured'")
    func copyCapturedRawValue() {
        #expect(AuditAction.copyCaptured.rawValue == "copy_captured")
    }

    @Test("AuditAction.ssoLogin raw value is 'sso_login'")
    func ssoLoginRawValue() {
        #expect(AuditAction.ssoLogin.rawValue == "sso_login")
    }

    @Test("AuditAction.policyViolation raw value is 'policy_violation'")
    func policyViolationRawValue() {
        #expect(AuditAction.policyViolation.rawValue == "policy_violation")
    }

    @Test("AuditAction.pastePerformed raw value is 'paste_performed'")
    func pastePerformedRawValue() {
        #expect(AuditAction.pastePerformed.rawValue == "paste_performed")
    }

    @Test("AuditAction.itemDeleted raw value is 'item_deleted'")
    func itemDeletedRawValue() {
        #expect(AuditAction.itemDeleted.rawValue == "item_deleted")
    }

    @Test("AuditAction.policyApplied raw value is 'policy_applied'")
    func policyAppliedRawValue() {
        #expect(AuditAction.policyApplied.rawValue == "policy_applied")
    }

    @Test("AuditAction.ssoLogout raw value is 'sso_logout'")
    func ssoLogoutRawValue() {
        #expect(AuditAction.ssoLogout.rawValue == "sso_logout")
    }

    @Test("AuditAction.loginFailure raw value is 'login_failure'")
    func loginFailureRawValue() {
        #expect(AuditAction.loginFailure.rawValue == "login_failure")
    }

    // MARK: Codable Round-trip

    @Test("AuditAction.copyCaptured survives Codable round-trip")
    func copyCapturedCodableRoundTrip() throws {
        let original = AuditAction.copyCaptured
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AuditAction.self, from: data)
        #expect(decoded == original)
    }

    @Test("AuditAction.ssoLogin survives Codable round-trip")
    func ssoLoginCodableRoundTrip() throws {
        let original = AuditAction.ssoLogin
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AuditAction.self, from: data)
        #expect(decoded == original)
    }

    @Test("AuditAction.policyViolation survives Codable round-trip")
    func policyViolationCodableRoundTrip() throws {
        let original = AuditAction.policyViolation
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AuditAction.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: - AuditEventTests

struct AuditEventTests {
    // MARK: Default Init Values

    @Test("AuditEvent default init produces non-nil id")
    func defaultInitIdNotNil() {
        let event = AuditEvent(category: .clipboard, action: .copyCaptured)
        let nilUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")
        #expect(event.id != nilUUID)
    }

    @Test("AuditEvent default init timestamp is recent (within 5 seconds)")
    func defaultInitTimestampIsRecent() {
        let event = AuditEvent(category: .clipboard, action: .copyCaptured)
        #expect(abs(event.timestamp.timeIntervalSinceNow) < 5)
    }

    @Test("AuditEvent default severity is .info")
    func defaultSeverityIsInfo() {
        let event = AuditEvent(category: .clipboard, action: .copyCaptured)
        #expect(event.severity == .info)
    }

    @Test("AuditEvent default detail is empty")
    func defaultDetailIsEmpty() {
        let event = AuditEvent(category: .clipboard, action: .copyCaptured)
        #expect(event.detail.isEmpty)
    }

    @Test("AuditEvent default userId is nil")
    func defaultUserIdIsNil() {
        let event = AuditEvent(category: .clipboard, action: .copyCaptured)
        #expect(event.userId == nil)
    }

    @Test("AuditEvent default deviceId is nil")
    func defaultDeviceIdIsNil() {
        let event = AuditEvent(category: .clipboard, action: .copyCaptured)
        #expect(event.deviceId == nil)
    }

    @Test("AuditEvent default resourceType is nil")
    func defaultResourceTypeIsNil() {
        let event = AuditEvent(category: .clipboard, action: .copyCaptured)
        #expect(event.resourceType == nil)
    }

    @Test("AuditEvent default resourceId is nil")
    func defaultResourceIdIsNil() {
        let event = AuditEvent(category: .clipboard, action: .copyCaptured)
        #expect(event.resourceId == nil)
    }

    // MARK: Full Init

    @Test("AuditEvent full init preserves all provided values")
    func fullInitPreservesAllValues() {
        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let event = AuditEvent(
            id: id,
            timestamp: timestamp,
            category: .authentication,
            action: .ssoLogin,
            severity: .critical,
            userId: "user-abc",
            deviceId: "dev-001",
            resourceType: "Session",
            resourceId: "session-xyz",
            detail: ["provider": "Okta", "method": "SAML"]
        )

        #expect(event.id == id)
        #expect(event.timestamp == timestamp)
        #expect(event.category == .authentication)
        #expect(event.action == .ssoLogin)
        #expect(event.severity == .critical)
        #expect(event.userId == "user-abc")
        #expect(event.deviceId == "dev-001")
        #expect(event.resourceType == "Session")
        #expect(event.resourceId == "session-xyz")
        #expect(event.detail["provider"] == "Okta")
        #expect(event.detail["method"] == "SAML")
    }

    // MARK: Codable Round-trip

    @Test("AuditEvent survives Codable round-trip with all fields set")
    func codableRoundTripAllFields() throws {
        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let original = AuditEvent(
            id: id,
            timestamp: timestamp,
            category: .policy,
            action: .policyViolation,
            severity: .warning,
            userId: "user-test",
            deviceId: "dev-test",
            resourceType: "Policy",
            resourceId: "pol-001",
            detail: ["ruleName": "NoSensitiveData", "policyId": "pol-001"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AuditEvent.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.timestamp == original.timestamp)
        #expect(decoded.category == original.category)
        #expect(decoded.action == original.action)
        #expect(decoded.severity == original.severity)
        #expect(decoded.userId == original.userId)
        #expect(decoded.deviceId == original.deviceId)
        #expect(decoded.resourceType == original.resourceType)
        #expect(decoded.resourceId == original.resourceId)
        #expect(decoded.detail == original.detail)
    }

    @Test("AuditEvent Codable round-trip preserves nil optional fields")
    func codableRoundTripNilOptionals() throws {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let original = AuditEvent(
            timestamp: timestamp,
            category: .clipboard,
            action: .copyCaptured
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AuditEvent.self, from: data)

        #expect(decoded.userId == nil)
        #expect(decoded.deviceId == nil)
        #expect(decoded.resourceType == nil)
        #expect(decoded.resourceId == nil)
        #expect(decoded.detail.isEmpty)
    }

    // MARK: Identifiable

    @Test("AuditEvent Identifiable conformance uses id property")
    func identifiableUsesIdProperty() {
        let id = UUID()
        let event = AuditEvent(id: id, category: .clipboard, action: .copyCaptured)
        #expect(event.id == id)
    }

    @Test("Two AuditEvents with different ids are not equal by id")
    func differentIdsAreNotEqual() {
        let event1 = AuditEvent(category: .clipboard, action: .copyCaptured)
        let event2 = AuditEvent(category: .clipboard, action: .copyCaptured)
        #expect(event1.id != event2.id)
    }
}

// MARK: - AuditRetentionConfigurationTests

struct AuditRetentionConfigurationTests {
    @Test("AuditRetentionConfiguration.default has retentionDays of 90")
    func defaultRetentionDaysIs90() {
        #expect(AuditRetentionConfiguration.default.retentionDays == 90)
    }

    @Test("AuditRetentionConfiguration.options contains [30, 60, 90, 180, 365, 2190]")
    func optionsContainsExpectedValues() {
        #expect(AuditRetentionConfiguration.options == [30, 60, 90, 180, 365, 2190])
    }

    @Test("AuditRetentionConfiguration.options contains 6 elements")
    func optionsContainsSixElements() {
        #expect(AuditRetentionConfiguration.options.count == 6)
    }

    @Test("AuditRetentionConfiguration.default is in options list")
    func defaultIsInOptions() {
        #expect(AuditRetentionConfiguration.options.contains(AuditRetentionConfiguration.default.retentionDays))
    }

    @Test("AuditRetentionConfiguration survives Codable round-trip")
    func codableRoundTrip() throws {
        let original = AuditRetentionConfiguration(retentionDays: 180, isImmutable: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AuditRetentionConfiguration.self, from: data)
        #expect(decoded.retentionDays == original.retentionDays)
        #expect(decoded.isImmutable == original.isImmutable)
    }

    @Test("Two AuditRetentionConfigurations with same values are equal")
    func equalConfigurations() {
        let config1 = AuditRetentionConfiguration(retentionDays: 30, isImmutable: false)
        let config2 = AuditRetentionConfiguration(retentionDays: 30, isImmutable: false)
        #expect(config1 == config2)
    }

    @Test("Two AuditRetentionConfigurations with different retentionDays are not equal")
    func notEqualConfigurations() {
        let config1 = AuditRetentionConfiguration(retentionDays: 30, isImmutable: false)
        let config2 = AuditRetentionConfiguration(retentionDays: 90, isImmutable: false)
        #expect(config1 != config2)
    }
}

// MARK: - AuditLogDisplayItemTests

struct AuditLogDisplayItemTests {
    // MARK: Factory from(_:decryptedDetail:)

    @Test("AuditLogDisplayItem.from returns nil when entry has no id")
    func fromReturnsNilWhenNoId() {
        let entry = makeInMemoryEntry()
        entry.id = nil
        let item = AuditLogDisplayItem.from(entry, decryptedDetail: [:])
        #expect(item == nil)
    }

    @Test("AuditLogDisplayItem.from returns nil when entry has no timestamp")
    func fromReturnsNilWhenNoTimestamp() {
        let entry = makeInMemoryEntry()
        entry.timestamp = nil
        let item = AuditLogDisplayItem.from(entry, decryptedDetail: [:])
        #expect(item == nil)
    }

    @Test("AuditLogDisplayItem.from returns nil when entry has no eventCategory")
    func fromReturnsNilWhenNoEventCategory() {
        let entry = makeInMemoryEntry()
        entry.eventCategory = nil
        let item = AuditLogDisplayItem.from(entry, decryptedDetail: [:])
        #expect(item == nil)
    }

    @Test("AuditLogDisplayItem.from returns nil when entry has no action")
    func fromReturnsNilWhenNoAction() {
        let entry = makeInMemoryEntry()
        entry.action = nil
        let item = AuditLogDisplayItem.from(entry, decryptedDetail: [:])
        #expect(item == nil)
    }

    @Test("AuditLogDisplayItem.from returns nil when entry has no severity")
    func fromReturnsNilWhenNoSeverity() {
        let entry = makeInMemoryEntry()
        entry.severity = nil
        let item = AuditLogDisplayItem.from(entry, decryptedDetail: [:])
        #expect(item == nil)
    }

    @Test("AuditLogDisplayItem.from returns nil when eventCategory is invalid raw value")
    func fromReturnsNilWhenInvalidCategory() {
        let entry = makeInMemoryEntry()
        entry.eventCategory = "invalid_category"
        let item = AuditLogDisplayItem.from(entry, decryptedDetail: [:])
        #expect(item == nil)
    }

    @Test("AuditLogDisplayItem.from returns nil when action is invalid raw value")
    func fromReturnsNilWhenInvalidAction() {
        let entry = makeInMemoryEntry()
        entry.action = "unknown_action"
        let item = AuditLogDisplayItem.from(entry, decryptedDetail: [:])
        #expect(item == nil)
    }

    @Test("AuditLogDisplayItem.from returns a fully populated item for a valid entry")
    func fromReturnsPopulatedItemForValidEntry() throws {
        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = makeInMemoryEntry(
            id: id,
            timestamp: timestamp,
            category: .policy,
            action: .policyViolation,
            severity: .warning,
            userId: "user-abc",
            deviceId: "dev-001",
            resourceType: "Policy",
            resourceId: "pol-007"
        )
        let detail = ["ruleName": "NoSensitiveData"]

        let item = try #require(AuditLogDisplayItem.from(entry, decryptedDetail: detail))

        #expect(item.id == id)
        #expect(item.timestamp == timestamp)
        #expect(item.category == .policy)
        #expect(item.action == .policyViolation)
        #expect(item.severity == .warning)
        #expect(item.userId == "user-abc")
        #expect(item.deviceId == "dev-001")
        #expect(item.resourceType == "Policy")
        #expect(item.resourceId == "pol-007")
        #expect(item.detail["ruleName"] == "NoSensitiveData")
    }

    // MARK: categoryDisplayName

    @Test("categoryDisplayName for .clipboard returns 'Clipboard'")
    func categoryDisplayNameClipboard() throws {
        let entry = makeInMemoryEntry(category: .clipboard, action: .copyCaptured)
        let item = try #require(AuditLogDisplayItem.from(entry, decryptedDetail: [:]))
        #expect(item.categoryDisplayName == "Clipboard")
    }

    @Test("categoryDisplayName for .userAction returns 'User Action'")
    func categoryDisplayNameUserAction() throws {
        let entry = makeInMemoryEntry(category: .userAction, action: .searchPerformed)
        let item = try #require(AuditLogDisplayItem.from(entry, decryptedDetail: [:]))
        #expect(item.categoryDisplayName == "User Action")
    }

    @Test("categoryDisplayName for .policy returns 'Policy'")
    func categoryDisplayNamePolicy() throws {
        let entry = makeInMemoryEntry(category: .policy, action: .policyApplied)
        let item = try #require(AuditLogDisplayItem.from(entry, decryptedDetail: [:]))
        #expect(item.categoryDisplayName == "Policy")
    }

    @Test("categoryDisplayName for .authentication returns 'Authentication'")
    func categoryDisplayNameAuthentication() throws {
        let entry = makeInMemoryEntry(category: .authentication, action: .ssoLogin)
        let item = try #require(AuditLogDisplayItem.from(entry, decryptedDetail: [:]))
        #expect(item.categoryDisplayName == "Authentication")
    }

    // MARK: actionDisplayName

    @Test("actionDisplayName converts 'copy_captured' to 'Copy Captured'")
    func actionDisplayNameCopyCaptured() throws {
        let entry = makeInMemoryEntry(action: .copyCaptured)
        let item = try #require(AuditLogDisplayItem.from(entry, decryptedDetail: [:]))
        #expect(item.actionDisplayName == "Copy Captured")
    }

    @Test("actionDisplayName converts 'sso_login' to 'Sso Login'")
    func actionDisplayNameSsoLogin() throws {
        let entry = makeInMemoryEntry(category: .authentication, action: .ssoLogin)
        let item = try #require(AuditLogDisplayItem.from(entry, decryptedDetail: [:]))
        #expect(item.actionDisplayName == "Sso Login")
    }

    @Test("actionDisplayName converts 'policy_violation' to 'Policy Violation'")
    func actionDisplayNamePolicyViolation() throws {
        let entry = makeInMemoryEntry(category: .policy, action: .policyViolation)
        let item = try #require(AuditLogDisplayItem.from(entry, decryptedDetail: [:]))
        #expect(item.actionDisplayName == "Policy Violation")
    }

    @Test("actionDisplayName converts 'paste_performed' to 'Paste Performed'")
    func actionDisplayNamePastePerformed() throws {
        let entry = makeInMemoryEntry(action: .pastePerformed)
        let item = try #require(AuditLogDisplayItem.from(entry, decryptedDetail: [:]))
        #expect(item.actionDisplayName == "Paste Performed")
    }

    // MARK: severityIconName

    @Test("severityIconName for .info returns 'info.circle'")
    func severityIconNameInfo() throws {
        let entry = makeInMemoryEntry(severity: .info)
        let item = try #require(AuditLogDisplayItem.from(entry, decryptedDetail: [:]))
        #expect(item.severityIconName == "info.circle")
    }

    @Test("severityIconName for .warning returns 'exclamationmark.triangle'")
    func severityIconNameWarning() throws {
        let entry = makeInMemoryEntry(severity: .warning)
        let item = try #require(AuditLogDisplayItem.from(entry, decryptedDetail: [:]))
        #expect(item.severityIconName == "exclamationmark.triangle")
    }

    @Test("severityIconName for .critical returns 'xmark.octagon'")
    func severityIconNameCritical() throws {
        let entry = makeInMemoryEntry(severity: .critical)
        let item = try #require(AuditLogDisplayItem.from(entry, decryptedDetail: [:]))
        #expect(item.severityIconName == "xmark.octagon")
    }

    // MARK: formattedTimestamp

    @Test("formattedTimestamp returns a non-empty string")
    func formattedTimestampIsNonEmpty() throws {
        let entry = makeInMemoryEntry(timestamp: Date(timeIntervalSinceNow: -3600))
        let item = try #require(AuditLogDisplayItem.from(entry, decryptedDetail: [:]))
        #expect(!item.formattedTimestamp.isEmpty)
    }

    // MARK: Hashable (id-based equality)

    @Test("Two AuditLogDisplayItems with the same id are equal")
    func hashableEqualityBasedOnId() throws {
        let sharedId = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

        let entry1 = makeInMemoryEntry(id: sharedId, timestamp: timestamp, category: .clipboard, action: .copyCaptured)
        let entry2 = makeInMemoryEntry(id: sharedId, timestamp: timestamp, category: .policy, action: .policyViolation)

        let item1 = try #require(AuditLogDisplayItem.from(entry1, decryptedDetail: [:]))
        let item2 = try #require(AuditLogDisplayItem.from(entry2, decryptedDetail: [:]))

        // Equality based on id — even though category/action differ, same id means equal
        #expect(item1 == item2)
    }

    @Test("Two AuditLogDisplayItems with different ids are not equal")
    func hashableInequalityForDifferentIds() throws {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let entry1 = makeInMemoryEntry(id: UUID(), timestamp: timestamp)
        let entry2 = makeInMemoryEntry(id: UUID(), timestamp: timestamp)

        let item1 = try #require(AuditLogDisplayItem.from(entry1, decryptedDetail: [:]))
        let item2 = try #require(AuditLogDisplayItem.from(entry2, decryptedDetail: [:]))

        #expect(item1 != item2)
    }

    @Test("AuditLogDisplayItem can be used in a Set (Hashable conformance)")
    func hashableCanBeUsedInSet() throws {
        let sharedId = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let entry1 = makeInMemoryEntry(id: sharedId, timestamp: timestamp)
        let entry2 = makeInMemoryEntry(id: sharedId, timestamp: timestamp)

        let item1 = try #require(AuditLogDisplayItem.from(entry1, decryptedDetail: [:]))
        let item2 = try #require(AuditLogDisplayItem.from(entry2, decryptedDetail: [:]))

        let set: Set<AuditLogDisplayItem> = [item1, item2]
        #expect(set.count == 1)
    }
}
