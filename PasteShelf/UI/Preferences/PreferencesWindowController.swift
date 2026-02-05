//
//  PreferencesWindowController.swift
//  PasteShelf
//
//  Controller for the preferences window.
//  Manages window lifecycle and SwiftUI hosting.
//

import AppKit
import os.log
import SwiftUI

/// Controller for the preferences window
@MainActor
final class PreferencesWindowController: NSObject {
    // MARK: - Singleton

    /// Shared instance
    static let shared = PreferencesWindowController()

    // MARK: - Properties

    /// The preferences window
    private var window: NSWindow?

    /// Logger for preferences operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "preferences"
    )

    // MARK: - Configuration

    /// Window width
    private let windowWidth: CGFloat = 700

    /// Window height
    private let windowHeight: CGFloat = 450

    // MARK: - Initialization

    override private init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Shows the preferences window
    func show() {
        if window == nil {
            createWindow()
        }

        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        logger.debug("Preferences window shown")
    }

    /// Hides the preferences window
    func hide() {
        window?.orderOut(nil)
        logger.debug("Preferences window hidden")
    }

    /// Closes the preferences window
    func close() {
        window?.close()
        window = nil
        logger.debug("Preferences window closed")
    }

    // MARK: - Private Methods

    private func createWindow() {
        let contentRect = NSRect(
            x: 0,
            y: 0,
            width: windowWidth,
            height: windowHeight
        )

        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Preferences"
        window.minSize = NSSize(width: windowWidth, height: windowHeight)
        window.isReleasedWhenClosed = false
        window.center()

        // Create SwiftUI content
        let viewModel = PreferencesViewModel()
        let contentView = PreferencesView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = contentRect

        window.contentView = hostingView
        window.delegate = self

        self.window = window

        logger.info("Preferences window created")
    }
}

// MARK: - NSWindowDelegate

extension PreferencesWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        logger.debug("Preferences window will close")
    }

    func windowDidBecomeKey(_ notification: Notification) {
        logger.debug("Preferences window became key")
    }
}
