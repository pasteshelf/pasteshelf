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
    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        cloudSyncEnabled: Bool = false,
        localStorageOnly: Bool = false,
        pluginsEnabled: Bool = true,
        gdprEnabled: Bool = false,
        soc2Enabled: Bool = false,
        hipaaEnabled: Bool = false
    ) {
        self.cloudSyncEnabled = cloudSyncEnabled
        self.localStorageOnly = localStorageOnly
        self.pluginsEnabled = pluginsEnabled
        self.gdprEnabled = gdprEnabled
        self.soc2Enabled = soc2Enabled
        self.hipaaEnabled = hipaaEnabled
    }

    // MARK: - Codable (backward compatibility)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.cloudSyncEnabled = try container.decode(Bool.self, forKey: .cloudSyncEnabled)
        self.localStorageOnly = try container.decode(Bool.self, forKey: .localStorageOnly)
        self.pluginsEnabled = try container.decode(Bool.self, forKey: .pluginsEnabled)
        self.gdprEnabled = try container.decodeIfPresent(Bool.self, forKey: .gdprEnabled) ?? false
        self.soc2Enabled = try container.decodeIfPresent(Bool.self, forKey: .soc2Enabled) ?? false
        self.hipaaEnabled = try container.decodeIfPresent(Bool.self, forKey: .hipaaEnabled) ?? false
    }

    // MARK: Internal

    // MARK: - Defaults

    static let `default` = EnterpriseSettings(
        cloudSyncEnabled: false,
        localStorageOnly: false,
        pluginsEnabled: true,
        gdprEnabled: false,
        soc2Enabled: false,
        hipaaEnabled: false
    )

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

    /// Whether HIPAA compliance mode is enabled via MDM.
    /// When `false`, HIPAA mode can still be enabled locally via `HIPAAComplianceMode`.
    var hipaaEnabled: Bool
}
