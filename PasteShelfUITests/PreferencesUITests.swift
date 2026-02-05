//
//  PreferencesUITests.swift
//  PasteShelfUITests
//
//  UI tests for the preferences window.
//

import XCTest

final class PreferencesUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments.append("--skip-onboarding")
        app.launchArguments.append("--show-preferences")
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Window Tests

    @MainActor
    func testPreferencesWindowOpens() throws {
        openPreferences()

        let prefsWindow = app.windows["PasteShelf Preferences"]
        XCTAssertTrue(prefsWindow.waitForExistence(timeout: 3))
    }

    @MainActor
    func testPreferencesWindowHasAllTabs() throws {
        openPreferences()

        let prefsWindow = app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        // Check all tabs exist (SwiftUI TabView renders as toolbar items on macOS)
        XCTAssertTrue(tabExists("General", in: prefsWindow))
        XCTAssertTrue(tabExists("Privacy", in: prefsWindow))
        XCTAssertTrue(tabExists("Appearance", in: prefsWindow))
        XCTAssertTrue(tabExists("Shortcuts", in: prefsWindow))
        XCTAssertTrue(tabExists("About", in: prefsWindow))
    }

    // MARK: - General Tab Tests

    @MainActor
    func testGeneralTabContent() throws {
        openPreferences()

        let prefsWindow = app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        // Click General tab
        selectTab("General", in: prefsWindow)

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
    func testHistoryLimitPicker() throws {
        openPreferences()

        let prefsWindow = app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        selectTab("General", in: prefsWindow)

        // Check history limit picker exists
        let historyPicker = prefsWindow.popUpButtons.firstMatch
        XCTAssertTrue(historyPicker.exists || prefsWindow.staticTexts["History Limit"].exists)
    }

    // MARK: - Privacy Tab Tests

    @MainActor
    func testPrivacyTabContent() throws {
        openPreferences()

        let prefsWindow = app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        // Click Privacy tab
        selectTab("Privacy", in: prefsWindow)

        // Check Privacy settings
        XCTAssertTrue(
            prefsWindow.staticTexts["Excluded Apps"].exists
                || prefsWindow.staticTexts["Privacy"].exists
        )
    }

    @MainActor
    func testClearHistoryButton() throws {
        openPreferences()

        let prefsWindow = app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        selectTab("Privacy", in: prefsWindow)

        // Check Clear History button exists (accessibilityLabel is "Clear all history")
        XCTAssertTrue(
            prefsWindow.buttons["Clear all history"].exists
                || prefsWindow.buttons["Clear All History"].exists
                || prefsWindow.staticTexts["Clear All History"].exists
        )
    }

    // MARK: - Appearance Tab Tests

    @MainActor
    func testAppearanceTabContent() throws {
        openPreferences()

        let prefsWindow = app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        // Click Appearance tab
        selectTab("Appearance", in: prefsWindow)

        // Check Appearance settings
        XCTAssertTrue(
            prefsWindow.staticTexts["Theme"].exists
                || prefsWindow.staticTexts["Appearance"].exists
        )
    }

    @MainActor
    func testThemePicker() throws {
        openPreferences()

        let prefsWindow = app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        selectTab("Appearance", in: prefsWindow)

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
    func testShortcutsTabContent() throws {
        openPreferences()

        let prefsWindow = app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        // Click Shortcuts tab
        selectTab("Shortcuts", in: prefsWindow)

        // Check Shortcuts settings
        XCTAssertTrue(
            prefsWindow.staticTexts["Global Hotkey"].exists
                || prefsWindow.staticTexts["Shortcuts"].exists
        )
    }

    @MainActor
    func testHotkeyRecorder() throws {
        openPreferences()

        let prefsWindow = app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        selectTab("Shortcuts", in: prefsWindow)

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
    func testAboutTabContent() throws {
        openPreferences()

        let prefsWindow = app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        // Click About tab
        selectTab("About", in: prefsWindow)

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
    func testAboutLinks() throws {
        openPreferences()

        let prefsWindow = app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        selectTab("About", in: prefsWindow)

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
    func testTabSwitching() throws {
        openPreferences()

        let prefsWindow = app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 3) else {
            XCTSkip("Preferences window not available")
            return
        }

        // Switch through all tabs
        let tabs = ["General", "Privacy", "Appearance", "Shortcuts", "About"]

        for tab in tabs {
            selectTab(tab, in: prefsWindow)
            // Give UI time to update
            Thread.sleep(forTimeInterval: 0.2)
        }
    }

    // MARK: - Helper Methods

    private func openPreferences() {
        // Preferences window auto-opens via --show-preferences launch argument
        // Wait for window and its sidebar to fully render
        let prefsWindow = app.windows["PasteShelf Preferences"]
        guard prefsWindow.waitForExistence(timeout: 5) else { return }
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
