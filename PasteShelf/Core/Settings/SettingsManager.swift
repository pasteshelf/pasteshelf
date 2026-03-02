//
//  SettingsManager.swift
//  PasteShelf
//
//  Central coordinator for application settings.
//  Provides ObservableObject interface for SwiftUI binding
//  and publishes changes for reactive updates.
//

import Combine
import Foundation
import os.log

/// Central manager for application settings
@MainActor
final class SettingsManager: ObservableObject {
    // MARK: - Singleton

    /// Shared settings manager instance
    static let shared = SettingsManager()

    // MARK: - Published Properties

    /// Current application settings
    @Published private(set) var settings: AppSettings {
        didSet {
            guard !isApplyingMDM else { return }
            reapplyMDMForcedValues()
            settings.save()
            notifySettingsChanged()
        }
    }

    // MARK: - Private Properties

    /// Logger for settings operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "settings"
    )

    /// Guard against recursive didSet when applying MDM overrides
    private var isApplyingMDM = false

    // MARK: - Initialization

    private init() {
        settings = AppSettings.load()
        applyMDMOverridesIfNeeded()
        logger.info("Settings loaded")
    }

    // MARK: - Settings Access

    /// General settings
    var general: GeneralSettings {
        get { settings.general }
        set {
            settings.general = newValue
            logger.debug("General settings updated")
        }
    }

    /// Privacy settings
    var privacy: PrivacySettings {
        get { settings.privacy }
        set {
            settings.privacy = newValue
            logger.debug("Privacy settings updated")
        }
    }

    /// Appearance settings
    var appearance: AppearanceSettings {
        get { settings.appearance }
        set {
            settings.appearance = newValue
            logger.debug("Appearance settings updated")
        }
    }

    /// Shortcuts settings
    var shortcuts: ShortcutsSettings {
        get { settings.shortcuts }
        set {
            settings.shortcuts = newValue
            logger.debug("Shortcuts settings updated")
        }
    }

    /// Search settings
    var search: SearchSettings {
        get { settings.search }
        set {
            settings.search = newValue
            logger.debug("Search settings updated")
        }
    }

    /// Enterprise settings (sync, storage, plugins)
    var enterprise: EnterpriseSettings {
        get { settings.enterprise }
        set {
            settings.enterprise = newValue
            logger.debug("Enterprise settings updated")
        }
    }

    /// Security settings (biometric auth, auto-lock, clear on quit)
    var security: SecuritySettings {
        get { settings.security }
        set {
            settings.security = newValue
            logger.debug("Security settings updated")
        }
    }

    // MARK: - Methods

    /// Updates a specific setting using a closure
    func update(_ block: (inout AppSettings) -> Void) {
        var newSettings = settings
        block(&newSettings)
        settings = newSettings
    }

    /// Saves new settings (replacing current)
    func save(_ newSettings: AppSettings) {
        settings = newSettings
        logger.debug("Settings saved")
    }

    /// Resets all settings to defaults
    func resetToDefaults() {
        AppSettings.reset()
        settings = .default
        logger.info("Settings reset to defaults")
    }

    // MARK: - MDM Integration

    /// Applies MDM overrides on top of loaded settings.
    ///
    /// Called during init and whenever the MDM profile changes mid-session.
    func applyMDMOverridesIfNeeded() {
        let mdm = MDMManager.shared
        mdm.loadConfiguration()
        guard mdm.isManaged else { return }

        isApplyingMDM = true
        defer { isApplyingMDM = false }

        mdm.applyOverrides(to: &settings)
        settings.save()
        logger.info("MDM overrides applied during initialization")
    }

    /// Re-applies forced MDM values after a user change to prevent overriding locked settings.
    private func reapplyMDMForcedValues() {
        let mdm = MDMManager.shared
        guard mdm.isManaged, !mdm.forcedKeys.isEmpty else { return }

        var current = settings
        mdm.applyOverrides(to: &current)

        if current != settings {
            isApplyingMDM = true
            settings = current
            isApplyingMDM = false
        }
    }

    /// Checks if a specific preference key is locked by MDM policy.
    ///
    /// - Parameter key: The preference key to check.
    /// - Returns: `true` if the setting is managed and cannot be changed by the user.
    func isLocked(_ key: ManagedPreferenceKey) -> Bool {
        return MDMManager.shared.isSettingLocked(key)
    }

    // MARK: - Notifications

    private func notifySettingsChanged() {
        NotificationCenter.default.post(name: .settingsDidChange, object: settings)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when any settings change
    static let settingsDidChange = Notification.Name("com.pasteshelf.settingsDidChange")
}
