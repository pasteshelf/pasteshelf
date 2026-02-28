//
//  MDMPolicyEnforcer.swift
//  PasteShelf
//
//  Applies MDM-managed preference overrides to application settings.
//  Maps MDM keys to AppSettings fields and enforces forced/default values.
//

import Foundation
import os.log

// MARK: - MDMPolicyEnforcer

/// Applies MDM configuration overrides on top of user settings.
///
/// The enforcer bridges `MDMConfiguration` and `AppSettings` by mapping each
/// `ManagedPreferenceKey` to the corresponding settings field. Forced preferences
/// always override user values; default preferences are applied only when the user
/// has not explicitly customized them.
struct MDMPolicyEnforcer {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.pasteshelf", category: "mdm-enforcer")

    // MARK: - Public API

    /// Applies admin-forced preferences, overriding user values.
    ///
    /// Any setting with a corresponding forced MDM key will be set to the MDM value
    /// regardless of what the user has configured.
    ///
    /// - Parameters:
    ///   - settings: The application settings to mutate.
    ///   - config: The MDM configuration containing forced preferences.
    func applyForcedPreferences(to settings: inout AppSettings, from config: MDMConfiguration) {
        for (key, value) in config.forcedPreferences {
            apply(key: key, value: value, to: &settings)
        }

        if !config.forcedPreferences.isEmpty {
            logger.info("Applied \(config.forcedPreferences.count) forced MDM preferences")
        }
    }

    /// Applies admin-supplied default preferences for keys the user has not customized.
    ///
    /// If a key is present in `userCustomizedKeys`, the MDM default is skipped and the
    /// user's value is preserved.
    ///
    /// - Parameters:
    ///   - settings: The application settings to mutate.
    ///   - config: The MDM configuration containing default preferences.
    ///   - userCustomizedKeys: Keys the user has explicitly changed (should not be overridden).
    func applyDefaults(
        to settings: inout AppSettings,
        from config: MDMConfiguration,
        userCustomizedKeys: Set<ManagedPreferenceKey> = []
    ) {
        for (key, value) in config.defaultPreferences {
            guard !userCustomizedKeys.contains(key) else { continue }
            apply(key: key, value: value, to: &settings)
        }

        if !config.defaultPreferences.isEmpty {
            logger.debug("Applied MDM default preferences (skipped \(userCustomizedKeys.count) user-customized)")
        }
    }

    /// Returns the set of all forced preference keys from the configuration.
    ///
    /// Use this to determine which settings should be locked in the UI.
    func lockedSettings(from config: MDMConfiguration) -> Set<ManagedPreferenceKey> {
        Set(config.forcedPreferences.keys)
    }

    // MARK: - Private Mapping

    /// Maps a single MDM key/value pair to the corresponding `AppSettings` field.
    private func apply(key: ManagedPreferenceKey, value: PreferenceValue, to settings: inout AppSettings) {
        switch key {
        // MARK: Privacy / History
        case .maxHistoryDays:
            if case .int(let days) = value, days > 0 {
                settings.privacy.autoDeleteEnabled = true
                settings.privacy.autoDeleteDays = days
            }

        case .maxHistoryItems:
            if case .int(let items) = value {
                settings.general.historyLimit = closestHistoryLimit(to: items)
            }

        case .excludePrivateBrowsing:
            if case .bool(let enabled) = value {
                settings.privacy.excludePrivateBrowsing = enabled
            }

        // MARK: Appearance
        case .theme:
            if case .string(let themeName) = value,
               let theme = AppTheme(rawValue: themeName) {
                settings.appearance.theme = theme
            }

        // MARK: Security (stored in privacy for now)
        case .clearOnQuit:
            // Note: clearOnQuit is not yet in AppSettings — will be a no-op
            // until the setting is added in a future iteration
            logger.debug("MDM key 'ClearOnQuit' received but not yet mapped to settings")

        case .requireBiometricAuth:
            // Note: biometric auth is not yet in AppSettings — will be a no-op
            logger.debug("MDM key 'RequireBiometricAuth' received but not yet mapped to settings")

        case .autoLockTimeout:
            // Note: auto-lock timeout is not yet in AppSettings — will be a no-op
            logger.debug("MDM key 'AutoLockTimeout' received but not yet mapped to settings")

        // MARK: Enterprise / SSO / DLP / Sync / Plugins
        // These keys are handled by their respective managers (SSOManager,
        // DLPManager, etc.) and do not map directly to AppSettings fields.
        case .organizationID,
             .adminConsoleURL,
             .ssoEnabled,
             .ssoProvider,
             .ssoDomain,
             .cloudSyncEnabled,
             .localStorageOnly,
             .pluginsEnabled,
             .dlpEnabled,
             .blockCreditCards,
             .blockAPIKeys:
            break
        }
    }

    /// Maps an integer item count to the closest `HistoryLimit` enum case.
    private func closestHistoryLimit(to items: Int) -> HistoryLimit {
        if items <= 0 { return .unlimited }
        if items <= 100 { return .small }
        if items <= 500 { return .medium }
        if items <= 1000 { return .large }
        return .unlimited
    }
}
