//
//  GeneralSettings.swift
//  PasteShelf
//
//  General application settings including launch behavior,
//  history limits, and update preferences.
//

import Foundation

/// General application settings
struct GeneralSettings: Codable, Equatable {
    // MARK: - Properties

    /// Whether to launch at login
    var launchAtLogin: Bool

    /// Whether to show the app in the Dock
    var showInDock: Bool

    /// Whether to check for updates automatically
    var checkForUpdates: Bool

    /// Maximum number of clipboard items to keep in history
    var historyLimit: HistoryLimit

    // MARK: - Initialization

    init(
        launchAtLogin: Bool = false,
        showInDock: Bool = false,
        checkForUpdates: Bool = true,
        historyLimit: HistoryLimit = .medium
    ) {
        self.launchAtLogin = launchAtLogin
        self.showInDock = showInDock
        self.checkForUpdates = checkForUpdates
        self.historyLimit = historyLimit
    }

    // MARK: - Default Configuration

    /// Default general settings
    static let `default` = GeneralSettings()
}

// MARK: - History Limit

/// Options for clipboard history limit
enum HistoryLimit: Int, Codable, CaseIterable, Identifiable {
    case small = 100
    case medium = 500
    case large = 1000
    case unlimited = 0

    var id: Int { rawValue }

    /// Display name for the limit
    var displayName: String {
        switch self {
        case .small: return "100 items"
        case .medium: return "500 items"
        case .large: return "1,000 items"
        case .unlimited: return "Unlimited"
        }
    }

    /// Actual limit value (nil for unlimited)
    var limit: Int? {
        switch self {
        case .unlimited: return nil
        default: return rawValue
        }
    }
}
