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
    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        general: GeneralSettings = .default,
        privacy: PrivacySettings = .default,
        appearance: AppearanceSettings = .default,
        shortcuts: ShortcutsSettings = .default,
        search: SearchSettings = .default,
        enterprise: EnterpriseSettings = .default,
        security: SecuritySettings = .default
    ) {
        self.general = general
        self.privacy = privacy
        self.appearance = appearance
        self.shortcuts = shortcuts
        self.search = search
        self.enterprise = enterprise
        self.security = security
    }

    // MARK: - Codable Migration

    /// Custom decoder to handle missing keys when new settings sections are added
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        general = try container.decode(GeneralSettings.self, forKey: .general)
        privacy = try container.decode(PrivacySettings.self, forKey: .privacy)
        appearance = try container.decode(AppearanceSettings.self, forKey: .appearance)
        shortcuts = try container.decode(ShortcutsSettings.self, forKey: .shortcuts)
        search = try container.decodeIfPresent(SearchSettings.self, forKey: .search) ?? .default
        enterprise = try container.decodeIfPresent(EnterpriseSettings.self, forKey: .enterprise) ?? .default
        security = try container.decodeIfPresent(SecuritySettings.self, forKey: .security) ?? .default
    }

    // MARK: Internal

    // MARK: - Default Configuration

    /// Default application settings
    static let `default` = AppSettings()

    // MARK: - Settings Sections

    /// General application settings
    var general: GeneralSettings

    /// Privacy and security settings
    var privacy: PrivacySettings

    /// Appearance and UI settings
    var appearance: AppearanceSettings

    /// Shortcuts and hotkey settings
    var shortcuts: ShortcutsSettings

    /// Search settings (semantic search, OCR)
    var search: SearchSettings

    /// Enterprise settings (sync, storage, plugins) — typically MDM-managed
    var enterprise: EnterpriseSettings

    /// Security settings (biometric auth, auto-lock, clear on quit) — typically MDM-managed
    var security: SecuritySettings

    /// Loads settings from UserDefaults, or returns default
    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              var settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return .default
        }

        // Migrate legacy search settings from raw UserDefaults keys
        settings.migrateSearchSettingsIfNeeded()

        return settings
    }

    /// Resets all settings to defaults
    static func reset() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    /// Saves settings to UserDefaults
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.userDefaultsKey)
        }
    }

    // MARK: Private

    // MARK: - Persistence

    private static let userDefaultsKey = "com.pasteshelf.settings"

    /// Migrates search settings from legacy raw UserDefaults keys to the new SearchSettings struct
    private mutating func migrateSearchSettingsIfNeeded() {
        let defaults = UserDefaults.standard
        let migrationKey = "com.pasteshelf.searchSettingsMigrated"

        guard !defaults.bool(forKey: migrationKey) else {
            return
        }

        if defaults.object(forKey: "semanticSearchEnabled") != nil {
            search.semanticSearchEnabled = defaults.bool(forKey: "semanticSearchEnabled")
        }
        let threshold = defaults.double(forKey: "semanticThreshold")
        if threshold > 0 {
            search.semanticThreshold = threshold
        }
        if defaults.object(forKey: "ocrSearchEnabled") != nil {
            search.ocrSearchEnabled = defaults.bool(forKey: "ocrSearchEnabled")
        }
        let ocrThreshold = defaults.double(forKey: "ocrConfidenceThreshold")
        if ocrThreshold > 0 {
            search.ocrConfidenceThreshold = ocrThreshold
        }

        // Clean up legacy keys and mark migration as done
        defaults.removeObject(forKey: "semanticSearchEnabled")
        defaults.removeObject(forKey: "semanticThreshold")
        defaults.removeObject(forKey: "ocrSearchEnabled")
        defaults.removeObject(forKey: "ocrConfidenceThreshold")
        defaults.set(true, forKey: migrationKey)
    }
}
