//
//  HotkeyRecorderView.swift
//  PasteShelf
//
//  A SwiftUI view for recording custom keyboard shortcuts.
//  Uses NSViewRepresentable to capture key events.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// SwiftUI wrapper for hotkey recording
struct HotkeyRecorderView: View {
    // MARK: - Properties

    @Binding var hotkey: StoredHotkey
    @Binding var isRecording: Bool

    // MARK: - Body

    var body: some View {
        HotkeyRecorderRepresentable(
            hotkey: $hotkey,
            isRecording: $isRecording
        )
        .frame(height: 24)
        .background(isRecording ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isRecording ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - NSViewRepresentable

struct HotkeyRecorderRepresentable: NSViewRepresentable {
    @Binding var hotkey: StoredHotkey
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.delegate = context.coordinator
        view.updateDisplay(hotkey: hotkey)
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.updateDisplay(hotkey: hotkey)
        nsView.isRecording = isRecording
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, HotkeyRecorderNSViewDelegate {
        var parent: HotkeyRecorderRepresentable

        init(_ parent: HotkeyRecorderRepresentable) {
            self.parent = parent
        }

        func hotkeyRecorderDidStartRecording() {
            parent.isRecording = true
        }

        func hotkeyRecorderDidStopRecording() {
            parent.isRecording = false
        }

        func hotkeyRecorderDidRecordHotkey(_ hotkey: StoredHotkey) {
            parent.hotkey = hotkey
            parent.isRecording = false
        }
    }
}

// MARK: - Delegate Protocol

protocol HotkeyRecorderNSViewDelegate: AnyObject {
    func hotkeyRecorderDidStartRecording()
    func hotkeyRecorderDidStopRecording()
    func hotkeyRecorderDidRecordHotkey(_ hotkey: StoredHotkey)
}

// MARK: - NSView Implementation

class HotkeyRecorderNSView: NSView {
    // MARK: - Properties

    weak var delegate: HotkeyRecorderNSViewDelegate?

    var isRecording = false {
        didSet {
            needsDisplay = true
            updateAccessibility()
        }
    }

    private var displayString = ""
    private var textField: NSTextField!

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Create text field for display
        textField = NSTextField()
        textField.isEditable = false
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.alignment = .center
        textField.font = .systemFont(ofSize: 12, weight: .medium)
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // Set up accessibility
        setAccessibilityRole(.button)
        setAccessibilityLabel("Hotkey recorder")
        updateAccessibility()
    }

    // MARK: - Display

    func updateDisplay(hotkey: StoredHotkey) {
        displayString = hotkey.displayString
        textField.stringValue = isRecording ? "Press shortcut..." : displayString
    }

    private func updateAccessibility() {
        if isRecording {
            setAccessibilityValue("Recording")
            setAccessibilityHelp("Press a key combination to set the hotkey, or Escape to cancel")
        } else {
            setAccessibilityValue(displayString)
            setAccessibilityHelp("Click to record a new hotkey")
        }
    }

    // MARK: - First Responder

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        isRecording = true
        textField.stringValue = "Press shortcut..."
        delegate?.hotkeyRecorderDidStartRecording()
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        textField.stringValue = displayString
        delegate?.hotkeyRecorderDidStopRecording()
        return super.resignFirstResponder()
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    // MARK: - Key Events

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        // Escape cancels recording
        if event.keyCode == UInt16(kVK_Escape) {
            window?.makeFirstResponder(nil)
            return
        }

        // Require at least one modifier
        let modifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])
        guard !modifiers.isEmpty else {
            NSSound.beep()
            return
        }

        // Convert to Carbon modifiers
        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }
        if modifiers.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if modifiers.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }
        if modifiers.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }

        // Check for conflicts with common system shortcuts
        if isSystemShortcut(keyCode: event.keyCode, modifiers: modifiers) {
            NSSound.beep()
            showConflictAlert()
            return
        }

        let newHotkey = StoredHotkey(
            keyCode: UInt32(event.keyCode),
            modifiers: carbonModifiers
        )

        displayString = newHotkey.displayString
        textField.stringValue = displayString

        delegate?.hotkeyRecorderDidRecordHotkey(newHotkey)
        window?.makeFirstResponder(nil)
    }

    // MARK: - Conflict Detection

    private func isSystemShortcut(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        // Common system shortcuts to avoid
        let systemShortcuts: [(UInt16, NSEvent.ModifierFlags)] = [
            (UInt16(kVK_ANSI_Q), .command), // Quit
            (UInt16(kVK_ANSI_W), .command), // Close window
            (UInt16(kVK_ANSI_H), .command), // Hide
            (UInt16(kVK_ANSI_M), .command), // Minimize
            (UInt16(kVK_ANSI_C), .command), // Copy
            (UInt16(kVK_ANSI_V), .command), // Paste
            (UInt16(kVK_ANSI_X), .command), // Cut
            (UInt16(kVK_ANSI_A), .command), // Select all
            (UInt16(kVK_ANSI_Z), .command), // Undo
            (UInt16(kVK_Tab), .command), // App switcher
            (UInt16(kVK_Space), .command), // Spotlight
        ]

        for (shortcutKeyCode, shortcutModifiers) in systemShortcuts {
            if keyCode == shortcutKeyCode, modifiers == shortcutModifiers {
                return true
            }
        }

        return false
    }

    private func showConflictAlert() {
        let alert = NSAlert()
        alert.messageText = "Shortcut Conflict"
        alert.informativeText = "This shortcut is reserved by the system. Please choose a different combination."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Preview

#if DEBUG
    struct HotkeyRecorderView_Previews: PreviewProvider {
        static var previews: some View {
            HotkeyRecorderView(
                hotkey: .constant(.default),
                isRecording: .constant(false)
            )
            .frame(width: 150, height: 30)
            .padding()
        }
    }
#endif
