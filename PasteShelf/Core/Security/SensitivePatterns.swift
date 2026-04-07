//
//  SensitivePatterns.swift
//  PasteShelf
//
//  Regex patterns for detecting sensitive data types.
//  Includes patterns for credentials, API keys, financial data, and PII.
//

import Foundation

// MARK: - SensitivePatterns

/// Collection of regex patterns for detecting sensitive data
enum SensitivePatterns {
    // MARK: - Category Definition

    /// Categories of sensitive data patterns
    enum SensitiveCategory: String, CaseIterable, Codable, Sendable {
        case apiKeys = "API Keys & Tokens"
        case passwords = "Passwords"
        case sshCerts = "SSH & Certificates"
        case financial = "Financial"
        case personalId = "Personal Identification"
        case health = "Health Information"
        case contact = "Contact Information"

        // MARK: Internal

        var displayName: String {
            rawValue
        }

        var iconName: String {
            switch self {
            case .apiKeys: "key"
            case .passwords: "lock"
            case .sshCerts: "lock.shield"
            case .financial: "creditcard"
            case .personalId: "person.text.rectangle"
            case .health: "heart.text.square"
            case .contact: "person.crop.circle"
            }
        }
    }

    // MARK: - Pattern Definition

    /// A sensitive data pattern with its metadata
    struct Pattern: Sendable {
        // MARK: Lifecycle

        init(
            name: String,
            pattern: String,
            severity: SensitiveSeverity,
            category: SensitiveCategory,
            options: NSRegularExpression.Options = [],
            validator: (@Sendable (String) -> Bool)? = nil
        ) {
            self.name = name
            // swiftlint:disable:next force_try
            regex = try! NSRegularExpression(pattern: pattern, options: options)
            self.severity = severity
            self.category = category
            self.validator = validator
        }

        // MARK: Internal

        let name: String
        let regex: NSRegularExpression
        let severity: SensitiveSeverity
        let category: SensitiveCategory
        let validator: (@Sendable (String) -> Bool)?
    }

    // MARK: - API Keys & Tokens (High Severity)

    /// AWS Access Key ID pattern
    static let awsAccessKey = Pattern(
        name: "AWS Access Key",
        pattern: "AKIA[0-9A-Z]{16}",
        severity: .high,
        category: .apiKeys
    )

    /// AWS Secret Access Key pattern (following AKIA key)
    static let awsSecretKey = Pattern(
        name: "AWS Secret Key",
        pattern: "[A-Za-z0-9/+=]{40}",
        severity: .critical,
        category: .apiKeys
    )

    /// GitHub Personal Access Token (classic)
    static let githubToken = Pattern(
        name: "GitHub Token",
        pattern: "ghp_[a-zA-Z0-9]{36}",
        severity: .high,
        category: .apiKeys
    )

    /// GitHub Fine-grained Personal Access Token
    static let githubFineGrainedToken = Pattern(
        name: "GitHub Fine-grained Token",
        pattern: "github_pat_[a-zA-Z0-9]{22}_[a-zA-Z0-9]{59}",
        severity: .high,
        category: .apiKeys
    )

    /// Stripe Live API Key
    static let stripeLiveKey = Pattern(
        name: "Stripe Live Key",
        pattern: "sk_live_[a-zA-Z0-9]{24,}",
        severity: .critical,
        category: .apiKeys
    )

    /// Stripe Test API Key
    static let stripeTestKey = Pattern(
        name: "Stripe Test Key",
        pattern: "sk_test_[a-zA-Z0-9]{24,}",
        severity: .medium,
        category: .apiKeys
    )

    /// Google API Key
    static let googleApiKey = Pattern(
        name: "Google API Key",
        pattern: "AIza[0-9A-Za-z_-]{35}",
        severity: .high,
        category: .apiKeys
    )

    /// Slack Bot Token
    static let slackBotToken = Pattern(
        name: "Slack Bot Token",
        pattern: "xoxb-[0-9]{11}-[0-9]{11}-[a-zA-Z0-9]{24}",
        severity: .high,
        category: .apiKeys
    )

    /// Slack User Token
    static let slackUserToken = Pattern(
        name: "Slack User Token",
        pattern: "xoxp-[0-9]{11}-[0-9]{11}-[0-9]{11}-[a-z0-9]{32}",
        severity: .high,
        category: .apiKeys
    )

    /// OpenAI API Key
    static let openAiKey = Pattern(
        name: "OpenAI API Key",
        pattern: "sk-[a-zA-Z0-9]{48}",
        severity: .high,
        category: .apiKeys
    )

    /// Generic API Key in assignment
    static let genericApiKey = Pattern(
        name: "Generic API Key",
        pattern: "['\"]?(?:api[_-]?key|apikey|api[_-]?secret|secret[_-]?key)['\"]?\\s*[:=]\\s*['\"][^'\"]{16,}['\"]",
        severity: .high,
        category: .apiKeys,
        options: .caseInsensitive
    )

    /// Bearer Token in Authorization header
    static let bearerToken = Pattern(
        name: "Bearer Token",
        pattern: "[Bb]earer\\s+[a-zA-Z0-9_-]+\\.[a-zA-Z0-9_-]+\\.[a-zA-Z0-9_-]+",
        severity: .high,
        category: .apiKeys
    )

    // MARK: - Passwords (High Severity)

    /// Password in assignment/config
    static let passwordAssignment = Pattern(
        name: "Password",
        pattern: "['\"]?(?:password|passwd|pwd)['\"]?\\s*[:=]\\s*['\"][^'\"]+['\"]",
        severity: .high,
        category: .passwords,
        options: .caseInsensitive
    )

    /// Database connection string with password
    static let connectionString = Pattern(
        name: "Connection String",
        pattern: "(?:mongodb|postgres|mysql|redis)://[^:]+:[^@]+@",
        severity: .critical,
        category: .passwords,
        options: .caseInsensitive
    )

    // MARK: - SSH & Certificates (Critical Severity)

    /// SSH Private Key header
    static let sshPrivateKey = Pattern(
        name: "SSH Private Key",
        pattern: "-----BEGIN (?:RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----",
        severity: .critical,
        category: .sshCerts
    )

    /// PGP Private Key header
    static let pgpPrivateKey = Pattern(
        name: "PGP Private Key",
        pattern: "-----BEGIN PGP PRIVATE KEY BLOCK-----",
        severity: .critical,
        category: .sshCerts
    )

    // MARK: - Financial (High Severity)

    /// Credit card number (Visa, Mastercard, Amex, Discover)
    static let creditCard = Pattern(
        name: "Credit Card",
        pattern: "\\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|6(?:011|5[0-9]{2})[0-9]{12})\\b",
        severity: .high,
        category: .financial
    ) { Validators.isValidLuhn($0) }

    /// Credit card with spaces or dashes
    static let creditCardFormatted = Pattern(
        name: "Credit Card (Formatted)",
        pattern: "\\b(?:\\d{4}[- ]?){3}\\d{4}\\b",
        severity: .high,
        category: .financial
    ) {
        Validators.isValidLuhn($0.replacingOccurrences(of: "[- ]", with: "", options: .regularExpression))
    }

    /// Bank account number (generic)
    static let bankAccount = Pattern(
        name: "Bank Account",
        pattern: "\\b(?:account[_\\s-]?(?:number|num|no)[:\\s]+)?\\d{8,17}\\b",
        severity: .medium,
        category: .financial,
        options: .caseInsensitive
    )

    /// IBAN
    static let iban = Pattern(
        name: "IBAN",
        pattern: "\\b[A-Z]{2}[0-9]{2}[A-Z0-9]{4}[0-9]{7}([A-Z0-9]?){0,16}\\b",
        severity: .high,
        category: .financial
    )

    // MARK: - Personal Identification (High Severity)

    /// US Social Security Number
    static let ssn = Pattern(
        name: "Social Security Number",
        pattern: "\\b\\d{3}-\\d{2}-\\d{4}\\b",
        severity: .high,
        category: .personalId
    )

    /// US Social Security Number (without dashes)
    static let ssnNoDash = Pattern(
        name: "SSN (No Dashes)",
        pattern: "\\b(?:ssn|social[_\\s-]?security)[:\\s]+\\d{9}\\b",
        severity: .high,
        category: .personalId,
        options: .caseInsensitive
    )

    /// Driver's License (generic US format)
    static let driversLicense = Pattern(
        name: "Driver's License",
        pattern: "\\b(?:dl|driver'?s?[_\\s-]?license)[:\\s]+[A-Z0-9]{6,12}\\b",
        severity: .high,
        category: .personalId,
        options: .caseInsensitive
    )

    /// Passport Number
    static let passport = Pattern(
        name: "Passport Number",
        pattern: "\\b(?:passport)[:\\s]+[A-Z0-9]{6,9}\\b",
        severity: .high,
        category: .personalId,
        options: .caseInsensitive
    )

    // MARK: - Contact Information (Low Severity)

    /// Email address
    static let email = Pattern(
        name: "Email Address",
        pattern: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
        severity: .low,
        category: .contact
    )

    /// Phone number (US format)
    static let phoneUS = Pattern(
        name: "Phone Number",
        pattern: "\\+?1?[-.\\s]?\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4}",
        severity: .low,
        category: .contact
    )

    /// International phone number
    static let phoneInternational = Pattern(
        name: "International Phone",
        pattern: "\\+[1-9]\\d{6,14}",
        severity: .low,
        category: .contact
    )

    // MARK: - Health Information (High Severity)

    /// Medical Record Number
    static let medicalRecordNumber = Pattern(
        name: "Medical Record Number",
        pattern: "\\b(?:mrn|medical[_\\s-]?record)[:\\s]+[A-Z0-9]{6,12}\\b",
        severity: .high,
        category: .health,
        options: .caseInsensitive
    )

    /// Health Insurance ID
    static let healthInsuranceId = Pattern(
        name: "Health Insurance ID",
        pattern: "\\b(?:member[_\\s-]?id|insurance[_\\s-]?id)[:\\s]+[A-Z0-9]{8,15}\\b",
        severity: .high,
        category: .health,
        options: .caseInsensitive
    )

    // MARK: - All Patterns

    /// All patterns grouped by category for efficient scanning
    static let allPatterns: [Pattern] = [
        // API Keys & Tokens
        awsAccessKey,
        awsSecretKey,
        githubToken,
        githubFineGrainedToken,
        stripeLiveKey,
        stripeTestKey,
        googleApiKey,
        slackBotToken,
        slackUserToken,
        openAiKey,
        genericApiKey,
        bearerToken,
        // Passwords
        passwordAssignment,
        connectionString,
        // SSH & Certificates
        sshPrivateKey,
        pgpPrivateKey,
        // Financial
        creditCard,
        creditCardFormatted,
        bankAccount,
        iban,
        // Personal Identification
        ssn,
        ssnNoDash,
        driversLicense,
        passport,
        // Health Information
        medicalRecordNumber,
        healthInsuranceId,
        // Contact (low severity - optional)
        email,
        phoneUS,
        phoneInternational,
    ]

    /// High-priority patterns only (for performance-sensitive contexts)
    static let highPriorityPatterns: [Pattern] = allPatterns.filter {
        $0.severity >= .high
    }

    /// Returns patterns filtered to the specified categories
    static func patterns(for categories: Set<SensitiveCategory>) -> [Pattern] {
        allPatterns.filter { categories.contains($0.category) }
    }
}

// MARK: - Validators

/// Validation functions for sensitive data patterns
enum Validators {
    /// Luhn algorithm validation for credit card numbers
    /// - Parameter number: The card number to validate (digits only)
    /// - Returns: True if the number passes Luhn check
    static func isValidLuhn(_ number: String) -> Bool {
        let digits = number.compactMap(\.wholeNumberValue)
        guard digits.count >= 13, digits.count <= 19 else {
            return false
        }

        var sum = 0
        let reversedDigits = digits.reversed().enumerated()

        for (index, digit) in reversedDigits {
            if index.isMultiple(of: 2) {
                sum += digit
            } else {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            }
        }

        return sum.isMultiple(of: 10)
    }

    /// Validates that a string looks like a real API key (not placeholder)
    /// - Parameter key: The potential API key
    /// - Returns: False if the key appears to be a placeholder
    static func isNotPlaceholder(_ key: String) -> Bool {
        let placeholders = [
            "your_api_key",
            "xxx",
            "000",
            "test",
            "example",
            "placeholder",
            "insert",
            "replace",
        ]
        let lowercased = key.lowercased()
        return !placeholders.contains { lowercased.contains($0) }
    }
}
