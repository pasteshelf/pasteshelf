//
//  MenuBarIconProvider.swift
//  PasteShelf
//
//  Provides SF Symbol icons for the menu bar status item with idle/active states.
//

import AppKit
import SwiftUI

/// Provides icons for the menu bar status item
enum MenuBarIconProvider {
    /// Icon shown when clipboard monitoring is idle
    static let idleIcon = "clipboard"

    /// Icon shown when clipboard monitoring is active/capturing
    static let activeIcon = "clipboard.fill"

    /// Icon shown when monitoring is paused
    static let pausedIcon = "pause.circle"

    /// Icon shown when there's an error
    static let errorIcon = "exclamationmark.triangle"

    // MARK: - NSImage Generation

    /// Creates an NSImage for the menu bar icon
    /// - Parameters:
    ///   - symbolName: The SF Symbol name
    ///   - configuration: Symbol configuration (default: scale medium)
    /// - Returns: NSImage configured for menu bar display
    static func image(
        for symbolName: String,
        configuration: NSImage.SymbolConfiguration = .init(scale: .medium)
    ) -> NSImage? {
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "PasteShelf"
        )
        image?.isTemplate = true
        return image?.withSymbolConfiguration(configuration)
    }

    /// Returns the idle state icon as NSImage
    /// Uses the custom menu bar icon from assets, falls back to SF Symbol
    static var idleImage: NSImage? {
        if let customIcon = NSImage(named: "MenuBarIcon") {
            customIcon.size = NSSize(width: 18, height: 18)
            customIcon.isTemplate = true
            return customIcon
        }
        return image(for: idleIcon)
    }
}

// MARK: - Menu Bar State

/// Represents the current state of the menu bar icon
enum MenuBarState {
    case idle
    case active
    case paused
    case error

    /// The SF Symbol name for this state
    var iconName: String {
        switch self {
        case .idle: return MenuBarIconProvider.idleIcon
        case .active: return MenuBarIconProvider.activeIcon
        case .paused: return MenuBarIconProvider.pausedIcon
        case .error: return MenuBarIconProvider.errorIcon
        }
    }

    /// The accessibility description for this state (localized at call site)
    var accessibilityDescription: String {
        switch self {
        case .idle: return String(localized: "PasteShelf - Monitoring")
        case .active: return String(localized: "PasteShelf - Capturing")
        case .paused: return String(localized: "PasteShelf - Paused")
        case .error: return String(localized: "PasteShelf - Error")
        }
    }

    /// Returns the NSImage for this state
    var image: NSImage? {
        switch self {
        case .idle, .active:
            return MenuBarIconProvider.idleImage
        default:
            return MenuBarIconProvider.image(for: iconName)
        }
    }
}
