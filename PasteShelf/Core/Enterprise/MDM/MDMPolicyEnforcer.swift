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
    // MARK: Internal

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
            guard !userCustomizedKeys.contains(key) else {
                continue
            }
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

    // MARK: Private

    private let logger = Logger(subsystem: "com.pasteshelf", category: "mdm-enforcer")

    // MARK: - Private Mapping

    /// Maps a single MDM key/value pair to the corresponding `AppSettings` field.
    private func apply(key: ManagedPreferenceKey, value: PreferenceValue, to settings: inout AppSettings) {
        switch key {
        case .maxHistoryDays,
             .maxHistoryItems,
             .theme:
            applyPrivacyAndAppearance(key: key, value: value, to: &settings)

        case .clearOnQuit,
             .requireBiometricAuth,
             .autoLockTimeout:
            applySecurityPreference(key: key, value: value, to: &settings)

        case .cloudSyncEnabled,
             .localStorageOnly,
             .pluginsEnabled:
            applyEnterprisePreference(key: key, value: value, to: &settings)

        case .organizationID,
             .adminConsoleURL,
             .ssoEnabled,
             .ssoProvider,
             .ssoDomain,
             .dlpEnabled,
             .blockCreditCards,
             .blockAPIKeys:
            logDelegatedPreference(key: key, value: value)

        case .gdprEnabled,
             .soc2Enabled,
             .hipaaEnabled:
            applyCompliancePreference(key: key, value: value, to: &settings)
        }
    }

    /// Applies privacy and appearance MDM preferences.
    private func applyPrivacyAndAppearance(
        key: ManagedPreferenceKey,
        value: PreferenceValue,
        to settings: inout AppSettings
    ) {
        switch key {
        case .maxHistoryDays:
            if case let .int(days) = value, days > 0 {
                settings.privacy.autoDeleteEnabled = true
                settings.privacy.autoDeleteDays = days
            }
        case .maxHistoryItems:
            if case let .int(items) = value {
                settings.general.historyLimit = closestHistoryLimit(to: items)
            }
        case .theme:
            if case let .string(themeName) = value,
               let theme = AppTheme(rawValue: themeName)
            {
                settings.appearance.theme = theme
            }
        default:
            break
        }
    }

    /// Applies security-related MDM preferences.
    private func applySecurityPreference(
        key: ManagedPreferenceKey,
        value: PreferenceValue,
        to settings: inout AppSettings
    ) {
        switch key {
        case .clearOnQuit:
            if case let .bool(enabled) = value {
                settings.security.clearOnQuit = enabled
            }
        case .requireBiometricAuth:
            if case let .bool(enabled) = value {
                settings.security.requireBiometricAuth = enabled
            }
        case .autoLockTimeout:
            if case let .int(seconds) = value, seconds >= 0 {
                settings.security.autoLockTimeout = seconds
            }
        default:
            break
        }
    }

    /// Applies enterprise sync/storage/plugin MDM preferences.
    private func applyEnterprisePreference(
        key: ManagedPreferenceKey,
        value: PreferenceValue,
        to settings: inout AppSettings
    ) {
        switch key {
        case .cloudSyncEnabled:
            if case let .bool(enabled) = value {
                settings.enterprise.cloudSyncEnabled = enabled
            }
        case .localStorageOnly:
            if case let .bool(enabled) = value {
                settings.enterprise.localStorageOnly = enabled
            }
        case .pluginsEnabled:
            if case let .bool(enabled) = value {
                settings.enterprise.pluginsEnabled = enabled
            }
        default:
            break
        }
    }

    /// Logs MDM keys that are handled by their respective managers rather than AppSettings.
    private func logDelegatedPreference(key: ManagedPreferenceKey, value: PreferenceValue) {
        logDelegatedStringPreference(key: key, value: value)
        logDelegatedBoolPreference(key: key, value: value)
    }

    /// Logs string-valued delegated MDM preferences.
    private func logDelegatedStringPreference(key: ManagedPreferenceKey, value: PreferenceValue) {
        guard case let .string(strValue) = value else {
            return
        }
        switch key {
        case .organizationID:
            logger.debug("MDM organizationID received: \(strValue)")
        case .adminConsoleURL:
            logger.debug("MDM adminConsoleURL received: \(strValue)")
        case .ssoProvider:
            logger.info("MDM SSO provider: \(strValue)")
        case .ssoDomain:
            logger.info("MDM SSO domain: \(strValue)")
        default:
            break
        }
    }

    /// Logs boolean-valued delegated MDM preferences.
    private func logDelegatedBoolPreference(key: ManagedPreferenceKey, value: PreferenceValue) {
        guard case let .bool(boolValue) = value else {
            return
        }
        switch key {
        case .ssoEnabled:
            logger.info("MDM SSO enabled: \(boolValue)")
        case .dlpEnabled:
            logger.info("MDM DLP enabled: \(boolValue)")
        case .blockCreditCards:
            logger.info("MDM block credit cards: \(boolValue)")
        case .blockAPIKeys:
            logger.info("MDM block API keys: \(boolValue)")
        default:
            break
        }
    }

    /// Applies compliance-related MDM preferences.
    private func applyCompliancePreference(
        key: ManagedPreferenceKey,
        value: PreferenceValue,
        to settings: inout AppSettings
    ) {
        switch key {
        case .gdprEnabled:
            if case let .bool(enabled) = value {
                settings.enterprise.gdprEnabled = enabled
            }
        case .soc2Enabled:
            if case let .bool(enabled) = value {
                settings.enterprise.soc2Enabled = enabled
            }
        case .hipaaEnabled:
            if case let .bool(enabled) = value {
                settings.enterprise.hipaaEnabled = enabled
            }
        default:
            break
        }
    }

    /// Maps an integer item count to the closest `HistoryLimit` enum case.
    private func closestHistoryLimit(to items: Int) -> HistoryLimit {
        if items <= 0 {
            return .unlimited
        }
        if items <= 100 {
            return .small
        }
        if items <= 500 {
            return .medium
        }
        if items <= 1000 {
            return .large
        }
        return .unlimited
    }
}
