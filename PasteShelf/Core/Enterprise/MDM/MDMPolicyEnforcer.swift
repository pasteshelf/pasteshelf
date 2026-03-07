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

        // MARK: Appearance
        case .theme:
            if case .string(let themeName) = value,
               let theme = AppTheme(rawValue: themeName) {
                settings.appearance.theme = theme
            }

        // MARK: Security
        case .clearOnQuit:
            if case .bool(let enabled) = value {
                settings.security.clearOnQuit = enabled
            }

        case .requireBiometricAuth:
            if case .bool(let enabled) = value {
                settings.security.requireBiometricAuth = enabled
            }

        case .autoLockTimeout:
            if case .int(let seconds) = value, seconds >= 0 {
                settings.security.autoLockTimeout = seconds
            }

        // MARK: Enterprise — sync, storage, plugins
        case .cloudSyncEnabled:
            if case .bool(let enabled) = value {
                settings.enterprise.cloudSyncEnabled = enabled
            }

        case .localStorageOnly:
            if case .bool(let enabled) = value {
                settings.enterprise.localStorageOnly = enabled
            }

        case .pluginsEnabled:
            if case .bool(let enabled) = value {
                settings.enterprise.pluginsEnabled = enabled
            }

        // MARK: Enterprise — keys handled by their respective managers
        // These are wired via AppDelegate.applyMDMEnterpriseKeys() and
        // do not map to AppSettings fields directly.
        case .organizationID:
            if case .string(let id) = value {
                logger.debug("MDM organizationID received: \(id)")
            }

        case .adminConsoleURL:
            if case .string(let url) = value {
                logger.debug("MDM adminConsoleURL received: \(url)")
            }

        case .ssoEnabled:
            if case .bool(let enabled) = value {
                logger.info("MDM SSO enabled: \(enabled)")
            }

        case .ssoProvider:
            if case .string(let provider) = value {
                logger.info("MDM SSO provider: \(provider)")
            }

        case .ssoDomain:
            if case .string(let domain) = value {
                logger.info("MDM SSO domain: \(domain)")
            }

        case .dlpEnabled:
            if case .bool(let enabled) = value {
                logger.info("MDM DLP enabled: \(enabled)")
            }

        case .blockCreditCards:
            if case .bool(let enabled) = value {
                logger.info("MDM block credit cards: \(enabled)")
            }

        case .blockAPIKeys:
            if case .bool(let enabled) = value {
                logger.info("MDM block API keys: \(enabled)")
            }

        // MARK: Compliance
        case .gdprEnabled:
            if case .bool(let enabled) = value {
                settings.enterprise.gdprEnabled = enabled
            }

        case .soc2Enabled:
            if case .bool(let enabled) = value {
                settings.enterprise.soc2Enabled = enabled
            }

        case .hipaaEnabled:
            if case .bool(let enabled) = value {
                settings.enterprise.hipaaEnabled = enabled
            }
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
