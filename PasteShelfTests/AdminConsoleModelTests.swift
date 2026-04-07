// swiftlint:disable file_length
//
//  AdminConsoleModelTests.swift
//  PasteShelfTests
//
//  Tests for admin console models: AdminConsoleConfiguration, DeviceEnrollmentStatus,
//  DeviceRegistration, DeviceHealthReport, ComplianceStatus, AdminPolicy,
//  sub-policies, AdminAnalyticsEventType, and AdminAnalyticsEvent.
//

import Foundation
@testable import PasteShelf
import Testing

// MARK: - AdminConsoleConfigurationTests

struct AdminConsoleConfigurationTests {
    // MARK: Empty Sentinel

    @Test("AdminConsoleConfiguration.empty has isConfigured false")
    func emptyIsConfiguredFalse() {
        #expect(AdminConsoleConfiguration.empty.isConfigured == false)
    }

    @Test("AdminConsoleConfiguration.empty has isEnabled false")
    func emptyIsEnabledFalse() {
        #expect(AdminConsoleConfiguration.empty.isEnabled == false)
    }

    @Test("AdminConsoleConfiguration.empty has serverURL nil")
    func emptyServerURLNil() {
        #expect(AdminConsoleConfiguration.empty.serverURL == nil)
    }

    // MARK: isConfigured

    @Test("isConfigured returns true when serverURL and organizationID are both set")
    func isConfiguredTrueWhenBothSet() {
        let config = AdminConsoleConfiguration(
            serverURL: URL(string: "https://admin.example.com"),
            organizationID: "org-abc-123"
        )
        #expect(config.isConfigured == true)
    }

    @Test("isConfigured returns false when organizationID is empty")
    func isConfiguredFalseWhenOrganizationIDEmpty() {
        let config = AdminConsoleConfiguration(
            serverURL: URL(string: "https://admin.example.com"),
            organizationID: ""
        )
        #expect(config.isConfigured == false)
    }

    @Test("isConfigured returns false when serverURL is nil")
    func isConfiguredFalseWhenServerURLNil() {
        let config = AdminConsoleConfiguration(
            serverURL: nil,
            organizationID: "org-abc-123"
        )
        #expect(config.isConfigured == false)
    }

    // MARK: Default pollingInterval

    @Test("Default pollingInterval is 300 seconds")
    func defaultPollingInterval() {
        let config = AdminConsoleConfiguration()
        #expect(config.pollingInterval == 300)
    }

    @Test("AdminConsoleConfiguration.empty pollingInterval is 300 seconds")
    func emptyPollingInterval() {
        #expect(AdminConsoleConfiguration.empty.pollingInterval == 300)
    }

    // MARK: Equatable

    @Test("Two AdminConsoleConfigurations with identical values are equal")
    func equalConfigurations() {
        let url = URL(string: "https://admin.example.com")
        let config1 = AdminConsoleConfiguration(
            serverURL: url,
            organizationID: "org-123",
            apiKey: "key-abc",
            isEnabled: true,
            pollingInterval: 600
        )
        let config2 = AdminConsoleConfiguration(
            serverURL: url,
            organizationID: "org-123",
            apiKey: "key-abc",
            isEnabled: true,
            pollingInterval: 600
        )
        #expect(config1 == config2)
    }

    @Test("Two AdminConsoleConfigurations with different organizationID are not equal")
    func notEqualDifferentOrganizationID() {
        let url = URL(string: "https://admin.example.com")
        let config1 = AdminConsoleConfiguration(serverURL: url, organizationID: "org-123")
        let config2 = AdminConsoleConfiguration(serverURL: url, organizationID: "org-456")
        #expect(config1 != config2)
    }

    @Test("Two AdminConsoleConfigurations with different serverURL are not equal")
    func notEqualDifferentServerURL() {
        let config1 = AdminConsoleConfiguration(
            serverURL: URL(string: "https://admin.example.com"),
            organizationID: "org-123"
        )
        let config2 = AdminConsoleConfiguration(
            serverURL: URL(string: "https://admin.other.com"),
            organizationID: "org-123"
        )
        #expect(config1 != config2)
    }
}

// MARK: - DeviceEnrollmentStatusTests

struct DeviceEnrollmentStatusTests {
    // MARK: Raw Values

    @Test("DeviceEnrollmentStatus.notEnrolled raw value is 'notEnrolled'")
    func notEnrolledRawValue() {
        #expect(DeviceEnrollmentStatus.notEnrolled.rawValue == "notEnrolled")
    }

    @Test("DeviceEnrollmentStatus.enrolling raw value is 'enrolling'")
    func enrollingRawValue() {
        #expect(DeviceEnrollmentStatus.enrolling.rawValue == "enrolling")
    }

    @Test("DeviceEnrollmentStatus.enrolled raw value is 'enrolled'")
    func enrolledRawValue() {
        #expect(DeviceEnrollmentStatus.enrolled.rawValue == "enrolled")
    }

    @Test("DeviceEnrollmentStatus.suspended raw value is 'suspended'")
    func suspendedRawValue() {
        #expect(DeviceEnrollmentStatus.suspended.rawValue == "suspended")
    }

    @Test("DeviceEnrollmentStatus.revoked raw value is 'revoked'")
    func revokedRawValue() {
        #expect(DeviceEnrollmentStatus.revoked.rawValue == "revoked")
    }

    // MARK: Codable Round-trip

    @Test("DeviceEnrollmentStatus.notEnrolled survives Codable round-trip")
    func notEnrolledCodableRoundTrip() throws {
        let original = DeviceEnrollmentStatus.notEnrolled
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeviceEnrollmentStatus.self, from: data)
        #expect(decoded == original)
    }

    @Test("DeviceEnrollmentStatus.enrolling survives Codable round-trip")
    func enrollingCodableRoundTrip() throws {
        let original = DeviceEnrollmentStatus.enrolling
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeviceEnrollmentStatus.self, from: data)
        #expect(decoded == original)
    }

    @Test("DeviceEnrollmentStatus.enrolled survives Codable round-trip")
    func enrolledCodableRoundTrip() throws {
        let original = DeviceEnrollmentStatus.enrolled
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeviceEnrollmentStatus.self, from: data)
        #expect(decoded == original)
    }

    @Test("DeviceEnrollmentStatus.suspended survives Codable round-trip")
    func suspendedCodableRoundTrip() throws {
        let original = DeviceEnrollmentStatus.suspended
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeviceEnrollmentStatus.self, from: data)
        #expect(decoded == original)
    }

    @Test("DeviceEnrollmentStatus.revoked survives Codable round-trip")
    func revokedCodableRoundTrip() throws {
        let original = DeviceEnrollmentStatus.revoked
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeviceEnrollmentStatus.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: - DeviceRegistrationTests

struct DeviceRegistrationTests {
    // MARK: Internal

    // MARK: isActive

    @Test("DeviceRegistration.isActive is true when enrollmentStatus is enrolled")
    func isActiveTrueWhenEnrolled() {
        let reg = self.makeRegistration(status: .enrolled)
        #expect(reg.isActive == true)
    }

    @Test("DeviceRegistration.isActive is false when enrollmentStatus is notEnrolled")
    func isActiveFalseWhenNotEnrolled() {
        let reg = self.makeRegistration(status: .notEnrolled)
        #expect(reg.isActive == false)
    }

    @Test("DeviceRegistration.isActive is false when enrollmentStatus is enrolling")
    func isActiveFalseWhenEnrolling() {
        let reg = self.makeRegistration(status: .enrolling)
        #expect(reg.isActive == false)
    }

    @Test("DeviceRegistration.isActive is false when enrollmentStatus is suspended")
    func isActiveFalseWhenSuspended() {
        let reg = self.makeRegistration(status: .suspended)
        #expect(reg.isActive == false)
    }

    @Test("DeviceRegistration.isActive is false when enrollmentStatus is revoked")
    func isActiveFalseWhenRevoked() {
        let reg = self.makeRegistration(status: .revoked)
        #expect(reg.isActive == false)
    }

    // MARK: Equatable

    @Test("Two DeviceRegistrations with the same values are equal")
    func equalRegistrations() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let reg1 = DeviceRegistration(
            id: id,
            deviceId: "dev-001",
            organizationID: "org-123",
            userId: "user-xyz",
            enrollmentStatus: .enrolled,
            enrolledAt: date,
            lastCheckIn: date,
            deviceName: "Test Mac",
            osVersion: "14.4.1",
            appVersion: "1.0.0",
            serialNumber: "C02ABC123"
        )
        let reg2 = DeviceRegistration(
            id: id,
            deviceId: "dev-001",
            organizationID: "org-123",
            userId: "user-xyz",
            enrollmentStatus: .enrolled,
            enrolledAt: date,
            lastCheckIn: date,
            deviceName: "Test Mac",
            osVersion: "14.4.1",
            appVersion: "1.0.0",
            serialNumber: "C02ABC123"
        )
        #expect(reg1 == reg2)
    }

    @Test("Two DeviceRegistrations with different deviceId are not equal")
    func notEqualDifferentDeviceId() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let reg1 = DeviceRegistration(
            id: id,
            deviceId: "dev-001",
            organizationID: "org-123",
            userId: "user-xyz",
            enrolledAt: date,
            lastCheckIn: date,
            deviceName: "Test Mac",
            osVersion: "14.4.1",
            appVersion: "1.0.0"
        )
        let reg2 = DeviceRegistration(
            id: id,
            deviceId: "dev-002",
            organizationID: "org-123",
            userId: "user-xyz",
            enrolledAt: date,
            lastCheckIn: date,
            deviceName: "Test Mac",
            osVersion: "14.4.1",
            appVersion: "1.0.0"
        )
        #expect(reg1 != reg2)
    }

    // MARK: Private

    private func makeRegistration(status: DeviceEnrollmentStatus) -> DeviceRegistration {
        DeviceRegistration(
            deviceId: "dev-001",
            organizationID: "org-123",
            userId: "user-xyz",
            enrollmentStatus: status,
            deviceName: "Test Mac",
            osVersion: "14.4.1",
            appVersion: "1.0.0"
        )
    }
}

// MARK: - DeviceHealthReportTests

struct DeviceHealthReportTests {
    // MARK: Internal

    @Test("DeviceHealthReport survives Codable round-trip and all fields are preserved")
    func codableRoundTrip() throws {
        let original = self.makeReport()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DeviceHealthReport.self, from: data)

        #expect(decoded.deviceId == original.deviceId)
        #expect(decoded.timestamp == original.timestamp)
        #expect(decoded.appVersion == original.appVersion)
        #expect(decoded.osVersion == original.osVersion)
        #expect(decoded.isSSOActive == original.isSSOActive)
        #expect(decoded.isMDMManaged == original.isMDMManaged)
        #expect(decoded.isSyncEnabled == original.isSyncEnabled)
        #expect(decoded.isEncryptionEnabled == original.isEncryptionEnabled)
        #expect(decoded.clipboardItemCount == original.clipboardItemCount)
        #expect(decoded.lastSyncDate == original.lastSyncDate)
        #expect(decoded.policyVersion == original.policyVersion)
        #expect(decoded.activePolicyId == original.activePolicyId)
        #expect(decoded.complianceStatus == original.complianceStatus)
    }

    @Test("DeviceHealthReport Codable round-trip preserves nil optional fields")
    func codableRoundTripNilOptionals() throws {
        let original = DeviceHealthReport(
            deviceId: "dev-002",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            appVersion: "1.0.0",
            osVersion: "14.0",
            isSSOActive: false,
            isMDMManaged: false,
            isSyncEnabled: false,
            isEncryptionEnabled: false,
            clipboardItemCount: 0,
            lastSyncDate: nil,
            policyVersion: nil,
            activePolicyId: nil,
            complianceStatus: .unknown
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DeviceHealthReport.self, from: data)

        #expect(decoded.lastSyncDate == nil)
        #expect(decoded.policyVersion == nil)
        #expect(decoded.activePolicyId == nil)
        #expect(decoded.complianceStatus == .unknown)
    }

    // MARK: Private

    private func makeReport() -> DeviceHealthReport {
        DeviceHealthReport(
            deviceId: "dev-001",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            appVersion: "1.2.3",
            osVersion: "14.4.1",
            isSSOActive: true,
            isMDMManaged: false,
            isSyncEnabled: true,
            isEncryptionEnabled: true,
            clipboardItemCount: 42,
            lastSyncDate: Date(timeIntervalSince1970: 1_699_990_000),
            policyVersion: "v3",
            activePolicyId: "pol-789",
            complianceStatus: .compliant
        )
    }
}

// MARK: - ComplianceStatusTests

struct ComplianceStatusTests {
    // MARK: Raw Values

    @Test("ComplianceStatus.compliant raw value is 'compliant'")
    func compliantRawValue() {
        #expect(ComplianceStatus.compliant.rawValue == "compliant")
    }

    @Test("ComplianceStatus.nonCompliant raw value is 'nonCompliant'")
    func nonCompliantRawValue() {
        #expect(ComplianceStatus.nonCompliant.rawValue == "nonCompliant")
    }

    @Test("ComplianceStatus.unknown raw value is 'unknown'")
    func unknownRawValue() {
        #expect(ComplianceStatus.unknown.rawValue == "unknown")
    }

    // MARK: Codable Round-trip

    @Test("ComplianceStatus.compliant survives Codable round-trip")
    func compliantCodableRoundTrip() throws {
        let original = ComplianceStatus.compliant
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ComplianceStatus.self, from: data)
        #expect(decoded == original)
    }

    @Test("ComplianceStatus.nonCompliant survives Codable round-trip")
    func nonCompliantCodableRoundTrip() throws {
        let original = ComplianceStatus.nonCompliant
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ComplianceStatus.self, from: data)
        #expect(decoded == original)
    }

    @Test("ComplianceStatus.unknown survives Codable round-trip")
    func unknownCodableRoundTrip() throws {
        let original = ComplianceStatus.unknown
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ComplianceStatus.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: - AdminPolicyTests

struct AdminPolicyTests {
    // MARK: Empty Sentinel

    @Test("AdminPolicy.empty has id of empty string")
    func emptyId() {
        #expect(AdminPolicy.empty.id.isEmpty)
    }

    @Test("AdminPolicy.empty has version '0'")
    func emptyVersion() {
        #expect(AdminPolicy.empty.version == "0")
    }

    @Test("AdminPolicy.empty has name 'None'")
    func emptyName() {
        #expect(AdminPolicy.empty.name == "None")
    }

    @Test("AdminPolicy.empty has all sub-policies nil")
    func emptyAllSubPoliciesNil() {
        #expect(AdminPolicy.empty.historyLimits == nil)
        #expect(AdminPolicy.empty.excludedApps == nil)
        #expect(AdminPolicy.empty.syncSettings == nil)
        #expect(AdminPolicy.empty.encryptionRequirements == nil)
    }

    // MARK: Equatable

    @Test("Two AdminPolicies with identical values are equal")
    func equalPolicies() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let policy1 = AdminPolicy(id: "pol-001", version: "1", name: "Default", updatedAt: date)
        let policy2 = AdminPolicy(id: "pol-001", version: "1", name: "Default", updatedAt: date)
        #expect(policy1 == policy2)
    }

    @Test("Two AdminPolicies with different id are not equal")
    func notEqualDifferentId() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let policy1 = AdminPolicy(id: "pol-001", version: "1", name: "Default", updatedAt: date)
        let policy2 = AdminPolicy(id: "pol-002", version: "1", name: "Default", updatedAt: date)
        #expect(policy1 != policy2)
    }

    @Test("AdminPolicy with all sub-policies set is not equal to AdminPolicy.empty")
    func policyWithSubPoliciesNotEqualToEmpty() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let policy = AdminPolicy(
            id: "pol-full",
            version: "2",
            name: "Full Policy",
            updatedAt: date,
            historyLimits: HistoryLimitPolicy(maxItems: 500, maxDays: 30, enforced: true),
            excludedApps: ExcludedAppsPolicy(bundleIds: ["com.example.app"], enforced: true),
            syncSettings: SyncSettingsPolicy(syncEnabled: false, localStorageOnly: true, enforced: true),
            encryptionRequirements: EncryptionPolicy(requireEncryption: true, minimumKeyLength: 256, enforced: true)
        )
        #expect(policy != AdminPolicy.empty)
    }

    @Test("AdminPolicy with all sub-policies set preserves sub-policy values")
    func policySubPolicyValues() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let historyLimits = HistoryLimitPolicy(maxItems: 100, maxDays: 7, enforced: true)
        let excludedApps = ExcludedAppsPolicy(bundleIds: ["com.example.browser"], enforced: false)
        let syncSettings = SyncSettingsPolicy(syncEnabled: true, localStorageOnly: false, enforced: true)
        let encryption = EncryptionPolicy(
            requireEncryption: true,
            minimumKeyLength: 128,
            requireBiometricAuth: true,
            enforced: true
        )

        let policy = AdminPolicy(
            id: "pol-001",
            version: "3",
            name: "Strict",
            updatedAt: date,
            historyLimits: historyLimits,
            excludedApps: excludedApps,
            syncSettings: syncSettings,
            encryptionRequirements: encryption
        )

        #expect(policy.historyLimits == historyLimits)
        #expect(policy.excludedApps == excludedApps)
        #expect(policy.syncSettings == syncSettings)
        #expect(policy.encryptionRequirements == encryption)
    }
}

// MARK: - HistoryLimitPolicyTests

struct HistoryLimitPolicyTests {
    @Test("HistoryLimitPolicy default enforced is false")
    func defaultEnforcedFalse() {
        let policy = HistoryLimitPolicy()
        #expect(policy.enforced == false)
    }

    @Test("Two HistoryLimitPolicies with identical values are equal")
    func equalPolicies() {
        let policy1 = HistoryLimitPolicy(maxItems: 100, maxDays: 30, enforced: true)
        let policy2 = HistoryLimitPolicy(maxItems: 100, maxDays: 30, enforced: true)
        #expect(policy1 == policy2)
    }

    @Test("Two HistoryLimitPolicies with different maxItems are not equal")
    func notEqualDifferentMaxItems() {
        let policy1 = HistoryLimitPolicy(maxItems: 100)
        let policy2 = HistoryLimitPolicy(maxItems: 200)
        #expect(policy1 != policy2)
    }

    @Test("HistoryLimitPolicy survives Codable round-trip")
    func codableRoundTrip() throws {
        let original = HistoryLimitPolicy(maxItems: 500, maxDays: 90, enforced: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HistoryLimitPolicy.self, from: data)
        #expect(decoded.maxItems == original.maxItems)
        #expect(decoded.maxDays == original.maxDays)
        #expect(decoded.enforced == original.enforced)
    }
}

// MARK: - ExcludedAppsPolicyTests

struct ExcludedAppsPolicyTests {
    @Test("ExcludedAppsPolicy default enforced is false")
    func defaultEnforcedFalse() {
        let policy = ExcludedAppsPolicy()
        #expect(policy.enforced == false)
    }

    @Test("ExcludedAppsPolicy default bundleIds is empty")
    func defaultBundleIdsEmpty() {
        let policy = ExcludedAppsPolicy()
        #expect(policy.bundleIds.isEmpty)
    }

    @Test("Two ExcludedAppsPolicies with identical values are equal")
    func equalPolicies() {
        let policy1 = ExcludedAppsPolicy(bundleIds: ["com.example.app"], enforced: true)
        let policy2 = ExcludedAppsPolicy(bundleIds: ["com.example.app"], enforced: true)
        #expect(policy1 == policy2)
    }

    @Test("Two ExcludedAppsPolicies with different bundleIds are not equal")
    func notEqualDifferentBundleIds() {
        let policy1 = ExcludedAppsPolicy(bundleIds: ["com.example.app"])
        let policy2 = ExcludedAppsPolicy(bundleIds: ["com.other.app"])
        #expect(policy1 != policy2)
    }

    @Test("ExcludedAppsPolicy survives Codable round-trip")
    func codableRoundTrip() throws {
        let original = ExcludedAppsPolicy(bundleIds: ["com.apple.Safari", "com.example.browser"], enforced: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ExcludedAppsPolicy.self, from: data)
        #expect(decoded.bundleIds == original.bundleIds)
        #expect(decoded.enforced == original.enforced)
    }
}

// MARK: - SyncSettingsPolicyTests

struct SyncSettingsPolicyTests {
    @Test("SyncSettingsPolicy default enforced is false")
    func defaultEnforcedFalse() {
        let policy = SyncSettingsPolicy()
        #expect(policy.enforced == false)
    }

    @Test("Two SyncSettingsPolicies with identical values are equal")
    func equalPolicies() {
        let policy1 = SyncSettingsPolicy(syncEnabled: true, localStorageOnly: false, enforced: true)
        let policy2 = SyncSettingsPolicy(syncEnabled: true, localStorageOnly: false, enforced: true)
        #expect(policy1 == policy2)
    }

    @Test("Two SyncSettingsPolicies with different syncEnabled are not equal")
    func notEqualDifferentSyncEnabled() {
        let policy1 = SyncSettingsPolicy(syncEnabled: true)
        let policy2 = SyncSettingsPolicy(syncEnabled: false)
        #expect(policy1 != policy2)
    }

    @Test("SyncSettingsPolicy survives Codable round-trip")
    func codableRoundTrip() throws {
        let original = SyncSettingsPolicy(syncEnabled: false, localStorageOnly: true, enforced: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SyncSettingsPolicy.self, from: data)
        #expect(decoded.syncEnabled == original.syncEnabled)
        #expect(decoded.localStorageOnly == original.localStorageOnly)
        #expect(decoded.enforced == original.enforced)
    }
}

// MARK: - EncryptionPolicyTests

struct EncryptionPolicyTests {
    @Test("EncryptionPolicy default enforced is false")
    func defaultEnforcedFalse() {
        let policy = EncryptionPolicy(requireEncryption: false)
        #expect(policy.enforced == false)
    }

    @Test("Two EncryptionPolicies with identical values are equal")
    func equalPolicies() {
        let policy1 = EncryptionPolicy(
            requireEncryption: true,
            minimumKeyLength: 256,
            requireBiometricAuth: true,
            enforced: true
        )
        let policy2 = EncryptionPolicy(
            requireEncryption: true,
            minimumKeyLength: 256,
            requireBiometricAuth: true,
            enforced: true
        )
        #expect(policy1 == policy2)
    }

    @Test("Two EncryptionPolicies with different requireEncryption are not equal")
    func notEqualDifferentRequireEncryption() {
        let policy1 = EncryptionPolicy(requireEncryption: true)
        let policy2 = EncryptionPolicy(requireEncryption: false)
        #expect(policy1 != policy2)
    }

    @Test("EncryptionPolicy survives Codable round-trip")
    func codableRoundTrip() throws {
        let original = EncryptionPolicy(
            requireEncryption: true,
            minimumKeyLength: 256,
            requireBiometricAuth: true,
            enforced: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EncryptionPolicy.self, from: data)
        #expect(decoded.requireEncryption == original.requireEncryption)
        #expect(decoded.minimumKeyLength == original.minimumKeyLength)
        #expect(decoded.requireBiometricAuth == original.requireBiometricAuth)
        #expect(decoded.enforced == original.enforced)
    }
}

// MARK: - AdminAnalyticsEventTypeTests

struct AdminAnalyticsEventTypeTests {
    // MARK: Raw Values

    @Test("AdminAnalyticsEventType.deviceEnrolled raw value is 'deviceEnrolled'")
    func deviceEnrolledRawValue() {
        #expect(AdminAnalyticsEventType.deviceEnrolled.rawValue == "deviceEnrolled")
    }

    @Test("AdminAnalyticsEventType.deviceUnenrolled raw value is 'deviceUnenrolled'")
    func deviceUnenrolledRawValue() {
        #expect(AdminAnalyticsEventType.deviceUnenrolled.rawValue == "deviceUnenrolled")
    }

    @Test("AdminAnalyticsEventType.policyApplied raw value is 'policyApplied'")
    func policyAppliedRawValue() {
        #expect(AdminAnalyticsEventType.policyApplied.rawValue == "policyApplied")
    }

    @Test("AdminAnalyticsEventType.policyViolation raw value is 'policyViolation'")
    func policyViolationRawValue() {
        #expect(AdminAnalyticsEventType.policyViolation.rawValue == "policyViolation")
    }

    @Test("AdminAnalyticsEventType.syncCompleted raw value is 'syncCompleted'")
    func syncCompletedRawValue() {
        #expect(AdminAnalyticsEventType.syncCompleted.rawValue == "syncCompleted")
    }

    @Test("AdminAnalyticsEventType.loginSuccess raw value is 'loginSuccess'")
    func loginSuccessRawValue() {
        #expect(AdminAnalyticsEventType.loginSuccess.rawValue == "loginSuccess")
    }

    @Test("AdminAnalyticsEventType.loginFailure raw value is 'loginFailure'")
    func loginFailureRawValue() {
        #expect(AdminAnalyticsEventType.loginFailure.rawValue == "loginFailure")
    }

    @Test("AdminAnalyticsEventType.appLaunched raw value is 'appLaunched'")
    func appLaunchedRawValue() {
        #expect(AdminAnalyticsEventType.appLaunched.rawValue == "appLaunched")
    }

    @Test("AdminAnalyticsEventType.appTerminated raw value is 'appTerminated'")
    func appTerminatedRawValue() {
        #expect(AdminAnalyticsEventType.appTerminated.rawValue == "appTerminated")
    }

    // MARK: Codable Round-trip

    @Test("AdminAnalyticsEventType.deviceEnrolled survives Codable round-trip")
    func deviceEnrolledCodableRoundTrip() throws {
        let original = AdminAnalyticsEventType.deviceEnrolled
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AdminAnalyticsEventType.self, from: data)
        #expect(decoded == original)
    }

    @Test("AdminAnalyticsEventType.policyViolation survives Codable round-trip")
    func policyViolationCodableRoundTrip() throws {
        let original = AdminAnalyticsEventType.policyViolation
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AdminAnalyticsEventType.self, from: data)
        #expect(decoded == original)
    }

    @Test("AdminAnalyticsEventType.loginFailure survives Codable round-trip")
    func loginFailureCodableRoundTrip() throws {
        let original = AdminAnalyticsEventType.loginFailure
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AdminAnalyticsEventType.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: - AdminAnalyticsEventTests

struct AdminAnalyticsEventTests {
    // MARK: Defaults

    @Test("AdminAnalyticsEvent default metadata is empty")
    func defaultMetadataEmpty() {
        let event = AdminAnalyticsEvent(deviceId: "dev-001", eventType: .appLaunched)
        #expect(event.metadata.isEmpty)
    }

    @Test("AdminAnalyticsEvent default timestamp is close to current date")
    func defaultTimestampCloseToNow() {
        let event = AdminAnalyticsEvent(deviceId: "dev-001", eventType: .appLaunched)
        #expect(abs(event.timestamp.timeIntervalSinceNow) < 5)
    }

    @Test("AdminAnalyticsEvent default userId is nil")
    func defaultUserIdNil() {
        let event = AdminAnalyticsEvent(deviceId: "dev-001", eventType: .appLaunched)
        #expect(event.userId == nil)
    }

    // MARK: Codable Round-trip

    @Test("AdminAnalyticsEvent survives Codable round-trip with all fields set")
    func codableRoundTrip() throws {
        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let original = AdminAnalyticsEvent(
            id: id,
            deviceId: "dev-001",
            userId: "user-abc",
            eventType: .policyApplied,
            timestamp: timestamp,
            metadata: ["policyId": "pol-123", "policyVersion": "4"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AdminAnalyticsEvent.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.deviceId == original.deviceId)
        #expect(decoded.userId == original.userId)
        #expect(decoded.eventType == original.eventType)
        #expect(decoded.timestamp == original.timestamp)
        #expect(decoded.metadata == original.metadata)
    }

    @Test("AdminAnalyticsEvent Codable round-trip preserves nil userId")
    func codableRoundTripNilUserId() throws {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let original = AdminAnalyticsEvent(
            deviceId: "dev-002",
            userId: nil,
            eventType: .appLaunched,
            timestamp: timestamp
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AdminAnalyticsEvent.self, from: data)

        #expect(decoded.userId == nil)
        #expect(decoded.eventType == .appLaunched)
    }
}
