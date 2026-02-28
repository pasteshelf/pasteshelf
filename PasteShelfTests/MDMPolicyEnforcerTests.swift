//
//  MDMPolicyEnforcerTests.swift
//  PasteShelfTests
//
//  Tests for MDMPolicyEnforcer: forced/default preference mapping to AppSettings.
//

import Foundation
import Testing
@testable import PasteShelf

// MARK: - MDMPolicyEnforcerTests

struct MDMPolicyEnforcerTests {

    // MARK: - maxHistoryDays

    @Test("applyForcedPreferences enables auto-delete and sets days for maxHistoryDays")
    func applyForcedMaxHistoryDays() {
        var settings = AppSettings.default
        let config = MDMConfiguration(forcedPreferences: [.maxHistoryDays: .int(30)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.privacy.autoDeleteEnabled == true)
        #expect(settings.privacy.autoDeleteDays == 30)
    }

    @Test("applyForcedPreferences with 90 days enables auto-delete and sets correct days")
    func applyForcedMaxHistoryDays90() {
        var settings = AppSettings.default
        let config = MDMConfiguration(forcedPreferences: [.maxHistoryDays: .int(90)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.privacy.autoDeleteEnabled == true)
        #expect(settings.privacy.autoDeleteDays == 90)
    }

    @Test("applyForcedPreferences ignores maxHistoryDays of 0")
    func applyForcedMaxHistoryDaysZeroIgnored() {
        var settings = AppSettings.default
        let originalAutoDelete = settings.privacy.autoDeleteEnabled
        let config = MDMConfiguration(forcedPreferences: [.maxHistoryDays: .int(0)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        // Days <= 0 should not enable auto-delete
        #expect(settings.privacy.autoDeleteEnabled == originalAutoDelete)
    }

    @Test("applyForcedPreferences ignores maxHistoryDays with negative value")
    func applyForcedMaxHistoryDaysNegativeIgnored() {
        var settings = AppSettings.default
        let originalAutoDelete = settings.privacy.autoDeleteEnabled
        let config = MDMConfiguration(forcedPreferences: [.maxHistoryDays: .int(-1)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.privacy.autoDeleteEnabled == originalAutoDelete)
    }

    @Test("applyForcedPreferences ignores maxHistoryDays with wrong type")
    func applyForcedMaxHistoryDaysWrongType() {
        var settings = AppSettings.default
        let original = settings
        let config = MDMConfiguration(forcedPreferences: [.maxHistoryDays: .string("30")])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings == original)
    }

    // MARK: - maxHistoryItems → HistoryLimit Mapping

    @Test("applyForcedPreferences maps maxHistoryItems <= 100 to .small")
    func applyForcedMaxHistoryItems100MapsToSmall() {
        var settings = AppSettings.default
        let config = MDMConfiguration(forcedPreferences: [.maxHistoryItems: .int(100)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.general.historyLimit == .small)
    }

    @Test("applyForcedPreferences maps maxHistoryItems of 1 to .small")
    func applyForcedMaxHistoryItems1MapsToSmall() {
        var settings = AppSettings.default
        let config = MDMConfiguration(forcedPreferences: [.maxHistoryItems: .int(1)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.general.historyLimit == .small)
    }

    @Test("applyForcedPreferences maps maxHistoryItems <= 500 to .medium")
    func applyForcedMaxHistoryItems500MapsToMedium() {
        var settings = AppSettings.default
        let config = MDMConfiguration(forcedPreferences: [.maxHistoryItems: .int(500)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.general.historyLimit == .medium)
    }

    @Test("applyForcedPreferences maps maxHistoryItems of 101 to .medium")
    func applyForcedMaxHistoryItems101MapsToMedium() {
        var settings = AppSettings.default
        let config = MDMConfiguration(forcedPreferences: [.maxHistoryItems: .int(101)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.general.historyLimit == .medium)
    }

    @Test("applyForcedPreferences maps maxHistoryItems <= 1000 to .large")
    func applyForcedMaxHistoryItems1000MapsToLarge() {
        var settings = AppSettings.default
        let config = MDMConfiguration(forcedPreferences: [.maxHistoryItems: .int(1000)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.general.historyLimit == .large)
    }

    @Test("applyForcedPreferences maps maxHistoryItems of 501 to .large")
    func applyForcedMaxHistoryItems501MapsToLarge() {
        var settings = AppSettings.default
        let config = MDMConfiguration(forcedPreferences: [.maxHistoryItems: .int(501)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.general.historyLimit == .large)
    }

    @Test("applyForcedPreferences maps maxHistoryItems > 1000 to .unlimited")
    func applyForcedMaxHistoryItems5000MapsToUnlimited() {
        var settings = AppSettings.default
        let config = MDMConfiguration(forcedPreferences: [.maxHistoryItems: .int(5000)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.general.historyLimit == .unlimited)
    }

    @Test("applyForcedPreferences maps maxHistoryItems of 0 to .unlimited")
    func applyForcedMaxHistoryItemsZeroMapsToUnlimited() {
        var settings = AppSettings.default
        let config = MDMConfiguration(forcedPreferences: [.maxHistoryItems: .int(0)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.general.historyLimit == .unlimited)
    }

    @Test("applyForcedPreferences maps negative maxHistoryItems to .unlimited")
    func applyForcedMaxHistoryItemsNegativeMapsToUnlimited() {
        var settings = AppSettings.default
        let config = MDMConfiguration(forcedPreferences: [.maxHistoryItems: .int(-10)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.general.historyLimit == .unlimited)
    }

    // MARK: - excludePrivateBrowsing

    @Test("applyForcedPreferences sets excludePrivateBrowsing to true")
    func applyForcedExcludePrivateBrowsingTrue() {
        var settings = AppSettings.default
        settings.privacy.excludePrivateBrowsing = false
        let config = MDMConfiguration(forcedPreferences: [.excludePrivateBrowsing: .bool(true)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.privacy.excludePrivateBrowsing == true)
    }

    @Test("applyForcedPreferences sets excludePrivateBrowsing to false")
    func applyForcedExcludePrivateBrowsingFalse() {
        var settings = AppSettings.default
        settings.privacy.excludePrivateBrowsing = true
        let config = MDMConfiguration(forcedPreferences: [.excludePrivateBrowsing: .bool(false)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.privacy.excludePrivateBrowsing == false)
    }

    @Test("applyForcedPreferences ignores excludePrivateBrowsing with wrong type")
    func applyForcedExcludePrivateBrowsingWrongType() {
        var settings = AppSettings.default
        settings.privacy.excludePrivateBrowsing = false
        let config = MDMConfiguration(forcedPreferences: [.excludePrivateBrowsing: .string("true")])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.privacy.excludePrivateBrowsing == false)
    }

    // MARK: - Theme

    @Test("applyForcedPreferences sets theme to dark")
    func applyForcedThemeDark() {
        var settings = AppSettings.default
        let config = MDMConfiguration(forcedPreferences: [.theme: .string("dark")])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.appearance.theme == .dark)
    }

    @Test("applyForcedPreferences sets theme to light")
    func applyForcedThemeLight() {
        var settings = AppSettings.default
        let config = MDMConfiguration(forcedPreferences: [.theme: .string("light")])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.appearance.theme == .light)
    }

    @Test("applyForcedPreferences sets theme to system")
    func applyForcedThemeSystem() {
        var settings = AppSettings.default
        settings.appearance.theme = .dark
        let config = MDMConfiguration(forcedPreferences: [.theme: .string("system")])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.appearance.theme == .system)
    }

    @Test("applyForcedPreferences ignores invalid theme string")
    func applyForcedThemeInvalidString() {
        var settings = AppSettings.default
        let originalTheme = settings.appearance.theme
        let config = MDMConfiguration(forcedPreferences: [.theme: .string("neon")])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.appearance.theme == originalTheme)
    }

    @Test("applyForcedPreferences ignores theme with wrong type (int)")
    func applyForcedThemeWrongType() {
        var settings = AppSettings.default
        let originalTheme = settings.appearance.theme
        let config = MDMConfiguration(forcedPreferences: [.theme: .int(42)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.appearance.theme == originalTheme)
    }

    @Test("applyForcedPreferences ignores theme with wrong type (bool)")
    func applyForcedThemeWrongTypeBool() {
        var settings = AppSettings.default
        let originalTheme = settings.appearance.theme
        let config = MDMConfiguration(forcedPreferences: [.theme: .bool(true)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.appearance.theme == originalTheme)
    }

    // MARK: - Multiple Forced Preferences

    @Test("applyForcedPreferences applies multiple keys simultaneously")
    func applyMultipleForcedPreferences() {
        var settings = AppSettings.default
        let config = MDMConfiguration(forcedPreferences: [
            .theme: .string("dark"),
            .excludePrivateBrowsing: .bool(true),
            .maxHistoryDays: .int(90)
        ])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings.appearance.theme == .dark)
        #expect(settings.privacy.excludePrivateBrowsing == true)
        #expect(settings.privacy.autoDeleteEnabled == true)
        #expect(settings.privacy.autoDeleteDays == 90)
    }

    @Test("applyForcedPreferences with empty config changes nothing")
    func applyForcedEmptyConfigChangesNothing() {
        var settings = AppSettings.default
        let original = settings
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: .empty)

        #expect(settings == original)
    }

    // MARK: - Default Preferences

    @Test("applyDefaults applies value when key is not user-customized")
    func applyDefaultsWhenNotCustomized() {
        var settings = AppSettings.default
        settings.privacy.excludePrivateBrowsing = false
        let config = MDMConfiguration(defaultPreferences: [.excludePrivateBrowsing: .bool(true)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyDefaults(to: &settings, from: config, userCustomizedKeys: [])

        #expect(settings.privacy.excludePrivateBrowsing == true)
    }

    @Test("applyDefaults skips value when key is user-customized")
    func applyDefaultsDoesNotOverrideUserCustomizedKey() {
        var settings = AppSettings.default
        settings.privacy.excludePrivateBrowsing = false
        let config = MDMConfiguration(defaultPreferences: [.excludePrivateBrowsing: .bool(true)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyDefaults(
            to: &settings,
            from: config,
            userCustomizedKeys: [.excludePrivateBrowsing]
        )

        #expect(settings.privacy.excludePrivateBrowsing == false)
    }

    @Test("applyDefaults applies non-customized keys and skips customized keys")
    func applyDefaultsMixedCustomization() {
        var settings = AppSettings.default
        settings.privacy.excludePrivateBrowsing = false
        let config = MDMConfiguration(defaultPreferences: [
            .excludePrivateBrowsing: .bool(true),
            .theme: .string("dark")
        ])
        let enforcer = MDMPolicyEnforcer()

        // Only excludePrivateBrowsing is user-customized; theme is not
        enforcer.applyDefaults(
            to: &settings,
            from: config,
            userCustomizedKeys: [.excludePrivateBrowsing]
        )

        #expect(settings.privacy.excludePrivateBrowsing == false)
        #expect(settings.appearance.theme == .dark)
    }

    @Test("applyDefaults with empty config changes nothing")
    func applyDefaultsEmptyConfigChangesNothing() {
        var settings = AppSettings.default
        let original = settings
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyDefaults(to: &settings, from: .empty, userCustomizedKeys: [])

        #expect(settings == original)
    }

    @Test("applyDefaults default parameter for userCustomizedKeys is empty set")
    func applyDefaultsDefaultUserCustomizedKeysIsEmpty() {
        var settings = AppSettings.default
        let config = MDMConfiguration(defaultPreferences: [.theme: .string("dark")])
        let enforcer = MDMPolicyEnforcer()

        // Call without userCustomizedKeys — defaults to []
        enforcer.applyDefaults(to: &settings, from: config)

        #expect(settings.appearance.theme == .dark)
    }

    // MARK: - lockedSettings

    @Test("lockedSettings returns all forced keys")
    func lockedSettingsReturnsForcedKeys() {
        let config = MDMConfiguration(
            forcedPreferences: [.theme: .string("dark"), .maxHistoryItems: .int(100)],
            defaultPreferences: [.excludePrivateBrowsing: .bool(true)]
        )
        let enforcer = MDMPolicyEnforcer()

        let locked = enforcer.lockedSettings(from: config)

        #expect(locked.contains(.theme))
        #expect(locked.contains(.maxHistoryItems))
        #expect(locked.count == 2)
    }

    @Test("lockedSettings does not include default-only keys")
    func lockedSettingsExcludesDefaultKeys() {
        let config = MDMConfiguration(
            forcedPreferences: [.theme: .string("dark")],
            defaultPreferences: [.excludePrivateBrowsing: .bool(true)]
        )
        let enforcer = MDMPolicyEnforcer()

        let locked = enforcer.lockedSettings(from: config)

        #expect(!locked.contains(.excludePrivateBrowsing))
    }

    @Test("lockedSettings returns empty set for empty config")
    func lockedSettingsEmptyForEmptyConfig() {
        let enforcer = MDMPolicyEnforcer()
        let locked = enforcer.lockedSettings(from: .empty)
        #expect(locked.isEmpty)
    }

    @Test("lockedSettings returns empty set when only default preferences exist")
    func lockedSettingsEmptyWhenOnlyDefaults() {
        let config = MDMConfiguration(
            defaultPreferences: [.theme: .string("dark"), .maxHistoryItems: .int(100)]
        )
        let enforcer = MDMPolicyEnforcer()

        let locked = enforcer.lockedSettings(from: config)

        #expect(locked.isEmpty)
    }

    // MARK: - Enterprise / No-op Keys

    @Test("applyForcedPreferences treats licenseServer as no-op for AppSettings")
    func enterpriseLicenseServerIsNoOp() {
        var settings = AppSettings.default
        let original = settings
        let config = MDMConfiguration(forcedPreferences: [.licenseServer: .string("https://license.acme.com")])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings == original)
    }

    @Test("applyForcedPreferences treats organizationID as no-op for AppSettings")
    func enterpriseOrganizationIDIsNoOp() {
        var settings = AppSettings.default
        let original = settings
        let config = MDMConfiguration(forcedPreferences: [.organizationID: .string("org-123")])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings == original)
    }

    @Test("applyForcedPreferences treats ssoEnabled as no-op for AppSettings")
    func enterpriseSSOEnabledIsNoOp() {
        var settings = AppSettings.default
        let original = settings
        let config = MDMConfiguration(forcedPreferences: [.ssoEnabled: .bool(true)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings == original)
    }

    @Test("applyForcedPreferences treats cloudSyncEnabled as no-op for AppSettings")
    func enterpriseCloudSyncEnabledIsNoOp() {
        var settings = AppSettings.default
        let original = settings
        let config = MDMConfiguration(forcedPreferences: [.cloudSyncEnabled: .bool(true)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings == original)
    }

    @Test("applyForcedPreferences treats dlpEnabled as no-op for AppSettings")
    func enterpriseDLPEnabledIsNoOp() {
        var settings = AppSettings.default
        let original = settings
        let config = MDMConfiguration(forcedPreferences: [.dlpEnabled: .bool(true)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings == original)
    }

    @Test("applyForcedPreferences treats all enterprise keys as no-op")
    func allEnterpriseKeysAreNoOp() {
        var settings = AppSettings.default
        let original = settings
        let config = MDMConfiguration(forcedPreferences: [
            .licenseServer: .string("https://license.acme.com"),
            .organizationID: .string("org-123"),
            .ssoEnabled: .bool(true),
            .ssoProvider: .string("okta"),
            .ssoDomain: .string("acme.com"),
            .cloudSyncEnabled: .bool(true),
            .localStorageOnly: .bool(false),
            .pluginsEnabled: .bool(true),
            .dlpEnabled: .bool(true),
            .blockCreditCards: .bool(true),
            .blockAPIKeys: .bool(true)
        ])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings == original)
    }

    // MARK: - Security No-op Keys

    @Test("applyForcedPreferences treats clearOnQuit as no-op for AppSettings")
    func securityClearOnQuitIsNoOp() {
        var settings = AppSettings.default
        let original = settings
        let config = MDMConfiguration(forcedPreferences: [.clearOnQuit: .bool(true)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings == original)
    }

    @Test("applyForcedPreferences treats requireBiometricAuth as no-op for AppSettings")
    func securityRequireBiometricAuthIsNoOp() {
        var settings = AppSettings.default
        let original = settings
        let config = MDMConfiguration(forcedPreferences: [.requireBiometricAuth: .bool(true)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings == original)
    }

    @Test("applyForcedPreferences treats autoLockTimeout as no-op for AppSettings")
    func securityAutoLockTimeoutIsNoOp() {
        var settings = AppSettings.default
        let original = settings
        let config = MDMConfiguration(forcedPreferences: [.autoLockTimeout: .int(300)])
        let enforcer = MDMPolicyEnforcer()

        enforcer.applyForcedPreferences(to: &settings, from: config)

        #expect(settings == original)
    }
}
