//
//  ScreenshotUITests.swift
//  PasteShelfUITests
//
//  UI tests for capturing App Store screenshots.
//  Run with: xcodebuild test -scheme PasteShelf -only-testing:PasteShelfUITests/ScreenshotUITests
//

import XCTest

/// UI tests dedicated to capturing App Store screenshots.
/// These tests are designed to set up realistic content and capture high-quality screenshots
/// that showcase PasteShelf's features.
final class ScreenshotUITests: XCTestCase {
    // MARK: Internal

    var app: XCUIApplication!
    var locale: String = "en"

    override func setUpWithError() throws {
        continueAfterFailure = false

        self.app = XCUIApplication()

        // Skip onboarding for screenshot tests
        self.app.launchArguments.append("--skip-onboarding")

        // Enable screenshot mode with sample data
        self.app.launchArguments.append("--screenshot-mode")

        // Set locale from environment if provided
        if let testLocale = ProcessInfo.processInfo.environment["SCREENSHOT_LOCALE"] {
            self.locale = testLocale
            self.app.launchArguments.append("-AppleLanguages")
            self.app.launchArguments.append("(\(self.locale))")
        }

        // Set appearance from environment if provided
        if let appearance = ProcessInfo.processInfo.environment["SCREENSHOT_APPEARANCE"] {
            if appearance == "dark" {
                ScreenshotHelper.setAppearance(darkMode: true, app: self.app)
            } else {
                ScreenshotHelper.setAppearance(darkMode: false, app: self.app)
            }
        }

        self.app.launch()
    }

    override func tearDownWithError() throws {
        self.app = nil
    }

    // MARK: - Screenshot 1: Floating Panel Overview

    /// Captures the main floating panel showing clipboard history.
    /// Shows: 8-10 items, mixed content types, date groupings, search field, filter chips.
    @MainActor
    func testScreenshot1_FloatingPanelOverview() {
        // Open the floating panel via menu bar
        self.showFloatingPanel()

        // Wait for panel to appear and populate
        let panel = self.app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 5) else {
            XCTSkip("Floating panel not available for screenshot")
            return
        }

        // Ensure the panel is fully loaded with items
        ScreenshotHelper.waitForUI()

        // Verify key elements are visible
        XCTAssertTrue(panel.searchFields.firstMatch.exists || panel.textFields.firstMatch.exists,
                      "Search field should be visible")

        // Capture the screenshot
        ScreenshotHelper.captureScreenshot(
            name: .floatingPanelOverview,
            locale: self.locale,
            testCase: self
        )
    }

    // MARK: - Screenshot 2: Search in Action

    /// Captures the floating panel with an active search query.
    /// Shows: Search query typed, filtered results, highlighted matches.
    @MainActor
    func testScreenshot2_SearchInAction() {
        // Open the floating panel
        self.showFloatingPanel()

        let panel = self.app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 5) else {
            XCTSkip("Floating panel not available for screenshot")
            return
        }

        // Find and focus the search field
        let searchField = panel.searchFields.firstMatch
        if searchField.exists {
            searchField.click()
            ScreenshotHelper.waitForUI()

            // Type a search query
            searchField.typeText("email")
            ScreenshotHelper.waitForUI()

            // Wait for search results to filter
            Thread.sleep(forTimeInterval: 0.5)
        } else {
            // Try alternative text field
            let textField = panel.textFields["Search clipboard..."]
            if textField.exists {
                textField.click()
                textField.typeText("email")
                ScreenshotHelper.waitForUI()
            }
        }

        // Capture the screenshot with search active
        ScreenshotHelper.captureScreenshot(
            name: .searchInAction,
            locale: self.locale,
            testCase: self
        )
    }

    // MARK: - Screenshot 3: Preferences Window - Privacy Tab

    /// Captures the Preferences window showing the Privacy tab.
    /// Shows: Excluded apps list, privacy toggles, Clear History button.
    @MainActor
    func testScreenshot3_PreferencesPrivacy() {
        // Open Preferences via menu bar
        self.openPreferences()

        let prefsWindow = self.app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 5) else {
            XCTSkip("Preferences window not available for screenshot")
            return
        }

        // Navigate to Privacy tab
        let privacyTab = prefsWindow.buttons["Privacy"]
        if privacyTab.exists {
            privacyTab.click()
            ScreenshotHelper.waitForUI()
        }

        // Verify Privacy content is showing
        XCTAssertTrue(
            prefsWindow.staticTexts["Excluded Apps"].exists ||
                prefsWindow.staticTexts["Privacy"].exists ||
                prefsWindow.buttons["Clear History"].exists,
            "Privacy tab content should be visible"
        )

        // Capture the screenshot
        ScreenshotHelper.captureScreenshot(
            name: .preferencesPrivacy,
            locale: self.locale,
            testCase: self
        )
    }

    // MARK: - Screenshot 4: Menu Bar Integration

    /// Captures the menu bar dropdown showing recent items.
    /// Note: This screenshot may need manual capture due to NSStatusItem limitations.
    /// Shows: Menu bar icon, dropdown with recent items, quick actions.
    @MainActor
    func testScreenshot4_MenuBarIntegration() {
        // Click the menu bar item to open dropdown
        let menuBarItem = self.app.menuBars.statusItems.firstMatch
        guard menuBarItem.exists else {
            XCTSkip("Menu bar item not available for screenshot")
            return
        }

        menuBarItem.click()
        ScreenshotHelper.waitForUI()

        // Wait for menu to appear
        let showPanelItem = self.app.menuItems["Show Clipboard Panel"]
        guard showPanelItem.waitForExistence(timeout: 3) else {
            XCTSkip("Menu dropdown not available for screenshot")
            return
        }

        // Capture the screenshot with menu open
        // Note: This captures the full screen including the menu
        ScreenshotHelper.captureScreenshot(
            name: .menuBarIntegration,
            locale: self.locale,
            testCase: self
        )

        // Dismiss the menu
        self.app.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - Screenshot 5: Keyboard Shortcuts

    /// Captures the Preferences window showing the Shortcuts tab.
    /// Shows: Global hotkey configuration, navigation shortcuts.
    @MainActor
    func testScreenshot5_KeyboardShortcuts() {
        // Open Preferences via menu bar
        self.openPreferences()

        let prefsWindow = self.app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 5) else {
            XCTSkip("Preferences window not available for screenshot")
            return
        }

        // Navigate to Shortcuts tab
        let shortcutsTab = prefsWindow.buttons["Shortcuts"]
        if shortcutsTab.exists {
            shortcutsTab.click()
            ScreenshotHelper.waitForUI()
        }

        // Verify Shortcuts content is showing
        XCTAssertTrue(
            prefsWindow.staticTexts["Global Hotkey"].exists ||
                prefsWindow.staticTexts["Shortcuts"].exists ||
                prefsWindow.staticTexts.matching(NSPredicate(format: "label CONTAINS '⌘'")).firstMatch.exists,
            "Shortcuts tab content should be visible"
        )

        // Capture the screenshot
        ScreenshotHelper.captureScreenshot(
            name: .keyboardShortcuts,
            locale: self.locale,
            testCase: self
        )
    }

    // MARK: - Batch Screenshot Capture

    /// Runs all screenshots in sequence for a given locale.
    /// This is useful for generating a complete set of localized screenshots.
    @MainActor
    func testAllScreenshots() throws {
        // Run each screenshot test in order
        try self.testScreenshot1_FloatingPanelOverview()

        // Reset app state between screenshots
        self.app.terminate()
        self.app.launch()
        try self.testScreenshot2_SearchInAction()

        self.app.terminate()
        self.app.launch()
        try self.testScreenshot3_PreferencesPrivacy()

        self.app.terminate()
        self.app.launch()
        try self.testScreenshot4_MenuBarIntegration()

        self.app.terminate()
        self.app.launch()
        try self.testScreenshot5_KeyboardShortcuts()
    }

    // MARK: - Dark Mode Screenshots (Optional)

    /// Captures all screenshots in dark mode.
    @MainActor
    func testAllScreenshots_DarkMode() throws {
        // Terminate and relaunch with dark mode
        self.app.terminate()
        ScreenshotHelper.setAppearance(darkMode: true, app: self.app)
        self.locale = "en_dark" // Mark as dark mode variant
        self.app.launch()

        try self.testAllScreenshots()
    }

    // MARK: Private

    // MARK: - Helper Methods

    /// Opens the floating clipboard panel via menu bar.
    private func showFloatingPanel() {
        let menuBarItem = self.app.menuBars.statusItems.firstMatch
        if menuBarItem.exists {
            menuBarItem.click()

            let showPanel = self.app.menuItems["Show Clipboard Panel"]
            if showPanel.waitForExistence(timeout: 2) {
                showPanel.click()
            }
        }
    }

    /// Opens the Preferences window via menu bar.
    private func openPreferences() {
        let menuBarItem = self.app.menuBars.statusItems.firstMatch
        if menuBarItem.exists {
            menuBarItem.click()

            let prefsMenuItem = self.app.menuItems["Preferences..."]
            if prefsMenuItem.waitForExistence(timeout: 2) {
                prefsMenuItem.click()
            }
        }
    }
}
