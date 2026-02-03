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

    // MARK: - Initialization

    private init() {
        settings = AppSettings.load()
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

    // MARK: - Methods

    /// Updates a specific setting using a closure
    func update(_ block: (inout AppSettings) -> Void) {
        var newSettings = settings
        block(&newSettings)
        settings = newSettings
    }

    /// Resets all settings to defaults
    func resetToDefaults() {
        AppSettings.reset()
        settings = .default
        logger.info("Settings reset to defaults")
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
