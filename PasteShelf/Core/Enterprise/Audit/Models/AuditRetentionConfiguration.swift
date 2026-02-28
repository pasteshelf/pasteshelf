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
struct AuditRetentionConfiguration: Codable, Sendable, Equatable {

    /// The number of days to retain audit log entries before pruning them.
    ///
    /// Must be one of the values in `options`. Entries older than this window
    /// are removed during the next scheduled retention sweep.
    var retentionDays: Int

    /// The default retention configuration used when no explicit policy has been set.
    ///
    /// Defaults to a 90-day retention window, which balances compliance requirements
    /// with local storage consumption for most enterprise deployments.
    static let `default` = AuditRetentionConfiguration(retentionDays: 90)

    /// The set of supported retention window values (in days) available in the UI.
    static let options: [Int] = [30, 60, 90, 180, 365]
}
