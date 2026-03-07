//
//  PrivacySettings.swift
//  PasteShelf
//
//  Privacy and security settings including auto-delete,
//  excluded apps, and monitoring controls.
//

import Foundation

/// Privacy and security settings
struct PrivacySettings: Codable, Equatable {
    // MARK: - Properties

    /// Whether auto-delete is enabled
    var autoDeleteEnabled: Bool

    /// Number of days after which items are automatically deleted
    var autoDeleteDays: Int

    /// Whether clipboard monitoring is paused
    var isMonitoringPaused: Bool

    /// Bundle IDs of excluded applications
    var excludedAppBundleIds: [String]

    // MARK: - Initialization

    init(
        autoDeleteEnabled: Bool = false,
        autoDeleteDays: Int = 30,
        isMonitoringPaused: Bool = false,
        excludedAppBundleIds: [String] = []
    ) {
        self.autoDeleteEnabled = autoDeleteEnabled
        self.autoDeleteDays = autoDeleteDays
        self.isMonitoringPaused = isMonitoringPaused
        self.excludedAppBundleIds = excludedAppBundleIds
    }

    // MARK: - Default Configuration

    /// Default privacy settings
    static let `default` = PrivacySettings()

    // MARK: - Auto-Delete Options

    /// Available auto-delete period options in days
    static let autoDeleteOptions: [Int] = [7, 14, 30, 60, 90, 180, 365]
}
