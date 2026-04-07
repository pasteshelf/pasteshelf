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

// MARK: - SettingsManager

/// Central manager for application settings
@MainActor
final class SettingsManager: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    private init() {
        self.settings = AppSettings.load()
        self.applyMDMOverridesIfNeeded()
        self.logger.info("Settings loaded")
    }

    // MARK: Internal

    // MARK: - Singleton

    /// Shared settings manager instance
    static let shared = SettingsManager()

    // MARK: - Published Properties

    /// Current application settings
    @Published private(set) var settings: AppSettings {
        didSet {
            guard !self.isApplyingMDM else {
                return
            }
            self.reapplyMDMForcedValues()
            self.settings.save()
            self.notifySettingsChanged()
        }
    }

    // MARK: - Settings Access

    /// General settings
    var general: GeneralSettings {
        get { self.settings.general }
        set {
            self.settings.general = newValue
            self.logger.debug("General settings updated")
        }
    }

    /// Privacy settings
    var privacy: PrivacySettings {
        get { self.settings.privacy }
        set {
            self.settings.privacy = newValue
            self.logger.debug("Privacy settings updated")
        }
    }

    /// Appearance settings
    var appearance: AppearanceSettings {
        get { self.settings.appearance }
        set {
            self.settings.appearance = newValue
            self.logger.debug("Appearance settings updated")
        }
    }

    /// Shortcuts settings
    var shortcuts: ShortcutsSettings {
        get { self.settings.shortcuts }
        set {
            self.settings.shortcuts = newValue
            self.logger.debug("Shortcuts settings updated")
        }
    }

    /// Search settings
    var search: SearchSettings {
        get { self.settings.search }
        set {
            self.settings.search = newValue
            self.logger.debug("Search settings updated")
        }
    }

    /// Enterprise settings (sync, storage, plugins)
    var enterprise: EnterpriseSettings {
        get { self.settings.enterprise }
        set {
            self.settings.enterprise = newValue
            self.logger.debug("Enterprise settings updated")
        }
    }

    /// Security settings (biometric auth, auto-lock, clear on quit)
    var security: SecuritySettings {
        get { self.settings.security }
        set {
            self.settings.security = newValue
            self.logger.debug("Security settings updated")
        }
    }

    // MARK: - Methods

    /// Updates a specific setting using a closure
    func update(_ block: (inout AppSettings) -> Void) {
        var newSettings = self.settings
        block(&newSettings)
        self.settings = newSettings
    }

    /// Saves new settings (replacing current)
    func save(_ newSettings: AppSettings) {
        self.settings = newSettings
        self.logger.debug("Settings saved")
    }

    /// Resets all settings to defaults
    func resetToDefaults() {
        AppSettings.reset()
        self.settings = .default
        self.logger.info("Settings reset to defaults")
    }

    // MARK: - MDM Integration

    /// Applies MDM overrides on top of loaded settings.
    ///
    /// Called during init and whenever the MDM profile changes mid-session.
    func applyMDMOverridesIfNeeded() {
        let mdm = MDMManager.shared
        mdm.loadConfiguration()
        guard mdm.isManaged else {
            return
        }

        self.isApplyingMDM = true
        defer { isApplyingMDM = false }

        mdm.applyOverrides(to: &self.settings)
        self.settings.save()
        self.notifySettingsChanged()
        self.logger.info("MDM overrides applied")
    }

    /// Checks if a specific preference key is locked by MDM policy.
    ///
    /// - Parameter key: The preference key to check.
    /// - Returns: `true` if the setting is managed and cannot be changed by the user.
    func isLocked(_ key: ManagedPreferenceKey) -> Bool {
        MDMManager.shared.isSettingLocked(key)
    }

    // MARK: Private

    // MARK: - Private Properties

    /// Logger for settings operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "settings"
    )

    /// Guard against recursive didSet when applying MDM overrides
    private var isApplyingMDM = false

    /// Re-applies forced MDM values after a user change to prevent overriding locked settings.
    private func reapplyMDMForcedValues() {
        let mdm = MDMManager.shared
        guard mdm.isManaged, !mdm.forcedKeys.isEmpty else {
            return
        }

        var current = self.settings
        mdm.applyOverrides(to: &current)

        if current != self.settings {
            self.isApplyingMDM = true
            self.settings = current
            self.isApplyingMDM = false
        }
    }

    // MARK: - Notifications

    private func notifySettingsChanged() {
        NotificationCenter.default.post(name: .settingsDidChange, object: self.settings)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when any settings change
    static let settingsDidChange = Notification.Name("com.pasteshelf.settingsDidChange")
}
