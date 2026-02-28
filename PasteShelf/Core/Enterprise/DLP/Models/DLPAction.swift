//
//  DLPAction.swift
//  PasteShelf
//
//  Enum defining DLP rule enforcement actions taken when a policy violation is detected.
//

import Foundation

// MARK: - DLPAction

/// The enforcement action taken when a DLP rule violation is detected.
///
/// Actions are ordered from most restrictive (`block`) to least restrictive (`logOnly`).
/// A single rule may specify multiple actions; the DLP evaluator applies all of them
/// in the order returned by the rule's `actions` array.
///
/// The raw `String` value is persisted in CoreData and transmitted to the admin console
/// for reporting purposes.
enum DLPAction: String, Codable, Sendable, CaseIterable {

    /// Prevents the clipboard item from being stored in the local history.
    ///
    /// When a `block` action is applied, the content is discarded immediately after
    /// detection and a `DLPViolation` is recorded with `wasBlocked == true`.
    case block

    /// Notifies the user that sensitive content was detected and logs to the audit trail.
    ///
    /// The user may choose to dismiss the alert. The clipboard item is still stored
    /// unless a `block` action is also present in the rule's action list.
    case alert

    /// Replaces matched content in the clipboard item with redaction markers before storage.
    ///
    /// Redacted items remain searchable by non-sensitive metadata but the sensitive
    /// portion is replaced with a placeholder (e.g. `[REDACTED]`).
    case redact

    /// Records the violation in the audit log without preventing storage or alerting the user.
    ///
    /// Use `logOnly` for monitoring and reporting without disrupting user workflow.
    case logOnly
}
