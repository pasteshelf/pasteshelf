//
//  DLPRule.swift
//  PasteShelf
//
//  Domain model for a DLP rule definition used to detect and act on sensitive clipboard content.
//

import Foundation

// MARK: - DLPRule

/// A single Data Loss Prevention rule that defines a pattern to detect and the actions to take.
///
/// `DLPRule` is the primary unit of DLP policy configuration. Each rule combines a
/// regex-based pattern with a severity classification and one or more enforcement actions.
/// Rules are composed into a `DLPPolicy` which is applied at clipboard capture time.
///
/// Rules may be pushed from the admin console (via `DLPPolicy`) or created locally by
/// an administrator on an enrolled device. The `isEnabled` flag allows rules to be
/// temporarily disabled without deleting them.
struct DLPRule: Codable, Identifiable, Equatable {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates a DLP rule with the given configuration.
    ///
    /// - Parameters:
    ///   - id: A locally generated UUID for this rule. Defaults to a new `UUID()`.
    ///   - name: A human-readable label for the rule.
    ///   - isEnabled: Whether the rule is active. Defaults to `true`.
    ///   - patternCategory: The category of sensitive data this rule targets.
    ///   - pattern: The regex pattern string used to match sensitive content.
    ///   - severity: The severity assigned to violations. Defaults to `.high`.
    ///   - actions: The enforcement actions to apply on violation. Defaults to `[.alert, .logOnly]`.
    ///   - createdAt: When the rule was created. Defaults to the current date.
    ///   - updatedAt: When the rule was last modified. Defaults to the current date.
    init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        patternCategory: DLPPatternCategory,
        pattern: String,
        severity: SensitiveSeverity = .high,
        actions: [DLPAction] = [.alert, .logOnly],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.patternCategory = patternCategory
        self.pattern = pattern
        self.severity = severity
        self.actions = actions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: Internal

    // MARK: - Identity

    /// A locally generated UUID that uniquely identifies this rule.
    let id: UUID

    /// A human-readable name for the rule, shown in the admin UI and violation reports.
    var name: String

    // MARK: - Configuration

    /// Whether this rule is currently active.
    ///
    /// Disabled rules are persisted but skipped during DLP evaluation.
    var isEnabled: Bool

    /// The category of sensitive data this rule targets.
    var patternCategory: DLPPatternCategory

    /// The regular expression pattern used to match sensitive content.
    ///
    /// The pattern is compiled into an `NSRegularExpression` at evaluation time.
    /// An invalid pattern causes `DLPError.invalidPattern` to be thrown during
    /// compilation in the DLP evaluator.
    var pattern: String

    /// The severity level assigned to violations of this rule.
    ///
    /// Reuses `SensitiveSeverity` from the `Core/Security` layer so that DLP
    /// and the built-in sensitive data detector share a common severity vocabulary.
    var severity: SensitiveSeverity

    /// The ordered list of actions to take when this rule is violated.
    ///
    /// Actions are applied in array order. At minimum one action should be specified;
    /// an empty `actions` array means the rule has no effect even when it matches.
    var actions: [DLPAction]

    // MARK: - Timestamps

    /// When this rule was first created.
    var createdAt: Date

    /// When this rule was last modified.
    var updatedAt: Date
}
