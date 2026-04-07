//
//  DLPRuleEngine.swift
//  PasteShelf
//
//  Evaluates clipboard content against DLP rules using regex matching and the
//  existing SensitiveDataDetector infrastructure.
//

import Foundation
import os.log

// MARK: - DLPRuleEngine

/// Evaluates clipboard content against a set of DLP rules and returns a consolidated result.
///
/// `DLPRuleEngine` is the core evaluation component of the DLP subsystem. For each enabled
/// rule it compiles the rule's regex pattern, scans the extracted text content for matches,
/// and creates a `DLPViolation` record for each match. The aggregate result includes
/// `shouldBlock` and `shouldRedact` flags derived from the matched rules' action lists.
///
/// Text is extracted from `ClipboardContent` using the same approach as `SensitiveDataDetector`:
/// plain text, HTML, and URL string representations are concatenated for scanning.
final class DLPRuleEngine: DLPRuleEvaluating, @unchecked Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    init() {}

    // MARK: Internal

    // MARK: - DLPRuleEvaluating

    /// Evaluates the given clipboard content against the provided rules.
    ///
    /// Only rules with `isEnabled == true` are evaluated. Rules with invalid regex patterns
    /// are silently skipped (logged at debug level). The evaluation extracts all text
    /// representations from the content and scans them against each rule's pattern.
    ///
    /// - Parameters:
    ///   - content: The in-memory clipboard content captured from the system pasteboard.
    ///   - rules: The ordered list of `DLPRule` values to evaluate.
    /// - Returns: A `DLPEvaluationResult` aggregating all violations and outcome flags.
    func evaluate( // swiftlint:disable:this function_body_length
        _ content: ClipboardContent,
        against rules: [DLPRule]
    ) async -> DLPEvaluationResult {
        let enabledRules = rules.filter(\.isEnabled)
        guard !enabledRules.isEmpty else {
            return .clean
        }

        // Collect individual text fields for per-field scanning
        let fields = self.extractFields(from: content)
        let textToScan = fields.map(\.value).joined(separator: "\n")
        guard !textToScan.isEmpty else {
            return .clean
        }

        var violations: [DLPViolation] = []
        var shouldBlock = false
        var shouldRedact = false

        // Per-field redacted content, starting with originals
        var redactedPlainText = content.plainText
        var redactedHTML = content.html
        var redactedURL = content.url?.absoluteString

        for rule in enabledRules {
            guard let regex = compiledRegex(for: rule.pattern) else {
                self.logger.debug("DLP: Skipping rule '\(rule.name)' — invalid pattern")
                continue
            }

            // Scan each field individually to track which fields matched
            for (fieldName, fieldText) in fields {
                let nsRange = NSRange(fieldText.startIndex..., in: fieldText)
                let matches = regex.matches(in: fieldText, options: [], range: nsRange)

                for match in matches {
                    guard let range = Range(match.range, in: fieldText) else {
                        continue
                    }

                    let matchedText = String(fieldText[range])
                    let primaryAction = rule.actions.first ?? .logOnly
                    let redactedPreview = self.redact(matchedText)

                    let violation = DLPViolation(
                        ruleId: rule.id,
                        ruleName: rule.name,
                        contentPreview: redactedPreview,
                        matchedPattern: redactedPreview,
                        actionTaken: primaryAction,
                        sourceAppBundleId: nil,
                        sourceAppName: nil,
                        wasBlocked: rule.actions.contains(.block)
                    )
                    violations.append(violation)

                    if rule.actions.contains(.block) {
                        shouldBlock = true
                    }
                    if rule.actions.contains(.redact) {
                        shouldRedact = true
                        // Apply redaction to the specific field that matched
                        switch fieldName {
                        case "plainText":
                            redactedPlainText = redactedPlainText?.replacingOccurrences(
                                of: matchedText,
                                with: redactedPreview
                            )
                        case "html":
                            redactedHTML = redactedHTML?.replacingOccurrences(of: matchedText, with: redactedPreview)
                        case "url":
                            redactedURL = redactedURL?.replacingOccurrences(of: matchedText, with: redactedPreview)
                        default:
                            break
                        }
                    }
                }
            }
        }

        // Deduplicate violations at the same location
        let uniqueViolations = self.deduplicateViolations(violations)

        if !uniqueViolations.isEmpty {
            self.logger
                .info("DLP: \(uniqueViolations.count) violation(s) found, block=\(shouldBlock), redact=\(shouldRedact)")
        }

        // Build per-field redacted content
        let perFieldRedaction: DLPRedactedFields? = shouldRedact ? DLPRedactedFields(
            plainText: redactedPlainText,
            html: redactedHTML,
            url: redactedURL
        ) : nil

        // Legacy composite redacted content for backward compatibility
        let compositeRedacted: String? = shouldRedact ? [redactedPlainText, redactedHTML, redactedURL].compactMap { $0 }
            .joined(separator: "\n") : nil

        return DLPEvaluationResult(
            violations: uniqueViolations,
            shouldBlock: shouldBlock,
            shouldRedact: shouldRedact,
            redactedContent: compositeRedacted,
            redactedFields: perFieldRedaction
        )
    }

    // MARK: Private

    // MARK: - Dependencies

    private let logger = Logger.security

    /// Cache of compiled regex patterns keyed by pattern string to avoid repeated compilation.
    private var regexCache: [String: NSRegularExpression] = [:]
    private let cacheLock = NSLock()

    // MARK: - Text Extraction

    /// Extracts text fields individually for per-field DLP scanning and redaction.
    ///
    /// Returns a dictionary keyed by field name ("plainText", "html", "url") with
    /// each non-nil text representation for separate scanning.
    private func extractFields(from content: ClipboardContent) -> [(key: String, value: String)] {
        var fields: [(key: String, value: String)] = []

        if let plainText = content.plainText {
            fields.append((key: "plainText", value: plainText))
        }
        if let html = content.html {
            fields.append((key: "html", value: html))
        }
        if let url = content.url {
            fields.append((key: "url", value: url.absoluteString))
        }

        return fields
    }

    // MARK: - Regex Compilation

    /// Returns a compiled `NSRegularExpression` for the given pattern string, using a cache.
    ///
    /// Returns `nil` if the pattern is invalid. Invalid patterns are logged once and cached
    /// as `nil` to avoid repeated compilation attempts.
    private func compiledRegex(for pattern: String) -> NSRegularExpression? {
        self.cacheLock.lock()
        defer { cacheLock.unlock() }

        if let cached = regexCache[pattern] {
            return cached
        }

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            self.regexCache[pattern] = regex
            return regex
        } catch {
            self.logger.debug("DLP: Invalid regex pattern: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Redaction

    /// Creates a redacted version of a matched text string.
    ///
    /// Shows the first 2 and last 2 characters for strings longer than 8 characters,
    /// or replaces the entire string with asterisks for shorter strings.
    private func redact(_ text: String) -> String {
        let length = text.count
        if length > 8 {
            let stars = String(repeating: "*", count: min(length - 4, 12))
            return String(text.prefix(2)) + stars + String(text.suffix(2))
        }
        return String(repeating: "*", count: length)
    }

    // MARK: - Deduplication

    /// Removes duplicate violations that reference the same rule and matched text.
    private func deduplicateViolations(_ violations: [DLPViolation]) -> [DLPViolation] {
        var seen = Set<String>()
        var unique: [DLPViolation] = []

        for violation in violations {
            let key = "\(violation.ruleId)-\(violation.matchedPattern)"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(violation)
            }
        }

        return unique
    }
}
