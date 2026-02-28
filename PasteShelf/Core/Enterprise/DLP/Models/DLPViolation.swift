//
//  DLPViolation.swift
//  PasteShelf
//
//  Record of a DLP policy violation detected during clipboard content evaluation.
//

import Foundation

// MARK: - DLPViolation

/// An immutable record of a DLP policy violation.
///
/// A `DLPViolation` is created each time the DLP evaluator finds that clipboard
/// content matches an active `DLPRule`. Violations are persisted to CoreData via
/// a `DLPViolationStoring` implementation and surfaced in the admin console for
/// review and reporting.
///
/// Sensitive content is never stored verbatim. The `contentPreview` field holds
/// a redacted representation that is safe to display without exposing the original
/// sensitive value.
struct DLPViolation: Codable, Sendable, Identifiable, Equatable {

    // MARK: - Identity

    /// A locally generated UUID that uniquely identifies this violation record.
    let id: UUID

    // MARK: - Rule Reference

    /// The UUID of the `DLPRule` that was violated.
    let ruleId: UUID

    /// The human-readable name of the violated rule, captured at the time of detection.
    ///
    /// Stored alongside the `ruleId` so that violation history remains readable even
    /// if the rule is later renamed or deleted.
    let ruleName: String

    // MARK: - Event Metadata

    /// When the violation was detected.
    let timestamp: Date

    /// A redacted preview of the clipboard content that triggered the violation.
    ///
    /// Sensitive portions of the content are replaced with redaction markers before
    /// this field is populated. The preview is intended for display in violation reports
    /// and must never contain the original sensitive value.
    let contentPreview: String

    /// The portion of the content that matched the rule's regex pattern.
    ///
    /// This field stores the matched text (which may itself be redacted), not the full
    /// clipboard content, to minimise the footprint of sensitive data in storage.
    let matchedPattern: String

    /// The primary action that was taken in response to this violation.
    let actionTaken: DLPAction

    // MARK: - Source Context

    /// The bundle identifier of the application that was the clipboard's source, if known.
    let sourceAppBundleId: String?

    /// The display name of the source application, if known.
    let sourceAppName: String?

    // MARK: - Outcome

    /// Whether the clipboard item was prevented from being stored due to this violation.
    ///
    /// `true` when `actionTaken == .block` or when the evaluated `DLPEvaluationResult`
    /// set `shouldBlock` to `true`.
    let wasBlocked: Bool

    // MARK: - Initialization

    /// Creates a DLP violation record.
    ///
    /// - Parameters:
    ///   - id: A locally generated UUID for this record. Defaults to a new `UUID()`.
    ///   - ruleId: The UUID of the `DLPRule` that was violated.
    ///   - ruleName: The name of the violated rule at detection time.
    ///   - timestamp: When the violation occurred. Defaults to the current date.
    ///   - contentPreview: A redacted preview of the offending clipboard content.
    ///   - matchedPattern: The substring of content that matched the rule pattern.
    ///   - actionTaken: The primary enforcement action applied.
    ///   - sourceAppBundleId: Bundle ID of the clipboard source application, if available.
    ///   - sourceAppName: Display name of the clipboard source application, if available.
    ///   - wasBlocked: Whether the clipboard item was blocked from storage.
    init(
        id: UUID = UUID(),
        ruleId: UUID,
        ruleName: String,
        timestamp: Date = Date(),
        contentPreview: String,
        matchedPattern: String,
        actionTaken: DLPAction,
        sourceAppBundleId: String? = nil,
        sourceAppName: String? = nil,
        wasBlocked: Bool
    ) {
        self.id = id
        self.ruleId = ruleId
        self.ruleName = ruleName
        self.timestamp = timestamp
        self.contentPreview = contentPreview
        self.matchedPattern = matchedPattern
        self.actionTaken = actionTaken
        self.sourceAppBundleId = sourceAppBundleId
        self.sourceAppName = sourceAppName
        self.wasBlocked = wasBlocked
    }
}
