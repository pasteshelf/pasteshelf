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

/// Controller for the onboarding window
@MainActor
final class OnboardingWindowController: NSObject {
    // MARK: - Singleton

    /// Shared instance
    static let shared = OnboardingWindowController()

    // MARK: - Properties

    /// The onboarding window
    private var window: NSWindow?

    /// View model for the onboarding flow
    private var viewModel: OnboardingViewModel?

    /// Callback when onboarding completes
    var onComplete: (() -> Void)?

    /// Logger for onboarding operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "onboarding"
    )

    // MARK: - Configuration

    /// Window width
    private let windowWidth: CGFloat = 560

    /// Window height
    private let windowHeight: CGFloat = 600

    // MARK: - Initialization

    override private init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Shows the onboarding window
    func show(completion: (() -> Void)? = nil) {
        onComplete = completion

        if window == nil {
            createWindow()
        }

        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        logger.info("Onboarding window shown")
    }

    /// Hides the onboarding window
    func hide() {
        window?.orderOut(nil)
        logger.debug("Onboarding window hidden")
    }

    /// Closes the onboarding window
    func close() {
        window?.close()
        window = nil
        viewModel = nil
        logger.debug("Onboarding window closed")
    }

    /// Check if onboarding should be shown
    func shouldShowOnboarding() -> Bool {
        OnboardingViewModel.shouldShowOnboarding()
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
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Welcome to PasteShelf"
        window.isReleasedWhenClosed = false
        window.center()

        // Create view model
        let vm = OnboardingViewModel()
        viewModel = vm

        // Create SwiftUI content
        let contentView = OnboardingView(viewModel: vm)
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

        logger.info("Onboarding window created")
    }

    private func handleCompletion() {
        logger.info("Onboarding completed, closing window")
        let completion = onComplete
        onComplete = nil
        close()
        completion?()
    }
}

// MARK: - NSWindowDelegate

extension OnboardingWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // If user closes window before completing, mark as completed anyway
        // to avoid showing on every launch
        if viewModel?.isComplete == false {
            viewModel?.completeOnboarding()
        }
        let completion = onComplete
        onComplete = nil
        completion?()
        logger.debug("Onboarding window will close")
    }

    func windowDidBecomeKey(_ notification: Notification) {
        logger.debug("Onboarding window became key")
    }
}
