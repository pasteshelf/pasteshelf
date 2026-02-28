//
//  MDMManager.swift
//  PasteShelf
//
//  Central orchestrator for Enterprise MDM support.
//  Coordinates ManagedPreferencesReader, MDMPolicyEnforcer, and SettingsManager.
//

import Combine
import Foundation
import os.log

// MARK: - MDMManager

/// Central manager for Enterprise MDM managed preferences.
///
/// Coordinates reading MDM configuration from the managed preferences domain,
/// enforcing policy overrides on user settings, and observing profile changes.
/// Follows the same singleton pattern as `SSOManager`.
@MainActor
final class MDMManager: ObservableObject {

    // MARK: - Singleton

    static let shared = MDMManager()

    // MARK: - Published State

    /// The current MDM configuration snapshot
    @Published private(set) var configuration: MDMConfiguration = .empty

    /// Whether the device is under MDM management
    @Published private(set) var isManaged: Bool = false

    /// Set of preference keys that are forced (locked) by MDM
    @Published private(set) var forcedKeys: Set<ManagedPreferenceKey> = []

    // MARK: - Properties

    private let reader: ManagedPreferencesReading & MDMConfigurationObserving
    private let enforcer: MDMPolicyEnforcer
    private let logger = Logger(subsystem: "com.pasteshelf", category: "mdm-manager")
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        let reader = ManagedPreferencesReader()
        self.reader = reader
        self.enforcer = MDMPolicyEnforcer()
    }

    /// Creates a manager with injected dependencies (for testing).
    ///
    /// - Parameters:
    ///   - reader: The managed preferences reader to use.
    ///   - enforcer: The policy enforcer to use.
    init(reader: ManagedPreferencesReading & MDMConfigurationObserving, enforcer: MDMPolicyEnforcer) {
        self.reader = reader
        self.enforcer = enforcer
    }

    // MARK: - Configuration Loading

    /// Loads the current MDM configuration and updates published state.
    func loadConfiguration() {
        let config = reader.readConfiguration()
        updateState(with: config)
    }

    /// Applies MDM overrides to the provided settings.
    ///
    /// Forced preferences override user values; default preferences are applied
    /// only for keys not already customized by the user.
    ///
    /// - Parameter settings: The application settings to apply overrides to.
    func applyOverrides(to settings: inout AppSettings) {
        guard configuration.isManaged else { return }

        enforcer.applyForcedPreferences(to: &settings, from: configuration)
        enforcer.applyDefaults(to: &settings, from: configuration)
    }

    /// Checks if a specific preference key is locked by MDM policy.
    ///
    /// - Parameter key: The preference key to check.
    /// - Returns: `true` if the key is forced by MDM and cannot be changed by the user.
    func isSettingLocked(_ key: ManagedPreferenceKey) -> Bool {
        forcedKeys.contains(key)
    }

    // MARK: - Monitoring

    /// Starts observing for MDM profile changes.
    ///
    /// When the MDM profile is updated, the configuration is re-read and
    /// overrides are re-applied to the current settings.
    func startMonitoring() {
        reader.startObserving()

        reader.configurationDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] config in
                self?.handleConfigurationChange(config)
            }
            .store(in: &cancellables)

        logger.info("MDM monitoring started")
    }

    /// Stops observing for MDM profile changes.
    func stopMonitoring() {
        cancellables.removeAll()
        reader.stopObserving()
        logger.info("MDM monitoring stopped")
    }

    // MARK: - Enterprise Key Access

    /// Returns the organization ID from MDM configuration, if set.
    ///
    /// This is always read regardless of license tier since it's used for
    /// license activation.
    var organizationID: String? {
        if case .string(let id) = configuration.effectiveValue(for: .organizationID) {
            return id
        }
        return nil
    }

    /// Returns the license server URL from MDM configuration, if set.
    var licenseServer: String? {
        if case .string(let url) = configuration.effectiveValue(for: .licenseServer) {
            return url
        }
        return nil
    }

    // MARK: - Private Helpers

    /// Updates internal state from a new configuration.
    private func updateState(with config: MDMConfiguration) {
        configuration = config
        isManaged = config.isManaged
        forcedKeys = enforcer.lockedSettings(from: config)
    }

    /// Handles a configuration change from the observer.
    private func handleConfigurationChange(_ config: MDMConfiguration) {
        updateState(with: config)
        logger.info("MDM configuration updated: \(self.forcedKeys.count) forced keys")
    }
}
