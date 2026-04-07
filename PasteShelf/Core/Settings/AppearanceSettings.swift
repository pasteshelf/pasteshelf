//
//  AppearanceSettings.swift
//  PasteShelf
//
//  Appearance settings including theme, panel width,
//  preview options, and display preferences.
//

import CoreGraphics
import Foundation

// MARK: - AppearanceSettings

/// Appearance and UI settings
struct AppearanceSettings: Codable, Equatable {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        theme: AppTheme = .system,
        panelWidth: PanelWidth = .normal,
        previewLines: Int = 1,
        showThumbnails: Bool = true,
        compactMode: Bool = false,
        showTagFilters: Bool = true
    ) {
        self.theme = theme
        self.panelWidth = panelWidth
        self.previewLines = max(1, min(5, previewLines))
        self.showThumbnails = showThumbnails
        self.compactMode = compactMode
        self.showTagFilters = showTagFilters
    }

    // MARK: Internal

    // MARK: - Default Configuration

    /// Default appearance settings
    static let `default` = AppearanceSettings()

    /// Application theme
    var theme: AppTheme

    /// Floating panel width preference
    var panelWidth: PanelWidth

    /// Number of preview lines for text items (1-5)
    var previewLines: Int

    /// Whether to show thumbnails for images
    var showThumbnails: Bool

    /// Whether to use compact mode
    var compactMode: Bool

    /// Whether to show the tag filter row in the floating panel
    var showTagFilters: Bool
}

// MARK: - AppTheme

/// Application color theme options
enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    // MARK: Internal

    var id: String {
        rawValue
    }

    /// Display name for the theme
    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

// MARK: - PanelWidth

/// Floating panel width options
enum PanelWidth: String, Codable, CaseIterable, Identifiable {
    case narrow
    case normal
    case wide

    // MARK: Internal

    var id: String {
        rawValue
    }

    /// Display name for the width
    var displayName: String {
        switch self {
        case .narrow: "Narrow"
        case .normal: "Normal"
        case .wide: "Wide"
        }
    }

    /// Actual width in points
    var width: CGFloat {
        switch self {
        case .narrow: 320
        case .normal: 400
        case .wide: 500
        }
    }
}
