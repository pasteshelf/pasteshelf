//
//  MDMConfiguration.swift
//  PasteShelf
//
//  Model representing the active MDM-managed configuration for the application,
//  distinguishing between admin-locked (forced) and admin-defaulted preferences.
//

import Foundation

// MARK: - MDMConfiguration

/// The resolved MDM configuration for the current device.
///
/// An MDM administrator can push two kinds of preferences via Apple's Managed
/// App Config (AppConfig) standard:
///
/// - **Forced preferences** — values the user cannot change.  These come from
///   the `forcedPreferences` dictionary and always take precedence.
/// - **Default preferences** — values that pre-populate settings but can be
///   overridden by the user.  These come from `defaultPreferences`.
///
/// Use `effectiveValue(for:)` to retrieve the right value for any key without
/// having to check both dictionaries manually.
struct MDMConfiguration: Equatable {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates an MDM configuration with explicit forced and default preference maps.
    ///
    /// - Parameters:
    ///   - forcedPreferences: Admin-locked key/value pairs.
    ///   - defaultPreferences: Admin-defaulted key/value pairs.
    init(
        forcedPreferences: [ManagedPreferenceKey: PreferenceValue] = [:],
        defaultPreferences: [ManagedPreferenceKey: PreferenceValue] = [:]
    ) {
        self.forcedPreferences = forcedPreferences
        self.defaultPreferences = defaultPreferences
    }

    // MARK: Internal

    // MARK: - Empty Sentinel

    /// An MDMConfiguration with no preferences — represents an unmanaged device.
    static let empty = MDMConfiguration(forcedPreferences: [:], defaultPreferences: [:])

    /// Admin-locked settings that users cannot change.
    ///
    /// Typically sourced from the `forcedPreferences` key inside a
    /// `com.apple.configuration.managed` payload.
    let forcedPreferences: [ManagedPreferenceKey: PreferenceValue]

    /// Admin-supplied default settings that users may override.
    ///
    /// Typically sourced from the `defaultPreferences` key inside a
    /// `com.apple.configuration.managed` payload.
    let defaultPreferences: [ManagedPreferenceKey: PreferenceValue]

    /// `true` when at least one forced or default preference has been set by an MDM administrator.
    ///
    /// Use this to show or hide the "Managed by your organization" notice in the UI.
    var isManaged: Bool {
        !self.forcedPreferences.isEmpty || !self.defaultPreferences.isEmpty
    }

    // MARK: - Query Methods

    /// Returns `true` if the given key is admin-locked and cannot be changed by the user.
    ///
    /// - Parameter key: The preference key to check.
    func isForced(_ key: ManagedPreferenceKey) -> Bool {
        self.forcedPreferences[key] != nil
    }

    /// Returns the effective value for a preference key, giving forced preferences
    /// priority over default preferences.
    ///
    /// Returns `nil` if the key is present in neither dictionary.
    ///
    /// - Parameter key: The preference key to look up.
    func effectiveValue(for key: ManagedPreferenceKey) -> PreferenceValue? {
        self.forcedPreferences[key] ?? self.defaultPreferences[key]
    }
}
