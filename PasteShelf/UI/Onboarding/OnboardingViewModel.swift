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
import os.log
import UserNotifications

// MARK: - OnboardingViewModel

/// View model for managing onboarding state
@MainActor
final class OnboardingViewModel: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    init() {
        #if !APP_STORE
            self.checkAccessibilityPermission()
        #endif
        Task { await self.checkNotificationPermission() }
    }

    deinit {
        permissionCheckTimer?.invalidate()
        notificationCheckTimer?.invalidate()
    }

    // MARK: Internal

    // MARK: - Constants

    /// UserDefaults key for tracking onboarding completion
    static let onboardingCompletedKey = "hasCompletedOnboarding"

    /// UserDefaults key for onboarding version (for future re-onboarding)
    static let onboardingVersionKey = "onboardingVersion"

    /// Current onboarding version
    static let currentOnboardingVersion = 1

    // MARK: - Published Properties

    /// Current step in the onboarding flow
    @Published var currentStep: OnboardingStep = .welcome

    /// Whether accessibility permission is granted
    @Published var hasAccessibilityPermission = false

    /// Whether notification permission is granted
    @Published var hasNotificationPermission = false

    /// Whether the onboarding is complete
    @Published var isComplete = false

    // MARK: - Public Methods

    /// Check if onboarding should be shown
    static func shouldShowOnboarding() -> Bool {
        let defaults = UserDefaults.standard
        let hasCompleted = defaults.bool(forKey: self.onboardingCompletedKey)
        let savedVersion = defaults.integer(forKey: self.onboardingVersionKey)

        // Show if never completed or version is outdated
        return !hasCompleted || savedVersion < self.currentOnboardingVersion
    }

    /// Reset onboarding (for testing)
    static func resetOnboarding() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: self.onboardingCompletedKey)
        defaults.removeObject(forKey: self.onboardingVersionKey)
    }

    /// Mark onboarding as complete
    func completeOnboarding() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Self.onboardingCompletedKey)
        defaults.set(Self.currentOnboardingVersion, forKey: Self.onboardingVersionKey)
        self.isComplete = true
        self.stopPermissionChecking()
        self.stopNotificationChecking()
        self.logger.info("Onboarding completed")
    }

    /// Move to the next step
    func nextStep() {
        if let next = currentStep.next {
            self.currentStep = next
            self.logger.debug("Moved to step: \(next.title)")

            #if !APP_STORE
                if next == .permissions {
                    self.startPermissionChecking()
                }
            #endif
            if next == .notifications {
                self.startNotificationChecking()
            }
        } else {
            self.completeOnboarding()
        }
    }

    /// Move to the previous step
    func previousStep() {
        if let previous = currentStep.previous {
            self.currentStep = previous
            self.logger.debug("Moved back to step: \(previous.title)")
        }
    }

    /// Skip the current step if allowed
    func skipStep() {
        guard self.currentStep.isSkippable else {
            return
        }
        self.nextStep()
    }

    /// Check accessibility permission status
    func checkAccessibilityPermission() {
        #if !APP_STORE
            #if DEBUG
                if CommandLine.arguments.contains("--bypass-permissions") {
                    self.hasAccessibilityPermission = true
                    return
                }
            #endif
            self.hasAccessibilityPermission = AXIsProcessTrusted()
            self.logger.debug("Accessibility permission: \(self.hasAccessibilityPermission)")
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

            self.hasAccessibilityPermission = trusted
            self.logger.info("Requested accessibility permission, trusted: \(trusted)")
        #endif
    }

    /// Start periodic permission checking
    func startPermissionChecking() {
        #if !APP_STORE
            self.stopPermissionChecking()
            self.permissionCheckTimer = Timer.scheduledTimer(
                withTimeInterval: 1.0,
                repeats: true
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.checkAccessibilityPermission()
                }
            }
        #endif
    }

    /// Stop periodic permission checking
    func stopPermissionChecking() {
        self.permissionCheckTimer?.invalidate()
        self.permissionCheckTimer = nil
    }

    // MARK: - Notification Permission

    /// Check notification permission status
    func checkNotificationPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.hasNotificationPermission = settings.authorizationStatus == .authorized
        self.logger.debug("Notification permission: \(self.hasNotificationPermission)")
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
                    self.hasNotificationPermission = granted
                    self.logger.info("Requested notification permission, granted: \(granted)")
                } catch {
                    self.logger.error("Failed to request notification permission: \(error.localizedDescription)")
                }
            } else {
                // Previously denied — open System Settings
                self.openNotificationSettings()
            }
        }
    }

    /// Start periodic notification permission checking
    func startNotificationChecking() {
        self.stopNotificationChecking()
        self.notificationCheckTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.checkNotificationPermission()
            }
        }
    }

    /// Stop periodic notification permission checking
    func stopNotificationChecking() {
        self.notificationCheckTimer?.invalidate()
        self.notificationCheckTimer = nil
    }

    // MARK: Private

    /// Timer for permission checking
    private var permissionCheckTimer: Timer?

    /// Timer for notification permission checking
    private var notificationCheckTimer: Timer?

    // MARK: - Private Properties

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "onboarding"
    )

    /// Opens System Settings to the Notifications pane for PasteShelf
    private func openNotificationSettings() {
        if let bundleId = Bundle.main.bundleIdentifier,
           let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleId)")
        {
            NSWorkspace.shared.open(url)
        }
    }
}
