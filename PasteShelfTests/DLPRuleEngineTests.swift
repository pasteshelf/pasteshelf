//
//  DLPRuleEngineTests.swift
//  PasteShelfTests
//
//  Unit tests for DLPRuleEngine: pattern detection, action flags, redaction,
//  disabled rule skipping, invalid regex handling, and multi-rule evaluation.
//

import Foundation
@testable import PasteShelf
import Testing

// MARK: - DLPRuleEngineTests

@Suite("DLP Rule Engine Tests")
struct DLPRuleEngineTests {
    // MARK: Internal

    // MARK: - Basic Evaluation

    @Test("No rules returns clean result")
    func noRulesReturnsCleanResult() async {
        let engine = makeEngine()
        let content = makeContent(text: "Hello, world!")

        let result = await engine.evaluate(content, against: [])

        #expect(result.hasViolations == false)
        #expect(result.shouldBlock == false)
        #expect(result.shouldRedact == false)
        #expect(result.violations.isEmpty)
    }

    @Test("Disabled rules are skipped")
    func disabledRulesAreSkipped() async {
        let engine = makeEngine()
        let content = makeContent(text: "4111111111111111")

        var rule = makeRule(pattern: "\\b4[0-9]{15}\\b", actions: [.block])
        rule = DLPRule(
            id: rule.id,
            name: rule.name,
            isEnabled: false,
            patternCategory: rule.patternCategory,
            pattern: rule.pattern,
            severity: rule.severity,
            actions: rule.actions
        )

        let result = await engine.evaluate(content, against: [rule])

        #expect(result.hasViolations == false)
        #expect(result.shouldBlock == false)
    }

    // MARK: - Pattern Detection

    @Test("Credit card pattern detection")
    func creditCardPatternDetection() async {
        let engine = makeEngine()
        // Standard Visa test card number
        let content = makeContent(text: "4111111111111111")
        let rule = makeRule(
            name: "Credit Card",
            pattern: "\\b4[0-9]{12}(?:[0-9]{3})?\\b",
            actions: [.alert, .logOnly]
        )

        let result = await engine.evaluate(content, against: [rule])

        #expect(result.hasViolations == true)
        #expect(result.violations.count >= 1)
        #expect(result.violations.first?.ruleName == "Credit Card")
    }

    @Test("SSN pattern detection")
    func ssnPatternDetection() async {
        let engine = makeEngine()
        let content = makeContent(text: "SSN: 123-45-6789")
        let rule = makeRule(
            name: "SSN Detector",
            pattern: "\\b\\d{3}-\\d{2}-\\d{4}\\b",
            actions: [.alert, .logOnly]
        )

        let result = await engine.evaluate(content, against: [rule])

        #expect(result.hasViolations == true)
        #expect(result.violations.first?.ruleName == "SSN Detector")
    }

    @Test("API key pattern detection")
    func apiKeyPatternDetection() async {
        let engine = makeEngine()
        // AWS-style access key format: AKIA followed by 16 alphanumeric characters
        let content = makeContent(text: "AKIA1234567890ABCDEF")
        let rule = makeRule(
            name: "AWS Key Detector",
            pattern: "AKIA[0-9A-Z]{16}",
            actions: [.alert, .logOnly]
        )

        let result = await engine.evaluate(content, against: [rule])

        #expect(result.hasViolations == true)
        #expect(result.violations.first?.ruleName == "AWS Key Detector")
    }

    @Test("Custom regex detection")
    func customRegexDetection() async {
        let engine = makeEngine()
        let content = makeContent(text: "The token is SECRET_ABCDEFGHIJ")
        let rule = makeRule(
            name: "Custom Secret",
            pattern: "SECRET_[A-Z]{10}",
            actions: [.alert, .logOnly]
        )

        let result = await engine.evaluate(content, against: [rule])

        #expect(result.hasViolations == true)
        #expect(result.violations.first?.ruleName == "Custom Secret")
    }

    // MARK: - Action Flags

    @Test("Block action sets shouldBlock")
    func blockActionSetsShouldBlock() async {
        let engine = makeEngine()
        let content = makeContent(text: "4111111111111111")
        let rule = makeRule(
            pattern: "\\b4[0-9]{12}(?:[0-9]{3})?\\b",
            actions: [.block, .alert, .logOnly]
        )

        let result = await engine.evaluate(content, against: [rule])

        #expect(result.shouldBlock == true)
        #expect(result.hasViolations == true)
    }

    @Test("Redact action sets shouldRedact")
    func redactActionSetsShouldRedact() async {
        let engine = makeEngine()
        let content = makeContent(text: "123-45-6789")
        let rule = makeRule(
            pattern: "\\b\\d{3}-\\d{2}-\\d{4}\\b",
            actions: [.redact, .logOnly]
        )

        let result = await engine.evaluate(content, against: [rule])

        #expect(result.shouldRedact == true)
        #expect(result.hasViolations == true)
    }

    // MARK: - Multiple Rules

    @Test("Multiple rules multiple violations")
    func multipleRulesMultipleViolations() async {
        let engine = makeEngine()
        // Content matches both a credit card pattern and an SSN pattern
        let content = makeContent(text: "Card: 4111111111111111 SSN: 123-45-6789")

        let ccRule = makeRule(
            name: "Credit Card",
            pattern: "\\b4[0-9]{12}(?:[0-9]{3})?\\b",
            actions: [.alert, .logOnly]
        )
        let ssnRule = makeRule(
            name: "SSN",
            pattern: "\\b\\d{3}-\\d{2}-\\d{4}\\b",
            actions: [.alert, .logOnly]
        )

        let result = await engine.evaluate(content, against: [ccRule, ssnRule])

        #expect(result.hasViolations == true)
        #expect(result.violations.count >= 2)
    }

    // MARK: - Edge Cases

    @Test("Invalid regex pattern skipped")
    func invalidRegexPatternSkipped() async {
        let engine = makeEngine()
        let content = makeContent(text: "Some sensitive content here")
        // "[invalid" is not a valid regex — the engine must skip it without crashing
        let rule = makeRule(pattern: "[invalid")

        let result = await engine.evaluate(content, against: [rule])

        // Engine should return a clean result rather than crashing
        #expect(result.hasViolations == false)
        #expect(result.shouldBlock == false)
    }

    @Test("No match returns clean result")
    func noMatchReturnsCleanResult() async {
        let engine = makeEngine()
        let content = makeContent(text: "This text contains no sensitive data")
        // A valid pattern that will not match the content
        let rule = makeRule(pattern: "\\b4[0-9]{12}(?:[0-9]{3})?\\b")

        let result = await engine.evaluate(content, against: [rule])

        #expect(result.hasViolations == false)
        #expect(result.shouldBlock == false)
        #expect(result.shouldRedact == false)
    }

    @Test("Redacted content replaces matched text")
    func redactedContentReplacesMatchedText() async {
        let engine = makeEngine()
        // Credit card number is long enough (16 digits) for the partial-redaction path
        let content = makeContent(text: "Card: 4111111111111111")
        let rule = makeRule(
            pattern: "\\b4[0-9]{12}(?:[0-9]{3})?\\b",
            actions: [.redact, .logOnly]
        )

        let result = await engine.evaluate(content, against: [rule])

        #expect(result.shouldRedact == true)
        #expect(result.redactedContent != nil)

        // The redacted content must contain asterisks where the card number was
        if let redacted = result.redactedContent {
            #expect(redacted.contains("*"))
            // The original card number must NOT appear verbatim in the redacted output
            #expect(!redacted.contains("4111111111111111"))
        }
    }

    // MARK: Private

    // MARK: - Helpers

    /// Creates a fresh DLPRuleEngine instance.
    private func makeEngine() -> DLPRuleEngine {
        DLPRuleEngine()
    }

    /// Creates a ClipboardContent with the given plain text.
    private func makeContent(text: String) -> ClipboardContent {
        ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: text
        )
    }

    /// Creates a DLPRule with the given parameters and sensible defaults for the rest.
    private func makeRule(
        name: String = "Test Rule",
        pattern: String,
        actions: [DLPAction] = [.alert, .logOnly]
    ) -> DLPRule {
        DLPRule(
            name: name,
            patternCategory: .custom,
            pattern: pattern,
            severity: .high,
            actions: actions
        )
    }
}
