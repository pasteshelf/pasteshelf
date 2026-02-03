//
//  AppSettings.swift
//  PasteShelf
//
//  Root settings container that aggregates all application settings.
//  Provides unified persistence via UserDefaults with Codable support.
//

import Foundation

/// Root container for all application settings
struct AppSettings: Codable, Equatable {
    // MARK: - Settings Sections

    /// General application settings
    var general: GeneralSettings

    /// Privacy and security settings
    var privacy: PrivacySettings

    /// Appearance and UI settings
    var appearance: AppearanceSettings

    /// Shortcuts and hotkey settings
    var shortcuts: ShortcutsSettings

    // MARK: - Initialization

    init(
        general: GeneralSettings = .default,
        privacy: PrivacySettings = .default,
        appearance: AppearanceSettings = .default,
        shortcuts: ShortcutsSettings = .default
    ) {
        self.general = general
        self.privacy = privacy
        self.appearance = appearance
        self.shortcuts = shortcuts
    }

    // MARK: - Default Configuration

    /// Default application settings
    static let `default` = AppSettings()

    // MARK: - Persistence

    private static let userDefaultsKey = "com.pasteshelf.settings"

    /// Saves settings to UserDefaults
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.userDefaultsKey)
        }
    }

    /// Loads settings from UserDefaults, or returns default
    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return .default
        }
        return settings
    }

    /// Resets all settings to defaults
    static func reset() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
