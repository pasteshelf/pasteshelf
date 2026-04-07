//
//  ShortcutsSettings.swift
//  PasteShelf
//
//  Shortcut and hotkey settings including global hotkey
//  configuration and quick paste shortcuts.
//

import Carbon.HIToolbox
import Foundation

// MARK: - ShortcutsSettings

/// Shortcuts and hotkey settings
struct ShortcutsSettings: Codable, Equatable {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        globalHotkey: StoredHotkey = .default,
        quickPasteEnabled: Bool = true
    ) {
        self.globalHotkey = globalHotkey
        self.quickPasteEnabled = quickPasteEnabled
    }

    // MARK: Internal

    // MARK: - Default Configuration

    /// Default shortcuts settings
    static let `default` = ShortcutsSettings()

    /// Global hotkey to show/hide clipboard panel
    var globalHotkey: StoredHotkey

    /// Whether quick paste shortcuts (Cmd+1-9) are enabled
    var quickPasteEnabled: Bool
}

// MARK: - StoredHotkey

/// A Codable representation of a hotkey configuration
struct StoredHotkey: Codable, Equatable {
    // MARK: Lifecycle

    /// Creates from HotkeyConfiguration
    init(from config: HotkeyConfiguration) {
        self.keyCode = config.keyCode
        self.modifiers = config.modifiers
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    // MARK: Internal

    // MARK: - Default Configuration

    /// Default hotkey: Cmd+Shift+V
    static let `default` = StoredHotkey(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    /// Alternative hotkey: Cmd+Option+V
    static let alternative = StoredHotkey(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(cmdKey | optionKey)
    )

    /// Virtual key code
    let keyCode: UInt32

    /// Modifier flags (Carbon format)
    let modifiers: UInt32

    // MARK: - Conversion

    /// Converts to HotkeyConfiguration
    var toHotkeyConfiguration: HotkeyConfiguration {
        HotkeyConfiguration(keyCode: self.keyCode, modifiers: self.modifiers)
    }

    // MARK: - Display

    /// Human-readable representation of the hotkey
    var displayString: String {
        self.toHotkeyConfiguration.displayString
    }
}
