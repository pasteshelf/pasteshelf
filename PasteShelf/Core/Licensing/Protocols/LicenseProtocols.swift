//
//  LicenseProtocols.swift
//  PasteShelf
//
//  Protocol definitions for the licensing system components.
//  These protocols enable dependency injection and testability.
//

import Foundation

// MARK: - License Management

/// Protocol for managing license state and feature access
@MainActor
protocol LicenseManaging: AnyObject {
    /// Current license tier
    var currentTier: LicenseTier { get }

    /// Current license status
    var status: LicenseStatus { get }

    /// Check if a feature is available with current license
    /// - Parameter feature: The feature to check
    /// - Returns: True if the feature is available
    func isFeatureAvailable(_ feature: LicensedFeature) -> Bool

    /// Activate a license with a license key
    /// - Parameter key: The license key to activate
    /// - Returns: Result containing license info or error
    func activate(licenseKey key: String) async -> Result<LicenseInfo, LicenseError>

    /// Deactivate the current license
    /// - Returns: Result indicating success or error
    func deactivate() async -> Result<Void, LicenseError>

    /// Validate the current license
    /// - Returns: The updated license status
    func validate() async -> LicenseStatus

    /// Refresh the license token
    /// - Returns: Result containing new license info or error
    func refresh() async -> Result<LicenseInfo, LicenseError>
}

// MARK: - License Validation

/// Protocol for validating license tokens
protocol LicenseValidating {
    /// Verify and decode a JWT license token
    /// - Parameter token: The JWT token string
    /// - Returns: Decoded license claims
    /// - Throws: LicenseError if validation fails
    func verify(_ token: String) throws -> LicenseClaims

    /// Verify token signature only (for quick checks)
    /// - Parameter token: The JWT token string
    /// - Returns: True if signature is valid
    func verifySignature(_ token: String) -> Bool
}

/// JWT claims structure for license tokens
struct LicenseClaims: Codable, Sendable {
    // Standard JWT claims
    let iss: String // Issuer
    let sub: String // Subject (license ID)
    let aud: String // Audience
    let exp: Date // Expiration
    let iat: Date // Issued at
    let nbf: Date // Not before

    // Custom claims
    let tier: LicenseTier
    let type: LicenseType
    let email: String
    let deviceId: String
    let deviceLimit: Int
    let features: [String]?
    let orgId: String?

    // Coding keys for snake_case JSON
    enum CodingKeys: String, CodingKey {
        case iss, sub, aud, exp, iat, nbf
        case tier, type, email, features
        case deviceId = "device_id"
        case deviceLimit = "device_limit"
        case orgId = "org_id"
    }
}

// MARK: - License Server Communication

/// Protocol for communicating with the license server
protocol LicenseServerClient {
    /// Activate a license on this device
    /// - Parameters:
    ///   - licenseKey: The license key
    ///   - deviceId: This device's identifier
    ///   - deviceName: Human-readable device name
    /// - Returns: JWT license token
    func activate(
        licenseKey: String,
        deviceId: String,
        deviceName: String
    ) async throws -> String

    /// Validate an existing license token
    /// - Parameter token: The current JWT token
    /// - Returns: Validation response with status
    func validate(token: String) async throws -> LicenseValidationResponse

    /// Refresh a license token
    /// - Parameter token: The current JWT token
    /// - Returns: New JWT token
    func refresh(token: String) async throws -> String

    /// Deactivate a device
    /// - Parameters:
    ///   - token: The current JWT token
    ///   - deviceId: The device to deactivate
    func deactivate(token: String, deviceId: String) async throws
}

/// Response from license validation endpoint
struct LicenseValidationResponse: Codable, Sendable {
    let isValid: Bool
    let status: String
    let message: String?
    let shouldRefresh: Bool

    enum CodingKeys: String, CodingKey {
        case isValid = "is_valid"
        case status
        case message
        case shouldRefresh = "should_refresh"
    }
}

// MARK: - Keychain Storage

/// Protocol for secure license token storage
protocol LicenseTokenStoring {
    /// Save a license token to secure storage
    /// - Parameter token: The JWT token to store
    /// - Throws: LicenseError if storage fails
    func save(token: String) throws

    /// Load the stored license token
    /// - Returns: The stored JWT token, or nil if not found
    func load() -> String?

    /// Delete the stored license token
    /// - Throws: LicenseError if deletion fails
    func delete() throws

    /// Save the device ID
    /// - Parameter deviceId: The device identifier
    /// - Throws: LicenseError if storage fails
    func saveDeviceId(_ deviceId: String) throws

    /// Load the device ID
    /// - Returns: The stored device ID, or nil if not found
    func loadDeviceId() -> String?
}

// MARK: - Offline Support

/// Protocol for managing offline license validation
protocol OfflineValidating {
    /// Grace period configuration
    var gracePeriodDays: Int { get }
    var warningPeriodDays: Int { get }
    var maxOfflineDays: Int { get }

    /// Check the current offline grace status
    /// - Returns: Current grace status
    func checkGraceStatus() -> OfflineGraceStatus

    /// Record a successful online validation
    func recordOnlineValidation()

    /// Get the last successful online validation date
    var lastOnlineValidation: Date? { get }
}

/// Offline grace period status
enum OfflineGraceStatus: Sendable, Equatable {
    /// Within grace period, all features available
    case valid

    /// Grace period expiring soon
    case graceExpiring(daysRemaining: Int)

    /// Warning period, user should connect
    case warning(daysRemaining: Int)

    /// Maximum offline period exceeded, features disabled
    case revoked

    /// No previous online validation recorded
    case unknown
}

// MARK: - Feature Gating

/// Protocol for feature access control
protocol FeatureGating {
    /// Check if a feature is available
    /// - Parameter feature: The feature to check
    /// - Returns: True if available
    func isAvailable(_ feature: LicensedFeature) -> Bool

    /// Get all available features
    /// - Returns: Array of available features
    func availableFeatures() -> [LicensedFeature]

    /// Get features that require upgrade
    /// - Returns: Array of features requiring higher tier
    func lockedFeatures() -> [LicensedFeature]
}

// MARK: - License Observer

/// Protocol for observing license state changes
@MainActor
protocol LicenseObserver: AnyObject {
    /// Called when license status changes
    /// - Parameter status: The new license status
    func licenseStatusDidChange(_ status: LicenseStatus)

    /// Called when feature availability changes
    /// - Parameters:
    ///   - feature: The affected feature
    ///   - available: Whether the feature is now available
    func featureAvailabilityDidChange(_ feature: LicensedFeature, available: Bool)
}

// MARK: - Default Implementations

extension LicenseObserver {
    func featureAvailabilityDidChange(_ feature: LicensedFeature, available: Bool) {
        // Optional - default empty implementation
    }
}
