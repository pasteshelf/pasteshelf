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

    // MARK: - Defaults

    static let `default` = EnterpriseSettings(
        cloudSyncEnabled: true,
        localStorageOnly: false,
        pluginsEnabled: true
    )
}
