//
//  FloatingPanelController.swift
//  PasteShelf
//
//  Manages the NSPanel window for displaying clipboard history.
//  Handles window positioning, visibility, and keyboard events.
//

import AppKit
import Combine
import os.log
import SwiftUI

/// NSPanel subclass that can become key without requiring .titled style mask.
/// This avoids the blue key-window focus indicator line that macOS draws on titled windows.
private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Controller for the floating clipboard history panel
@MainActor
final class FloatingPanelController: NSObject {
    // MARK: - Properties

    /// The floating panel window
    private var panel: NSPanel?

    /// ViewModel for the panel content
    let viewModel: FloatingPanelViewModel

    /// Reference to clipboard monitor for paste operations
    weak var clipboardMonitor: ClipboardMonitor? {
        didSet {
            viewModel.clipboardMonitor = clipboardMonitor
        }
    }

    /// Whether the panel is currently visible
    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    // MARK: - Private Properties

    /// Logger for panel operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "panel"
    )

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// The app that was active before the panel was shown
    private var previousApp: NSRunningApplication?

    /// Storage manager reference
    private let storageManager: StorageManager

    // MARK: - Configuration

    /// Panel width (from settings)
    private var panelWidth: CGFloat {
        SettingsManager.shared.appearance.panelWidth.width
    }

    /// Panel height
    private let panelHeight: CGFloat = 500

    // MARK: - Initialization

    init(storageManager: StorageManager = .shared) {
        self.storageManager = storageManager
        viewModel = FloatingPanelViewModel(storageManager: storageManager)
        super.init()

        viewModel.restorePreviousAppFocus = { [weak self] in
            self?.restorePreviousAppFocus()
        }

        setupPanel()
        setupBindings()
        setupSettingsObserver()
    }

    // MARK: - Setup

    private func setupPanel() {
        // Create a borderless panel. KeyablePanel overrides canBecomeKey so keyboard
        // events work without .titled (which draws the blue focus indicator line).
        let contentRect = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)

        panel = KeyablePanel(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        guard let panel = panel else {
            logger.error("Failed to create panel")
            return
        }

        // Configure panel properties
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Create SwiftUI hosting view
        let contentView = FloatingPanelView(viewModel: viewModel)
            .environment(\.controlActiveState, .active)

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = contentRect

        panel.contentView = hostingView

        // Set up window delegate
        panel.delegate = self

        logger.info("Floating panel created")
    }

    private func setupBindings() {
        // Observe visibility changes in viewmodel
        viewModel.$isVisible
            .dropFirst()
            .sink { [weak self] visible in
                if visible {
                    self?.showPanel()
                } else {
                    self?.hidePanel()
                }
            }
            .store(in: &cancellables)
    }

    private func setupSettingsObserver() {
        // Observe settings changes to update panel width
        NotificationCenter.default.publisher(for: .settingsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePanelSize()
            }
            .store(in: &cancellables)
    }

    private func updatePanelSize() {
        guard let panel = panel else { return }

        let newWidth = panelWidth
        var frame = panel.frame
        let widthDiff = newWidth - frame.width

        // Adjust x position to keep panel centered
        frame.origin.x -= widthDiff / 2
        frame.size.width = newWidth

        panel.setFrame(frame, display: true, animate: true)
        logger.debug("Panel size updated to width: \(newWidth)")
    }

    // MARK: - Visibility

    /// Shows the floating panel
    func show() {
        Task {
            await viewModel.show()
        }
    }

    /// Hides the floating panel
    func hide() {
        viewModel.hide()
    }

    /// Toggles panel visibility
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    private func showPanel() {
        guard let panel = panel else { return }

        // Capture the frontmost app BEFORE showing the panel
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontmost
        }

        // Position panel in center of main screen
        positionPanelCentered()

        // Show and order front
        panel.makeKeyAndOrderFront(nil)

        // Activate without stealing focus from other apps
        NSApp.activate(ignoringOtherApps: true)

        logger.debug("Panel shown")
    }

    private func hidePanel() {
        guard panel?.isVisible == true else { return }
        panel?.orderOut(nil)
        logger.debug("Panel hidden")
    }

    /// Restores focus to the app that was active before the panel was shown
    func restorePreviousAppFocus() {
        guard let previousApp = previousApp else { return }
        previousApp.activate()
        self.previousApp = nil
    }

    // MARK: - Positioning

    /// Positions the panel in the center of the main screen
    private func positionPanelCentered() {
        guard let panel = panel,
              let screen = NSScreen.main
        else { return }

        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size

        let x = screenFrame.midX - (panelSize.width / 2)
        let y = screenFrame.midY - (panelSize.height / 2) + 50 // Slightly above center

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Positions the panel near the mouse cursor
    private func positionPanelNearCursor() {
        guard let panel = panel,
              let screen = NSScreen.main
        else { return }

        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size

        // Calculate position - prefer below cursor, but adjust if off-screen
        var x = mouseLocation.x - (panelSize.width / 2)
        var y = mouseLocation.y - panelSize.height - 20

        // Clamp to screen bounds
        x = max(screenFrame.minX, min(x, screenFrame.maxX - panelSize.width))
        y = max(screenFrame.minY, min(y, screenFrame.maxY - panelSize.height))

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Keyboard Handling

    /// Handles key events from the panel
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }

        switch event.keyCode {
        case 125: // Down arrow
            viewModel.selectNext()
            return true
        case 126: // Up arrow
            viewModel.selectPrevious()
            return true
        case 36: // Return/Enter
            Task {
                await viewModel.pasteSelected()
            }
            return true
        case 53: // Escape
            hide()
            return true
        case 51: // Delete/Backspace
            Task {
                await viewModel.deleteSelected()
            }
            return true
        default:
            // Check for Cmd+S (favorite)
            if event.modifierFlags.contains(.command), event.keyCode == 1 {
                Task {
                    await viewModel.toggleFavorite()
                }
                return true
            }
            // Check for number keys 1-9 for quick selection (if enabled)
            if SettingsManager.shared.shortcuts.quickPasteEnabled,
               let number = numberFromKeyCode(event.keyCode), number >= 1, number <= 9 {
                let index = number - 1
                if index < viewModel.items.count {
                    viewModel.select(at: index)
                    Task {
                        await viewModel.pasteSelected()
                    }
                }
                return true
            }
            return false
        }
    }

    /// Converts key codes to numbers 1-9
    private func numberFromKeyCode(_ keyCode: UInt16) -> Int? {
        switch keyCode {
        case 18: return 1
        case 19: return 2
        case 20: return 3
        case 21: return 4
        case 23: return 5
        case 22: return 6
        case 26: return 7
        case 28: return 8
        case 25: return 9
        default: return nil
        }
    }

}

// MARK: - NSWindowDelegate

extension FloatingPanelController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        // Hide panel when it loses focus
        hide()
    }

    func windowWillClose(_ notification: Notification) {
        viewModel.isVisible = false
    }
}
