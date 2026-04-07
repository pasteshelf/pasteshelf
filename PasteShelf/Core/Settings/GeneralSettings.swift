//
//  GeneralSettings.swift
//  PasteShelf
//
//  General application settings including launch behavior,
//  history limits, and update preferences.
//

import Foundation

// MARK: - GeneralSettings

/// General application settings
struct GeneralSettings: Codable, Equatable {
    // MARK: Lifecycle

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
        self.launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
        self.showInDock = try container.decode(Bool.self, forKey: .showInDock)
        self.historyLimit = try container.decode(HistoryLimit.self, forKey: .historyLimit)
        self.captureTextContent = try container.decodeIfPresent(Bool.self, forKey: .captureTextContent) ?? true
        self.captureImageContent = try container.decodeIfPresent(Bool.self, forKey: .captureImageContent) ?? true
        self.captureFileContent = try container.decodeIfPresent(Bool.self, forKey: .captureFileContent) ?? true
        self.captureLinkContent = try container.decodeIfPresent(Bool.self, forKey: .captureLinkContent) ?? true
    }

    // MARK: Internal

    // MARK: - Default Configuration

    /// Default general settings
    static let `default` = GeneralSettings()

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

    // MARK: - Capture Filtering

    /// Whether a given content type should be captured based on settings
    func shouldCapture(_ type: ContentType) -> Bool {
        if type.isTextType {
            return self.captureTextContent
        }
        if type.isImageType {
            return self.captureImageContent
        }
        switch type {
        case .pdf,
             .fileURL: return self.captureFileContent
        case .url: return self.captureLinkContent
        default: return true
        }
    }
}

// MARK: - HistoryLimit

/// Options for clipboard history limit
enum HistoryLimit: Int, Codable, CaseIterable, Identifiable {
    case small = 100
    case medium = 500
    case large = 1000
    case unlimited = 0

    // MARK: Internal

    var id: Int {
        rawValue
    }

    /// Display name for the limit
    var displayName: String {
        switch self {
        case .small: "100 items"
        case .medium: "500 items"
        case .large: "1,000 items"
        case .unlimited: "Unlimited"
        }
    }

    /// Actual limit value (nil for unlimited)
    var limit: Int? {
        switch self {
        case .unlimited: nil
        default: rawValue
        }
    }
}
