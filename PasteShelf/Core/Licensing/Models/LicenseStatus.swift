//
//  LicenseStatus.swift
//  PasteShelf
//
//  Represents the current state of a license.
//  Includes validation state, expiration info, and error conditions.
//

import Foundation

/// Current status of the license
enum LicenseStatus: Sendable, Equatable {
    /// No license active, using Community edition
    case inactive

    /// License is valid and active
    case active(LicenseInfo)

    /// License has expired
    case expired(LicenseInfo)

    /// Trial period active
    case trial(daysRemaining: Int)

    /// In offline grace period
    case offlineGrace(daysRemaining: Int)

    /// License validation failed
    case invalid(LicenseError)

    // MARK: - Computed Properties

    /// Whether the license allows Pro features
    var isProEnabled: Bool {
        switch self {
        case let .active(info):
            return info.tier >= .pro
        case .trial:
            return true
        case let .offlineGrace(days):
            return days > 0
        case .inactive, .expired, .invalid:
            return false
        }
    }

    /// Whether the license allows Enterprise features
    var isEnterpriseEnabled: Bool {
        switch self {
        case let .active(info):
            return info.tier == .enterprise
        default:
            return false
        }
    }

    /// The effective tier based on current status
    var effectiveTier: LicenseTier {
        switch self {
        case let .active(info):
            return info.tier
        case .trial, .offlineGrace:
            return .pro // Trial gets Pro features
        case let .expired(info):
            // Enterprise downgrades to Pro gracefully, Pro to Community
            return info.tier == .enterprise ? .pro : .community
        case .inactive, .invalid:
            return .community
        }
    }

    /// Human-readable status description
    var displayDescription: String {
        switch self {
        case .inactive:
            return String(localized: "Community Edition")
        case let .active(info):
            return info.tier.displayName
        case let .expired(info):
            return String(localized: "\(info.tier.displayName) (Expired)")
        case let .trial(days):
            return String(localized: "Pro Trial (\(days) days remaining)")
        case let .offlineGrace(days):
            return String(localized: "Offline Mode (\(days) days remaining)")
        case let .invalid(error):
            return String(localized: "License Error: \(error.localizedDescription)")
        }
    }

    /// Whether the user should be prompted about license status
    var requiresAttention: Bool {
        switch self {
        case .inactive, .active:
            return false
        case .trial(let days) where days <= 3:
            return true
        case let .offlineGrace(days) where days <= 7:
            return true
        case .expired, .invalid:
            return true
        default:
            return false
        }
    }
}

// MARK: - License Info

/// Information about an active license
struct LicenseInfo: Sendable, Equatable, Codable {
    /// The license tier
    let tier: LicenseTier

    /// Type of license (subscription, lifetime, etc.)
    let type: LicenseType

    /// Email associated with the license
    let email: String

    /// License expiration date (nil for lifetime)
    let expirationDate: Date?

    /// Device ID this license is bound to
    let deviceId: String

    /// Maximum number of devices allowed
    let deviceLimit: Int

    /// Explicitly enabled features (may override tier defaults)
    let enabledFeatures: [String]?

    /// Organization ID (for enterprise licenses)
    let organizationId: String?

    /// License ID from the server
    let licenseId: String

    /// When the license was issued
    let issuedAt: Date

    // MARK: - Computed Properties

    /// Whether the license has expired
    var isExpired: Bool {
        guard let expiration = expirationDate else { return false }
        return expiration < Date()
    }

    /// Days until expiration (nil if no expiration)
    var daysUntilExpiration: Int? {
        guard let expiration = expirationDate else { return nil }
        let interval = expiration.timeIntervalSince(Date())
        return max(0, Int(interval / 86400))
    }

    /// Whether this is an enterprise license
    var isEnterprise: Bool {
        tier == .enterprise
    }
}

// MARK: - License Error

/// Errors that can occur during license validation
enum LicenseError: Error, Sendable, Equatable {
    /// License token is malformed
    case malformedToken

    /// Signature verification failed
    case invalidSignature

    /// Token has expired
    case expired

    /// Token is not yet valid (nbf claim)
    case notYetValid

    /// Invalid issuer claim
    case invalidIssuer

    /// Invalid audience claim
    case invalidAudience

    /// Device ID mismatch
    case deviceMismatch

    /// Device limit exceeded
    case deviceLimitExceeded

    /// License has been revoked
    case revoked

    /// Network error during validation
    case networkError(String)

    /// Public key not found
    case invalidPublicKey

    /// Keychain access error
    case keychainError(String)

    /// Server returned an error
    case serverError(String)

    /// Unknown error
    case unknown(String)
}

// MARK: - LocalizedError

extension LicenseError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .malformedToken:
            return String(localized: "The license token is invalid or corrupted.")
        case .invalidSignature:
            return String(localized: "License signature verification failed.")
        case .expired:
            return String(localized: "Your license has expired.")
        case .notYetValid:
            return String(localized: "This license is not yet valid.")
        case .invalidIssuer:
            return String(localized: "License was issued by an untrusted source.")
        case .invalidAudience:
            return String(localized: "This license is not valid for PasteShelf.")
        case .deviceMismatch:
            return String(localized: "This license is registered to a different device.")
        case .deviceLimitExceeded:
            return String(localized: "Maximum device limit reached for this license.")
        case .revoked:
            return String(localized: "This license has been revoked.")
        case let .networkError(message):
            return String(localized: "Network error: \(message)")
        case .invalidPublicKey:
            return String(localized: "Unable to verify license authenticity.")
        case let .keychainError(message):
            return String(localized: "Keychain error: \(message)")
        case let .serverError(message):
            return String(localized: "Server error: \(message)")
        case let .unknown(message):
            return String(localized: "Unknown error: \(message)")
        }
    }
}
