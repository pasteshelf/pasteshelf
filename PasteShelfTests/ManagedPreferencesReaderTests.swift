//
//  ManagedPreferencesReaderTests.swift
//  PasteShelfTests
//
//  Tests for ManagedPreferencesReader using a test-scoped UserDefaults suite.
//

import Combine
import Foundation
@testable import PasteShelf
import Testing

// MARK: - ManagedPreferencesReaderTests

struct ManagedPreferencesReaderTests {
    // MARK: Internal

    // MARK: - Empty State

    @Test("readConfiguration returns empty config when no managed preferences exist")
    func emptyConfigurationWhenNoManagedPreferences() {
        let (reader, defaults, suiteName) = self.makeReader()
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let config = reader.readConfiguration()

        #expect(config.isManaged == false)
        #expect(config.forcedPreferences.isEmpty)
        #expect(config.defaultPreferences.isEmpty)
    }

    @Test("isKeyForced returns false when no preferences exist")
    func isKeyForcedReturnsFalseWhenEmpty() {
        let (reader, defaults, suiteName) = self.makeReader()
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        #expect(reader.isKeyForced(.theme) == false)
        #expect(reader.isKeyForced(.maxHistoryItems) == false)
    }

    // MARK: - Nested ManagedPreferences Dictionary

    @Test("readConfiguration reads string value from nested ManagedPreferences dict")
    func readsNestedManagedPreferencesStringValue() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(["Theme": "dark"], forKey: "ManagedPreferences")
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let config = reader.readConfiguration()

        #expect(config.isManaged == true)
        #expect(config.forcedPreferences[.theme] == .string("dark"))
    }

    @Test("readConfiguration reads integer value from nested ManagedPreferences dict")
    func readsNestedManagedPreferencesIntValue() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(["MaxHistoryItems": 100], forKey: "ManagedPreferences")
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let config = reader.readConfiguration()

        #expect(config.isManaged == true)
        #expect(config.forcedPreferences[.maxHistoryItems] == .int(100))
    }

    @Test("readConfiguration reads multiple keys from nested ManagedPreferences dict")
    func readsMultipleKeysFromNestedManagedPreferences() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(
                ["Theme": "dark", "MaxHistoryItems": 100],
                forKey: "ManagedPreferences"
            )
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let config = reader.readConfiguration()

        #expect(config.isManaged == true)
        #expect(config.forcedPreferences[.theme] == .string("dark"))
        #expect(config.forcedPreferences[.maxHistoryItems] == .int(100))
    }

    // MARK: - Nested DefaultPreferences Dictionary

    @Test("readConfiguration reads string value from nested DefaultPreferences dict")
    func readsNestedDefaultPreferencesStringValue() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(["Theme": "light"], forKey: "DefaultPreferences")
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let config = reader.readConfiguration()

        #expect(config.isManaged == true)
        #expect(config.defaultPreferences[.theme] == .string("light"))
    }

    @Test("readConfiguration reads boolean value from nested DefaultPreferences dict")
    func readsNestedDefaultPreferencesBoolValue() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(["DLPEnabled": true], forKey: "DefaultPreferences")
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let config = reader.readConfiguration()

        #expect(config.isManaged == true)
        #expect(config.defaultPreferences[.dlpEnabled] == .bool(true))
    }

    // MARK: - Forced vs Default Priority

    @Test("Forced ManagedPreferences take priority over DefaultPreferences for same key")
    func forcedTakesPriorityOverDefault() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(["Theme": "dark"], forKey: "ManagedPreferences")
            defaults.set(["Theme": "light"], forKey: "DefaultPreferences")
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let config = reader.readConfiguration()

        #expect(config.forcedPreferences[.theme] == .string("dark"))
    }

    // MARK: - isKeyForced with Nested Dict

    @Test("isKeyForced returns true for key present in nested ManagedPreferences")
    func isKeyForcedTrueForNestedManagedKey() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(["Theme": "dark"], forKey: "ManagedPreferences")
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        #expect(reader.isKeyForced(.theme) == true)
    }

    @Test("isKeyForced returns false for key present only in DefaultPreferences")
    func isKeyForcedFalseForDefaultOnlyKey() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(["Theme": "light"], forKey: "DefaultPreferences")
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        #expect(reader.isKeyForced(.theme) == false)
    }

    @Test("isKeyForced returns false for a key absent from both dicts")
    func isKeyForcedFalseForAbsentKey() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(["Theme": "dark"], forKey: "ManagedPreferences")
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        #expect(reader.isKeyForced(.maxHistoryItems) == false)
    }

    // MARK: - Boolean Preference Values

    @Test("readConfiguration reads boolean true from ManagedPreferences dict")
    func readsBooleanTrueFromManagedPreferences() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(["BlockCreditCards": true], forKey: "ManagedPreferences")
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let config = reader.readConfiguration()
        #expect(config.forcedPreferences[.blockCreditCards] == .bool(true))
    }

    @Test("readConfiguration reads boolean false from ManagedPreferences dict")
    func readsBooleanFalseFromManagedPreferences() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(["DLPEnabled": false], forKey: "ManagedPreferences")
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let config = reader.readConfiguration()
        #expect(config.forcedPreferences[.dlpEnabled] == .bool(false))
    }

    @Test("readConfiguration reads multiple boolean preferences correctly")
    func readsMultipleBooleanPreferences() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(
                ["BlockCreditCards": true, "DLPEnabled": false],
                forKey: "ManagedPreferences"
            )
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let config = reader.readConfiguration()
        #expect(config.forcedPreferences[.blockCreditCards] == .bool(true))
        #expect(config.forcedPreferences[.dlpEnabled] == .bool(false))
    }

    // MARK: - Integer Preference Values

    @Test("readConfiguration reads integer MaxHistoryDays from ManagedPreferences dict")
    func readsIntegerMaxHistoryDays() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(["MaxHistoryDays": 30], forKey: "ManagedPreferences")
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let config = reader.readConfiguration()
        #expect(config.forcedPreferences[.maxHistoryDays] == .int(30))
    }

    @Test("readConfiguration reads integer AutoLockTimeout from ManagedPreferences dict")
    func readsIntegerAutoLockTimeout() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(["AutoLockTimeout": 300], forKey: "ManagedPreferences")
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let config = reader.readConfiguration()
        #expect(config.forcedPreferences[.autoLockTimeout] == .int(300))
    }

    @Test("readConfiguration reads multiple integer preferences correctly")
    func readsMultipleIntegerPreferences() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(
                ["MaxHistoryDays": 30, "AutoLockTimeout": 300],
                forKey: "ManagedPreferences"
            )
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let config = reader.readConfiguration()
        #expect(config.forcedPreferences[.maxHistoryDays] == .int(30))
        #expect(config.forcedPreferences[.autoLockTimeout] == .int(300))
    }

    // MARK: - String Preference Values

    @Test("readConfiguration reads OrganizationID string from ManagedPreferences dict")
    func readsOrganizationID() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(["OrganizationID": "org-123"], forKey: "ManagedPreferences")
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let config = reader.readConfiguration()
        #expect(config.forcedPreferences[.organizationID] == .string("org-123"))
    }

    @Test("readConfiguration reads multiple string preferences correctly")
    func readsMultipleStringPreferences() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(
                ["OrganizationID": "org-123", "AdminConsoleURL": "https://admin.acme.com"],
                forKey: "ManagedPreferences"
            )
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let config = reader.readConfiguration()
        #expect(config.forcedPreferences[.organizationID] == .string("org-123"))
        #expect(config.forcedPreferences[.adminConsoleURL] == .string("https://admin.acme.com"))
    }

    // MARK: - value(for:) Generic Method

    @Test("value(for:) returns typed value from nested ManagedPreferences")
    func valueForKeyReturnsTypedStringValue() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(["Theme": "dark"], forKey: "ManagedPreferences")
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let value: String? = reader.value(for: .theme)
        #expect(value == "dark")
    }

    @Test("value(for:) returns typed integer value from nested ManagedPreferences")
    func valueForKeyReturnsTypedIntValue() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(["MaxHistoryItems": 500], forKey: "ManagedPreferences")
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let value: Int? = reader.value(for: .maxHistoryItems)
        #expect(value == 500)
    }

    @Test("value(for:) returns nil for absent key")
    func valueForKeyReturnsNilWhenAbsent() {
        let (reader, defaults, suiteName) = self.makeReader()
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let value: String? = reader.value(for: .theme)
        #expect(value == nil)
    }

    @Test("value(for:) returns typed value from nested DefaultPreferences when not in Managed")
    func valueForKeyReturnsFromDefaultPreferences() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(["Theme": "light"], forKey: "DefaultPreferences")
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let value: String? = reader.value(for: .theme)
        #expect(value == "light")
    }

    // MARK: - Mixed Forced + Default

    @Test("readConfiguration returns both forced and default keys from different dicts")
    func readConfigurationReturnsBothForcedAndDefault() {
        let (reader, defaults, suiteName) = self.makeReader { defaults in
            defaults.set(["Theme": "dark"], forKey: "ManagedPreferences")
            defaults.set(["DLPEnabled": true], forKey: "DefaultPreferences")
        }
        defer { cleanup(suiteName: suiteName, defaults: defaults) }

        let config = reader.readConfiguration()

        #expect(config.isManaged == true)
        #expect(config.forcedPreferences[.theme] == .string("dark"))
        #expect(config.defaultPreferences[.dlpEnabled] == .bool(true))
    }

    // MARK: Private

    // MARK: - Helpers

    // Creates a fresh reader backed by a volatile in-memory UserDefaults suite.
    // The returned suite name can be used to clean up after the test.
    // swiftlint:disable large_tuple
    private func makeReader(
        populateWith block: ((UserDefaults) -> Void)? = nil
    ) -> (reader: ManagedPreferencesReader, defaults: UserDefaults, suiteName: String) {
        // swiftlint:enable large_tuple
        let suiteName = "com.pasteshelf.test.mdm.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create UserDefaults suite: \(suiteName)")
        }
        defaults.removePersistentDomain(forName: suiteName)
        block?(defaults)
        let reader = ManagedPreferencesReader(
            preferenceDomain: "com.pasteshelf.test",
            userDefaults: defaults,
            pollingInterval: 999_999 // very long to avoid timer interference
        )
        return (reader, defaults, suiteName)
    }

    private func cleanup(suiteName: String, defaults: UserDefaults) {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
