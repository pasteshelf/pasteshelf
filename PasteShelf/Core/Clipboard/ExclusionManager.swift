//
//  ExclusionManager.swift
//  PasteShelf
//
//  Manages app exclusions for clipboard capture including
//  default password manager exclusions and private browsing detection.
//

import AppKit
import Foundation
import os.log

/// Manages which applications should be excluded from clipboard capture
@MainActor
final class ExclusionManager: AppExcluding {
    // MARK: - Singleton

    /// Shared instance for app-wide use
    static let shared = ExclusionManager()

    // MARK: - Constants

    /// Default excluded apps (password managers, sensitive apps)
    let defaultExcludedBundleIds: [String] = [
        // Password Managers
        "com.1password.1Password",
        "com.1password.1password7",
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword-osx",
        "com.bitwarden.desktop",
        "com.lastpass.LastPass",
        "com.lastpass.LastPassHelper",
        "de.kps-software.enpass",
        "com.dashlane.Dashlane",
        "com.nordpass.NordPass",
        "com.keepersecurity.keeper",
        "com.apple.keychainaccess",

        // System Security
        "com.apple.systempreferences",
        "com.apple.security.coreservices",

        // Other Security Tools
        "com.apple.dt.Xcode.sourcecontrol.Git",
        "com.apple.Terminal"
    ]

    /// Browser bundle IDs for private browsing detection
    private let browserBundleIds: [String: BrowserType] = [
        "com.apple.Safari": .safari,
        "com.google.Chrome": .chrome,
        "com.google.Chrome.canary": .chrome,
        "org.chromium.Chromium": .chrome,
        "com.brave.Browser": .chrome,
        "com.microsoft.edgemac": .chrome,
        "com.vivaldi.Vivaldi": .chrome,
        "org.mozilla.firefox": .firefox,
        "org.mozilla.firefoxdeveloperedition": .firefox,
        "com.operasoftware.Opera": .chrome
    ]

    private enum BrowserType {
        case safari
        case chrome
        case firefox
    }

    // MARK: - Properties

    /// User-customized excluded bundle IDs (stored in UserDefaults)
    private var userExcludedBundleIds: Set<String> {
        didSet {
            saveUserExclusions()
        }
    }

    /// Whether to exclude own app by default
    private let excludeOwnApp: Bool

    /// Own bundle ID
    private let ownBundleId: String

    // MARK: - Initialization

    private init(excludeOwnApp: Bool = true) {
        self.excludeOwnApp = excludeOwnApp
        self.ownBundleId = Bundle.main.bundleIdentifier ?? "com.pasteshelf.PasteShelf"
        self.userExcludedBundleIds = Self.loadUserExclusions()
    }

    /// Creates an ExclusionManager for testing
    static func forTesting(
        defaultExclusions: [String] = [],
        userExclusions: Set<String> = [],
        excludeOwnApp: Bool = false
    ) -> ExclusionManager {
        let manager = ExclusionManager(excludeOwnApp: excludeOwnApp)
        manager.userExcludedBundleIds = userExclusions
        return manager
    }

    // MARK: - AppExcluding

    var excludedBundleIds: [String] {
        var allExcluded = Set(defaultExcludedBundleIds)
        allExcluded.formUnion(userExcludedBundleIds)
        if excludeOwnApp {
            allExcluded.insert(ownBundleId)
        }
        return Array(allExcluded).sorted()
    }

    func isExcluded(bundleId: String) -> Bool {
        // Check own app
        if excludeOwnApp && bundleId == ownBundleId {
            return true
        }

        // Check default exclusions
        if defaultExcludedBundleIds.contains(bundleId) {
            return true
        }

        // Check user exclusions
        if userExcludedBundleIds.contains(bundleId) {
            return true
        }

        // Check wildcard patterns (e.g., "com.1password.*")
        for defaultId in defaultExcludedBundleIds where defaultId.hasSuffix("*") {
            let prefix = String(defaultId.dropLast())
            if bundleId.hasPrefix(prefix) {
                return true
            }
        }

        return false
    }

    func exclude(bundleId: String) {
        guard !defaultExcludedBundleIds.contains(bundleId) else {
            Logger.clipboard.debug("Bundle ID \(bundleId) is already in default exclusions")
            return
        }
        userExcludedBundleIds.insert(bundleId)
        Logger.clipboard.info("Added \(bundleId) to exclusion list")
    }

    func include(bundleId: String) {
        guard !defaultExcludedBundleIds.contains(bundleId) else {
            Logger.clipboard.warning("Cannot include default-excluded app: \(bundleId)")
            return
        }
        userExcludedBundleIds.remove(bundleId)
        Logger.clipboard.info("Removed \(bundleId) from exclusion list")
    }

    func isPrivateBrowsingActive() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier,
              let browserType = browserBundleIds[bundleId] else {
            return false
        }

        // Get the frontmost window title
        guard let windowTitle = getActiveWindowTitle() else {
            return false
        }

        return isPrivateBrowsingWindow(title: windowTitle, browser: browserType)
    }

    // MARK: - Private Browsing Detection

    /// Detects if a window title indicates private browsing
    private func isPrivateBrowsingWindow(title: String, browser: BrowserType) -> Bool {
        let lowercased = title.lowercased()

        switch browser {
        case .safari:
            // Safari uses "Private" in window title
            return lowercased.contains("private")

        case .chrome:
            // Chrome/Edge/Brave use "Incognito" or "InPrivate"
            return lowercased.contains("incognito") || lowercased.contains("inprivate")

        case .firefox:
            // Firefox uses "Private Browsing"
            return lowercased.contains("private browsing")
        }
    }

    /// Gets the title of the active window using Accessibility API
    private func getActiveWindowTitle() -> String? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let pid = frontApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        guard result == .success,
              let windowElement = focusedWindow else {
            return nil
        }

        var titleValue: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(
            // swiftlint:disable:next force_cast
            windowElement as! AXUIElement,
            kAXTitleAttribute as CFString,
            &titleValue
        )

        guard titleResult == .success,
              let title = titleValue as? String else {
            return nil
        }

        return title
    }

    // MARK: - Persistence

    private static let userExclusionsKey = "PasteShelf.UserExcludedBundleIds"

    private static func loadUserExclusions() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: userExclusionsKey) ?? []
        return Set(array)
    }

    private func saveUserExclusions() {
        UserDefaults.standard.set(
            Array(userExcludedBundleIds),
            forKey: Self.userExclusionsKey
        )
    }

    // MARK: - Utility Methods

    /// Check if current capture should be excluded based on frontmost app
    func shouldExcludeCurrentCapture() -> (excluded: Bool, reason: ExclusionReason?) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else {
            return (false, nil)
        }

        // Check app exclusion
        if isExcluded(bundleId: bundleId) {
            return (true, .excludedApp(bundleId: bundleId))
        }

        // Check private browsing (only if the setting is enabled)
        if SettingsManager.shared.privacy.excludePrivateBrowsing, isPrivateBrowsingActive() {
            return (true, .privateBrowsing)
        }

        return (false, nil)
    }

    /// Returns info about why an app is excluded (for UI display)
    func exclusionInfo(for bundleId: String) -> ExclusionInfo? {
        guard isExcluded(bundleId: bundleId) else { return nil }

        if bundleId == ownBundleId {
            return ExclusionInfo(
                bundleId: bundleId,
                reason: "Own application",
                isDefault: true,
                isRemovable: false
            )
        }

        if defaultExcludedBundleIds.contains(bundleId) {
            return ExclusionInfo(
                bundleId: bundleId,
                reason: "Password manager or security app",
                isDefault: true,
                isRemovable: false
            )
        }

        return ExclusionInfo(
            bundleId: bundleId,
            reason: "User excluded",
            isDefault: false,
            isRemovable: true
        )
    }
}

// MARK: - Supporting Types

/// Information about why an app is excluded
struct ExclusionInfo {
    let bundleId: String
    let reason: String
    let isDefault: Bool
    let isRemovable: Bool
}
