//
//  DLPEvaluationResult.swift
//  PasteShelf
//
//  Result of evaluating clipboard content against a set of DLP rules.
//

import Foundation

// MARK: - DLPEvaluationResult

/// The result returned by a `DLPRuleEvaluating` implementation after scanning
/// clipboard content against a set of active `DLPRule` values.
///
/// `DLPEvaluationResult` aggregates all violations found during a single evaluation
/// pass and provides derived flags that the clipboard capture pipeline uses to decide
/// whether to store, redact, or discard the incoming content.
///
/// Use the `clean` static sentinel when content passes all checks without any violations.
struct DLPEvaluationResult {
    /// A result representing content that passed all DLP checks without any violations.
    ///
    /// Use this as the result value when no active rules matched the content, or
    /// when DLP evaluation is skipped (e.g. the feature is unavailable).
    static let clean = DLPEvaluationResult(
        violations: [],
        shouldBlock: false,
        shouldRedact: false,
        redactedContent: nil,
        redactedFields: nil
    )

    // MARK: - Violations

    /// All policy violations found during the evaluation pass.
    ///
    /// An empty array indicates that no active rules were matched. Use `hasViolations`
    /// as a convenience check.
    let violations: [DLPViolation]

    // MARK: - Outcome Flags

    /// Whether the clipboard item must be blocked from being stored.
    ///
    /// `true` when at least one matched rule included a `.block` action, or when the
    /// policy's `blockUnknownSensitive` flag caused an unconditional block.
    let shouldBlock: Bool

    /// Whether the matched portions of the clipboard item must be redacted before storage.
    ///
    /// `true` when at least one matched rule included a `.redact` action.
    let shouldRedact: Bool

    // MARK: - Redacted Content

    /// The redacted version of the clipboard content, or `nil` if no redaction was required.
    ///
    /// When `shouldRedact` is `true`, this property contains the content string with
    /// all matched sensitive substrings replaced by redaction markers. The clipboard
    /// capture pipeline stores this value instead of the original content.
    ///
    /// `nil` when `shouldRedact` is `false`.
    let redactedContent: String?

    /// Per-field redacted content for accurate field-level redaction.
    ///
    /// When `shouldRedact` is `true`, each field that contained sensitive matches
    /// has its redacted version here. Fields without matches retain their original values.
    /// The pipeline should prefer this over `redactedContent` for storage updates.
    let redactedFields: DLPRedactedFields?

    // MARK: - Convenience

    /// Whether any violations were found during evaluation.
    var hasViolations: Bool {
        !self.violations.isEmpty
    }

    // MARK: - Clean Sentinel

    /// Returns a copy with source app context injected into all violations.
    func withSourceApp(bundleId: String, name: String) -> DLPEvaluationResult {
        let enriched = self.violations.map { violation in
            DLPViolation(
                id: violation.id,
                ruleId: violation.ruleId,
                ruleName: violation.ruleName,
                timestamp: violation.timestamp,
                contentPreview: violation.contentPreview,
                matchedPattern: violation.matchedPattern,
                actionTaken: violation.actionTaken,
                sourceAppBundleId: bundleId,
                sourceAppName: name,
                wasBlocked: violation.wasBlocked
            )
        }
        return DLPEvaluationResult(
            violations: enriched,
            shouldBlock: self.shouldBlock,
            shouldRedact: self.shouldRedact,
            redactedContent: self.redactedContent,
            redactedFields: self.redactedFields
        )
    }
}

// MARK: - DLPRedactedFields

/// Per-field redacted content produced by DLP evaluation.
///
/// Each non-nil field contains the redacted version of the corresponding
/// `ClipboardContent` property. Fields that had no sensitive matches retain
/// their original value.
struct DLPRedactedFields {
    let plainText: String?
    let html: String?
    let url: String?
}
