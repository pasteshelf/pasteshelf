//
//  MDMConfigurationTests.swift
//  PasteShelfTests
//
//  Tests for MDM models: PreferenceValue, MDMConfiguration, and ManagedPreferenceKey.
//

import Foundation
@testable import PasteShelf
import Testing

// MARK: - PreferenceValueTests

struct PreferenceValueTests {
    // MARK: Bool Equality

    @Test("PreferenceValue bool true equals bool true")
    func preferenceValueBoolEqualityTrue() {
        let value1 = PreferenceValue.bool(true)
        let value2 = PreferenceValue.bool(true)
        #expect(value1 == value2)
    }

    @Test("PreferenceValue bool false equals bool false")
    func preferenceValueBoolEqualityFalse() {
        let value1 = PreferenceValue.bool(false)
        let value2 = PreferenceValue.bool(false)
        #expect(value1 == value2)
    }

    @Test("PreferenceValue bool true does not equal bool false")
    func preferenceValueBoolInequality() {
        #expect(PreferenceValue.bool(true) != PreferenceValue.bool(false))
    }

    // MARK: Int Equality

    @Test("PreferenceValue int equality for same values")
    func preferenceValueIntEquality() {
        let int42a = PreferenceValue.int(42)
        let int42b = PreferenceValue.int(42)
        #expect(int42a == int42b)
        let int0a = PreferenceValue.int(0)
        let int0b = PreferenceValue.int(0)
        #expect(int0a == int0b)
    }

    @Test("PreferenceValue int inequality for different values")
    func preferenceValueIntInequality() {
        #expect(PreferenceValue.int(42) != PreferenceValue.int(43))
    }

    // MARK: String Equality

    @Test("PreferenceValue string equality for same values")
    func preferenceValueStringEquality() {
        let darkA = PreferenceValue.string("dark")
        let darkB = PreferenceValue.string("dark")
        #expect(darkA == darkB)
        let emptyA = PreferenceValue.string("")
        let emptyB = PreferenceValue.string("")
        #expect(emptyA == emptyB)
    }

    @Test("PreferenceValue string inequality for different values")
    func preferenceValueStringInequality() {
        #expect(PreferenceValue.string("dark") != PreferenceValue.string("light"))
    }

    // MARK: Cross-Type Inequality

    @Test("PreferenceValue bool true does not equal int 1")
    func preferenceValueCrossTypeBoolInt() {
        #expect(PreferenceValue.bool(true) != PreferenceValue.int(1))
    }

    @Test("PreferenceValue int does not equal string with same numeral")
    func preferenceValueCrossTypeIntString() {
        #expect(PreferenceValue.int(42) != PreferenceValue.string("42"))
    }

    @Test("PreferenceValue bool does not equal string")
    func preferenceValueCrossTypeBoolString() {
        #expect(PreferenceValue.bool(true) != PreferenceValue.string("true"))
    }

    // MARK: Display Values

    @Test("PreferenceValue bool displayValue is 'true' for true")
    func preferenceValueDisplayValueBoolTrue() {
        #expect(PreferenceValue.bool(true).displayValue == "true")
    }

    @Test("PreferenceValue bool displayValue is 'false' for false")
    func preferenceValueDisplayValueBoolFalse() {
        #expect(PreferenceValue.bool(false).displayValue == "false")
    }

    @Test("PreferenceValue int displayValue is string representation")
    func preferenceValueDisplayValueInt() {
        #expect(PreferenceValue.int(42).displayValue == "42")
        #expect(PreferenceValue.int(0).displayValue == "0")
        #expect(PreferenceValue.int(-1).displayValue == "-1")
    }

    @Test("PreferenceValue string displayValue returns the string itself")
    func preferenceValueDisplayValueString() {
        #expect(PreferenceValue.string("dark").displayValue == "dark")
        #expect(PreferenceValue.string("").displayValue.isEmpty)
        #expect(PreferenceValue.string("https://license.acme.com").displayValue == "https://license.acme.com")
    }
}

// MARK: - MDMConfigurationTests

struct MDMConfigurationTests {
    // MARK: Empty Configuration

    @Test("MDMConfiguration.empty has no preferences and isManaged is false")
    func emptyConfiguration() {
        let config = MDMConfiguration.empty
        #expect(config.isManaged == false)
        #expect(config.forcedPreferences.isEmpty)
        #expect(config.defaultPreferences.isEmpty)
    }

    // MARK: isManaged

    @Test("MDMConfiguration with forced preferences isManaged is true")
    func isManagedWithForcedPreferences() {
        let config = MDMConfiguration(forcedPreferences: [.theme: .string("dark")])
        #expect(config.isManaged == true)
    }

    @Test("MDMConfiguration with default preferences isManaged is true")
    func isManagedWithDefaultPreferences() {
        let config = MDMConfiguration(defaultPreferences: [.theme: .string("dark")])
        #expect(config.isManaged == true)
    }

    @Test("MDMConfiguration with both forced and default preferences isManaged is true")
    func isManagedWithBothPreferences() {
        let config = MDMConfiguration(
            forcedPreferences: [.theme: .string("dark")],
            defaultPreferences: [.maxHistoryItems: .int(500)]
        )
        #expect(config.isManaged == true)
    }

    // MARK: isForced

    @Test("isForced returns true for a forced key")
    func isForcedForForcedKey() {
        let config = MDMConfiguration(
            forcedPreferences: [.theme: .string("dark")],
            defaultPreferences: [.maxHistoryItems: .int(500)]
        )
        #expect(config.isForced(.theme) == true)
    }

    @Test("isForced returns false for a default-only key")
    func isForcedForDefaultKey() {
        let config = MDMConfiguration(
            forcedPreferences: [.theme: .string("dark")],
            defaultPreferences: [.maxHistoryItems: .int(500)]
        )
        #expect(config.isForced(.maxHistoryItems) == false)
    }

    @Test("isForced returns false for an absent key")
    func isForcedForAbsentKey() {
        let config = MDMConfiguration(
            forcedPreferences: [.theme: .string("dark")],
            defaultPreferences: [.maxHistoryItems: .int(500)]
        )
        #expect(config.isForced(.clearOnQuit) == false)
    }

    // MARK: effectiveValue Priority

    @Test("effectiveValue returns forced value when key is forced")
    func effectiveValueReturnsForcedValue() {
        let config = MDMConfiguration(
            forcedPreferences: [.theme: .string("dark")],
            defaultPreferences: [.theme: .string("light"), .maxHistoryItems: .int(500)]
        )
        #expect(config.effectiveValue(for: .theme) == .string("dark"))
    }

    @Test("effectiveValue returns default value when key is default-only")
    func effectiveValueReturnsDefaultValue() {
        let config = MDMConfiguration(
            forcedPreferences: [.theme: .string("dark")],
            defaultPreferences: [.maxHistoryItems: .int(500)]
        )
        #expect(config.effectiveValue(for: .maxHistoryItems) == .int(500))
    }

    @Test("effectiveValue returns nil for absent key")
    func effectiveValueReturnsNilForAbsentKey() {
        let config = MDMConfiguration(
            forcedPreferences: [.theme: .string("dark")],
            defaultPreferences: [.maxHistoryItems: .int(500)]
        )
        #expect(config.effectiveValue(for: .clearOnQuit) == nil)
    }

    @Test("effectiveValue forced takes priority over default for same key")
    func effectiveValueForcedPriorityOverDefault() {
        let config = MDMConfiguration(
            forcedPreferences: [.dlpEnabled: .bool(true)],
            defaultPreferences: [.dlpEnabled: .bool(false)]
        )
        #expect(config.effectiveValue(for: .dlpEnabled) == .bool(true))
    }

    // MARK: Equality

    @Test("MDMConfiguration equality for identical configs")
    func configurationEquality() {
        let config1 = MDMConfiguration(forcedPreferences: [.theme: .string("dark")])
        let config2 = MDMConfiguration(forcedPreferences: [.theme: .string("dark")])
        #expect(config1 == config2)
    }

    @Test("MDMConfiguration inequality for different forced values")
    func configurationInequalityForcedValues() {
        let config1 = MDMConfiguration(forcedPreferences: [.theme: .string("dark")])
        let config2 = MDMConfiguration(forcedPreferences: [.theme: .string("light")])
        #expect(config1 != config2)
    }

    @Test("MDMConfiguration inequality when one has extra keys")
    func configurationInequalityExtraKeys() {
        let config1 = MDMConfiguration(forcedPreferences: [.theme: .string("dark")])
        let config2 = MDMConfiguration(forcedPreferences: [
            .theme: .string("dark"),
            .maxHistoryItems: .int(100),
        ])
        #expect(config1 != config2)
    }

    @Test("MDMConfiguration inequality between forced and default for same key/value")
    func configurationInequalityForcedVsDefault() {
        let config1 = MDMConfiguration(forcedPreferences: [.theme: .string("dark")])
        let config2 = MDMConfiguration(defaultPreferences: [.theme: .string("dark")])
        #expect(config1 != config2)
    }
}

// MARK: - ManagedPreferenceKeyTests

struct ManagedPreferenceKeyTests {
    @Test("All ManagedPreferenceKey cases have non-empty display names")
    func allKeysHaveDisplayNames() {
        for key in ManagedPreferenceKey.allCases {
            #expect(!key.displayName.isEmpty, "Key \(key) should have a non-empty display name")
        }
    }

    @Test("All ManagedPreferenceKey cases return a settingsGroup without crashing")
    func allKeysHaveSettingsGroup() {
        for key in ManagedPreferenceKey.allCases {
            _ = key.settingsGroup
        }
    }

    @Test("Theme key belongs to appearance group")
    func themeKeyBelongsToAppearanceGroup() {
        #expect(ManagedPreferenceKey.theme.settingsGroup == .appearance)
    }

    @Test("SSO keys belong to enterprise group")
    func ssoKeysBelongToEnterpriseGroup() {
        #expect(ManagedPreferenceKey.ssoEnabled.settingsGroup == .enterprise)
        #expect(ManagedPreferenceKey.ssoProvider.settingsGroup == .enterprise)
        #expect(ManagedPreferenceKey.ssoDomain.settingsGroup == .enterprise)
    }

    @Test("Organization ID key belongs to enterprise group")
    func organizationIDKeyBelongsToEnterpriseGroup() {
        #expect(ManagedPreferenceKey.organizationID.settingsGroup == .enterprise)
    }

    @Test("Privacy keys belong to privacy group")
    func privacyKeysBelongToPrivacyGroup() {
        #expect(ManagedPreferenceKey.maxHistoryDays.settingsGroup == .privacy)
        #expect(ManagedPreferenceKey.maxHistoryItems.settingsGroup == .privacy)
        #expect(ManagedPreferenceKey.dlpEnabled.settingsGroup == .privacy)
    }

    @Test("Security keys belong to security group")
    func securityKeysBelongToSecurityGroup() {
        #expect(ManagedPreferenceKey.requireBiometricAuth.settingsGroup == .security)
        #expect(ManagedPreferenceKey.autoLockTimeout.settingsGroup == .security)
        #expect(ManagedPreferenceKey.clearOnQuit.settingsGroup == .security)
    }

    @Test("ManagedPreferenceKey raw values match plist key strings")
    func keyRawValues() {
        #expect(ManagedPreferenceKey.theme.rawValue == "Theme")
        #expect(ManagedPreferenceKey.maxHistoryItems.rawValue == "MaxHistoryItems")
        #expect(ManagedPreferenceKey.maxHistoryDays.rawValue == "MaxHistoryDays")
        #expect(ManagedPreferenceKey.ssoEnabled.rawValue == "SSOEnabled")
        #expect(ManagedPreferenceKey.organizationID.rawValue == "OrganizationID")
        #expect(ManagedPreferenceKey.dlpEnabled.rawValue == "DLPEnabled")
        #expect(ManagedPreferenceKey.autoLockTimeout.rawValue == "AutoLockTimeout")
        #expect(ManagedPreferenceKey.clearOnQuit.rawValue == "ClearOnQuit")
    }

    @Test("SettingsGroup display names are not empty")
    func settingsGroupDisplayNames() {
        #expect(!ManagedPreferenceKey.SettingsGroup.general.displayName.isEmpty)
        #expect(!ManagedPreferenceKey.SettingsGroup.privacy.displayName.isEmpty)
        #expect(!ManagedPreferenceKey.SettingsGroup.appearance.displayName.isEmpty)
        #expect(!ManagedPreferenceKey.SettingsGroup.security.displayName.isEmpty)
        #expect(!ManagedPreferenceKey.SettingsGroup.enterprise.displayName.isEmpty)
    }
}
