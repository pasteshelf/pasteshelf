//
//  HIPAARetentionPolicy.swift
//  PasteShelf
//
//  Enforces HIPAA-mandated minimum 6-year audit log retention with immutability.
//

import Foundation
import os.log

/// Validates and enforces HIPAA-mandated retention policy constraints.
///
/// HIPAA requires that audit logs be retained for a minimum of 6 years (2190 days)
/// and that logs cannot be deleted during the retention window. This struct provides
/// validation that ensures any given `AuditRetentionConfiguration` meets these requirements.
enum HIPAARetentionPolicy {
    // MARK: Internal

    /// Returns a default HIPAA-compliant retention configuration.
    static var hipaaDefault: AuditRetentionConfiguration {
        AuditRetentionConfiguration(
            retentionDays: AuditRetentionConfiguration.hipaaMinimumDays,
            isImmutable: true
        )
    }

    /// Validates the given configuration against HIPAA requirements.
    ///
    /// If the configuration does not meet HIPAA minimums, a corrected version is returned
    /// with `retentionDays` set to at least 2190 and `isImmutable` set to `true`.
    ///
    /// - Parameter configuration: The retention configuration to validate.
    /// - Returns: A HIPAA-compliant retention configuration.
    static func validate(_ configuration: AuditRetentionConfiguration) -> AuditRetentionConfiguration {
        var corrected = configuration

        if corrected.retentionDays < AuditRetentionConfiguration.hipaaMinimumDays {
            let currentDays = corrected.retentionDays
            let minimumDays = AuditRetentionConfiguration.hipaaMinimumDays
            logger.warning(
                "HIPAA retention: increasing retention from \(currentDays) to \(minimumDays) days"
            )
            corrected.retentionDays = AuditRetentionConfiguration.hipaaMinimumDays
        }

        if !corrected.isImmutable {
            logger.warning("HIPAA retention: enabling immutability flag for compliance")
            corrected.isImmutable = true
        }

        return corrected
    }

    /// Checks whether the given configuration meets HIPAA requirements.
    ///
    /// - Parameter configuration: The retention configuration to check.
    /// - Returns: `true` if the configuration meets HIPAA requirements.
    static func isCompliant(_ configuration: AuditRetentionConfiguration) -> Bool {
        configuration.retentionDays >= AuditRetentionConfiguration.hipaaMinimumDays
            && configuration.isImmutable
    }

    // MARK: Private

    private static let logger = Logger.compliance
}
