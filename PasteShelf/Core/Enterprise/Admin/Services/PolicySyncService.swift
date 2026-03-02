//
//  PolicySyncService.swift
//  PasteShelf
//
//  Fetches admin policies from the admin console and applies them to AppSettings.
//  Mirrors the MDMPolicyEnforcer pattern for policy-to-settings mapping.
//

import Foundation
import os.log

// MARK: - PolicySyncService

/// Fetches the latest admin policy from the admin console server and applies
/// enforced sub-policies to the application settings.
///
/// `PolicySyncService` mirrors `MDMPolicyEnforcer` in design: it receives a
/// structured policy document (here `AdminPolicy` rather than `MDMConfiguration`)
/// and maps its sub-policies into concrete mutations on `AppSettings`.
///
/// A periodic polling timer can be started to keep the local policy in sync with
/// the server. The most recently fetched policy is cached locally for offline
/// resilience via `UserDefaults`.
final class PolicySyncService: PolicySyncing {

    // MARK: - Properties

    private let apiClient: AdminAPIProviding
    private let deviceId: () -> String?
    private var cachedPolicy: AdminPolicy?
    private var pollingTimer: Timer?
    private let logger = Logger(subsystem: "com.pasteshelf", category: "policy-sync")

    /// UserDefaults key used to cache the last-fetched policy for offline use.
    private static let cachedPolicyKey = "com.pasteshelf.admin.cachedPolicy"

    // MARK: - Initialization

    /// Creates a policy sync service.
    ///
    /// - Parameters:
    ///   - apiClient: The admin console API client for fetching policies.
    ///   - deviceId: A closure that returns the current enrolled device ID, or `nil`.
    init(apiClient: AdminAPIProviding, deviceId: @escaping () -> String?) {
        self.apiClient = apiClient
        self.deviceId = deviceId
        self.cachedPolicy = Self.loadCachedPolicy()
    }

    // MARK: - PolicySyncing

    var currentPolicy: AdminPolicy? {
        cachedPolicy
    }

    func fetchLatestPolicy() async throws -> AdminPolicy {
        guard let id = deviceId() else {
            throw AdminError.notEnrolled
        }

        let policy = try await apiClient.fetchPolicy(for: id)
        cachedPolicy = policy
        Self.saveCachedPolicy(policy)
        logger.info("Fetched policy '\(policy.name)' v\(policy.version)")
        return policy
    }

    func applyPolicy(_ policy: AdminPolicy, to settings: inout AppSettings) {
        applyHistoryLimits(policy.historyLimits, to: &settings)
        applyExcludedApps(policy.excludedApps, to: &settings)
        applySyncSettings(policy.syncSettings, to: &settings)
        applyEncryptionRequirements(policy.encryptionRequirements, to: &settings)
    }

    // MARK: - Polling

    /// Starts periodic policy polling at the given interval.
    ///
    /// Each poll fetches the latest policy from the server and applies it. If the
    /// fetch fails, the cached policy remains in effect. Calling this method when
    /// already polling replaces the existing timer.
    ///
    /// - Parameter interval: The time interval in seconds between polls.
    func startPolling(interval: TimeInterval) {
        stopPolling()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                do {
                    _ = try await self?.fetchLatestPolicy()
                } catch {
                    self?.logger.warning("Policy poll failed: \(error.localizedDescription)")
                }
            }
        }
        logger.info("Policy polling started (interval: \(interval)s)")
    }

    /// Stops periodic policy polling.
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    // MARK: - Policy Mapping

    /// Applies history limit sub-policy to settings.
    ///
    /// Maps `maxItems` to `general.historyLimit` and `maxDays` to
    /// `privacy.autoDeleteEnabled/Days`, matching the `MDMPolicyEnforcer` pattern.
    private func applyHistoryLimits(_ policy: HistoryLimitPolicy?, to settings: inout AppSettings) {
        guard let policy, policy.enforced else { return }

        if let maxItems = policy.maxItems {
            settings.general.historyLimit = closestHistoryLimit(to: maxItems)
        }

        if let maxDays = policy.maxDays, maxDays > 0 {
            settings.privacy.autoDeleteEnabled = true
            settings.privacy.autoDeleteDays = maxDays
        }
    }

    /// Applies excluded apps sub-policy to settings.
    ///
    /// Merges enforced bundle IDs with the user's existing exclusions (union).
    /// Users can add their own exclusions but cannot remove enforced ones.
    private func applyExcludedApps(_ policy: ExcludedAppsPolicy?, to settings: inout AppSettings) {
        guard let policy, policy.enforced else { return }

        let merged = Set(settings.privacy.excludedAppBundleIds).union(policy.bundleIds)
        settings.privacy.excludedAppBundleIds = Array(merged).sorted()
    }

    /// Applies sync settings sub-policy to settings.
    ///
    /// Controls whether cloud sync is enabled via `EnterpriseSettings`. When
    /// `localStorageOnly` is `true`, sync is implicitly disabled.
    private func applySyncSettings(_ policy: SyncSettingsPolicy?, to settings: inout AppSettings) {
        guard let policy, policy.enforced else { return }

        if let syncEnabled = policy.syncEnabled {
            settings.enterprise.cloudSyncEnabled = syncEnabled
        }
        if let localOnly = policy.localStorageOnly {
            settings.enterprise.localStorageOnly = localOnly
        }

        let syncEnabled = settings.enterprise.cloudSyncEnabled
        let localOnly = settings.enterprise.localStorageOnly
        logger.debug("Sync policy applied (cloudSyncEnabled: \(syncEnabled), localStorageOnly: \(localOnly))")
    }

    /// Applies encryption requirements sub-policy to settings.
    ///
    /// When biometric authentication is required, maps to `SecuritySettings.requireBiometricAuth`.
    private func applyEncryptionRequirements(_ policy: EncryptionPolicy?, to settings: inout AppSettings) {
        guard let policy, policy.enforced else { return }

        if let requireBiometric = policy.requireBiometricAuth {
            settings.security.requireBiometricAuth = requireBiometric
        }

        let biometric = settings.security.requireBiometricAuth
        logger.debug("Encryption policy applied (requireBiometricAuth: \(biometric))")
    }

    // MARK: - History Limit Mapping

    /// Maps an integer item count to the closest `HistoryLimit` enum case.
    ///
    /// Mirrors `MDMPolicyEnforcer.closestHistoryLimit(to:)` exactly.
    private func closestHistoryLimit(to items: Int) -> HistoryLimit {
        if items <= 0 { return .unlimited }
        if items <= 100 { return .small }
        if items <= 500 { return .medium }
        if items <= 1000 { return .large }
        return .unlimited
    }

    // MARK: - Local Cache

    /// Saves the policy to UserDefaults for offline resilience.
    private static func saveCachedPolicy(_ policy: AdminPolicy) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(policy) {
            UserDefaults.standard.set(data, forKey: cachedPolicyKey)
        }
    }

    /// Loads the cached policy from UserDefaults.
    private static func loadCachedPolicy() -> AdminPolicy? {
        guard let data = UserDefaults.standard.data(forKey: cachedPolicyKey) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AdminPolicy.self, from: data)
    }
}
