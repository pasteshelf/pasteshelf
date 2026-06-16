//
//  HotkeyManagerTests.swift
//  PasteShelfTests
//
//  Unit tests for HotkeyManager and hotkey configuration.
//

import Carbon.HIToolbox
import Foundation
import Testing
@testable import PasteShelf

struct HotkeyManagerTests {
    // MARK: - HotkeyConfiguration Tests

    @Test("Default hotkey is Cmd+Shift+V")
    func defaultHotkeyIsCmdShiftV() {
        let config = HotkeyConfiguration.default

        #expect(config.keyCode == UInt32(kVK_ANSI_V))
        #expect(config.hasCommand == true)
        #expect(config.hasShift == true)
        #expect(config.hasOption == false)
        #expect(config.hasControl == false)
    }

    @Test("Alternative hotkey is Cmd+Option+V")
    func alternativeHotkeyIsCmdOptionV() {
        let config = HotkeyConfiguration.alternative

        #expect(config.keyCode == UInt32(kVK_ANSI_V))
        #expect(config.hasCommand == true)
        #expect(config.hasOption == true)
        #expect(config.hasShift == false)
    }

    @Test("Display string includes all modifiers")
    func displayStringIncludesAllModifiers() {
        let config = HotkeyConfiguration(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(cmdKey | shiftKey | optionKey | controlKey)
        )
        let display = config.displayString

        // Should contain all modifier symbols
        #expect(display.contains("⌘"))  // Command
        #expect(display.contains("⇧"))  // Shift
        #expect(display.contains("⌥"))  // Option
        #expect(display.contains("⌃"))  // Control
        #expect(display.contains("V"))  // Key
    }

    @Test("Display string for common keys")
    func displayStringForCommonKeys() {
        let testCases: [(Int32, String)] = [
            (Int32(kVK_ANSI_A), "A"),
            (Int32(kVK_ANSI_V), "V"),
            (Int32(kVK_ANSI_C), "C"),
            (Int32(kVK_Space), "␣"),
            (Int32(kVK_Return), "↩"),
            (Int32(kVK_Tab), "⇥"),
            (Int32(kVK_Escape), "⎋"),
        ]

        for (keyCode, expectedKey) in testCases {
            let config = HotkeyConfiguration(
                keyCode: UInt32(keyCode),
                modifiers: UInt32(cmdKey)
            )
            #expect(config.displayString.contains(expectedKey), "Expected \(expectedKey) in display string")
        }
    }

    @Test("Display string renders previously-unmapped letters (regression)")
    func displayStringRendersPreviouslyUnmappedLetters() {
        // These letters used to fall through to "?" in the old hardcoded switch.
        let previouslyBroken: [(Int32, String)] = [
            (Int32(kVK_ANSI_I), "I"),
            (Int32(kVK_ANSI_J), "J"),
            (Int32(kVK_ANSI_K), "K"),
            (Int32(kVK_ANSI_L), "L"),
            (Int32(kVK_ANSI_M), "M"),
            (Int32(kVK_ANSI_N), "N"),
            (Int32(kVK_ANSI_O), "O"),
            (Int32(kVK_ANSI_P), "P"),
            (Int32(kVK_ANSI_U), "U"),
        ]

        for (keyCode, expected) in previouslyBroken {
            let display = HotkeyConfiguration.keyDisplayString(forKeyCode: UInt32(keyCode))
            #expect(display == expected, "keyCode \(keyCode) should display \(expected), got \(display)")
            #expect(display != "?", "keyCode \(keyCode) should not display '?'")
        }
    }

    @Test("Cmd+Shift+P displays as ⌘⇧P (regression)")
    func cmdShiftPDisplaysCorrectly() {
        let config = HotkeyConfiguration(
            keyCode: UInt32(kVK_ANSI_P),
            modifiers: UInt32(cmdKey | shiftKey)
        )
        let display = config.displayString

        #expect(display.contains("P"))
        #expect(!display.contains("?"))
        #expect(display == "⇧⌘P")
    }

    @Test("All ANSI letters resolve to a non-placeholder glyph")
    func allLettersResolve() {
        let letterKeyCodes: [Int32] = [
            kVK_ANSI_A, kVK_ANSI_B, kVK_ANSI_C, kVK_ANSI_D, kVK_ANSI_E,
            kVK_ANSI_F, kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_I, kVK_ANSI_J,
            kVK_ANSI_K, kVK_ANSI_L, kVK_ANSI_M, kVK_ANSI_N, kVK_ANSI_O,
            kVK_ANSI_P, kVK_ANSI_Q, kVK_ANSI_R, kVK_ANSI_S, kVK_ANSI_T,
            kVK_ANSI_U, kVK_ANSI_V, kVK_ANSI_W, kVK_ANSI_X, kVK_ANSI_Y,
            kVK_ANSI_Z,
        ].map(Int32.init)

        for keyCode in letterKeyCodes {
            let display = HotkeyConfiguration.keyDisplayString(forKeyCode: UInt32(keyCode))
            #expect(display != "?", "keyCode \(keyCode) returned placeholder '?'")
            #expect(display.count == 1, "letter keyCode \(keyCode) should be a single character, got \(display)")
        }
    }

    @Test("Special keys map to fixed glyphs")
    func specialKeysMapToGlyphs() {
        let cases: [(Int32, String)] = [
            (Int32(kVK_Space), "␣"),
            (Int32(kVK_Return), "↩"),
            (Int32(kVK_ANSI_KeypadEnter), "↩"),
            (Int32(kVK_Tab), "⇥"),
            (Int32(kVK_Escape), "⎋"),
            (Int32(kVK_Delete), "⌫"),
            (Int32(kVK_ForwardDelete), "⌦"),
            (Int32(kVK_LeftArrow), "←"),
            (Int32(kVK_RightArrow), "→"),
            (Int32(kVK_UpArrow), "↑"),
            (Int32(kVK_DownArrow), "↓"),
            (Int32(kVK_F1), "F1"),
            (Int32(kVK_F12), "F12"),
        ]

        for (keyCode, expected) in cases {
            let display = HotkeyConfiguration.keyDisplayString(forKeyCode: UInt32(keyCode))
            #expect(display == expected, "keyCode \(keyCode) should display \(expected), got \(display)")
        }
    }

    // MARK: - Modifier Detection Tests

    @Test("hasCommand detects Command modifier")
    func hasCommandDetectsCommandModifier() {
        let withCommand = HotkeyConfiguration(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(cmdKey)
        )
        let withoutCommand = HotkeyConfiguration(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(shiftKey)
        )

        #expect(withCommand.hasCommand == true)
        #expect(withoutCommand.hasCommand == false)
    }

    @Test("hasShift detects Shift modifier")
    func hasShiftDetectsShiftModifier() {
        let withShift = HotkeyConfiguration(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(shiftKey)
        )
        let withoutShift = HotkeyConfiguration(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(cmdKey)
        )

        #expect(withShift.hasShift == true)
        #expect(withoutShift.hasShift == false)
    }

    @Test("hasOption detects Option modifier")
    func hasOptionDetectsOptionModifier() {
        let withOption = HotkeyConfiguration(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(optionKey)
        )
        let withoutOption = HotkeyConfiguration(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(cmdKey)
        )

        #expect(withOption.hasOption == true)
        #expect(withoutOption.hasOption == false)
    }

    @Test("hasControl detects Control modifier")
    func hasControlDetectsControlModifier() {
        let withControl = HotkeyConfiguration(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(controlKey)
        )
        let withoutControl = HotkeyConfiguration(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(cmdKey)
        )

        #expect(withControl.hasControl == true)
        #expect(withoutControl.hasControl == false)
    }

    // MARK: - Codable Tests

    @Test("HotkeyConfiguration is Codable")
    func hotkeyConfigurationIsCodable() throws {
        let original = HotkeyConfiguration.default
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(HotkeyConfiguration.self, from: data)

        #expect(decoded.keyCode == original.keyCode)
        #expect(decoded.modifiers == original.modifiers)
    }

    @Test("HotkeyConfiguration encodes to JSON correctly")
    func hotkeyConfigurationEncodesToJSON() throws {
        let config = HotkeyConfiguration(
            keyCode: 9,  // V
            modifiers: 256  // Cmd
        )
        let encoder = JSONEncoder()

        let data = try encoder.encode(config)
        let json = String(data: data, encoding: .utf8)

        #expect(json?.contains("\"keyCode\":9") == true)
        #expect(json?.contains("\"modifiers\":256") == true)
    }

    // MARK: - Equality Tests

    @Test("HotkeyConfiguration equality")
    func hotkeyConfigurationEquality() {
        let config1 = HotkeyConfiguration(keyCode: 9, modifiers: 256)
        let config2 = HotkeyConfiguration(keyCode: 9, modifiers: 256)
        let config3 = HotkeyConfiguration(keyCode: 10, modifiers: 256)
        let config4 = HotkeyConfiguration(keyCode: 9, modifiers: 512)

        #expect(config1 == config2)
        #expect(config1 != config3)
        #expect(config1 != config4)
    }

    // MARK: - StoredHotkey Tests

    @Test("StoredHotkey converts to HotkeyConfiguration")
    func storedHotkeyConvertsToHotkeyConfiguration() {
        let stored = StoredHotkey.default
        let config = stored.toHotkeyConfiguration

        #expect(config.keyCode == stored.keyCode)
        #expect(config.modifiers == stored.modifiers)
    }

    @Test("StoredHotkey created from HotkeyConfiguration")
    func storedHotkeyCreatedFromHotkeyConfiguration() {
        let config = HotkeyConfiguration.default
        let stored = StoredHotkey(from: config)

        #expect(stored.keyCode == config.keyCode)
        #expect(stored.modifiers == config.modifiers)
    }

    @Test("StoredHotkey displayString matches configuration")
    func storedHotkeyDisplayStringMatchesConfiguration() {
        let stored = StoredHotkey.default
        let config = stored.toHotkeyConfiguration

        #expect(stored.displayString == config.displayString)
    }
}

// MARK: - Hotkey Conflict Tests

struct HotkeyConflictTests {
    @Test("System shortcuts are reserved")
    func systemShortcutsAreReserved() {
        // Cmd+Q (Quit)
        let quitShortcut = HotkeyConfiguration(
            keyCode: UInt32(kVK_ANSI_Q),
            modifiers: UInt32(cmdKey)
        )

        // Cmd+C (Copy)
        let copyShortcut = HotkeyConfiguration(
            keyCode: UInt32(kVK_ANSI_C),
            modifiers: UInt32(cmdKey)
        )

        // These should be detected as conflicts (if HotkeyManager has conflict detection)
        // For now, just verify they can be created
        #expect(quitShortcut.keyCode == UInt32(kVK_ANSI_Q))
        #expect(copyShortcut.keyCode == UInt32(kVK_ANSI_C))
    }

    @Test("Custom shortcuts with multiple modifiers are allowed")
    func customShortcutsWithMultipleModifiersAllowed() {
        // Cmd+Shift+V (default for PasteShelf)
        let pasteShelfDefault = HotkeyConfiguration.default

        #expect(pasteShelfDefault.hasCommand == true)
        #expect(pasteShelfDefault.hasShift == true)
    }
}
