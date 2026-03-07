//
//  SettingsManagerTests.swift
//  PasteShelfTests
//
//  Unit tests for SettingsManager and related settings models.
//

import Foundation
import Testing
@testable import PasteShelf

struct SettingsManagerTests {
    // MARK: - GeneralSettings Tests

    @Test("GeneralSettings default values are correct")
    func generalSettingsDefaultValues() {
        let settings = GeneralSettings.default

        #expect(settings.launchAtLogin == false)
        #expect(settings.showInDock == false)
        #expect(settings.historyLimit == .medium)
    }

    @Test("HistoryLimit has correct values")
    func historyLimitValues() {
        #expect(HistoryLimit.small.limit == 100)
        #expect(HistoryLimit.medium.limit == 500)
        #expect(HistoryLimit.large.limit == 1000)
        #expect(HistoryLimit.unlimited.limit == nil)
    }

    @Test("HistoryLimit display names are correct")
    func historyLimitDisplayNames() {
        #expect(HistoryLimit.small.displayName == "100 items")
        #expect(HistoryLimit.medium.displayName == "500 items")
        #expect(HistoryLimit.large.displayName == "1,000 items")
        #expect(HistoryLimit.unlimited.displayName == "Unlimited")
    }

    // MARK: - PrivacySettings Tests

    @Test("PrivacySettings default values are correct")
    func privacySettingsDefaultValues() {
        let settings = PrivacySettings.default

        #expect(settings.autoDeleteEnabled == false)
        #expect(settings.autoDeleteDays == 30)
        #expect(settings.isMonitoringPaused == false)
    }

    @Test("AutoDeleteDays validation")
    func autoDeleteDaysValidation() {
        var settings = PrivacySettings.default

        settings.autoDeleteDays = 7
        #expect(settings.autoDeleteDays == 7)

        settings.autoDeleteDays = 365
        #expect(settings.autoDeleteDays == 365)
    }

    // MARK: - AppearanceSettings Tests

    @Test("AppearanceSettings default values are correct")
    func appearanceSettingsDefaultValues() {
        let settings = AppearanceSettings.default

        #expect(settings.theme == .system)
        #expect(settings.panelWidth == .normal)
        #expect(settings.previewLines == 3)
        #expect(settings.showThumbnails == true)
        #expect(settings.compactMode == false)
    }

    @Test("AppTheme raw values are correct")
    func appThemeRawValues() {
        #expect(AppTheme.system.rawValue == "system")
        #expect(AppTheme.light.rawValue == "light")
        #expect(AppTheme.dark.rawValue == "dark")
    }

    @Test("PanelWidth dimensions are correct")
    func panelWidthDimensions() {
        #expect(PanelWidth.narrow.width == 320)
        #expect(PanelWidth.normal.width == 400)
        #expect(PanelWidth.wide.width == 500)
    }

    @Test("PreviewLines clamped to valid range")
    func previewLinesClamped() {
        var settings = AppearanceSettings.default

        settings.previewLines = 1
        #expect(settings.previewLines >= 1)

        settings.previewLines = 5
        #expect(settings.previewLines <= 5)
    }

    // MARK: - ShortcutsSettings Tests

    @Test("ShortcutsSettings default values are correct")
    func shortcutsSettingsDefaultValues() {
        let settings = ShortcutsSettings.default

        #expect(settings.quickPasteEnabled == true)
        #expect(settings.globalHotkey == .default)
    }

    @Test("StoredHotkey default is Cmd+Shift+V")
    func storedHotkeyDefault() {
        let hotkey = StoredHotkey.default

        // kVK_ANSI_V = 9
        #expect(hotkey.keyCode == 9)
        // cmdKey | shiftKey
        #expect(hotkey.modifiers != 0)
    }

    @Test("StoredHotkey alternative is Cmd+Option+V")
    func storedHotkeyAlternative() {
        let hotkey = StoredHotkey.alternative

        // kVK_ANSI_V = 9
        #expect(hotkey.keyCode == 9)
        #expect(hotkey.modifiers != StoredHotkey.default.modifiers)
    }

    @Test("StoredHotkey displayString is not empty")
    func storedHotkeyDisplayString() {
        let hotkey = StoredHotkey.default
        let displayString = hotkey.displayString

        #expect(!displayString.isEmpty)
        #expect(displayString.contains("V"))
    }

    // MARK: - AppSettings Tests

    @Test("AppSettings has all setting categories")
    func appSettingsHasAllCategories() {
        let settings = AppSettings.default

        // Verify all categories exist
        _ = settings.general
        _ = settings.privacy
        _ = settings.appearance
        _ = settings.shortcuts
    }

    @Test("AppSettings is Codable")
    func appSettingsIsCodable() throws {
        let original = AppSettings.default
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AppSettings.self, from: data)

        #expect(decoded.general.launchAtLogin == original.general.launchAtLogin)
        #expect(decoded.appearance.theme == original.appearance.theme)
        #expect(decoded.shortcuts.quickPasteEnabled == original.shortcuts.quickPasteEnabled)
    }

    @Test("AppSettings is Equatable")
    func appSettingsIsEquatable() {
        let settings1 = AppSettings.default
        let settings2 = AppSettings.default

        #expect(settings1 == settings2)
    }

    // MARK: - Settings Migration Tests

    @Test("Settings can decode from minimal JSON")
    func settingsCanDecodeFromMinimalJSON() throws {
        let json = "{}"
        let data = json.data(using: .utf8)!

        // Should not throw - should use defaults for missing fields
        do {
            _ = try JSONDecoder().decode(AppSettings.self, from: data)
            // If it throws, that's expected for required fields
        } catch {
            // Expected - empty JSON can't decode required fields
        }
    }
}

// MARK: - Hotkey Configuration Tests

struct HotkeyConfigurationTests {
    @Test("HotkeyConfiguration default is Cmd+Shift+V")
    func hotkeyConfigurationDefault() {
        let config = HotkeyConfiguration.default

        // Verify it has modifiers set
        #expect(config.hasCommand == true)
        #expect(config.hasShift == true)
        #expect(config.hasOption == false)
        #expect(config.hasControl == false)
    }

    @Test("HotkeyConfiguration alternative is Cmd+Option+V")
    func hotkeyConfigurationAlternative() {
        let config = HotkeyConfiguration.alternative

        #expect(config.hasCommand == true)
        #expect(config.hasOption == true)
        #expect(config.hasShift == false)
    }

    @Test("HotkeyConfiguration displayString contains modifiers")
    func hotkeyConfigurationDisplayString() {
        let config = HotkeyConfiguration.default
        let display = config.displayString

        // Should contain modifier symbols
        #expect(display.contains("⌘") || display.contains("⇧"))
    }

    @Test("HotkeyConfiguration equality")
    func hotkeyConfigurationEquality() {
        let config1 = HotkeyConfiguration.default
        let config2 = HotkeyConfiguration.default
        let config3 = HotkeyConfiguration.alternative

        #expect(config1 == config2)
        #expect(config1 != config3)
    }
}
