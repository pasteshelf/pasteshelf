//
//  LaunchAtLoginManager.swift
//  PasteShelf
//
//  Manages launch at login functionality using ServiceManagement framework.
//

import AppKit
import Combine
import Foundation
import os.log
import ServiceManagement

/// Manages the "Launch at Login" preference
@MainActor
final class LaunchAtLoginManager: ObservableObject {
    // MARK: - Singleton

    /// Shared instance
    static let shared = LaunchAtLoginManager()

    // MARK: - Published Properties

    /// Whether the app is configured to launch at login
    @Published private(set) var isEnabled: Bool = false

    // MARK: - Private Properties

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "launch-at-login"
    )

    // MARK: - Initialization

    private init() {
        refreshStatus()
    }

    // MARK: - Public Methods

    /// Enables or disables launch at login
    /// - Parameter enabled: Whether to enable launch at login
    /// - Returns: True if the change was successful
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            return setEnabledModern(enabled)
        } else {
            return setEnabledLegacy(enabled)
        }
    }

    /// Refreshes the current status
    func refreshStatus() {
        if #available(macOS 13.0, *) {
            refreshStatusModern()
        } else {
            refreshStatusLegacy()
        }
    }

    // MARK: - Modern Implementation (macOS 13+)

    @available(macOS 13.0, *)
    private func setEnabledModern(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                logger.info("Registered for launch at login")
            } else {
                try SMAppService.mainApp.unregister()
                logger.info("Unregistered from launch at login")
            }
            isEnabled = enabled
            return true
        } catch {
            logger.error("Failed to set launch at login: \(error.localizedDescription)")
            return false
        }
    }

    @available(macOS 13.0, *)
    private func refreshStatusModern() {
        isEnabled = SMAppService.mainApp.status == .enabled
        logger.debug("Launch at login status: \(self.isEnabled)")
    }

    // MARK: - Legacy Implementation (macOS 12 and earlier)

    private func setEnabledLegacy(_ enabled: Bool) -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            logger.error("Failed to get bundle identifier")
            return false
        }

        let result = SMLoginItemSetEnabled(bundleIdentifier as CFString, enabled)

        if result {
            isEnabled = enabled
            logger.info("Set launch at login (legacy): \(enabled)")
        } else {
            logger.error("Failed to set launch at login (legacy)")
        }

        return result
    }

    private func refreshStatusLegacy() {
        // Legacy API doesn't provide a way to check status
        // We rely on the last known state from UserDefaults
        isEnabled = SettingsManager.shared.general.launchAtLogin
    }
}

// MARK: - Dock Visibility Manager

/// Manages the app's Dock visibility
@MainActor
final class DockVisibilityManager {
    // MARK: - Singleton

    /// Shared instance
    static let shared = DockVisibilityManager()

    // MARK: - Private Properties

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "dock-visibility"
    )

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Whether the app is currently visible in the Dock
    var isVisible: Bool {
        NSApp.activationPolicy() == .regular
    }

    /// Sets whether the app should be visible in the Dock
    /// - Parameter visible: Whether to show in the Dock
    func setVisible(_ visible: Bool) {
        let policy: NSApplication.ActivationPolicy = visible ? .regular : .accessory
        let success = NSApp.setActivationPolicy(policy)

        if success {
            logger.info("Dock visibility set to: \(visible)")
        } else {
            logger.error("Failed to set dock visibility")
        }
    }
}
