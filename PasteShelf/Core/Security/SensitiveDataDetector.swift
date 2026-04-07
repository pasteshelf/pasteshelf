//
//  SensitiveDataDetector.swift
//  PasteShelf
//
//  Pattern-based detection engine for identifying sensitive data
//  in clipboard content. Uses regex matching with optional validation.
//

import AppKit
import Foundation
import os.log

// MARK: - SensitiveDataDetector

/// Detects sensitive data in clipboard content using pattern matching
final class SensitiveDataDetector: SensitiveDataDetecting, Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates a detector with specified patterns
    /// - Parameters:
    ///   - patterns: Patterns to use for detection
    ///   - includeLowSeverity: Whether to include low severity patterns
    init(
        patterns: [SensitivePatterns.Pattern] = SensitivePatterns.allPatterns,
        includeLowSeverity: Bool = false
    ) {
        if includeLowSeverity {
            self.patterns = patterns
        } else {
            self.patterns = patterns.filter { $0.severity > .low }
        }
        self.includeLowSeverity = includeLowSeverity
    }

    // MARK: Internal

    /// Creates a detector optimized for high-priority detection only
    static func highPriorityOnly() -> SensitiveDataDetector {
        SensitiveDataDetector(
            patterns: SensitivePatterns.highPriorityPatterns,
            includeLowSeverity: false
        )
    }

    // MARK: - SensitiveDataDetecting

    func analyze(_ content: ClipboardContent) -> SensitiveDataResult {
        // Collect all text content to analyze
        var textToAnalyze: [String] = []

        if let plainText = content.plainText {
            textToAnalyze.append(plainText)
        }

        if let html = content.html {
            textToAnalyze.append(html)
        }

        // Extract text from RTF data for analysis
        if let rtfData = content.rtfData,
           let attrString = NSAttributedString(rtf: rtfData, documentAttributes: nil)
        {
            textToAnalyze.append(attrString.string)
        }

        if let url = content.url {
            textToAnalyze.append(url.absoluteString)
        }

        // Analyze all collected text
        let combinedText = textToAnalyze.joined(separator: "\n")
        return self.analyze(text: combinedText)
    }

    func analyze(text: String) -> SensitiveDataResult {
        guard !text.isEmpty else {
            return .empty
        }

        var detections: [SensitiveDetection] = []
        let nsRange = NSRange(text.startIndex..., in: text)

        for pattern in self.patterns {
            let matches = pattern.regex.matches(in: text, options: [], range: nsRange)

            for match in matches {
                guard let range = Range(match.range, in: text) else {
                    continue
                }

                let matchedText = String(text[range])

                // Run optional validator if present
                if let validator = pattern.validator {
                    guard validator(matchedText) else {
                        continue
                    }
                }

                // Skip obvious placeholders
                guard Validators.isNotPlaceholder(matchedText) else {
                    continue
                }

                let detection = SensitiveDetection(
                    type: pattern.name,
                    severity: pattern.severity,
                    range: range,
                    redactedPreview: self.redact(matchedText, type: pattern.name)
                )

                detections.append(detection)
            }
        }

        // Remove duplicate detections at same location
        let uniqueDetections = self.removeDuplicateDetections(detections)

        let highestSeverity = uniqueDetections.map(\.severity).max() ?? .none

        Logger.security
            .debug(
                // swiftlint:disable:next line_length
                "Sensitive data scan: \(uniqueDetections.count) detections, severity: \(String(describing: highestSeverity))"
            )

        return SensitiveDataResult(
            isSensitive: !uniqueDetections.isEmpty,
            detections: uniqueDetections,
            highestSeverity: highestSeverity
        )
    }

    // MARK: Private

    /// Patterns to scan for
    private let patterns: [SensitivePatterns.Pattern]

    /// Whether to include low-severity patterns (email, phone)
    private let includeLowSeverity: Bool

    // MARK: - Private Helpers

    /// Removes detections that overlap at the same position
    private func removeDuplicateDetections(_ detections: [SensitiveDetection]) -> [SensitiveDetection] {
        var seen = Set<String>()
        var unique: [SensitiveDetection] = []

        for detection in detections.sorted(by: { $0.severity > $1.severity }) {
            // Create a key based on the range
            let key: String = if let range = detection.range {
                "\(range.lowerBound)-\(range.upperBound)"
            } else {
                detection.type + (detection.redactedPreview ?? "")
            }

            if !seen.contains(key) {
                seen.insert(key)
                unique.append(detection)
            }
        }

        return unique
    }

    /// Redacts sensitive content for safe preview
    /// - Parameters:
    ///   - text: The original text
    ///   - type: The type of sensitive data
    /// - Returns: A redacted version safe for display
    private func redact(_ text: String, type: String) -> String {
        let length = text.count

        switch type {
        case "Credit Card",
             "Credit Card (Formatted)":
            // Show last 4 digits only
            let cleaned = text.replacingOccurrences(of: "[- ]", with: "", options: .regularExpression)
            if cleaned.count >= 4 {
                return "****-****-****-" + String(cleaned.suffix(4))
            }
            return "****-****-****-****"

        case "Social Security Number",
             "SSN (No Dashes)":
            return "***-**-" + String(text.suffix(4))

        case "Email Address":
            // Show first char and domain
            if let atIndex = text.firstIndex(of: "@") {
                let prefix = text.prefix(1)
                let domain = text[atIndex...]
                return "\(prefix)***\(domain)"
            }
            return "***@***"

        case "Phone Number",
             "International Phone":
            // Show last 4 digits
            let digits = text.filter(\.isNumber)
            if digits.count >= 4 {
                return "***-***-" + String(digits.suffix(4))
            }
            return "***-***-****"

        case "AWS Access Key":
            // Show type prefix only
            return "AKIA****************"

        case "GitHub Token":
            return "ghp_************************************"

        case "SSH Private Key",
             "PGP Private Key":
            return "[Private Key Detected]"

        case "Password",
             "Connection String":
            return "[Credential Detected]"

        default:
            // Generic redaction - show first and last 2 chars
            if length > 8 {
                let stars = String(repeating: "*", count: min(length - 4, 12))
                return String(text.prefix(2)) + stars + String(text.suffix(2))
            }
            return String(repeating: "*", count: length)
        }
    }
}

// MARK: - Convenience Extensions

extension SensitiveDataResult {
    /// Returns types of all detections
    var detectedTypes: [String] {
        detections.map(\.type)
    }

    /// Returns unique detection types
    var uniqueTypes: Set<String> {
        Set(self.detectedTypes)
    }

    /// Whether critical severity data was detected
    var hasCriticalData: Bool {
        highestSeverity >= .critical
    }

    /// Whether any high or critical severity data was detected
    var hasHighSeverityData: Bool {
        highestSeverity >= .high
    }
}
