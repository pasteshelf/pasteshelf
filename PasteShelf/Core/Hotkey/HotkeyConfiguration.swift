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
        Self.keyDisplayString(forKeyCode: keyCode)
    }

    /// Fixed glyphs for non-printing keys that `UCKeyTranslate` can't render
    /// meaningfully (space, return, arrows, function keys, …).
    private static let specialKeyGlyphs: [Int: String] = [
        kVK_Space: "\u{2423}", // ␣
        kVK_Return: "\u{21A9}", // ↩
        kVK_ANSI_KeypadEnter: "\u{21A9}", // ↩
        kVK_Tab: "\u{21E5}", // ⇥
        kVK_Escape: "\u{238B}", // ⎋
        kVK_Delete: "\u{232B}", // ⌫
        kVK_ForwardDelete: "\u{2326}", // ⌦
        kVK_LeftArrow: "\u{2190}", // ←
        kVK_RightArrow: "\u{2192}", // →
        kVK_UpArrow: "\u{2191}", // ↑
        kVK_DownArrow: "\u{2193}", // ↓
        kVK_Home: "\u{2196}", // ↖
        kVK_End: "\u{2198}", // ↘
        kVK_PageUp: "\u{21DE}", // ⇞
        kVK_PageDown: "\u{21DF}", // ⇟
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
        kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
        kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    /// Maps a virtual key code to a displayable string.
    ///
    /// Non-printing keys use the fixed glyphs above. Every other key is
    /// resolved through the *current keyboard layout* via `UCKeyTranslate`, so
    /// all letters, digits, and punctuation display correctly regardless of
    /// layout. Falls back to "?" only when the layout can't produce a character.
    static func keyDisplayString(forKeyCode keyCode: UInt32) -> String {
        if let glyph = specialKeyGlyphs[Int(keyCode)] {
            return glyph
        }
        if let character = character(forKeyCode: keyCode), !character.isEmpty {
            return character.uppercased()
        }
        return "?"
    }

    /// Resolves the unmodified character produced by a key code using the
    /// current ASCII-capable keyboard layout.
    private static func character(forKeyCode keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else {
            return nil
        }

        let layoutData = Unmanaged<CFData>.fromOpaque(layoutPointer).takeUnretainedValue() as Data

        var deadKeyState: UInt32 = 0
        var characters = [UniChar](repeating: 0, count: 4)
        var actualLength = 0

        let status = layoutData.withUnsafeBytes { buffer -> OSStatus in
            guard let keyLayout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(
                keyLayout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0, // no modifier keys — we render modifiers separately
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &actualLength,
                &characters
            )
        }

        guard status == noErr, actualLength > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: actualLength)
    }

    // MARK: - Persistence (delegates to SettingsManager)

    /// Saves the configuration via SettingsManager
    @MainActor func save() {
        SettingsManager.shared.shortcuts = ShortcutsSettings(
            globalHotkey: StoredHotkey(from: self),
            quickPasteEnabled: SettingsManager.shared.shortcuts.quickPasteEnabled
        )
    }

    /// Loads the configuration from SettingsManager
    @MainActor static func load() -> HotkeyConfiguration {
        SettingsManager.shared.shortcuts.globalHotkey.toHotkeyConfiguration
    }

    /// Resets to default configuration
    @MainActor static func reset() {
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
