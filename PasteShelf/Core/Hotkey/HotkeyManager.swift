//
//  HotkeyManager.swift
//  PasteShelf
//
//  Manages global hotkey registration using Carbon Event API.
//  Handles registration, unregistration, and hotkey event handling.
//

import Carbon.HIToolbox
import Foundation
import os.log

/// Manages global hotkey registration and handling
@MainActor
final class HotkeyManager {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(configuration: HotkeyConfiguration? = nil) {
        self.configuration = configuration ?? HotkeyConfiguration.load()
        Self.shared = self
    }

    deinit {
        MainActor.assumeIsolated {
            unregisterHotkey()
            if Self.shared === self {
                Self.shared = nil
            }
        }
    }

    // MARK: Internal

    /// Current hotkey configuration
    private(set) var configuration: HotkeyConfiguration

    /// Callback invoked when hotkey is pressed
    var onHotkeyPressed: (() -> Void)?

    /// Whether a hotkey is currently registered
    var isRegistered: Bool {
        self.hotkeyRef != nil
    }

    // MARK: - Registration

    /// Registers the default hotkey (Cmd+Shift+V)
    @discardableResult
    func registerDefaultHotkey() -> Bool {
        self.register(configuration: .default)
    }

    /// Registers a hotkey with the given configuration
    /// - Parameter configuration: The hotkey configuration to register
    /// - Returns: True if registration was successful
    @discardableResult
    func register(configuration: HotkeyConfiguration) -> Bool {
        // Unregister existing hotkey first
        self.unregisterHotkey()

        self.configuration = configuration

        // Install event handler if not already installed
        self.installEventHandler()

        // Register the hotkey
        var hotkeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            configuration.keyCode,
            configuration.modifiers,
            self.hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr {
            self.hotkeyRef = hotkeyRef
            self.logger.info("Hotkey registered: \(configuration.displayString)")
            return true
        } else {
            self.logger.error("Failed to register hotkey: \(status)")
            return false
        }
    }

    /// Unregisters the current hotkey
    func unregisterHotkey() {
        guard let hotkeyRef else {
            return
        }

        let status = UnregisterEventHotKey(hotkeyRef)
        if status == noErr {
            self.hotkeyRef = nil
            self.logger.info("Hotkey unregistered")
        } else {
            self.logger.error("Failed to unregister hotkey: \(status)")
        }
    }

    /// Updates the hotkey configuration
    /// - Parameter configuration: The new configuration
    /// - Returns: True if the update was successful
    @discardableResult
    func updateConfiguration(_ configuration: HotkeyConfiguration) -> Bool {
        self.register(configuration: configuration)
    }

    /// Updates the hotkey (alias for updateConfiguration)
    /// - Parameter configuration: The new configuration
    /// - Returns: True if the update was successful
    @discardableResult
    func updateHotkey(_ configuration: HotkeyConfiguration) -> Bool {
        self.updateConfiguration(configuration)
    }

    /// Resets to the default hotkey
    @discardableResult
    func resetToDefault() -> Bool {
        HotkeyConfiguration.reset()
        return self.register(configuration: .default)
    }

    // MARK: - Conflict Detection

    /// Checks if a hotkey configuration conflicts with system shortcuts
    /// - Parameter configuration: The configuration to check
    /// - Returns: True if there might be a conflict
    func mightConflict(with configuration: HotkeyConfiguration) -> Bool {
        // Common system shortcuts that might conflict
        let systemShortcuts: [(keyCode: UInt32, modifiers: UInt32)] = [
            (UInt32(kVK_ANSI_C), UInt32(cmdKey)), // Cmd+C (Copy)
            (UInt32(kVK_ANSI_V), UInt32(cmdKey)), // Cmd+V (Paste)
            (UInt32(kVK_ANSI_X), UInt32(cmdKey)), // Cmd+X (Cut)
            (UInt32(kVK_ANSI_Z), UInt32(cmdKey)), // Cmd+Z (Undo)
            (UInt32(kVK_ANSI_A), UInt32(cmdKey)), // Cmd+A (Select All)
            (UInt32(kVK_ANSI_Q), UInt32(cmdKey)), // Cmd+Q (Quit)
            (UInt32(kVK_ANSI_W), UInt32(cmdKey)), // Cmd+W (Close Window)
            (UInt32(kVK_Tab), UInt32(cmdKey)), // Cmd+Tab (App Switcher)
            (UInt32(kVK_Space), UInt32(cmdKey)), // Cmd+Space (Spotlight)
        ]

        return systemShortcuts.contains { shortcut in
            shortcut.keyCode == configuration.keyCode && shortcut.modifiers == configuration.modifiers
        }
    }

    // MARK: Private

    /// Shared instance for event handler callback
    private static var shared: HotkeyManager?

    /// Reference to the registered hotkey
    private var hotkeyRef: EventHotKeyRef?

    /// Unique identifier for the hotkey
    private let hotkeyID = EventHotKeyID(signature: OSType("PSHF".utf8.reduce(0) { $0 << 8 + OSType($1) }), id: 1)

    /// Logger for hotkey operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "hotkey"
    )

    // MARK: - Event Handler

    private var eventHandlerInstalled = false

    /// Handles hotkey events (called from C callback)
    private static func handleHotkeyEvent(_ event: EventRef?) -> OSStatus {
        guard let event else {
            return OSStatus(eventNotHandledErr)
        }

        var hotkeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyID
        )

        guard status == noErr else {
            return status
        }

        // Check if this is our hotkey
        if hotkeyID.signature == self.shared?.hotkeyID.signature, hotkeyID.id == self.shared?.hotkeyID.id {
            DispatchQueue.main.async {
                self.shared?.onHotkeyPressed?()
            }
            return noErr
        }

        return OSStatus(eventNotHandledErr)
    }

    private func installEventHandler() {
        guard !self.eventHandlerInstalled else {
            return
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                HotkeyManager.handleHotkeyEvent(event)
            },
            1,
            &eventType,
            nil,
            nil
        )

        if status == noErr {
            self.eventHandlerInstalled = true
            self.logger.debug("Event handler installed")
        } else {
            self.logger.error("Failed to install event handler: \(status)")
        }
    }
}
