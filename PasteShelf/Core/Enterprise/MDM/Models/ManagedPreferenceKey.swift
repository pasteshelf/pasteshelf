//
//  ManagedPreferenceKey.swift
//  PasteShelf
//
//  Defines all recognized MDM preference keys and type-safe preference values
//  used when reading managed configuration from an MDM profile payload.
//

import Foundation

// MARK: - ManagedPreferenceKey

/// All preference keys that PasteShelf recognizes from an MDM-managed
/// `com.apple.configuration.managed` payload (AppConfig / Managed App Config).
///
/// Raw values match the plist keys documented in the Enterprise Deployment Guide
/// so that `UserDefaults(suiteName: "com.apple.configuration.managed")` look-ups
/// work without any transformation.
enum ManagedPreferenceKey: String, CaseIterable, Sendable {

    // MARK: Enterprise

    /// Unique identifier for the managing organization
    case organizationID = "OrganizationID"

    /// URL of the organization's enterprise admin console
    case adminConsoleURL = "AdminConsoleURL"

    // MARK: SSO

    /// Whether Single Sign-On is enabled for the organization
    case ssoEnabled = "SSOEnabled"

    /// Identity provider type (e.g. "okta", "azure", "google")
    case ssoProvider = "SSOProvider"

    /// Corporate domain used for SSO (e.g. "acme.com")
    case ssoDomain = "SSODomain"

    // MARK: Storage & Sync

    /// Whether iCloud / cloud sync is enabled
    case cloudSyncEnabled = "CloudSyncEnabled"

    /// When true, data must remain on the local device only
    case localStorageOnly = "LocalStorageOnly"

    // MARK: Plugins

    /// Whether the plugin system is enabled
    case pluginsEnabled = "PluginsEnabled"

    // MARK: Security

    /// Whether biometric (Touch ID / Face ID) authentication is required
    case requireBiometricAuth = "RequireBiometricAuth"

    /// Idle timeout in seconds before the app auto-locks (0 = disabled)
    case autoLockTimeout = "AutoLockTimeout"

    /// Whether clipboard history is cleared when the app quits
    case clearOnQuit = "ClearOnQuit"

    // MARK: History Limits

    /// Maximum number of days to retain clipboard history
    case maxHistoryDays = "MaxHistoryDays"

    /// Maximum number of items to retain in clipboard history
    case maxHistoryItems = "MaxHistoryItems"

    // MARK: Privacy

    /// Whether clipboard content from private-browsing windows is excluded
    case excludePrivateBrowsing = "ExcludePrivateBrowsing"

    // MARK: DLP (Data Loss Prevention)

    /// Whether Data Loss Prevention scanning is enabled
    case dlpEnabled = "DLPEnabled"

    /// Whether credit card numbers are blocked from being stored
    case blockCreditCards = "BlockCreditCards"

    /// Whether API keys and secrets are blocked from being stored
    case blockAPIKeys = "BlockAPIKeys"

    // MARK: Appearance

    /// UI theme override ("light", "dark", or "system")
    case theme = "Theme"

    // MARK: - Display Metadata

    /// Human-readable label used in admin UIs and audit logs
    var displayName: String {
        switch self {
        case .organizationID:       return "Organization ID"
        case .adminConsoleURL:      return "Admin Console URL"
        case .ssoEnabled:           return "SSO Enabled"
        case .ssoProvider:          return "SSO Provider"
        case .ssoDomain:            return "SSO Domain"
        case .cloudSyncEnabled:     return "Cloud Sync Enabled"
        case .localStorageOnly:     return "Local Storage Only"
        case .pluginsEnabled:       return "Plugins Enabled"
        case .requireBiometricAuth: return "Require Biometric Auth"
        case .autoLockTimeout:      return "Auto-Lock Timeout"
        case .clearOnQuit:          return "Clear on Quit"
        case .maxHistoryDays:       return "Max History Days"
        case .maxHistoryItems:      return "Max History Items"
        case .excludePrivateBrowsing: return "Exclude Private Browsing"
        case .dlpEnabled:           return "DLP Enabled"
        case .blockCreditCards:     return "Block Credit Cards"
        case .blockAPIKeys:         return "Block API Keys"
        case .theme:                return "Theme"
        }
    }

    /// The logical settings group this key belongs to
    var settingsGroup: SettingsGroup {
        switch self {
        case .organizationID, .adminConsoleURL:
            return .enterprise
        case .ssoEnabled, .ssoProvider, .ssoDomain:
            return .enterprise
        case .cloudSyncEnabled, .localStorageOnly:
            return .general
        case .pluginsEnabled:
            return .general
        case .requireBiometricAuth, .autoLockTimeout, .clearOnQuit:
            return .security
        case .maxHistoryDays, .maxHistoryItems:
            return .privacy
        case .excludePrivateBrowsing, .dlpEnabled, .blockCreditCards, .blockAPIKeys:
            return .privacy
        case .theme:
            return .appearance
        }
    }

    // MARK: - SettingsGroup

    /// Logical grouping used to organize keys in the settings UI
    enum SettingsGroup: String, Sendable {
        case general
        case privacy
        case appearance
        case security
        case enterprise

        /// Human-readable section heading
        var displayName: String {
            switch self {
            case .general:    return "General"
            case .privacy:    return "Privacy"
            case .appearance: return "Appearance"
            case .security:   return "Security"
            case .enterprise: return "Enterprise"
            }
        }
    }
}

// MARK: - PreferenceValue

/// A type-safe representation of a value read from an MDM managed preference payload.
///
/// MDM payloads carry values as plain plist types; this enum wraps the three
/// primitive types used by PasteShelf's managed keys.
enum PreferenceValue: Equatable, Sendable {

    /// A boolean preference (maps to plist `<true/>` / `<false/>`)
    case bool(Bool)

    /// An integer preference (maps to plist `<integer>`)
    case int(Int)

    /// A string preference (maps to plist `<string>`)
    case string(String)

    // MARK: - Display

    /// A human-readable string representation of the value, suitable for display
    /// in admin consoles or audit log entries.
    var displayValue: String {
        switch self {
        case .bool(let value):   return value ? "true" : "false"
        case .int(let value):    return "\(value)"
        case .string(let value): return value
        }
    }
}
