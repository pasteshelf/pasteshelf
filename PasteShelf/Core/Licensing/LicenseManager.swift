//
//  LicenseManager.swift
//  PasteShelf
//
//  Central manager for license validation and feature access control.
//  Implements LicenseManaging protocol following singleton pattern.
//

import Combine
import Foundation
import os.log

/// Central manager for license state and feature access
@MainActor
final class LicenseManager: ObservableObject, LicenseManaging {
    // MARK: - Singleton

    /// Shared license manager instance
    static let shared = LicenseManager()

    // MARK: - Published Properties

    /// Current license tier
    @Published private(set) var currentTier: LicenseTier = .community

    /// Current license status
    @Published private(set) var status: LicenseStatus = .inactive

    /// License info (when active)
    @Published private(set) var licenseInfo: LicenseInfo?

    // MARK: - Dependencies

    /// Keychain storage for tokens
    private let keychainStorage: KeychainStorage

    /// License validator for JWT verification
    private var validator: LicenseValidating?

    /// Server client for API calls
    private var serverClient: LicenseServerClient?

    /// Offline validator for grace period
    private var offlineValidator: OfflineValidating?

    /// Observers for license changes
    private var observers: [WeakObserver] = []

    // MARK: - Private Properties

    /// Logger for license operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "license"
    )

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Timer for periodic validation
    private var validationTimer: Timer?

    /// Validation interval (24 hours)
    private let validationInterval: TimeInterval = 24 * 60 * 60

    // MARK: - Initialization

    private init() {
        keychainStorage = KeychainStorage()
        loadStoredLicense()
    }

    /// Initialize with custom dependencies (for testing)
    init(
        keychainStorage: KeychainStorage,
        validator: LicenseValidating? = nil,
        serverClient: LicenseServerClient? = nil,
        offlineValidator: OfflineValidating? = nil
    ) {
        self.keychainStorage = keychainStorage
        self.validator = validator
        self.serverClient = serverClient
        self.offlineValidator = offlineValidator
        loadStoredLicense()
    }

    deinit {
        validationTimer?.invalidate()
    }

    // MARK: - Configuration

    /// Configure dependencies after initialization
    func configure(
        validator: LicenseValidating,
        serverClient: LicenseServerClient,
        offlineValidator: OfflineValidating
    ) {
        self.validator = validator
        self.serverClient = serverClient
        self.offlineValidator = offlineValidator
        schedulePeriodicValidation()
    }

    // MARK: - LicenseManaging Implementation

    /// Check if a feature is available with current license
    func isFeatureAvailable(_ feature: LicensedFeature) -> Bool {
        // Check if feature's required tier is met by current effective tier
        return feature.requiredTier <= status.effectiveTier
    }

    /// Activate a license with a license key
    func activate(licenseKey key: String) async -> Result<LicenseInfo, LicenseError> {
        logger.info("Activating license...")

        guard let serverClient = serverClient else {
            logger.error("Server client not configured")
            return .failure(.unknown("License server not configured"))
        }

        do {
            // Get device ID
            let deviceId = try keychainStorage.getOrCreateDeviceId()
            let deviceName = Host.current().localizedName ?? "Unknown Mac"

            // Activate with server
            let token = try await serverClient.activate(
                licenseKey: key,
                deviceId: deviceId,
                deviceName: deviceName
            )

            // Validate and store token
            let info = try await processToken(token)

            logger.info("License activated: \(info.tier.displayName)")
            return .success(info)

        } catch let error as LicenseError {
            logger.error("Activation failed: \(error.localizedDescription)")
            return .failure(error)
        } catch {
            logger.error("Activation failed: \(error.localizedDescription)")
            return .failure(.unknown(error.localizedDescription))
        }
    }

    /// Deactivate the current license
    func deactivate() async -> Result<Void, LicenseError> {
        logger.info("Deactivating license...")

        // Get current token
        guard let token = keychainStorage.load(),
              let serverClient = serverClient
        else {
            // Just clear local state if no token or server
            clearLicenseState()
            return .success(())
        }

        do {
            let deviceId = keychainStorage.loadDeviceId() ?? ""
            try await serverClient.deactivate(token: token, deviceId: deviceId)

            // Clear local state
            clearLicenseState()

            logger.info("License deactivated")
            return .success(())

        } catch let error as LicenseError {
            // Still clear local state even if server call fails
            clearLicenseState()
            logger.warning("Server deactivation failed, cleared locally: \(error.localizedDescription)")
            return .success(())
        } catch {
            clearLicenseState()
            return .success(())
        }
    }

    /// Validate the current license
    func validate() async -> LicenseStatus {
        logger.debug("Validating license...")

        // Check for stored token
        guard let token = keychainStorage.load() else {
            updateStatus(.inactive)
            return .inactive
        }

        // First, try local validation
        guard let validator = validator else {
            logger.warning("Validator not configured, using offline mode")
            return checkOfflineStatus()
        }

        do {
            let claims = try validator.verify(token)

            // Check if online validation is needed
            if shouldValidateOnline(claims: claims) {
                return await validateOnline(token: token)
            }

            // Use cached validation
            let info = licenseInfoFrom(claims: claims)
            updateStatus(.active(info))
            return .active(info)

        } catch let error as LicenseError {
            logger.warning("Local validation failed: \(error.localizedDescription)")

            // Check offline grace period
            if let offlineStatus = checkOfflineGraceStatus() {
                return offlineStatus
            }

            updateStatus(.invalid(error))
            return .invalid(error)
        } catch {
            return checkOfflineStatus()
        }
    }

    /// Refresh the license token
    func refresh() async -> Result<LicenseInfo, LicenseError> {
        logger.info("Refreshing license token...")

        guard let token = keychainStorage.load(),
              let serverClient = serverClient
        else {
            return .failure(.keychainError("No license token found"))
        }

        do {
            let newToken = try await serverClient.refresh(token: token)
            let info = try await processToken(newToken)

            logger.info("License refreshed successfully")
            return .success(info)

        } catch let error as LicenseError {
            logger.error("Refresh failed: \(error.localizedDescription)")
            return .failure(error)
        } catch {
            logger.error("Refresh failed: \(error.localizedDescription)")
            return .failure(.unknown(error.localizedDescription))
        }
    }

    // MARK: - Observer Management

    /// Add an observer for license changes
    func addObserver(_ observer: LicenseObserver) {
        observers.removeAll { $0.observer == nil } // Clean up
        observers.append(WeakObserver(observer: observer))
    }

    /// Remove an observer
    func removeObserver(_ observer: LicenseObserver) {
        observers.removeAll { $0.observer === observer || $0.observer == nil }
    }

    // MARK: - Private Methods

    /// Load stored license on startup
    private func loadStoredLicense() {
        guard let token = keychainStorage.load(),
              let validator = validator
        else {
            updateStatus(.inactive)
            return
        }

        do {
            let claims = try validator.verify(token)
            let info = licenseInfoFrom(claims: claims)

            if claims.exp < Date() {
                updateStatus(.expired(info))
            } else {
                updateStatus(.active(info))
            }
        } catch {
            // Will validate on next opportunity
            logger.debug("Stored license validation deferred")
        }
    }

    /// Process and store a license token
    private func processToken(_ token: String) async throws -> LicenseInfo {
        // Validate token
        guard let validator = validator else {
            throw LicenseError.unknown("Validator not configured")
        }

        let claims = try validator.verify(token)

        // Store token
        try keychainStorage.save(token: token)

        // Record online validation
        offlineValidator?.recordOnlineValidation()

        // Update state
        let info = licenseInfoFrom(claims: claims)
        updateStatus(.active(info))

        return info
    }

    /// Convert claims to LicenseInfo
    private func licenseInfoFrom(claims: LicenseClaims) -> LicenseInfo {
        LicenseInfo(
            tier: claims.tier,
            type: claims.type,
            email: claims.email,
            expirationDate: claims.exp,
            deviceId: claims.deviceId,
            deviceLimit: claims.deviceLimit,
            enabledFeatures: claims.features,
            organizationId: claims.orgId,
            licenseId: claims.sub,
            issuedAt: claims.iat
        )
    }

    /// Clear all license state
    private func clearLicenseState() {
        try? keychainStorage.delete()
        licenseInfo = nil
        updateStatus(.inactive)
    }

    /// Update status and notify observers
    private func updateStatus(_ newStatus: LicenseStatus) {
        let oldTier = currentTier
        status = newStatus
        currentTier = newStatus.effectiveTier

        if let info = newStatus.licenseInfo {
            licenseInfo = info
        }

        // Notify status change
        notifyObservers(of: newStatus)

        // Notify feature changes if tier changed
        if oldTier != currentTier {
            notifyFeatureChanges(from: oldTier, to: currentTier)
        }

        // Post notification
        NotificationCenter.default.post(
            name: .licenseStatusDidChange,
            object: self,
            userInfo: ["status": newStatus]
        )
    }

    /// Check if online validation is needed
    private func shouldValidateOnline(claims: LicenseClaims) -> Bool {
        // Validate online at least every 24 hours
        return Date().timeIntervalSince(claims.iat) > validationInterval
    }

    /// Perform online validation
    private func validateOnline(token: String) async -> LicenseStatus {
        guard let serverClient = serverClient else {
            return checkOfflineStatus()
        }

        do {
            let response = try await serverClient.validate(token: token)

            if response.isValid {
                offlineValidator?.recordOnlineValidation()

                if response.shouldRefresh {
                    _ = await refresh()
                }

                return status
            } else {
                // License invalid on server
                if response.status == "revoked" {
                    clearLicenseState()
                    return .invalid(.revoked)
                }
                return .invalid(.unknown(response.message ?? "Validation failed"))
            }

        } catch {
            logger.warning("Online validation failed, using offline mode")
            return checkOfflineStatus()
        }
    }

    /// Check offline grace status
    private func checkOfflineStatus() -> LicenseStatus {
        guard let offlineStatus = checkOfflineGraceStatus() else {
            return status
        }
        updateStatus(offlineStatus)
        return offlineStatus
    }

    /// Check offline grace period status
    private func checkOfflineGraceStatus() -> LicenseStatus? {
        guard let offlineValidator = offlineValidator else { return nil }

        switch offlineValidator.checkGraceStatus() {
        case .valid, .graceExpiring:
            return nil // Keep current status
        case let .warning(days):
            return .offlineGrace(daysRemaining: days)
        case .revoked:
            return .invalid(.revoked)
        case .unknown:
            return nil
        }
    }

    /// Schedule periodic validation
    private func schedulePeriodicValidation() {
        validationTimer?.invalidate()
        validationTimer = Timer.scheduledTimer(
            withTimeInterval: validationInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                _ = await self?.validate()
            }
        }
    }

    /// Notify observers of status change
    private func notifyObservers(of status: LicenseStatus) {
        observers.forEach { weak in
            weak.observer?.licenseStatusDidChange(status)
        }
    }

    /// Notify observers of feature availability changes
    private func notifyFeatureChanges(from oldTier: LicenseTier, to newTier: LicenseTier) {
        for feature in LicensedFeature.allCases {
            let wasAvailable = feature.requiredTier <= oldTier
            let isAvailable = feature.requiredTier <= newTier

            if wasAvailable != isAvailable {
                observers.forEach { weak in
                    weak.observer?.featureAvailabilityDidChange(feature, available: isAvailable)
                }
            }
        }
    }
}

// MARK: - Helper Types

/// Weak wrapper for observers
private struct WeakObserver {
    weak var observer: LicenseObserver?
}

/// Extract license info from status
private extension LicenseStatus {
    var licenseInfo: LicenseInfo? {
        switch self {
        case let .active(info), let .expired(info):
            return info
        default:
            return nil
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when license status changes
    static let licenseStatusDidChange = Notification.Name("com.pasteshelf.licenseStatusDidChange")
}
