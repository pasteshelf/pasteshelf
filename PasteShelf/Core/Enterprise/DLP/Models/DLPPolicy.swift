//
//  DLPPolicy.swift
//  PasteShelf
//
//  Admin-pushed DLP policy composing rules and global enforcement settings.
//

import Foundation

// MARK: - DLPPolicy

/// A Data Loss Prevention policy pushed from the admin console to enrolled devices.
///
/// `DLPPolicy` is a sub-policy of `AdminPolicy` that groups all DLP configuration
/// into a single, versioned container. It follows the same structural pattern as
/// `HistoryLimitPolicy` and `ExcludedAppsPolicy` defined in `AdminPolicy.swift`.
///
/// When `enforced` is `true`, the policy is administrator-locked and the user cannot
/// disable or modify it. Rules are evaluated sequentially at clipboard capture time
/// by a `DLPRuleEvaluating` implementation.
///
/// Use the `empty` sentinel when no DLP policy has been received from the server,
/// or initialise with `DLPPolicy()` to create a policy with no rules and no enforcement.
struct DLPPolicy: Codable, Sendable, Equatable {

    // MARK: - Rules

    /// The ordered list of DLP rules to evaluate against incoming clipboard content.
    ///
    /// Rules are applied in array order. Only rules with `isEnabled == true` are
    /// evaluated. An empty array means no DLP scanning is performed.
    var rules: [DLPRule]

    // MARK: - Enforcement

    /// When `true`, this policy is administrator-locked and cannot be modified or
    /// disabled by the end user.
    var enforced: Bool

    /// When `true`, any content identified as sensitive by the built-in
    /// `SensitiveDataDetector` (independent of explicit DLP rules) is blocked.
    ///
    /// This provides a broad safety net for sensitive data categories that may not
    /// be covered by explicitly configured rules.
    var blockUnknownSensitive: Bool

    // MARK: - Initialization

    /// Creates a DLP policy with the given configuration.
    ///
    /// - Parameters:
    ///   - rules: The DLP rules to evaluate. Defaults to an empty array.
    ///   - enforced: Whether the policy is administrator-locked. Defaults to `false`.
    ///   - blockUnknownSensitive: Whether to block content flagged by the sensitive
    ///     data detector even without an explicit rule match. Defaults to `false`.
    init(
        rules: [DLPRule] = [],
        enforced: Bool = false,
        blockUnknownSensitive: Bool = false
    ) {
        self.rules = rules
        self.enforced = enforced
        self.blockUnknownSensitive = blockUnknownSensitive
    }

    // MARK: - Empty Sentinel

    /// A `DLPPolicy` with no rules and no enforcement — represents a device with no active DLP policy.
    ///
    /// Use this as a safe zero-value before any DLP policy has been received from the admin console.
    static let empty = DLPPolicy(rules: [], enforced: false, blockUnknownSensitive: false)
}
