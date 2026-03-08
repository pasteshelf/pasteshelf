//
//  OnboardingViewModel.swift
//  PasteShelf
//
//  State management for the onboarding flow.
//

import AppKit
import ApplicationServices
import Combine
import Foundation
import UserNotifications
import os.log

/// View model for managing onboarding state
@MainActor
final class OnboardingViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Current step in the onboarding flow
    @Published var currentStep: OnboardingStep = .welcome

    /// Whether accessibility permission is granted
    @Published var hasAccessibilityPermission = false

    /// Whether notification permission is granted
    @Published var hasNotificationPermission = false

    /// Whether the onboarding is complete
    @Published var isComplete = false

    /// Timer for permission checking
    private var permissionCheckTimer: Timer?

    /// Timer for notification permission checking
    private var notificationCheckTimer: Timer?

    // MARK: - Private Properties

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "onboarding"
    )

    // MARK: - Constants

    /// UserDefaults key for tracking onboarding completion
    static let onboardingCompletedKey = "hasCompletedOnboarding"

    /// UserDefaults key for onboarding version (for future re-onboarding)
    static let onboardingVersionKey = "onboardingVersion"

    /// Current onboarding version
    static let currentOnboardingVersion = 1

    // MARK: - Initialization

    init() {
        checkAccessibilityPermission()
        Task { await checkNotificationPermission() }
    }

    deinit {
        permissionCheckTimer?.invalidate()
        notificationCheckTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Check if onboarding should be shown
    static func shouldShowOnboarding() -> Bool {
        let defaults = UserDefaults.standard
        let hasCompleted = defaults.bool(forKey: onboardingCompletedKey)
        let savedVersion = defaults.integer(forKey: onboardingVersionKey)

        // Show if never completed or version is outdated
        return !hasCompleted || savedVersion < currentOnboardingVersion
    }

    /// Mark onboarding as complete
    func completeOnboarding() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Self.onboardingCompletedKey)
        defaults.set(Self.currentOnboardingVersion, forKey: Self.onboardingVersionKey)
        isComplete = true
        stopPermissionChecking()
        stopNotificationChecking()
        logger.info("Onboarding completed")
    }

    /// Move to the next step
    func nextStep() {
        if let next = currentStep.next {
            currentStep = next
            logger.debug("Moved to step: \(next.title)")

            if next == .permissions {
                startPermissionChecking()
            } else if next == .notifications {
                startNotificationChecking()
            }
        } else {
            completeOnboarding()
        }
    }

    /// Move to the previous step
    func previousStep() {
        if let previous = currentStep.previous {
            currentStep = previous
            logger.debug("Moved back to step: \(previous.title)")
        }
    }

    /// Skip the current step if allowed
    func skipStep() {
        guard currentStep.isSkippable else { return }
        nextStep()
    }

    /// Check accessibility permission status
    func checkAccessibilityPermission() {
        #if DEBUG
        if CommandLine.arguments.contains("--bypass-permissions") {
            hasAccessibilityPermission = true
            return
        }
        #endif
        hasAccessibilityPermission = AXIsProcessTrusted()
        logger.debug("Accessibility permission: \(self.hasAccessibilityPermission)")
    }

    /// Request accessibility permission by opening System Settings
    func requestAccessibilityPermission() {
        // Create prompt options to trigger the system permission dialog
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !trusted {
            // Open System Settings to Accessibility pane
            if let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            ) {
                NSWorkspace.shared.open(url)
            }
        }

        hasAccessibilityPermission = trusted
        logger.info("Requested accessibility permission, trusted: \(trusted)")
    }

    /// Start periodic permission checking
    func startPermissionChecking() {
        stopPermissionChecking()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.checkAccessibilityPermission()
            }
        }
    }

    /// Stop periodic permission checking
    func stopPermissionChecking() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }

    // MARK: - Notification Permission

    /// Check notification permission status
    func checkNotificationPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        hasNotificationPermission = settings.authorizationStatus == .authorized
        logger.debug("Notification permission: \(self.hasNotificationPermission)")
    }

    /// Request notification permission
    func requestNotificationPermission() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()

            if settings.authorizationStatus == .notDetermined {
                // First time — show system prompt
                do {
                    let granted = try await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound, .badge])
                    hasNotificationPermission = granted
                    logger.info("Requested notification permission, granted: \(granted)")
                } catch {
                    logger.error("Failed to request notification permission: \(error.localizedDescription)")
                }
            } else {
                // Previously denied — open System Settings
                openNotificationSettings()
            }
        }
    }

    /// Opens System Settings to the Notifications pane for PasteShelf
    private func openNotificationSettings() {
        if let bundleId = Bundle.main.bundleIdentifier,
           let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleId)")
        {
            NSWorkspace.shared.open(url)
        }
    }

    /// Start periodic notification permission checking
    func startNotificationChecking() {
        stopNotificationChecking()
        notificationCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                await self?.checkNotificationPermission()
            }
        }
    }

    /// Stop periodic notification permission checking
    func stopNotificationChecking() {
        notificationCheckTimer?.invalidate()
        notificationCheckTimer = nil
    }

    /// Reset onboarding (for testing)
    static func resetOnboarding() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: onboardingCompletedKey)
        defaults.removeObject(forKey: onboardingVersionKey)
    }
}
