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

    /// Maximum number of clipboard items to keep in history
    var historyLimit: HistoryLimit

    /// Whether to capture text content (plain text, rich text, HTML)
    var captureTextContent: Bool

    /// Whether to capture image content (PNG, JPEG, TIFF)
    var captureImageContent: Bool

    /// Whether to capture file content (file references, PDFs)
    var captureFileContent: Bool

    /// Whether to capture link content (URLs)
    var captureLinkContent: Bool

    // MARK: - Initialization

    init(
        launchAtLogin: Bool = false,
        showInDock: Bool = false,
        historyLimit: HistoryLimit = .medium,
        captureTextContent: Bool = true,
        captureImageContent: Bool = true,
        captureFileContent: Bool = true,
        captureLinkContent: Bool = true
    ) {
        self.launchAtLogin = launchAtLogin
        self.showInDock = showInDock
        self.historyLimit = historyLimit
        self.captureTextContent = captureTextContent
        self.captureImageContent = captureImageContent
        self.captureFileContent = captureFileContent
        self.captureLinkContent = captureLinkContent
    }

    // MARK: - Codable (backwards compatibility)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
        showInDock = try container.decode(Bool.self, forKey: .showInDock)
        historyLimit = try container.decode(HistoryLimit.self, forKey: .historyLimit)
        captureTextContent = try container.decodeIfPresent(Bool.self, forKey: .captureTextContent) ?? true
        captureImageContent = try container.decodeIfPresent(Bool.self, forKey: .captureImageContent) ?? true
        captureFileContent = try container.decodeIfPresent(Bool.self, forKey: .captureFileContent) ?? true
        captureLinkContent = try container.decodeIfPresent(Bool.self, forKey: .captureLinkContent) ?? true
    }

    // MARK: - Capture Filtering

    /// Whether a given content type should be captured based on settings
    func shouldCapture(_ type: ContentType) -> Bool {
        if type.isTextType { return captureTextContent }
        if type.isImageType { return captureImageContent }
        switch type {
        case .pdf, .fileURL: return captureFileContent
        case .url: return captureLinkContent
        default: return true
        }
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

    /// Display name for the limit (English; used for logs and tests)
    var displayName: String {
        switch self {
        case .small: return "100 items"
        case .medium: return "500 items"
        case .large: return "1,000 items"
        case .unlimited: return "Unlimited"
        }
    }

    /// Localized display name key (use in SwiftUI views)
    var displayNameKey: LocalizedStringResource {
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
