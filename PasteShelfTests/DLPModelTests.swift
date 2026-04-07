//
//  DLPModelTests.swift
//  PasteShelfTests
//
//  Unit tests for DLP model types: DLPRule, DLPViolation, DLPAction,
//  DLPPatternCategory, DLPPolicy, DLPEvaluationResult, and DLPError.
//

import Foundation
@testable import PasteShelf
import Testing

// MARK: - DLPModelTests

struct DLPModelTests {
    // MARK: - DLPRule

    @Test("DLPRule init with defaults")
    func dlpRuleInitWithDefaults() {
        let before = Date()
        let rule = DLPRule(
            name: "Test Rule",
            patternCategory: .creditCard,
            pattern: "\\d{16}"
        )
        let after = Date()

        #expect(rule.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        #expect(rule.name == "Test Rule")
        #expect(rule.isEnabled == true)
        #expect(rule.patternCategory == .creditCard)
        #expect(rule.pattern == "\\d{16}")
        #expect(rule.severity == .high)
        #expect(rule.actions == [.alert, .logOnly])
        #expect(rule.createdAt >= before)
        #expect(rule.createdAt <= after)
        #expect(rule.updatedAt >= before)
        #expect(rule.updatedAt <= after)
    }

    @Test("DLPRule Codable round-trip")
    func dlpRuleCodeableRoundTrip() throws {
        let originalId = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_001_000)

        let original = DLPRule(
            id: originalId,
            name: "Credit Card Detector",
            isEnabled: false,
            patternCategory: .creditCard,
            pattern: "\\b4[0-9]{12}(?:[0-9]{3})?\\b",
            severity: .critical,
            actions: [.block, .alert],
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DLPRule.self, from: data)

        #expect(decoded.id == originalId)
        #expect(decoded.name == "Credit Card Detector")
        #expect(decoded.isEnabled == false)
        #expect(decoded.patternCategory == .creditCard)
        #expect(decoded.pattern == "\\b4[0-9]{12}(?:[0-9]{3})?\\b")
        #expect(decoded.severity == .critical)
        #expect(decoded.actions == [.block, .alert])
        #expect(decoded.createdAt == createdAt)
        #expect(decoded.updatedAt == updatedAt)
    }

    // MARK: - DLPViolation

    @Test("DLPViolation init with defaults")
    func dlpViolationInitWithDefaults() {
        let ruleId = UUID()
        let before = Date()
        let violation = DLPViolation(
            ruleId: ruleId,
            ruleName: "Test Rule",
            contentPreview: "****",
            matchedPattern: "****",
            actionTaken: .logOnly,
            wasBlocked: false
        )
        let after = Date()

        #expect(violation.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        #expect(violation.ruleId == ruleId)
        #expect(violation.ruleName == "Test Rule")
        #expect(violation.timestamp >= before)
        #expect(violation.timestamp <= after)
        #expect(violation.contentPreview == "****")
        #expect(violation.matchedPattern == "****")
        #expect(violation.actionTaken == .logOnly)
        #expect(violation.sourceAppBundleId == nil)
        #expect(violation.sourceAppName == nil)
        #expect(violation.wasBlocked == false)
    }

    @Test("DLPViolation Codable round-trip")
    func dlpViolationCodeableRoundTrip() throws {
        let violationId = UUID()
        let ruleId = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_700_500_000)

        let original = DLPViolation(
            id: violationId,
            ruleId: ruleId,
            ruleName: "SSN Detector",
            timestamp: timestamp,
            contentPreview: "***-**-****",
            matchedPattern: "\\b\\d{3}-\\d{2}-\\d{4}\\b",
            actionTaken: .block,
            sourceAppBundleId: "com.example.app",
            sourceAppName: "Example App",
            wasBlocked: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DLPViolation.self, from: data)

        #expect(decoded.id == violationId)
        #expect(decoded.ruleId == ruleId)
        #expect(decoded.ruleName == "SSN Detector")
        #expect(decoded.timestamp == timestamp)
        #expect(decoded.contentPreview == "***-**-****")
        #expect(decoded.matchedPattern == "\\b\\d{3}-\\d{2}-\\d{4}\\b")
        #expect(decoded.actionTaken == .block)
        #expect(decoded.sourceAppBundleId == "com.example.app")
        #expect(decoded.sourceAppName == "Example App")
        #expect(decoded.wasBlocked == true)
    }

    // MARK: - DLPAction

    @Test("DLPAction raw values")
    func dlpActionRawValues() {
        #expect(DLPAction.block.rawValue == "block")
        #expect(DLPAction.alert.rawValue == "alert")
        #expect(DLPAction.redact.rawValue == "redact")
        #expect(DLPAction.logOnly.rawValue == "logOnly")
    }

    // MARK: - DLPPatternCategory

    @Test("DLPPatternCategory display names")
    func dlpPatternCategoryDisplayNames() {
        #expect(DLPPatternCategory.creditCard.displayName == "Credit Card")
        #expect(DLPPatternCategory.ssn.displayName == "Social Security Number")
        #expect(DLPPatternCategory.apiKey.displayName == "API Key / Credential")
        #expect(DLPPatternCategory.pii.displayName == "Personally Identifiable Information")
        #expect(DLPPatternCategory.healthData.displayName == "Health Data")
        #expect(DLPPatternCategory.custom.displayName == "Custom")
    }

    // MARK: - DLPPolicy

    @Test("DLPPolicy empty sentinel")
    func dlpPolicyEmptySentinel() {
        let policy = DLPPolicy.empty

        #expect(policy.rules.isEmpty)
        #expect(policy.enforced == false)
        #expect(policy.blockUnknownSensitive == false)
    }

    // MARK: - DLPEvaluationResult

    @Test("DLPEvaluationResult clean sentinel")
    func dlpEvaluationResultCleanSentinel() {
        let result = DLPEvaluationResult.clean

        #expect(result.violations.isEmpty)
        #expect(result.shouldBlock == false)
        #expect(result.shouldRedact == false)
        #expect(result.redactedContent == nil)
    }

    @Test("DLPEvaluationResult hasViolations")
    func dlpEvaluationResultHasViolations() {
        let noViolationsResult = DLPEvaluationResult(
            violations: [],
            shouldBlock: false,
            shouldRedact: false,
            redactedContent: nil,
            redactedFields: nil
        )
        #expect(noViolationsResult.hasViolations == false)

        let ruleId = UUID()
        let violation = DLPViolation(
            ruleId: ruleId,
            ruleName: "Test Rule",
            contentPreview: "****",
            matchedPattern: "****",
            actionTaken: .alert,
            wasBlocked: false
        )
        let withViolationsResult = DLPEvaluationResult(
            violations: [violation],
            shouldBlock: false,
            shouldRedact: false,
            redactedContent: nil,
            redactedFields: nil
        )
        #expect(withViolationsResult.hasViolations == true)
    }

    // MARK: - DLPError

    @Test("DLPError localized descriptions")
    func dlpErrorLocalizedDescriptions() {
        let errors: [DLPError] = [
            .featureUnavailable,
            .invalidPattern("[bad regex"),
            .storageFailure("disk full"),
            .ruleNotFound(UUID()),
            .evaluationFailed("unexpected nil"),
        ]

        for error in errors {
            let description = error.errorDescription
            #expect(description != nil)
            #expect((description ?? "").isEmpty == false)
        }
    }
}
