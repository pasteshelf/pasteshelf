//
//  Accessibility+Extensions.swift
//  PasteShelf
//
//  Accessibility helpers and extensions for improved VoiceOver support,
//  reduce motion handling, and high contrast support.
//

import AppKit
import Combine
import SwiftUI

// MARK: - ReduceMotionKey

/// Environment key for reduce motion preference
struct ReduceMotionKey: EnvironmentKey {
    static let defaultValue: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
}

// MARK: - HighContrastKey

/// Environment key for high contrast preference
struct HighContrastKey: EnvironmentKey {
    static let defaultValue: Bool = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
}

extension EnvironmentValues {
    /// Whether reduce motion is enabled
    var reduceMotion: Bool {
        get { self[ReduceMotionKey.self] }
        set { self[ReduceMotionKey.self] = newValue }
    }

    /// Whether high contrast is enabled
    var highContrast: Bool {
        get { self[HighContrastKey.self] }
        set { self[HighContrastKey.self] = newValue }
    }
}

// MARK: - ReduceMotionModifier

/// Applies appropriate animation based on reduce motion setting
struct ReduceMotionModifier: ViewModifier {
    // MARK: Internal

    let animation: Animation

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation)
    }

    // MARK: Private

    @Environment(\.reduceMotion)
    private var reduceMotion
}

// MARK: - HighContrastModifier

/// Applies high contrast styling when enabled
struct HighContrastModifier: ViewModifier {
    // MARK: Internal

    func body(content: Content) -> some View {
        content
            .foregroundColor(highContrast ? .primary : nil)
    }

    // MARK: Private

    @Environment(\.highContrast)
    private var highContrast
}

extension View {
    /// Applies animation only when reduce motion is disabled
    func animationWithReduceMotion(_ animation: Animation) -> some View {
        modifier(ReduceMotionModifier(animation: animation))
    }

    /// Applies high contrast styling when accessibility setting is enabled
    func highContrastAware() -> some View {
        modifier(HighContrastModifier())
    }

    /// Adds comprehensive accessibility to a clipboard item
    func clipboardItemAccessibility(
        contentType: String,
        preview: String,
        timestamp: String,
        isFavorite: Bool,
        isSensitive: Bool,
        sourceApp: String?
    ) -> some View {
        let description = buildAccessibilityDescription(
            contentType: contentType,
            preview: preview,
            timestamp: timestamp,
            isFavorite: isFavorite,
            isSensitive: isSensitive,
            sourceApp: sourceApp
        )

        return accessibilityElement(children: .combine)
            .accessibilityLabel(description)
            .accessibilityHint("Press Enter to paste, Delete to remove")
            .accessibilityAddTraits(isFavorite ? [.isButton, .isSelected] : .isButton)
    }

    private func buildAccessibilityDescription(
        contentType: String,
        preview: String,
        timestamp: String,
        isFavorite: Bool,
        isSensitive: Bool,
        sourceApp: String?
    ) -> String {
        var parts: [String] = []

        if isFavorite {
            parts.append("Favorite")
        }

        if isSensitive {
            parts.append("Sensitive")
        }

        parts.append(contentType)

        if !isSensitive, !preview.isEmpty {
            parts.append(preview)
        }

        if let app = sourceApp {
            parts.append("from \(app)")
        }

        parts.append(timestamp)

        return parts.joined(separator: ", ")
    }
}

// MARK: - NSWorkspace Extension

extension NSWorkspace {
    /// Checks if reduce motion is enabled
    static var reduceMotionEnabled: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Checks if high contrast is enabled
    static var highContrastEnabled: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }

    /// Checks if VoiceOver is running
    static var voiceOverEnabled: Bool {
        NSWorkspace.shared.isVoiceOverEnabled
    }
}

// MARK: - AccessibilityAnnouncement

/// Helper for making VoiceOver announcements
@MainActor
enum AccessibilityAnnouncement {
    /// Announces a message to VoiceOver users
    static func announce(_ message: String, priority: NSAccessibilityPriorityLevel = .medium) {
        guard NSWorkspace.voiceOverEnabled else {
            return
        }

        let userInfo: [NSAccessibility.NotificationUserInfoKey: Any] = [
            .announcement: message,
            .priority: priority.rawValue,
        ]
        NSAccessibility.post(
            element: NSApp as Any,
            notification: NSAccessibility.Notification.announcementRequested,
            userInfo: userInfo
        )
    }

    /// Announces item selection
    static func announceSelection(at index: Int, of total: Int, item: String) {
        announce("Item \(index + 1) of \(total): \(item)")
    }

    /// Announces action completion
    static func announceAction(_ action: String) {
        announce(action, priority: .high)
    }
}

// MARK: - KeyboardNavigationHelper

/// Helps manage keyboard focus for accessibility
@MainActor
final class KeyboardNavigationHelper: ObservableObject {
    @Published var focusedIndex: Int = 0
    @Published var itemCount: Int = 0

    func moveToNext() {
        if focusedIndex < itemCount - 1 {
            focusedIndex += 1
        }
    }

    func moveToPrevious() {
        if focusedIndex > 0 {
            focusedIndex -= 1
        }
    }

    func moveToFirst() {
        focusedIndex = 0
    }

    func moveToLast() {
        if itemCount > 0 {
            focusedIndex = itemCount - 1
        }
    }
}
