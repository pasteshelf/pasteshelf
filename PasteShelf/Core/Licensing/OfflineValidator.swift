//
//  OfflineValidator.swift
//  PasteShelf
//
//  Manages offline license validation with grace period support.
//  Implements OfflineValidating protocol for graceful degradation.
//

import Foundation
import os.log

/// Validates license status during offline periods
final class OfflineValidator: OfflineValidating {
    // MARK: - Constants

    /// Default grace period (7 days) - full features, no warnings
    static let defaultGracePeriodDays = 7

    /// Default warning period (14 days) - features still work, warning shown
    static let defaultWarningPeriodDays = 14

    /// Default max offline period (30 days) - features disabled
    static let defaultMaxOfflineDays = 30

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let lastOnlineValidation = "com.pasteshelf.license.lastOnlineValidation"
        static let offlineStartDate = "com.pasteshelf.license.offlineStartDate"
        static let cachedLicenseStatus = "com.pasteshelf.license.cachedStatus"
    }

    // MARK: - Properties

    /// Grace period in days
    let gracePeriodDays: Int

    /// Warning period in days
    let warningPeriodDays: Int

    /// Maximum offline days
    let maxOfflineDays: Int

    /// User defaults for persistence
    private let defaults: UserDefaults

    /// Logger for offline validation
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "offline-validator"
    )

    /// Last successful online validation date
    var lastOnlineValidation: Date? {
        defaults.object(forKey: Keys.lastOnlineValidation) as? Date
    }

    // MARK: - Computed Properties

    /// Grace period in seconds
    private var gracePeriodInterval: TimeInterval {
        TimeInterval(gracePeriodDays) * 24 * 60 * 60
    }

    /// Warning period in seconds
    private var warningPeriodInterval: TimeInterval {
        TimeInterval(warningPeriodDays) * 24 * 60 * 60
    }

    /// Max offline period in seconds
    private var maxOfflineInterval: TimeInterval {
        TimeInterval(maxOfflineDays) * 24 * 60 * 60
    }

    // MARK: - Initialization

    /// Initialize with default configuration
    convenience init() {
        self.init(
            gracePeriodDays: Self.defaultGracePeriodDays,
            warningPeriodDays: Self.defaultWarningPeriodDays,
            maxOfflineDays: Self.defaultMaxOfflineDays
        )
    }

    /// Initialize with custom configuration
    init(
        gracePeriodDays: Int = defaultGracePeriodDays,
        warningPeriodDays: Int = defaultWarningPeriodDays,
        maxOfflineDays: Int = defaultMaxOfflineDays,
        defaults: UserDefaults = .standard
    ) {
        self.gracePeriodDays = gracePeriodDays
        self.warningPeriodDays = warningPeriodDays
        self.maxOfflineDays = maxOfflineDays
        self.defaults = defaults
    }

    // MARK: - OfflineValidating Implementation

    /// Check the current offline grace status
    func checkGraceStatus() -> OfflineGraceStatus {
        guard let lastOnline = lastOnlineValidation else {
            logger.debug("No previous online validation recorded")
            return .unknown
        }

        let offlineDuration = Date().timeIntervalSince(lastOnline)
        let offlineDays = Int(offlineDuration / 86400)

        logger.debug("Offline for \(offlineDays) days")

        // Check against thresholds
        if offlineDuration > maxOfflineInterval {
            logger.warning("Max offline period exceeded (\(offlineDays) days)")
            return .revoked
        } else if offlineDuration > warningPeriodInterval {
            let remaining = maxOfflineDays - offlineDays
            logger.info("In warning period, \(remaining) days remaining")
            return .warning(daysRemaining: remaining)
        } else if offlineDuration > gracePeriodInterval {
            let remaining = warningPeriodDays - offlineDays
            logger.debug("Grace period expiring, \(remaining) days until warning")
            return .graceExpiring(daysRemaining: remaining)
        } else {
            logger.debug("Within grace period")
            return .valid
        }
    }

    /// Record a successful online validation
    func recordOnlineValidation() {
        let now = Date()
        defaults.set(now, forKey: Keys.lastOnlineValidation)

        // Clear offline start date since we're back online
        defaults.removeObject(forKey: Keys.offlineStartDate)

        logger.info("Recorded online validation at \(now)")
    }

    // MARK: - Additional Methods

    /// Get days since last online validation
    var daysSinceLastOnlineValidation: Int? {
        guard let lastOnline = lastOnlineValidation else { return nil }
        return Int(Date().timeIntervalSince(lastOnline) / 86400)
    }

    /// Check if currently in offline mode
    var isOffline: Bool {
        guard let lastOnline = lastOnlineValidation else { return true }
        return Date().timeIntervalSince(lastOnline) > gracePeriodInterval
    }

    /// Get the date when features will be disabled
    var featureDisableDate: Date? {
        guard let lastOnline = lastOnlineValidation else { return nil }
        return lastOnline.addingTimeInterval(maxOfflineInterval)
    }

    /// Get days until features are disabled
    var daysUntilFeaturesDisabled: Int? {
        guard let disableDate = featureDisableDate else { return nil }
        let interval = disableDate.timeIntervalSince(Date())
        return max(0, Int(interval / 86400))
    }

    /// Reset offline validation state (for testing or license change)
    func reset() {
        defaults.removeObject(forKey: Keys.lastOnlineValidation)
        defaults.removeObject(forKey: Keys.offlineStartDate)
        defaults.removeObject(forKey: Keys.cachedLicenseStatus)
        logger.info("Offline validation state reset")
    }

    // MARK: - Status Caching

    /// Cache license status for offline use
    func cacheLicenseStatus(_ status: CachedLicenseStatus) {
        if let data = try? JSONEncoder().encode(status) {
            defaults.set(data, forKey: Keys.cachedLicenseStatus)
            logger.debug("Cached license status")
        }
    }

    /// Load cached license status
    func loadCachedStatus() -> CachedLicenseStatus? {
        guard let data = defaults.data(forKey: Keys.cachedLicenseStatus),
              let status = try? JSONDecoder().decode(CachedLicenseStatus.self, from: data)
        else {
            return nil
        }
        return status
    }
}

// MARK: - Cached License Status

/// Minimal license status cached for offline use
struct CachedLicenseStatus: Codable {
    let tier: LicenseTier
    let email: String
    let expirationDate: Date?
    let cachedAt: Date

    /// Whether the cached status has expired
    var isExpired: Bool {
        guard let expiration = expirationDate else { return false }
        return expiration < Date()
    }
}

// MARK: - Convenience Extensions

extension OfflineGraceStatus {
    /// Human-readable description for UI
    var displayDescription: String {
        switch self {
        case .valid:
            return String(localized: "License validated")
        case let .graceExpiring(days):
            return String(localized: "Offline mode (\(days) days until warning)")
        case let .warning(days):
            return String(localized: "Please connect to internet within \(days) days to validate your license")
        case .revoked:
            return String(localized: "License validation required. Please connect to the internet.")
        case .unknown:
            return String(localized: "License status unknown")
        }
    }

    /// Whether the user should be warned
    var shouldWarnUser: Bool {
        switch self {
        case .warning, .revoked:
            return true
        case .graceExpiring(let days) where days <= 3:
            return true
        default:
            return false
        }
    }

    /// Whether features should be disabled
    var featuresDisabled: Bool {
        self == .revoked
    }
}
