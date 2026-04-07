//
//  SourceApp.swift
//  PasteShelf
//
//  Represents the source application from which clipboard content originated.
//

import AppKit
import Foundation

/// Represents metadata about the application that provided clipboard content
struct SourceApp: Sendable, Equatable {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates a SourceApp from bundle identifier and name
    /// - Parameters:
    ///   - bundleId: The application's bundle identifier
    ///   - name: The application's display name
    ///   - iconData: Optional PNG data for the application icon
    init(bundleId: String, name: String, iconData: Data? = nil) {
        self.bundleId = bundleId
        self.name = name
        self.iconData = iconData
    }

    // MARK: Internal

    /// The bundle identifier of the application (e.g., "com.apple.Safari")
    let bundleId: String

    /// The localized display name of the application
    let name: String

    /// PNG data for the application's icon (optional for Sendable compliance)
    let iconData: Data?

    // MARK: - Display

    /// Returns the application icon as an NSImage
    @MainActor var icon: NSImage? {
        if let data = iconData {
            return NSImage(data: data)
        }
        // Try to get icon from bundle
        if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: bundleURL.path)
        }
        return nil
    }

    /// Creates a SourceApp from an NSRunningApplication
    /// - Parameter runningApp: The running application instance
    /// - Returns: A SourceApp instance, or nil if the app lacks required info
    @MainActor
    static func from(runningApp: NSRunningApplication) -> SourceApp? {
        guard let bundleId = runningApp.bundleIdentifier else {
            return nil
        }

        let name = runningApp.localizedName ?? "Unknown"
        let iconData = runningApp.icon?.pngData

        return SourceApp(
            bundleId: bundleId,
            name: name,
            iconData: iconData
        )
    }

    /// Creates a SourceApp from the frontmost application
    /// - Returns: A SourceApp for the current frontmost app, or nil
    @MainActor
    static func frontmost() -> SourceApp? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        return from(runningApp: frontApp)
    }
}

// Note: pngData extension is defined in ImageProcessor.swift
