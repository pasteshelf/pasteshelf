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

    /// Timer that keeps the panel on top of aggressive always-on-top windows
    /// (e.g. FortiClient's credential prompt) while the panel is visible.
    private var topmostEnforcementTimer: Timer?

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

        // Configure panel properties.
        // Start at the maximum documented window level. This alone is NOT
        // sufficient against aggressive prompts (e.g. FortiClient's credential
        // dialog): the WindowServer honors raw levels up to INT32_MAX, and at
        // equal levels z-order decides — which such dialogs re-assert on a
        // timer. While visible, enforceTopmost() adapts the level to whatever
        // is covering the panel and re-fronts it.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Create SwiftUI hosting view
        let contentView = FloatingPanelView(viewModel: viewModel)
            .environmentObject(SettingsManager.shared)
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

    /// Shows the floating panel, gated by security and HIPAA lock checks.
    func show() {
        Task {
            // Gate 1: General security lock (biometric auth from SecuritySettings)
            if SecurityLockService.shared.isLocked {
                let unlocked = await SecurityLockService.shared.unlock()
                guard unlocked else {
                    logger.debug("Panel show blocked by security lock")
                    return
                }
            }

            // Gate 2: HIPAA access control lock (if HIPAA compliance is active)
            if HIPAAAccessControlService.shared.isLocked {
                let unlocked = await HIPAAAccessControlService.shared.unlock()
                guard unlocked else {
                    logger.debug("Panel show blocked by HIPAA lock")
                    return
                }
            }

            // Record activity for inactivity timeout tracking
            SecurityLockService.shared.recordActivity()
            HIPAAAccessControlService.shared.recordActivity()

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

        // Show and order front. orderFrontRegardless() forces the panel above
        // windows of other (possibly active) apps, regardless of activation —
        // needed to clear high-level prompts like FortiClient's credential box.
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        // Activate without stealing focus from other apps
        NSApp.activate(ignoringOtherApps: true)

        startTopmostEnforcement()

        logger.debug("Panel shown")
    }

    private func hidePanel() {
        stopTopmostEnforcement()
        guard panel?.isVisible == true else { return }
        panel?.orderOut(nil)
        logger.debug("Panel hidden")
    }

    // MARK: - Topmost Enforcement

    /// Keeps the panel above aggressive always-on-top windows while visible.
    ///
    /// A static window level cannot guarantee this: the WindowServer honors
    /// raw levels up to INT32_MAX from any app, and when two windows share a
    /// level, z-order decides — which prompts like FortiClient's credential
    /// dialog re-assert on their own timer. So while the panel is visible we
    /// periodically look for another app's window that is both above the
    /// panel in z-order and overlapping it, match its level, and re-front.
    private func startTopmostEnforcement() {
        stopTopmostEnforcement()
        enforceTopmost()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.enforceTopmost()
            }
        }
        // .common so the timer keeps firing during event tracking (scrolling).
        RunLoop.main.add(timer, forMode: .common)
        topmostEnforcementTimer = timer
    }

    private func stopTopmostEnforcement() {
        topmostEnforcementTimer?.invalidate()
        topmostEnforcementTimer = nil
    }

    private func enforceTopmost() {
        guard let panel = panel, panel.isVisible else { return }
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return }

        // CG window bounds use a top-left-origin global space anchored to the
        // primary screen; flip the panel frame to compare.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        var panelBounds = panel.frame
        panelBounds.origin.y = primaryHeight - panelBounds.maxY

        let myPID = ProcessInfo.processInfo.processIdentifier

        // The list is ordered front-to-back, so every window before ours is
        // above us. Find the first one from another app that overlaps the
        // panel — that's what is covering us.
        for window in windows {
            if window[kCGWindowNumber as String] as? Int == panel.windowNumber {
                return // Reached ourselves: nothing relevant is above us.
            }
            guard (window[kCGWindowOwnerPID as String] as? Int32) != myPID,
                  (window[kCGWindowOwnerName as String] as? String) != "Window Server",
                  let layer = window[kCGWindowLayer as String] as? Int,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.intersects(panelBounds)
            else { continue }

            // Go one level above the covering window so z-order no longer
            // matters (a tie flickers if the other window also re-fronts).
            // Never exceed INT32_MAX, the WindowServer's true ceiling.
            let target = min(max(layer + 1, panel.level.rawValue), Int(Int32.max))
            if panel.level.rawValue < target {
                panel.level = NSWindow.Level(rawValue: target)
                logger.info("Raised panel level to \(target) to clear covering window")
            }
            panel.orderFrontRegardless()
            return
        }
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

        // Record activity for inactivity timeout tracking
        SecurityLockService.shared.recordActivity()
        HIPAAAccessControlService.shared.recordActivity()

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
