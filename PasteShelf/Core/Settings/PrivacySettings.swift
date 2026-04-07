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
    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        autoDeleteEnabled: Bool = false,
        autoDeleteDays: Int = 30,
        isMonitoringPaused: Bool = false,
        excludedAppBundleIds: [String] = [],
        sensitiveDetectionEnabled: Bool = true,
        enabledSensitiveCategories: Set<SensitivePatterns.SensitiveCategory> = Set(SensitivePatterns.SensitiveCategory
            .allCases)
    ) {
        self.autoDeleteEnabled = autoDeleteEnabled
        self.autoDeleteDays = autoDeleteDays
        self.isMonitoringPaused = isMonitoringPaused
        self.excludedAppBundleIds = excludedAppBundleIds
        self.sensitiveDetectionEnabled = sensitiveDetectionEnabled
        self.enabledSensitiveCategories = enabledSensitiveCategories
    }

    // MARK: - Codable (backwards compatibility)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.autoDeleteEnabled = try container.decode(Bool.self, forKey: .autoDeleteEnabled)
        self.autoDeleteDays = try container.decode(Int.self, forKey: .autoDeleteDays)
        self.isMonitoringPaused = try container.decode(Bool.self, forKey: .isMonitoringPaused)
        self.excludedAppBundleIds = try container.decode([String].self, forKey: .excludedAppBundleIds)
        self.sensitiveDetectionEnabled = try container
            .decodeIfPresent(Bool.self, forKey: .sensitiveDetectionEnabled) ?? true
        self.enabledSensitiveCategories = try container.decodeIfPresent(
            Set<SensitivePatterns.SensitiveCategory>.self,
            forKey: .enabledSensitiveCategories
        ) ?? Set(SensitivePatterns.SensitiveCategory.allCases)
    }

    // MARK: Internal

    // MARK: - Default Configuration

    /// Default privacy settings
    static let `default` = PrivacySettings()

    // MARK: - Auto-Delete Options

    /// Available auto-delete period options in days
    static let autoDeleteOptions: [Int] = [7, 14, 30, 60, 90, 180, 365]

    /// Whether auto-delete is enabled
    var autoDeleteEnabled: Bool

    /// Number of days after which items are automatically deleted
    var autoDeleteDays: Int

    /// Whether clipboard monitoring is paused
    var isMonitoringPaused: Bool

    /// Bundle IDs of excluded applications
    var excludedAppBundleIds: [String]

    /// Whether sensitive data detection is enabled
    var sensitiveDetectionEnabled: Bool

    /// Which categories of sensitive data to detect
    var enabledSensitiveCategories: Set<SensitivePatterns.SensitiveCategory>
}
