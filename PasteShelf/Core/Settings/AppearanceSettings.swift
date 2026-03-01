//
//  AppearanceSettings.swift
//  PasteShelf
//
//  Appearance settings including theme, panel width,
//  preview options, and display preferences.
//

import CoreGraphics
import Foundation

/// Appearance and UI settings
struct AppearanceSettings: Codable, Equatable {
    // MARK: - Properties

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

    // MARK: - Initialization

    init(
        theme: AppTheme = .system,
        panelWidth: PanelWidth = .normal,
        previewLines: Int = 3,
        showThumbnails: Bool = true,
        compactMode: Bool = false
    ) {
        self.theme = theme
        self.panelWidth = panelWidth
        self.previewLines = max(1, min(5, previewLines))
        self.showThumbnails = showThumbnails
        self.compactMode = compactMode
    }

    // MARK: - Default Configuration

    /// Default appearance settings
    static let `default` = AppearanceSettings()
}

// MARK: - App Theme

/// Application color theme options
enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// Display name for the theme
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

// MARK: - Panel Width

/// Floating panel width options
enum PanelWidth: String, Codable, CaseIterable, Identifiable {
    case narrow
    case normal
    case wide

    var id: String { rawValue }

    /// Display name for the width
    var displayName: String {
        switch self {
        case .narrow: return "Narrow"
        case .normal: return "Normal"
        case .wide: return "Wide"
        }
    }

    /// Actual width in points
    var width: CGFloat {
        switch self {
        case .narrow: return 320
        case .normal: return 400
        case .wide: return 500
        }
    }
}
