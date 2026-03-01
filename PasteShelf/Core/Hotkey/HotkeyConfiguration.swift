//
//  HotkeyConfiguration.swift
//  PasteShelf
//
//  Configuration and persistence for global hotkey settings.
//

import Carbon.HIToolbox
import Foundation

/// Configuration for a global hotkey
struct HotkeyConfiguration: Codable, Equatable {
    // MARK: - Properties

    /// Virtual key code (e.g., kVK_ANSI_V = 9)
    let keyCode: UInt32

    /// Modifier flags (Command, Shift, etc.)
    let modifiers: UInt32

    // MARK: - Initialization

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

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

    /// Display string for the key
    private var keyDisplayString: String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_0: return "0"
        case kVK_Space: return "\u{2423}" // ␣
        case kVK_Return: return "\u{21A9}" // ↩
        case kVK_Tab: return "\u{21E5}" // ⇥
        case kVK_Escape: return "\u{238B}" // ⎋
        case kVK_Delete: return "\u{232B}" // ⌫
        default: return "?"
        }
    }

    // MARK: - Persistence (delegates to SettingsManager)

    /// Saves the configuration via SettingsManager
    func save() {
        SettingsManager.shared.shortcuts = ShortcutsSettings(
            globalHotkey: StoredHotkey(from: self),
            quickPasteEnabled: SettingsManager.shared.shortcuts.quickPasteEnabled
        )
    }

    /// Loads the configuration from SettingsManager
    static func load() -> HotkeyConfiguration {
        SettingsManager.shared.shortcuts.globalHotkey.toHotkeyConfiguration
    }

    /// Resets to default configuration
    static func reset() {
        SettingsManager.shared.shortcuts = ShortcutsSettings(
            globalHotkey: .default,
            quickPasteEnabled: SettingsManager.shared.shortcuts.quickPasteEnabled
        )
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
