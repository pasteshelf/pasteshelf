//
//  AuditRetentionConfiguration.swift
//  PasteShelf
//
//  Configuration model for audit log retention policy, specifying how long events are kept locally.
//

import Foundation

// MARK: - AuditRetentionConfiguration

/// Configuration that controls how long audit log entries are retained locally before pruning.
///
/// Administrators can configure the retention window in the Enterprise settings panel.
/// Events older than `retentionDays` are eligible for removal during the next scheduled
/// pruning pass performed by the `AuditLogStoring` implementation.
struct AuditRetentionConfiguration: Codable, Equatable {
    /// The default retention configuration used when no explicit policy has been set.
    ///
    /// Defaults to a 90-day retention window, which balances compliance requirements
    /// with local storage consumption for most enterprise deployments.
    static let `default` = AuditRetentionConfiguration(retentionDays: 90, isImmutable: false)

    /// The set of supported retention window values (in days) available in the UI.
    /// Includes 2190 (6 years) for HIPAA compliance.
    static let options: [Int] = [30, 60, 90, 180, 365, 2190]

    /// The HIPAA-mandated minimum retention (6 years = 2190 days).
    static let hipaaMinimumDays: Int = 2190

    /// The number of days to retain audit log entries before pruning them.
    ///
    /// Must be one of the values in `options`. Entries older than this window
    /// are removed during the next scheduled retention sweep.
    var retentionDays: Int

    /// When true, audit log entries cannot be pruned regardless of age.
    /// Required for HIPAA compliance where a minimum 6-year retention is mandated.
    var isImmutable: Bool
}
