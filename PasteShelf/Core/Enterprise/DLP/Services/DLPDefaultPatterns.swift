// DLPDefaultPatterns.swift
// PasteShelf
//
// Factory providing pre-configured DLP rules based on built-in sensitive data patterns.
// Maps patterns from SensitivePatterns.swift to DLPRule instances for use in DLP policies.

import Foundation

// MARK: - DLPDefaultPatterns

/// A factory namespace that provides pre-configured `DLPRule` instances for each
/// built-in sensitive data pattern category.
///
/// Each static method returns one or more `DLPRule` values whose regex patterns are
/// taken verbatim from `SensitivePatterns`, ensuring that DLP detection is consistent
/// with the core sensitive-data detector used throughout the app.
///
/// All rules default to `isEnabled == true` and are ready to be inserted into a
/// `DLPPolicy` without further configuration.
enum DLPDefaultPatterns {
    // MARK: - Credit Card Patterns

    /// Returns DLP rules for detecting payment card numbers.
    ///
    /// Maps `SensitivePatterns.creditCard` (raw digits) and
    /// `SensitivePatterns.creditCardFormatted` (space/dash-separated digits).
    /// Both carry `.high` severity and use `[.alert, .logOnly]` actions.
    ///
    /// - Returns: An array of two `DLPRule` values covering unformatted and formatted card numbers.
    static func creditCardRules() -> [DLPRule] {
        [
            DLPRule(
                name: "Credit Card Numbers",
                patternCategory: .creditCard,
                pattern: "\\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|6(?:011|5[0-9]{2})[0-9]{12})\\b",
                severity: .high,
                actions: [.alert, .logOnly]
            ),
            DLPRule(
                name: "Credit Card Numbers (Formatted)",
                patternCategory: .creditCard,
                pattern: "\\b(?:\\d{4}[- ]?){3}\\d{4}\\b",
                severity: .high,
                actions: [.alert, .logOnly]
            ),
        ]
    }

    // MARK: - SSN Patterns

    /// Returns DLP rules for detecting US Social Security Numbers.
    ///
    /// Maps `SensitivePatterns.ssn` (dashed format: `XXX-XX-XXXX`) and
    /// `SensitivePatterns.ssnNoDash` (keyword-prefixed 9-digit form).
    /// Both carry `.high` severity and use `[.alert, .logOnly]` actions.
    ///
    /// - Returns: An array of two `DLPRule` values covering standard and compact SSN formats.
    static func ssnRules() -> [DLPRule] {
        [
            DLPRule(
                name: "Social Security Numbers",
                patternCategory: .ssn,
                pattern: "\\b\\d{3}-\\d{2}-\\d{4}\\b",
                severity: .high,
                actions: [.alert, .logOnly]
            ),
            DLPRule(
                name: "Social Security Numbers (No Dashes)",
                patternCategory: .ssn,
                pattern: "\\b(?:ssn|social[_\\s-]?security)[:\\s]+\\d{9}\\b",
                severity: .high,
                actions: [.alert, .logOnly]
            ),
        ]
    }

    // MARK: - API Key Patterns

    /// Returns DLP rules for detecting API keys, secret tokens, and programmatic credentials.
    ///
    /// Maps the following `SensitivePatterns` entries:
    /// - `awsAccessKey` → `.high`, `[.alert, .logOnly]`
    /// - `githubToken` → `.high`, `[.alert, .logOnly]`
    /// - `githubFineGrainedToken` → `.high`, `[.alert, .logOnly]`
    /// - `stripeLiveKey` → `.critical`, `[.block, .alert, .logOnly]`
    /// - `googleApiKey` → `.high`, `[.alert, .logOnly]`
    /// - `slackBotToken` → `.high`, `[.alert, .logOnly]`
    /// - `openAiKey` → `.high`, `[.alert, .logOnly]`
    /// - `genericApiKey` → `.high`, `[.alert, .logOnly]`
    /// - `bearerToken` → `.high`, `[.alert, .logOnly]`
    ///
    /// - Returns: An array of `DLPRule` values covering the major API key/token formats.
    static func apiKeyRules() -> [DLPRule] { // swiftlint:disable:this function_body_length
        [
            DLPRule(
                name: "AWS Access Keys",
                patternCategory: .apiKey,
                pattern: "AKIA[0-9A-Z]{16}",
                severity: .high,
                actions: [.alert, .logOnly]
            ),
            DLPRule(
                name: "GitHub Personal Access Tokens",
                patternCategory: .apiKey,
                pattern: "ghp_[a-zA-Z0-9]{36}",
                severity: .high,
                actions: [.alert, .logOnly]
            ),
            DLPRule(
                name: "GitHub Fine-Grained Access Tokens",
                patternCategory: .apiKey,
                pattern: "github_pat_[a-zA-Z0-9]{22}_[a-zA-Z0-9]{59}",
                severity: .high,
                actions: [.alert, .logOnly]
            ),
            DLPRule(
                name: "Stripe Live API Keys",
                patternCategory: .apiKey,
                pattern: "sk_live_[a-zA-Z0-9]{24,}",
                severity: .critical,
                actions: [.block, .alert, .logOnly]
            ),
            DLPRule(
                name: "Google API Keys",
                patternCategory: .apiKey,
                pattern: "AIza[0-9A-Za-z_-]{35}",
                severity: .high,
                actions: [.alert, .logOnly]
            ),
            DLPRule(
                name: "Slack Bot Tokens",
                patternCategory: .apiKey,
                pattern: "xoxb-[0-9]{11}-[0-9]{11}-[a-zA-Z0-9]{24}",
                severity: .high,
                actions: [.alert, .logOnly]
            ),
            DLPRule(
                name: "OpenAI API Keys",
                patternCategory: .apiKey,
                pattern: "sk-[a-zA-Z0-9]{48}",
                severity: .high,
                actions: [.alert, .logOnly]
            ),
            DLPRule(
                name: "Generic API Keys",
                patternCategory: .apiKey,
                // swiftlint:disable:next line_length
                pattern: "['\"]?(?:api[_-]?key|apikey|api[_-]?secret|secret[_-]?key)['\"]?\\s*[:=]\\s*['\"][^'\"]{16,}['\"]",
                severity: .high,
                actions: [.alert, .logOnly]
            ),
            DLPRule(
                name: "Bearer Tokens",
                patternCategory: .apiKey,
                pattern: "[Bb]earer\\s+[a-zA-Z0-9_-]+\\.[a-zA-Z0-9_-]+\\.[a-zA-Z0-9_-]+",
                severity: .high,
                actions: [.alert, .logOnly]
            ),
        ]
    }

    // MARK: - PII Patterns

    /// Returns DLP rules for detecting Personally Identifiable Information.
    ///
    /// Maps `SensitivePatterns.driversLicense` (generic US format) and
    /// `SensitivePatterns.passport` (keyword-prefixed alphanumeric).
    /// Both carry `.high` severity and use `[.alert, .logOnly]` actions.
    ///
    /// - Returns: An array of two `DLPRule` values covering driver's license and passport numbers.
    static func piiRules() -> [DLPRule] {
        [
            DLPRule(
                name: "Driver's License Numbers",
                patternCategory: .pii,
                pattern: "\\b(?:dl|driver'?s?[_\\s-]?license)[:\\s]+[A-Z0-9]{6,12}\\b",
                severity: .high,
                actions: [.alert, .logOnly]
            ),
            DLPRule(
                name: "Passport Numbers",
                patternCategory: .pii,
                pattern: "\\b(?:passport)[:\\s]+[A-Z0-9]{6,9}\\b",
                severity: .high,
                actions: [.alert, .logOnly]
            ),
        ]
    }

    // MARK: - Health Data Patterns

    /// Returns DLP rules for detecting protected health information.
    ///
    /// Maps `SensitivePatterns.medicalRecordNumber` and
    /// `SensitivePatterns.healthInsuranceId`.
    /// Both carry `.high` severity and use `[.alert, .logOnly]` actions.
    ///
    /// - Returns: An array of two `DLPRule` values covering MRNs and insurance IDs.
    static func healthDataRules() -> [DLPRule] {
        [
            DLPRule(
                name: "Medical Record Numbers",
                patternCategory: .healthData,
                pattern: "\\b(?:mrn|medical[_\\s-]?record)[:\\s]+[A-Z0-9]{6,12}\\b",
                severity: .high,
                actions: [.alert, .logOnly]
            ),
            DLPRule(
                name: "Health Insurance IDs",
                patternCategory: .healthData,
                pattern: "\\b(?:member[_\\s-]?id|insurance[_\\s-]?id)[:\\s]+[A-Z0-9]{8,15}\\b",
                severity: .high,
                actions: [.alert, .logOnly]
            ),
        ]
    }

    // MARK: - Credential Patterns

    /// Returns DLP rules for detecting passwords, connection strings, and private keys.
    ///
    /// Maps the following `SensitivePatterns` entries:
    /// - `passwordAssignment` → `.high`, `[.block, .alert, .logOnly]`
    /// - `connectionString` → `.critical`, `[.block, .alert, .logOnly]`
    /// - `sshPrivateKey` → `.critical`, `[.block, .alert, .logOnly]`
    /// - `pgpPrivateKey` → `.critical`, `[.block, .alert, .logOnly]`
    ///
    /// All credential rules use the `[.block, .alert, .logOnly]` action set, preventing
    /// private key material and database credentials from being stored in clipboard history.
    ///
    /// - Returns: An array of four `DLPRule` values covering the most critical credential types.
    static func credentialRules() -> [DLPRule] {
        [
            DLPRule(
                name: "Password Assignments",
                patternCategory: .apiKey,
                pattern: "['\"]?(?:password|passwd|pwd)['\"]?\\s*[:=]\\s*['\"][^'\"]+['\"]",
                severity: .high,
                actions: [.block, .alert, .logOnly]
            ),
            DLPRule(
                name: "Database Connection Strings",
                patternCategory: .apiKey,
                pattern: "(?:mongodb|postgres|mysql|redis)://[^:]+:[^@]+@",
                severity: .critical,
                actions: [.block, .alert, .logOnly]
            ),
            DLPRule(
                name: "SSH Private Keys",
                patternCategory: .apiKey,
                pattern: "-----BEGIN (?:RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----",
                severity: .critical,
                actions: [.block, .alert, .logOnly]
            ),
            DLPRule(
                name: "PGP Private Keys",
                patternCategory: .apiKey,
                pattern: "-----BEGIN PGP PRIVATE KEY BLOCK-----",
                severity: .critical,
                actions: [.block, .alert, .logOnly]
            ),
        ]
    }

    // MARK: - All Default Rules

    /// Returns the complete set of pre-configured default DLP rules.
    ///
    /// Combines all built-in rule categories in the following order:
    /// credit card, SSN, API keys, PII, health data, credentials.
    ///
    /// Use this method to populate a new `DLPPolicy` with a sensible baseline
    /// that covers the most common sensitive data types.
    ///
    /// - Returns: An array of all default `DLPRule` values (currently 19 rules).
    static func allDefaultRules() -> [DLPRule] {
        creditCardRules()
            + ssnRules()
            + apiKeyRules()
            + piiRules()
            + healthDataRules()
            + credentialRules()
    }

    // MARK: - Custom Rule Template

    /// Returns a blank `DLPRule` template suitable for administrator customization.
    ///
    /// The returned rule is assigned the `.custom` pattern category and `.medium`
    /// severity with `[.alert, .logOnly]` actions. Administrators should update
    /// `name`, `pattern`, `severity`, and `actions` before adding the rule to a policy.
    ///
    /// - Parameters:
    ///   - name: A human-readable label for the custom rule. Defaults to `"Custom Rule"`.
    ///   - pattern: The regex pattern string for the rule. Defaults to an empty string.
    /// - Returns: A disabled-by-default `DLPRule` ready for customization.
    static func customRuleTemplate(name: String = "Custom Rule", pattern: String = "") -> DLPRule {
        DLPRule(
            name: name,
            patternCategory: .custom,
            pattern: pattern,
            severity: .medium,
            actions: [.alert, .logOnly]
        )
    }
}
