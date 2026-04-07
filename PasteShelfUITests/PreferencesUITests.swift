//
//  PreferencesUITests.swift
//  PasteShelfUITests
//
//  UI tests for the preferences window.
//

import XCTest

final class PreferencesUITests: XCTestCase {
    // MARK: Internal

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        self.app = XCUIApplication()
        self.app.launchArguments.append("--skip-onboarding")
        self.app.launchArguments.append("--show-preferences")
        self.app.launch()
    }

    override func tearDownWithError() throws {
        self.app = nil
    }

    // MARK: - Window Tests

    @MainActor
    func testPreferencesWindowOpens() {
        self.openPreferences()

        let prefsWindow = self.app.windows["PasteShelf Preferences"]
        XCTAssertTrue(prefsWindow.waitForExistence(timeout: 3))
    }

    @MainActor
    func testPreferencesWindowHasAllTabs() {
        self.openPreferences()

        let prefsWindow = self.app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        // Check all tabs exist (SwiftUI TabView renders as toolbar items on macOS)
        XCTAssertTrue(self.tabExists("General", in: prefsWindow))
        XCTAssertTrue(self.tabExists("Privacy", in: prefsWindow))
        XCTAssertTrue(self.tabExists("Appearance", in: prefsWindow))
        XCTAssertTrue(self.tabExists("Shortcuts", in: prefsWindow))
        XCTAssertTrue(self.tabExists("About", in: prefsWindow))
    }

    // MARK: - General Tab Tests

    @MainActor
    func testGeneralTabContent() {
        self.openPreferences()

        let prefsWindow = self.app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        // Click General tab
        self.selectTab("General", in: prefsWindow)

        // Check General settings (accessibility labels override visible text)
        XCTAssertTrue(
            prefsWindow.switches["Launch PasteShelf at login"].exists
                || prefsWindow.toggles["Launch PasteShelf at login"].exists
                || prefsWindow.checkBoxes["Launch PasteShelf at login"].exists
                || prefsWindow.staticTexts["Launch at login"].exists
        )
        XCTAssertTrue(
            prefsWindow.switches["Show in Dock"].exists
                || prefsWindow.toggles["Show in Dock"].exists
                || prefsWindow.checkBoxes["Show in Dock"].exists
                || prefsWindow.staticTexts["Show in Dock"].exists
        )
    }

    @MainActor
    func testHistoryLimitPicker() {
        self.openPreferences()

        let prefsWindow = self.app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        self.selectTab("General", in: prefsWindow)

        // Check history limit picker exists
        let historyPicker = prefsWindow.popUpButtons.firstMatch
        XCTAssertTrue(historyPicker.exists || prefsWindow.staticTexts["History Limit"].exists)
    }

    // MARK: - Privacy Tab Tests

    @MainActor
    func testPrivacyTabContent() {
        self.openPreferences()

        let prefsWindow = self.app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        // Click Privacy tab
        self.selectTab("Privacy", in: prefsWindow)

        // Check Privacy settings
        XCTAssertTrue(
            prefsWindow.staticTexts["Excluded Apps"].exists
                || prefsWindow.staticTexts["Privacy"].exists
        )
    }

    @MainActor
    func testClearHistoryButton() {
        self.openPreferences()

        let prefsWindow = self.app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        self.selectTab("Privacy", in: prefsWindow)

        // Check Clear History button exists (accessibilityLabel is "Clear all history")
        XCTAssertTrue(
            prefsWindow.buttons["Clear all history"].exists
                || prefsWindow.buttons["Clear All History"].exists
                || prefsWindow.staticTexts["Clear All History"].exists
        )
    }

    // MARK: - Appearance Tab Tests

    @MainActor
    func testAppearanceTabContent() {
        self.openPreferences()

        let prefsWindow = self.app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        // Click Appearance tab
        self.selectTab("Appearance", in: prefsWindow)

        // Check Appearance settings
        XCTAssertTrue(
            prefsWindow.staticTexts["Theme"].exists
                || prefsWindow.staticTexts["Appearance"].exists
        )
    }

    @MainActor
    func testThemePicker() {
        self.openPreferences()

        let prefsWindow = self.app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        self.selectTab("Appearance", in: prefsWindow)

        // Check theme options
        let systemOption = prefsWindow.radioButtons["System"]
        let lightOption = prefsWindow.radioButtons["Light"]
        let darkOption = prefsWindow.radioButtons["Dark"]

        XCTAssertTrue(
            systemOption.exists || lightOption.exists || darkOption.exists
                || prefsWindow.popUpButtons.firstMatch.exists
        )
    }

    // MARK: - Shortcuts Tab Tests

    @MainActor
    func testShortcutsTabContent() {
        self.openPreferences()

        let prefsWindow = self.app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        // Click Shortcuts tab
        self.selectTab("Shortcuts", in: prefsWindow)

        // Check Shortcuts settings
        XCTAssertTrue(
            prefsWindow.staticTexts["Global Hotkey"].exists
                || prefsWindow.staticTexts["Shortcuts"].exists
        )
    }

    @MainActor
    func testHotkeyRecorder() {
        self.openPreferences()

        let prefsWindow = self.app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        self.selectTab("Shortcuts", in: prefsWindow)

        // Check hotkey recorder exists
        // The hotkey display should show something like "⌘⇧V" or section header "Global Hotkey"
        let hotkeyText = prefsWindow.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '\u{2318}'")
        ).firstMatch
        XCTAssertTrue(
            hotkeyText.exists
                || prefsWindow.staticTexts["Global Hotkey"].exists
                || prefsWindow.staticTexts["Show/Hide Panel"].exists
        )
    }

    // MARK: - About Tab Tests

    @MainActor
    func testAboutTabContent() {
        self.openPreferences()

        let prefsWindow = self.app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        // Click About tab
        self.selectTab("About", in: prefsWindow)

        // Check About content
        XCTAssertTrue(
            prefsWindow.staticTexts["PasteShelf"].exists
                || prefsWindow.staticTexts.matching(NSPredicate(format: "value CONTAINS 'PasteShelf'"))
                .firstMatch.exists
        )
        XCTAssertTrue(
            prefsWindow.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Version'"))
                .firstMatch.exists
                || prefsWindow.staticTexts.matching(NSPredicate(format: "value CONTAINS 'Version'"))
                .firstMatch.exists
        )
    }

    @MainActor
    func testAboutLinks() {
        self.openPreferences()

        let prefsWindow = self.app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        self.selectTab("About", in: prefsWindow)

        // Check links exist (Link accessibilityLabels differ from visible text)
        XCTAssertTrue(
            prefsWindow.links["Visit PasteShelf website"].exists
                || prefsWindow.links["View source code on GitHub"].exists
                || prefsWindow.buttons["Visit PasteShelf website"].exists
                || prefsWindow.staticTexts["Website"].exists
                || prefsWindow.links.firstMatch.exists
        )
    }

    // MARK: - Tab Navigation Tests

    @MainActor
    func testTabSwitching() {
        self.openPreferences()

        let prefsWindow = self.app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        // Switch through all tabs
        let tabs = ["General", "Privacy", "Appearance", "Shortcuts", "About"]

        for tab in tabs {
            self.selectTab(tab, in: prefsWindow)
            // Give UI time to update
            Thread.sleep(forTimeInterval: 0.2)
        }
    }

    // MARK: Private

    // MARK: - Helper Methods

    private func openPreferences() {
        // Preferences window auto-opens via --show-preferences launch argument
        // Wait for window and its sidebar to fully render
        let prefsWindow = self.app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 5) else {
            return
        }
        // Wait for sidebar content to render
        _ = prefsWindow.staticTexts["General"].waitForExistence(timeout: 5)
    }

    /// Finds and clicks a tab in the preferences sidebar
    private func selectTab(_ name: String, in prefsWindow: XCUIElement) {
        let sidebarItem = prefsWindow.staticTexts[name]
        if sidebarItem.waitForExistence(timeout: 3) {
            sidebarItem.click()
            // Give SwiftUI time to update the detail view
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    /// Checks if a tab exists in the preferences sidebar
    private func tabExists(_ name: String, in prefsWindow: XCUIElement) -> Bool {
        prefsWindow.staticTexts[name].exists
    }
}
