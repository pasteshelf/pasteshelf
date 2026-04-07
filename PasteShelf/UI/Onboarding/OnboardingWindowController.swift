//
//  OnboardingWindowController.swift
//  PasteShelf
//
//  Controller for the onboarding window.
//  Manages window lifecycle and completion callback.
//

import AppKit
import os.log
import SwiftUI

// MARK: - OnboardingWindowController

/// Controller for the onboarding window
@MainActor
final class OnboardingWindowController: NSObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    override private init() {
        super.init()
    }

    // MARK: Internal

    // MARK: - Singleton

    /// Shared instance
    static let shared = OnboardingWindowController()

    /// Callback when onboarding completes
    var onComplete: (() -> Void)?

    // MARK: - Public Methods

    /// Shows the onboarding window
    func show(completion: (() -> Void)? = nil) {
        self.onComplete = completion

        if self.window == nil {
            self.createWindow()
        }

        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.logger.info("Onboarding window shown")
    }

    /// Hides the onboarding window
    func hide() {
        self.window?.orderOut(nil)
        self.logger.debug("Onboarding window hidden")
    }

    /// Closes the onboarding window
    func close() {
        self.window?.close()
        self.window = nil
        self.viewModel = nil
        self.logger.debug("Onboarding window closed")
    }

    /// Check if onboarding should be shown
    func shouldShowOnboarding() -> Bool {
        OnboardingViewModel.shouldShowOnboarding()
    }

    // MARK: Private

    /// The onboarding window
    private var window: NSWindow?

    /// View model for the onboarding flow
    private var viewModel: OnboardingViewModel?

    /// Logger for onboarding operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "onboarding"
    )

    // MARK: - Configuration

    /// Window width
    private let windowWidth: CGFloat = 520

    /// Window height
    private let windowHeight: CGFloat = 560

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
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Welcome to PasteShelf"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.center()

        // Create view model
        let vm = OnboardingViewModel()
        self.viewModel = vm

        // Create SwiftUI content
        let contentView = OnboardingView(viewModel: vm)
            .environmentObject(SettingsManager.shared)
            .onReceive(vm.$isComplete) { [weak self] isComplete in
                if isComplete {
                    self?.handleCompletion()
                }
            }
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = contentRect

        window.contentView = hostingView
        window.delegate = self

        self.window = window

        self.logger.info("Onboarding window created")
    }

    private func handleCompletion() {
        self.logger.info("Onboarding completed, closing window")
        let completion = self.onComplete
        self.onComplete = nil
        self.close()
        completion?()
    }
}

// MARK: NSWindowDelegate

extension OnboardingWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // If user closes window before completing, mark as completed anyway
        // to avoid showing on every launch
        if self.viewModel?.isComplete == false {
            self.viewModel?.completeOnboarding()
        }
        let completion = self.onComplete
        self.onComplete = nil
        completion?()
        self.logger.debug("Onboarding window will close")
    }

    func windowDidBecomeKey(_ notification: Notification) {
        self.logger.debug("Onboarding window became key")
    }
}
