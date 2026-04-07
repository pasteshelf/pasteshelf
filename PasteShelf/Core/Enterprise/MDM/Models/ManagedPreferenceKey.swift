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
enum ManagedPreferenceKey: String, CaseIterable {
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

    // MARK: DLP (Data Loss Prevention)

    /// Whether Data Loss Prevention scanning is enabled
    case dlpEnabled = "DLPEnabled"

    /// Whether credit card numbers are blocked from being stored
    case blockCreditCards = "BlockCreditCards"

    /// Whether API keys and secrets are blocked from being stored
    case blockAPIKeys = "BlockAPIKeys"

    // MARK: Compliance

    /// Whether GDPR consent management and data export/deletion are active
    case gdprEnabled = "GDPREnabled"

    /// Whether SOC 2 reporting and evidence collection are active
    case soc2Enabled = "SOC2Enabled"

    /// Whether HIPAA compliance mode is active
    case hipaaEnabled = "HIPAAEnabled"

    // MARK: Appearance

    /// UI theme override ("light", "dark", or "system")
    case theme = "Theme"

    // MARK: Internal

    // MARK: - SettingsGroup

    /// Logical grouping used to organize keys in the settings UI
    enum SettingsGroup: String {
        case general
        case privacy
        case appearance
        case security
        case enterprise

        // MARK: Internal

        /// Human-readable section heading
        var displayName: String {
            switch self {
            case .general: "General"
            case .privacy: "Privacy"
            case .appearance: "Appearance"
            case .security: "Security"
            case .enterprise: "Enterprise"
            }
        }
    }

    // MARK: - Display Metadata

    /// Human-readable label used in admin UIs and audit logs
    var displayName: String {
        switch self {
        case .organizationID: "Organization ID"
        case .adminConsoleURL: "Admin Console URL"
        case .ssoEnabled: "SSO Enabled"
        case .ssoProvider: "SSO Provider"
        case .ssoDomain: "SSO Domain"
        case .cloudSyncEnabled: "Cloud Sync Enabled"
        case .localStorageOnly: "Local Storage Only"
        case .pluginsEnabled: "Plugins Enabled"
        case .requireBiometricAuth: "Require Biometric Auth"
        case .autoLockTimeout: "Auto-Lock Timeout"
        case .clearOnQuit: "Clear on Quit"
        case .maxHistoryDays: "Max History Days"
        case .maxHistoryItems: "Max History Items"
        case .dlpEnabled: "DLP Enabled"
        case .blockCreditCards: "Block Credit Cards"
        case .blockAPIKeys: "Block API Keys"
        case .gdprEnabled: "GDPR Enabled"
        case .soc2Enabled: "SOC 2 Enabled"
        case .hipaaEnabled: "HIPAA Enabled"
        case .theme: "Theme"
        }
    }

    /// The logical settings group this key belongs to
    var settingsGroup: SettingsGroup {
        switch self {
        case .organizationID,
             .adminConsoleURL:
            .enterprise
        case .ssoEnabled,
             .ssoProvider,
             .ssoDomain:
            .enterprise
        case .cloudSyncEnabled,
             .localStorageOnly:
            .general
        case .pluginsEnabled:
            .general
        case .requireBiometricAuth,
             .autoLockTimeout,
             .clearOnQuit:
            .security
        case .maxHistoryDays,
             .maxHistoryItems:
            .privacy
        case .dlpEnabled,
             .blockCreditCards,
             .blockAPIKeys:
            .privacy
        case .gdprEnabled,
             .soc2Enabled,
             .hipaaEnabled:
            .enterprise
        case .theme:
            .appearance
        }
    }
}

// MARK: - PreferenceValue

/// A type-safe representation of a value read from an MDM managed preference payload.
///
/// MDM payloads carry values as plain plist types; this enum wraps the three
/// primitive types used by PasteShelf's managed keys.
enum PreferenceValue: Equatable {
    /// A boolean preference (maps to plist `<true/>` / `<false/>`)
    case bool(Bool)

    /// An integer preference (maps to plist `<integer>`)
    case int(Int)

    /// A string preference (maps to plist `<string>`)
    case string(String)

    // MARK: Internal

    // MARK: - Display

    /// A human-readable string representation of the value, suitable for display
    /// in admin consoles or audit log entries.
    var displayValue: String {
        switch self {
        case let .bool(value): value ? "true" : "false"
        case let .int(value): "\(value)"
        case let .string(value): value
        }
    }
}
