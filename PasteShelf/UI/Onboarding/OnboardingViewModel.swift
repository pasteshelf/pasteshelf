//
//  OnboardingViewModel.swift
//  PasteShelf
//
//  State management for the onboarding flow.
//

import AppKit
#if !APP_STORE
import ApplicationServices
#endif
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
    @Published var isNotificationPermissionDenied = false

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
        #if !APP_STORE
        checkAccessibilityPermission()
        #endif
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
        // Leaving the notifications step doubles as the permission request
        // (first decision only) — the step has no separate request button.
        if currentStep == .notifications {
            Task { @MainActor in
                await requestNotificationPermissionIfNeeded()
                advanceStep()
            }
            return
        }
        advanceStep()
    }

    private func advanceStep() {
        if let next = currentStep.next {
            currentStep = next
            logger.debug("Moved to step: \(String(describing: next))")

            #if !APP_STORE
            if next == .permissions {
                startPermissionChecking()
            }
            #endif
            if next == .notifications {
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
            logger.debug("Moved back to step: \(String(describing: previous))")
        }
    }

    /// Skip the current step if allowed
    func skipStep() {
        guard currentStep.isSkippable else { return }
        nextStep()
    }

    /// Check accessibility permission status
    func checkAccessibilityPermission() {
        #if !APP_STORE
        #if DEBUG
        if CommandLine.arguments.contains("--bypass-permissions") {
            hasAccessibilityPermission = true
            return
        }
        #endif
        hasAccessibilityPermission = AXIsProcessTrusted()
        logger.debug("Accessibility permission: \(self.hasAccessibilityPermission)")
        #endif
    }

    /// Request accessibility permission by opening System Settings
    func requestAccessibilityPermission() {
        #if !APP_STORE
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
        #endif
    }

    /// Start periodic permission checking
    func startPermissionChecking() {
        #if !APP_STORE
        stopPermissionChecking()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.checkAccessibilityPermission()
            }
        }
        #endif
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
        let status = settings.authorizationStatus
        hasNotificationPermission = status == .authorized || status == .provisional
        isNotificationPermissionDenied = status == .denied
        logger.debug("Notification permission: \(self.hasNotificationPermission)")
    }

    /// Shows the system notification prompt if the user has not decided yet.
    /// Previously-decided states are left alone (recovery goes through the
    /// step's explicit "Open System Settings" button).
    func requestNotificationPermissionIfNeeded() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            hasNotificationPermission = granted
            isNotificationPermissionDenied = !granted
            logger.info("Requested notification permission, granted: \(granted)")
        } catch {
            logger.error("Failed to request notification permission: \(error.localizedDescription)")
        }
    }

    /// Opens System Settings to the Notifications pane for PasteShelf
    func openNotificationSettings() {
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
