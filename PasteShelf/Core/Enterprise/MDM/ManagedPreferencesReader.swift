//
//  ManagedPreferencesReader.swift
//  PasteShelf
//
//  Reads MDM-managed preferences from the macOS managed preferences domain.
//  Detects forced vs. default keys and observes profile changes.
//

import Combine
import Foundation
import os.log

// MARK: - ManagedPreferencesReader

/// Reads managed preferences from the macOS `UserDefaults` managed domain.
///
/// When an MDM server pushes a configuration profile with `PayloadType`
/// matching `com.pasteshelf.PasteShelf`, macOS surfaces those values through
/// `UserDefaults`. This reader detects which keys are forced (locked) via
/// `objectIsForced(forKey:)` and which are admin defaults.
///
/// Supports two payload formats:
/// - **Flat keys**: Each key at the top level of the preference domain
/// - **Nested dictionaries**: `ManagedPreferences` and `DefaultPreferences` dicts
final class ManagedPreferencesReader: ManagedPreferencesReading, MDMConfigurationObserving {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates a reader for the specified preference domain.
    ///
    /// - Parameters:
    ///   - preferenceDomain: The application preference domain (default: `com.pasteshelf.PasteShelf`).
    ///   - userDefaults: The `UserDefaults` instance to read from (default: `.standard`).
    ///   - pollingInterval: Interval in seconds for fallback polling (default: 60).
    init(
        preferenceDomain: String = "com.pasteshelf.PasteShelf",
        userDefaults: UserDefaults = .standard,
        pollingInterval: TimeInterval = 60
    ) {
        self.preferenceDomain = preferenceDomain
        self.userDefaults = userDefaults
        self.pollingInterval = pollingInterval
    }

    deinit {
        stopObserving()
    }

    // MARK: Internal

    // MARK: - MDMConfigurationObserving

    var configurationDidChange: AnyPublisher<MDMConfiguration, Never> {
        configurationSubject.eraseToAnyPublisher()
    }

    // MARK: - ManagedPreferencesReading

    func readConfiguration() -> MDMConfiguration {
        var forced: [ManagedPreferenceKey: PreferenceValue] = [:]
        var defaults: [ManagedPreferenceKey: PreferenceValue] = [:]

        // Strategy 1: Check flat keys via objectIsForced
        readFlatForcedKeys(into: &forced)

        // Strategy 2: Check nested ManagedPreferences / DefaultPreferences dicts
        readNestedManagedKeys(into: &forced)
        readNestedDefaultKeys(into: &defaults)

        // Strategy 3: Non-forced flat keys that exist become defaults
        readFlatDefaultKeys(forced: forced, into: &defaults)

        let config = MDMConfiguration(
            forcedPreferences: forced,
            defaultPreferences: defaults
        )

        if config.isManaged {
            logger.info("MDM configuration loaded: \(forced.count) forced, \(defaults.count) default keys")
        }

        return config
    }

    func isKeyForced(_ key: ManagedPreferenceKey) -> Bool {
        // Check flat key forced status
        if userDefaults.objectIsForced(forKey: key.rawValue) {
            return true
        }

        // Check nested ManagedPreferences dict
        if let managedDict = userDefaults.dictionary(forKey: "ManagedPreferences"),
           managedDict[key.rawValue] != nil
        {
            return true
        }

        return false
    }

    func value<T>(for key: ManagedPreferenceKey) -> T? {
        // Try flat key first
        if let value = userDefaults.object(forKey: key.rawValue) as? T {
            return value
        }

        // Try nested ManagedPreferences
        if let managedDict = userDefaults.dictionary(forKey: "ManagedPreferences"),
           let value = managedDict[key.rawValue] as? T
        {
            return value
        }

        // Try nested DefaultPreferences
        if let defaultDict = userDefaults.dictionary(forKey: "DefaultPreferences"),
           let value = defaultDict[key.rawValue] as? T
        {
            return value
        }

        return nil
    }

    func startObserving() {
        guard !isObserving else {
            return
        }
        isObserving = true

        // Read initial configuration
        lastConfiguration = readConfiguration()
        configurationSubject.send(lastConfiguration)

        // Observe UserDefaults changes via DistributedNotificationCenter
        notificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkForConfigurationChanges()
        }

        // Fallback polling timer (MDM profile changes don't always trigger notifications)
        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: pollingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkForConfigurationChanges()
        }

        logger.debug("MDM observation started (polling interval: \(pollingInterval)s)")
    }

    func stopObserving() {
        guard isObserving else {
            return
        }
        isObserving = false

        if let observer = notificationObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            notificationObserver = nil
        }

        pollingTimer?.invalidate()
        pollingTimer = nil

        logger.debug("MDM observation stopped")
    }

    // MARK: Private

    /// The preference domain to read from
    private let preferenceDomain: String

    /// UserDefaults instance for reading preferences
    private let userDefaults: UserDefaults

    /// Logger for MDM operations
    private let logger = Logger(subsystem: "com.pasteshelf", category: "mdm")

    /// Subject backing the configuration change publisher
    private let configurationSubject = CurrentValueSubject<MDMConfiguration, Never>(.empty)

    /// Timer for periodic polling of profile changes
    private var pollingTimer: Timer?

    /// Notification observer token
    private var notificationObserver: NSObjectProtocol?

    /// Whether observation is currently active
    private var isObserving = false

    /// Polling interval for checking profile changes (seconds)
    private let pollingInterval: TimeInterval

    /// Last known configuration for change detection
    private var lastConfiguration: MDMConfiguration = .empty

    // MARK: - Private Helpers

    /// Reads flat forced keys from UserDefaults.
    private func readFlatForcedKeys(into forced: inout [ManagedPreferenceKey: PreferenceValue]) {
        for key in ManagedPreferenceKey.allCases where userDefaults.objectIsForced(forKey: key.rawValue) {
            if let value = readPreferenceValue(for: key) {
                forced[key] = value
            }
        }
    }

    /// Reads nested ManagedPreferences dictionary keys into forced preferences.
    private func readNestedManagedKeys(into forced: inout [ManagedPreferenceKey: PreferenceValue]) {
        guard let managedDict = userDefaults.dictionary(forKey: "ManagedPreferences") else {
            return
        }
        for key in ManagedPreferenceKey.allCases where forced[key] == nil {
            if let rawValue = managedDict[key.rawValue],
               let value = convertToPreferenceValue(rawValue)
            {
                forced[key] = value
            }
        }
    }

    /// Reads nested DefaultPreferences dictionary keys into default preferences.
    private func readNestedDefaultKeys(into defaults: inout [ManagedPreferenceKey: PreferenceValue]) {
        guard let defaultDict = userDefaults.dictionary(forKey: "DefaultPreferences") else {
            return
        }
        for key in ManagedPreferenceKey.allCases {
            if let rawValue = defaultDict[key.rawValue],
               let value = convertToPreferenceValue(rawValue)
            {
                defaults[key] = value
            }
        }
    }

    /// Reads non-forced flat keys that exist as default preferences.
    private func readFlatDefaultKeys(
        forced: [ManagedPreferenceKey: PreferenceValue],
        into defaults: inout [ManagedPreferenceKey: PreferenceValue]
    ) {
        for key in ManagedPreferenceKey.allCases where forced[key] == nil && defaults[key] == nil {
            if userDefaults.object(forKey: key.rawValue) != nil,
               !userDefaults.objectIsForced(forKey: key.rawValue),
               let value = readPreferenceValue(for: key)
            {
                defaults[key] = value
            }
        }
    }

    /// Reads a single preference value from flat UserDefaults keys.
    private func readPreferenceValue(for key: ManagedPreferenceKey) -> PreferenceValue? {
        guard let raw = userDefaults.object(forKey: key.rawValue) else {
            return nil
        }
        return convertToPreferenceValue(raw)
    }

    /// Converts a raw plist value to a typed `PreferenceValue`.
    private func convertToPreferenceValue(_ raw: Any) -> PreferenceValue? {
        switch raw {
        case let boolValue as Bool:
            return .bool(boolValue)
        case let intValue as Int:
            return .int(intValue)
        case let stringValue as String:
            return .string(stringValue)
        case let nsNumber as NSNumber:
            // NSNumber can represent booleans or integers
            if CFGetTypeID(nsNumber) == CFBooleanGetTypeID() {
                return .bool(nsNumber.boolValue)
            }
            return .int(nsNumber.intValue)
        default:
            logger.warning("Unsupported MDM preference value type: \(type(of: raw))")
            return nil
        }
    }

    /// Checks if the MDM configuration has changed since the last read.
    private func checkForConfigurationChanges() {
        let newConfig = readConfiguration()
        if newConfig != lastConfiguration {
            lastConfiguration = newConfig
            configurationSubject.send(newConfig)
            logger.info("MDM configuration changed")
        }
    }
}
