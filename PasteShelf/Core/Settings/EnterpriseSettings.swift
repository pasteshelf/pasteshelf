//
//  EnterpriseSettings.swift
//  PasteShelf
//
//  Enterprise-specific settings managed via MDM or admin console.
//  Controls cloud sync, local storage, and plugin availability.
//

import Foundation

/// Enterprise-specific settings typically managed via MDM policies.
struct EnterpriseSettings: Codable, Equatable {
    /// Whether cloud sync (iCloud or self-hosted) is enabled.
    /// When `false`, sync is completely disabled.
    var cloudSyncEnabled: Bool

    /// When `true`, data must remain on the local device only.
    /// Overrides `cloudSyncEnabled` — if both are set, local-only wins.
    var localStorageOnly: Bool

    /// Whether the plugin system is enabled.
    /// When `false`, plugins will not be initialized or loaded.
    var pluginsEnabled: Bool

    /// Whether GDPR compliance features are enabled.
    /// When `false`, GDPR consent management and data export/deletion are inactive.
    var gdprEnabled: Bool

    /// Whether SOC 2 compliance features are enabled.
    /// When `false`, SOC 2 reporting and evidence collection are inactive.
    var soc2Enabled: Bool

    // MARK: - Initialization

    init(
        cloudSyncEnabled: Bool = true,
        localStorageOnly: Bool = false,
        pluginsEnabled: Bool = true,
        gdprEnabled: Bool = false,
        soc2Enabled: Bool = false
    ) {
        self.cloudSyncEnabled = cloudSyncEnabled
        self.localStorageOnly = localStorageOnly
        self.pluginsEnabled = pluginsEnabled
        self.gdprEnabled = gdprEnabled
        self.soc2Enabled = soc2Enabled
    }

    // MARK: - Codable (backward compatibility)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cloudSyncEnabled = try container.decode(Bool.self, forKey: .cloudSyncEnabled)
        localStorageOnly = try container.decode(Bool.self, forKey: .localStorageOnly)
        pluginsEnabled = try container.decode(Bool.self, forKey: .pluginsEnabled)
        gdprEnabled = try container.decodeIfPresent(Bool.self, forKey: .gdprEnabled) ?? false
        soc2Enabled = try container.decodeIfPresent(Bool.self, forKey: .soc2Enabled) ?? false
    }

    // MARK: - Defaults

    static let `default` = EnterpriseSettings(
        cloudSyncEnabled: true,
        localStorageOnly: false,
        pluginsEnabled: true,
        gdprEnabled: false,
        soc2Enabled: false
    )
}
