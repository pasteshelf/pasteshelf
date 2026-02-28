//
//  HIPAAComplianceTests.swift
//  PasteShelfTests
//
//  Tests for HIPAA compliance: HIPAAComplianceMode, HIPAARetentionPolicy,
//  HIPAAEnhancedAuditLogger, ComplianceFinding, ComplianceFindingStatus.
//

import Foundation
import Testing
@testable import PasteShelf

// MARK: - HIPAAComplianceMode Tests

struct HIPAAComplianceModeTests {

    // MARK: Default Values

    @Test("HIPAAComplianceMode.default has isEnabled false")
    func defaultIsDisabled() {
        #expect(HIPAAComplianceMode.default.isEnabled == false)
    }

    @Test("HIPAAComplianceMode.default has sessionTimeoutMinutes of 15")
    func defaultSessionTimeout() {
        #expect(HIPAAComplianceMode.default.sessionTimeoutMinutes == 15)
    }

    @Test("HIPAAComplianceMode.default has requireBiometric false")
    func defaultRequireBiometric() {
        #expect(HIPAAComplianceMode.default.requireBiometric == false)
    }

    @Test("HIPAAComplianceMode.default has requireSSO false")
    func defaultRequireSSO() {
        #expect(HIPAAComplianceMode.default.requireSSO == false)
    }

    // MARK: Codable Round-trip

    @Test("HIPAAComplianceMode survives Codable round-trip with default values")
    func codableRoundTripDefault() throws {
        let original = HIPAAComplianceMode.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HIPAAComplianceMode.self, from: data)
        #expect(decoded == original)
    }

    @Test("HIPAAComplianceMode survives Codable round-trip with custom values")
    func codableRoundTripCustom() throws {
        let original = HIPAAComplianceMode(
            isEnabled: true,
            sessionTimeoutMinutes: 30,
            requireBiometric: true,
            requireSSO: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HIPAAComplianceMode.self, from: data)
        #expect(decoded == original)
    }

    // MARK: Equatable

    @Test("Two HIPAAComplianceModes with same values are equal")
    func equalModes() {
        let a = HIPAAComplianceMode(isEnabled: true, sessionTimeoutMinutes: 10, requireBiometric: false, requireSSO: true)
        let b = HIPAAComplianceMode(isEnabled: true, sessionTimeoutMinutes: 10, requireBiometric: false, requireSSO: true)
        #expect(a == b)
    }

    @Test("Two HIPAAComplianceModes with different values are not equal")
    func notEqualModes() {
        let a = HIPAAComplianceMode.default
        let b = HIPAAComplianceMode(isEnabled: true, sessionTimeoutMinutes: 15, requireBiometric: false, requireSSO: false)
        #expect(a != b)
    }

    // MARK: Sendable

    @Test("HIPAAComplianceMode can be sent across concurrency boundaries")
    func sendableConformance() async {
        let mode = HIPAAComplianceMode(isEnabled: true, sessionTimeoutMinutes: 5, requireBiometric: true, requireSSO: false)
        let result: HIPAAComplianceMode = await Task.detached { mode }.value
        #expect(result == mode)
    }
}

// MARK: - HIPAARetentionPolicy Tests

struct HIPAARetentionPolicyTests {

    // MARK: hipaaDefault

    @Test("hipaaDefault has retentionDays of 2190")
    func hipaaDefaultRetentionDays() {
        let config = HIPAARetentionPolicy.hipaaDefault
        #expect(config.retentionDays == 2190)
    }

    @Test("hipaaDefault has isImmutable true")
    func hipaaDefaultIsImmutable() {
        let config = HIPAARetentionPolicy.hipaaDefault
        #expect(config.isImmutable == true)
    }

    // MARK: isCompliant

    @Test("isCompliant returns true for hipaaDefault")
    func isCompliantForHipaaDefault() {
        #expect(HIPAARetentionPolicy.isCompliant(HIPAARetentionPolicy.hipaaDefault))
    }

    @Test("isCompliant returns false for default config")
    func isCompliantFalseForDefault() {
        #expect(!HIPAARetentionPolicy.isCompliant(AuditRetentionConfiguration.default))
    }

    @Test("isCompliant returns false when retentionDays < 2190")
    func isCompliantFalseForLowRetention() {
        let config = AuditRetentionConfiguration(retentionDays: 365, isImmutable: true)
        #expect(!HIPAARetentionPolicy.isCompliant(config))
    }

    @Test("isCompliant returns false when not immutable")
    func isCompliantFalseForMutable() {
        let config = AuditRetentionConfiguration(retentionDays: 2190, isImmutable: false)
        #expect(!HIPAARetentionPolicy.isCompliant(config))
    }

    @Test("isCompliant returns true for retention > 2190 and immutable")
    func isCompliantForHighRetention() {
        let config = AuditRetentionConfiguration(retentionDays: 3000, isImmutable: true)
        #expect(HIPAARetentionPolicy.isCompliant(config))
    }

    // MARK: validate

    @Test("validate corrects low retention days to 2190")
    func validateCorrectsLowRetention() {
        let input = AuditRetentionConfiguration(retentionDays: 90, isImmutable: false)
        let result = HIPAARetentionPolicy.validate(input)
        #expect(result.retentionDays == 2190)
    }

    @Test("validate sets isImmutable to true")
    func validateSetsImmutable() {
        let input = AuditRetentionConfiguration(retentionDays: 90, isImmutable: false)
        let result = HIPAARetentionPolicy.validate(input)
        #expect(result.isImmutable == true)
    }

    @Test("validate preserves retention days when already >= 2190")
    func validatePreservesHighRetention() {
        let input = AuditRetentionConfiguration(retentionDays: 3000, isImmutable: false)
        let result = HIPAARetentionPolicy.validate(input)
        #expect(result.retentionDays == 3000)
    }

    @Test("validate output is always HIPAA compliant")
    func validateOutputIsCompliant() {
        let input = AuditRetentionConfiguration(retentionDays: 30, isImmutable: false)
        let result = HIPAARetentionPolicy.validate(input)
        #expect(HIPAARetentionPolicy.isCompliant(result))
    }

    @Test("validate is idempotent for compliant input")
    func validateIdempotent() {
        let compliant = HIPAARetentionPolicy.hipaaDefault
        let result = HIPAARetentionPolicy.validate(compliant)
        #expect(result == compliant)
    }
}

// MARK: - AuditRetentionConfiguration HIPAA Extensions Tests

struct AuditRetentionConfigurationHIPAATests {

    @Test("hipaaMinimumDays is 2190")
    func hipaaMinimumDays() {
        #expect(AuditRetentionConfiguration.hipaaMinimumDays == 2190)
    }

    @Test("options includes 2190 for HIPAA compliance")
    func optionsIncludes2190() {
        #expect(AuditRetentionConfiguration.options.contains(2190))
    }

    @Test("options has 6 entries (original 5 + HIPAA 2190)")
    func optionsCountSix() {
        #expect(AuditRetentionConfiguration.options.count == 6)
    }

    @Test("default config has isImmutable false")
    func defaultIsNotImmutable() {
        #expect(AuditRetentionConfiguration.default.isImmutable == false)
    }

    @Test("AuditRetentionConfiguration with isImmutable survives Codable round-trip")
    func codableRoundTripImmutable() throws {
        let original = AuditRetentionConfiguration(retentionDays: 2190, isImmutable: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AuditRetentionConfiguration.self, from: data)
        #expect(decoded.retentionDays == 2190)
        #expect(decoded.isImmutable == true)
    }
}

// MARK: - HIPAAEnhancedAuditLogger Tests

struct HIPAAEnhancedAuditLoggerTests {

    /// A mock AuditLogging implementation that captures logged events.
    final class MockAuditLogger: AuditLogging, @unchecked Sendable {
        var loggedEvents: [AuditEvent] = []
        var batchLoggedEvents: [[AuditEvent]] = []

        func log(_ event: AuditEvent) async {
            loggedEvents.append(event)
        }

        func logBatch(_ events: [AuditEvent]) async {
            batchLoggedEvents.append(events)
        }
    }

    @Test("Logger passes events through when HIPAA mode is disabled")
    func passThrough() async {
        let mock = MockAuditLogger()
        let logger = HIPAAEnhancedAuditLogger(delegate: mock)
        let event = AuditEvent(category: .clipboard, action: .copyCaptured)

        // Ensure HIPAA is disabled by saving default config
        HIPAAComplianceMode.default.save()

        await logger.log(event)

        #expect(mock.loggedEvents.count == 1)
        #expect(mock.loggedEvents.first?.detail["hipaa.accessReason"] == nil)
    }

    @Test("Logger injects HIPAA fields when HIPAA mode is enabled")
    func hipaaFieldsInjected() async {
        let mock = MockAuditLogger()
        let logger = HIPAAEnhancedAuditLogger(delegate: mock)
        let event = AuditEvent(category: .clipboard, action: .copyCaptured)

        // Enable HIPAA mode
        let config = HIPAAComplianceMode(isEnabled: true, sessionTimeoutMinutes: 15, requireBiometric: false, requireSSO: false)
        config.save()

        await logger.log(event)

        // Restore default
        HIPAAComplianceMode.default.save()

        #expect(mock.loggedEvents.count == 1)
        let logged = mock.loggedEvents[0]
        #expect(logged.detail["hipaa.accessReason"] != nil)
        #expect(logged.detail["hipaa.phiIndicator"] != nil)
        #expect(logged.detail["hipaa.minimumNecessary"] != nil)
    }

    @Test("Logger sets clipboard_capture access reason for copyCaptured")
    func accessReasonForCopyCaptured() async {
        let mock = MockAuditLogger()
        let logger = HIPAAEnhancedAuditLogger(delegate: mock)

        let config = HIPAAComplianceMode(isEnabled: true, sessionTimeoutMinutes: 15, requireBiometric: false, requireSSO: false)
        config.save()

        await logger.log(AuditEvent(category: .clipboard, action: .copyCaptured))

        HIPAAComplianceMode.default.save()

        #expect(mock.loggedEvents[0].detail["hipaa.accessReason"] == "clipboard_capture")
    }

    @Test("Logger sets paste_operation access reason for pastePerformed")
    func accessReasonForPastePerformed() async {
        let mock = MockAuditLogger()
        let logger = HIPAAEnhancedAuditLogger(delegate: mock)

        let config = HIPAAComplianceMode(isEnabled: true, sessionTimeoutMinutes: 15, requireBiometric: false, requireSSO: false)
        config.save()

        await logger.log(AuditEvent(category: .clipboard, action: .pastePerformed))

        HIPAAComplianceMode.default.save()

        #expect(mock.loggedEvents[0].detail["hipaa.accessReason"] == "paste_operation")
    }

    @Test("Logger sets PHI indicator to possible for clipboard actions")
    func phiIndicatorForClipboard() async {
        let mock = MockAuditLogger()
        let logger = HIPAAEnhancedAuditLogger(delegate: mock)

        let config = HIPAAComplianceMode(isEnabled: true, sessionTimeoutMinutes: 15, requireBiometric: false, requireSSO: false)
        config.save()

        await logger.log(AuditEvent(category: .clipboard, action: .copyCaptured))

        HIPAAComplianceMode.default.save()

        #expect(mock.loggedEvents[0].detail["hipaa.phiIndicator"] == "possible")
    }

    @Test("Logger sets PHI indicator to true for sensitive data")
    func phiIndicatorForSensitiveData() async {
        let mock = MockAuditLogger()
        let logger = HIPAAEnhancedAuditLogger(delegate: mock)

        let config = HIPAAComplianceMode(isEnabled: true, sessionTimeoutMinutes: 15, requireBiometric: false, requireSSO: false)
        config.save()

        let event = AuditEvent(
            category: .clipboard,
            action: .copyCaptured,
            detail: ["isSensitive": "true"]
        )
        await logger.log(event)

        HIPAAComplianceMode.default.save()

        #expect(mock.loggedEvents[0].detail["hipaa.phiIndicator"] == "true")
    }

    @Test("Logger handles batch logging with HIPAA enrichment")
    func batchLogging() async {
        let mock = MockAuditLogger()
        let logger = HIPAAEnhancedAuditLogger(delegate: mock)

        let config = HIPAAComplianceMode(isEnabled: true, sessionTimeoutMinutes: 15, requireBiometric: false, requireSSO: false)
        config.save()

        let events = [
            AuditEvent(category: .clipboard, action: .copyCaptured),
            AuditEvent(category: .clipboard, action: .pastePerformed)
        ]
        await logger.logBatch(events)

        HIPAAComplianceMode.default.save()

        #expect(mock.batchLoggedEvents.count == 1)
        #expect(mock.batchLoggedEvents[0].count == 2)
        #expect(mock.batchLoggedEvents[0][0].detail["hipaa.accessReason"] != nil)
        #expect(mock.batchLoggedEvents[0][1].detail["hipaa.accessReason"] != nil)
    }

    @Test("Logger does not overwrite existing HIPAA fields")
    func noOverwrite() async {
        let mock = MockAuditLogger()
        let logger = HIPAAEnhancedAuditLogger(delegate: mock)

        let config = HIPAAComplianceMode(isEnabled: true, sessionTimeoutMinutes: 15, requireBiometric: false, requireSSO: false)
        config.save()

        let event = AuditEvent(
            category: .clipboard,
            action: .copyCaptured,
            detail: ["hipaa.accessReason": "custom_reason"]
        )
        await logger.log(event)

        HIPAAComplianceMode.default.save()

        #expect(mock.loggedEvents[0].detail["hipaa.accessReason"] == "custom_reason")
    }

    @Test("Logger preserves event identity (id, timestamp, category, action)")
    func preservesEventIdentity() async {
        let mock = MockAuditLogger()
        let logger = HIPAAEnhancedAuditLogger(delegate: mock)

        let config = HIPAAComplianceMode(isEnabled: true, sessionTimeoutMinutes: 15, requireBiometric: false, requireSSO: false)
        config.save()

        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let event = AuditEvent(
            id: id,
            timestamp: timestamp,
            category: .authentication,
            action: .ssoLogin,
            severity: .critical,
            userId: "user-1"
        )
        await logger.log(event)

        HIPAAComplianceMode.default.save()

        let logged = mock.loggedEvents[0]
        #expect(logged.id == id)
        #expect(logged.timestamp == timestamp)
        #expect(logged.category == .authentication)
        #expect(logged.action == .ssoLogin)
        #expect(logged.severity == .critical)
        #expect(logged.userId == "user-1")
    }
}

// MARK: - ComplianceFinding Tests

struct ComplianceFindingTests {

    @Test("ComplianceFinding default id is a unique UUID")
    func defaultIdIsUnique() {
        let a = ComplianceFinding(category: "test", status: .pass, description: "ok")
        let b = ComplianceFinding(category: "test", status: .pass, description: "ok")
        #expect(a.id != b.id)
    }

    @Test("ComplianceFinding default recommendation is nil")
    func defaultRecommendationIsNil() {
        let finding = ComplianceFinding(category: "test", status: .pass, description: "ok")
        #expect(finding.recommendation == nil)
    }

    @Test("ComplianceFinding preserves all provided values")
    func preservesValues() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let finding = ComplianceFinding(
            id: id,
            category: "Encryption",
            status: .fail,
            description: "Key missing",
            recommendation: "Add key",
            timestamp: date
        )
        #expect(finding.id == id)
        #expect(finding.category == "Encryption")
        #expect(finding.status == .fail)
        #expect(finding.description == "Key missing")
        #expect(finding.recommendation == "Add key")
        #expect(finding.timestamp == date)
    }

    @Test("ComplianceFinding survives Codable round-trip")
    func codableRoundTrip() throws {
        let original = ComplianceFinding(
            category: "Access Control",
            status: .warning,
            description: "SSO not configured",
            recommendation: "Enable SSO"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ComplianceFinding.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.category == original.category)
        #expect(decoded.status == original.status)
        #expect(decoded.description == original.description)
        #expect(decoded.recommendation == original.recommendation)
    }
}

// MARK: - ComplianceFindingStatus Tests

struct ComplianceFindingStatusTests {

    @Test("ComplianceFindingStatus.pass raw value is 'pass'")
    func passRawValue() {
        #expect(ComplianceFindingStatus.pass.rawValue == "pass")
    }

    @Test("ComplianceFindingStatus.fail raw value is 'fail'")
    func failRawValue() {
        #expect(ComplianceFindingStatus.fail.rawValue == "fail")
    }

    @Test("ComplianceFindingStatus.warning raw value is 'warning'")
    func warningRawValue() {
        #expect(ComplianceFindingStatus.warning.rawValue == "warning")
    }

    @Test("ComplianceFindingStatus survives Codable round-trip")
    func codableRoundTrip() throws {
        for status in [ComplianceFindingStatus.pass, .fail, .warning] {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(ComplianceFindingStatus.self, from: data)
            #expect(decoded == status)
        }
    }
}

// MARK: - ComplianceReport Tests

struct ComplianceReportTests {

    @Test("ComplianceReport overallStatus is .pass when all findings pass")
    func overallStatusAllPass() {
        let findings = [
            ComplianceFinding(category: "A", status: .pass, description: "ok"),
            ComplianceFinding(category: "B", status: .pass, description: "ok")
        ]
        let report = ComplianceReport(reportType: "Test", findings: findings, summary: "All good")
        #expect(report.overallStatus == .pass)
    }

    @Test("ComplianceReport overallStatus is .warning when worst finding is warning")
    func overallStatusWarning() {
        let findings = [
            ComplianceFinding(category: "A", status: .pass, description: "ok"),
            ComplianceFinding(category: "B", status: .warning, description: "watch out")
        ]
        let report = ComplianceReport(reportType: "Test", findings: findings, summary: "Mostly good")
        #expect(report.overallStatus == .warning)
    }

    @Test("ComplianceReport overallStatus is .fail when any finding fails")
    func overallStatusFail() {
        let findings = [
            ComplianceFinding(category: "A", status: .pass, description: "ok"),
            ComplianceFinding(category: "B", status: .fail, description: "bad"),
            ComplianceFinding(category: "C", status: .warning, description: "meh")
        ]
        let report = ComplianceReport(reportType: "Test", findings: findings, summary: "Issues found")
        #expect(report.overallStatus == .fail)
    }

    @Test("ComplianceReport overallStatus is .pass when no findings")
    func overallStatusEmpty() {
        let report = ComplianceReport(reportType: "Test", findings: [], summary: "No findings")
        #expect(report.overallStatus == .pass)
    }

    @Test("ComplianceReport survives Codable round-trip")
    func codableRoundTrip() throws {
        let findings = [
            ComplianceFinding(category: "A", status: .pass, description: "ok")
        ]
        let original = ComplianceReport(reportType: "SOC2", findings: findings, summary: "Test")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ComplianceReport.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.reportType == original.reportType)
        #expect(decoded.overallStatus == original.overallStatus)
    }
}

// MARK: - HIPAAEncryptionReport Tests

struct HIPAAEncryptionReportTests {

    @Test("HIPAAEncryptionReport default id is unique")
    func defaultIdIsUnique() {
        let a = HIPAAEncryptionReport(
            findings: [], auditEncryptionActive: false, syncEncryptionActive: false,
            localDiskEncrypted: false, keyRotationStatus: .warning, overallCompliant: false
        )
        let b = HIPAAEncryptionReport(
            findings: [], auditEncryptionActive: false, syncEncryptionActive: false,
            localDiskEncrypted: false, keyRotationStatus: .warning, overallCompliant: false
        )
        #expect(a.id != b.id)
    }

    @Test("HIPAAEncryptionReport preserves all values")
    func preservesValues() {
        let finding = ComplianceFinding(category: "Test", status: .pass, description: "ok")
        let report = HIPAAEncryptionReport(
            findings: [finding],
            auditEncryptionActive: true,
            syncEncryptionActive: false,
            localDiskEncrypted: true,
            keyRotationStatus: .pass,
            overallCompliant: true
        )
        #expect(report.findings.count == 1)
        #expect(report.auditEncryptionActive == true)
        #expect(report.syncEncryptionActive == false)
        #expect(report.localDiskEncrypted == true)
        #expect(report.keyRotationStatus == .pass)
        #expect(report.overallCompliant == true)
    }

    @Test("HIPAAEncryptionReport survives Codable round-trip")
    func codableRoundTrip() throws {
        let original = HIPAAEncryptionReport(
            findings: [ComplianceFinding(category: "Test", status: .pass, description: "ok")],
            auditEncryptionActive: true,
            syncEncryptionActive: true,
            localDiskEncrypted: true,
            keyRotationStatus: .pass,
            overallCompliant: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HIPAAEncryptionReport.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.overallCompliant == original.overallCompliant)
    }
}
