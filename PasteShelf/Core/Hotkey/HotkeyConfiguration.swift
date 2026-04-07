//
//  HotkeyConfiguration.swift
//  PasteShelf
//
//  Configuration and persistence for global hotkey settings.
//

import Carbon.HIToolbox
import Foundation

// MARK: - HotkeyConfiguration

/// Configuration for a global hotkey
struct HotkeyConfiguration: Codable, Equatable {
    // MARK: Internal

    // MARK: - Default Configuration

    /// Default hotkey: Cmd+Shift+V
    static let `default` = HotkeyConfiguration(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    /// Alternative hotkey: Cmd+Option+V
    static let alternative = HotkeyConfiguration(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(cmdKey | optionKey)
    )

    /// Virtual key code (e.g., kVK_ANSI_V = 9)
    let keyCode: UInt32

    /// Modifier flags (Command, Shift, etc.)
    let modifiers: UInt32

    // MARK: - Display String

    /// Human-readable representation of the hotkey
    var displayString: String {
        var parts: [String] = []

        if modifiers & UInt32(controlKey) != 0 {
            parts.append("\u{2303}") // ⌃
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("\u{2325}") // ⌥
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("\u{21E7}") // ⇧
        }
        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("\u{2318}") // ⌘
        }

        parts.append(keyDisplayString)

        return parts.joined()
    }

    /// Loads the configuration from SettingsManager
    @MainActor
    static func load() -> HotkeyConfiguration {
        SettingsManager.shared.shortcuts.globalHotkey.toHotkeyConfiguration
    }

    /// Resets to default configuration
    @MainActor
    static func reset() {
        SettingsManager.shared.shortcuts = ShortcutsSettings(
            globalHotkey: .default,
            quickPasteEnabled: SettingsManager.shared.shortcuts.quickPasteEnabled
        )
    }

    // MARK: - Persistence (delegates to SettingsManager)

    /// Saves the configuration via SettingsManager
    @MainActor
    func save() {
        SettingsManager.shared.shortcuts = ShortcutsSettings(
            globalHotkey: StoredHotkey(from: self),
            quickPasteEnabled: SettingsManager.shared.shortcuts.quickPasteEnabled
        )
    }

    // MARK: Private

    /// Display string for the key
    private var keyDisplayString: String {
        switch Int(keyCode) {
        case kVK_ANSI_A: "A"
        case kVK_ANSI_S: "S"
        case kVK_ANSI_D: "D"
        case kVK_ANSI_F: "F"
        case kVK_ANSI_H: "H"
        case kVK_ANSI_G: "G"
        case kVK_ANSI_Z: "Z"
        case kVK_ANSI_X: "X"
        case kVK_ANSI_C: "C"
        case kVK_ANSI_V: "V"
        case kVK_ANSI_B: "B"
        case kVK_ANSI_Q: "Q"
        case kVK_ANSI_W: "W"
        case kVK_ANSI_E: "E"
        case kVK_ANSI_R: "R"
        case kVK_ANSI_Y: "Y"
        case kVK_ANSI_T: "T"
        case kVK_ANSI_1: "1"
        case kVK_ANSI_2: "2"
        case kVK_ANSI_3: "3"
        case kVK_ANSI_4: "4"
        case kVK_ANSI_5: "5"
        case kVK_ANSI_6: "6"
        case kVK_ANSI_7: "7"
        case kVK_ANSI_8: "8"
        case kVK_ANSI_9: "9"
        case kVK_ANSI_0: "0"
        case kVK_Space: "\u{2423}" // ␣
        case kVK_Return: "\u{21A9}" // ↩
        case kVK_Tab: "\u{21E5}" // ⇥
        case kVK_Escape: "\u{238B}" // ⎋
        case kVK_Delete: "\u{232B}" // ⌫
        default: "?"
        }
    }
}

// MARK: - Modifier Helpers

extension HotkeyConfiguration {
    /// Returns true if Command modifier is set
    var hasCommand: Bool {
        modifiers & UInt32(cmdKey) != 0
    }

    /// Returns true if Shift modifier is set
    var hasShift: Bool {
        modifiers & UInt32(shiftKey) != 0
    }

    /// Returns true if Option modifier is set
    var hasOption: Bool {
        modifiers & UInt32(optionKey) != 0
    }

    /// Returns true if Control modifier is set
    var hasControl: Bool {
        modifiers & UInt32(controlKey) != 0
    }
}
