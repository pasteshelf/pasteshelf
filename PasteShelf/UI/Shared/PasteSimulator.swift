//
//  PasteSimulator.swift
//  PasteShelf
//
//  Simulates Cmd+V paste keystroke using CGEvent API.
//  Requires Accessibility permissions to work properly.
//  Excluded from App Store builds (Guideline 2.4.5).
//

#if !APP_STORE

    import AppKit
    import Carbon.HIToolbox
    import Foundation
    import os.log

    /// Simulates keyboard events for pasting clipboard content
    final class PasteSimulator {
        // MARK: Internal

        /// Checks if Accessibility permissions are granted
        var hasAccessibilityPermission: Bool {
            AXIsProcessTrusted()
        }

        // MARK: - Public Methods

        /// Simulates a Cmd+V paste keystroke
        /// - Parameter delay: Optional delay before simulating (default: 0)
        /// - Returns: `true` if the paste was attempted with accessibility permission, `false` if permission is missing
        @discardableResult
        func simulatePaste(delay: TimeInterval = 0) -> Bool {
            if delay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.performPaste()
                }
                return hasAccessibilityPermission
            } else {
                return performPaste()
            }
        }

        /// Prompts for Accessibility permissions if not already granted
        func requestAccessibilityPermission() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
        }

        /// Simulates typing a string (for future use)
        /// - Parameter text: The text to type
        func simulateTyping(_ text: String) {
            guard hasAccessibilityPermission else {
                logger.warning("Accessibility permission not granted")
                return
            }

            for character in text {
                if let keyCode = keyCode(for: character) {
                    simulateKey(keyCode: keyCode, shift: character.isUppercase)
                }
            }
        }

        // MARK: Private

        // MARK: - Constants

        /// Key code for 'V' key
        private static let vKeyCode: CGKeyCode = 9

        // MARK: - Private Properties

        /// Logger for paste simulation operations
        private let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
            category: "paste"
        )

        // MARK: - Private Methods

        @discardableResult
        private func performPaste() -> Bool {
            guard hasAccessibilityPermission else {
                logger.warning("Accessibility permission not granted - requesting permission")
                requestAccessibilityPermission()
                return false
            }

            // Get the CGEventSource for keyboard events
            let source = CGEventSource(stateID: .hidSystemState)

            // Create key down event for Cmd+V
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: Self.vKeyCode, keyDown: true) else {
                logger.error("Failed to create key down event")
                return false
            }

            // Create key up event for Cmd+V
            guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: Self.vKeyCode, keyDown: false) else {
                logger.error("Failed to create key up event")
                return false
            }

            // Add Command modifier to both events
            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand

            // Post events to the system
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)

            logger.debug("Paste keystroke simulated (Cmd+V)")
            return true
        }

        /// Simulates a single key press
        private func simulateKey(keyCode: CGKeyCode, shift: Bool = false) {
            let source = CGEventSource(stateID: .hidSystemState)

            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
            else {
                return
            }

            if shift {
                keyDown.flags = .maskShift
                keyUp.flags = .maskShift
            }

            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }

        /// Maps characters to key codes (basic implementation)
        private func keyCode(for character: Character) -> CGKeyCode? {
            let lowercased = character.lowercased()

            // Basic alphanumeric mapping
            let keyMap: [Character: CGKeyCode] = [
                "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
                "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
                "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
                "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
                "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
                "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
                "n": 45, "m": 46, ".": 47, " ": 49,
            ]

            if let first = lowercased.first {
                return keyMap[first]
            }
            return nil
        }
    }

    // MARK: - Accessibility Helper

    extension PasteSimulator {
        /// Opens System Preferences to the Accessibility pane
        static func openAccessibilityPreferences() {
            let urlString = "x-apple.systempreferences:"
                + "com.apple.preference.security?Privacy_Accessibility"
            guard let url = URL(string: urlString) else {
                return
            }
            NSWorkspace.shared.open(url)
        }
    }

#endif
