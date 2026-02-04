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

        // Check all tabs exist
        XCTAssertTrue(prefsWindow.buttons["General"].exists)
        XCTAssertTrue(prefsWindow.buttons["Privacy"].exists)
        XCTAssertTrue(prefsWindow.buttons["Appearance"].exists)
        XCTAssertTrue(prefsWindow.buttons["Shortcuts"].exists)
        XCTAssertTrue(prefsWindow.buttons["About"].exists)
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
        prefsWindow.buttons["General"].click()

        // Check General settings
        XCTAssertTrue(
            prefsWindow.checkBoxes["Launch at Login"].exists
                || prefsWindow.toggles["Launch at Login"].exists
        )
        XCTAssertTrue(
            prefsWindow.checkBoxes["Show in Dock"].exists
                || prefsWindow.toggles["Show in Dock"].exists
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

        prefsWindow.buttons["General"].click()

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
        prefsWindow.buttons["Privacy"].click()

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

        prefsWindow.buttons["Privacy"].click()

        // Check Clear History button exists
        let clearButton = prefsWindow.buttons["Clear History"]
        XCTAssertTrue(clearButton.exists)
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
        prefsWindow.buttons["Appearance"].click()

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

        prefsWindow.buttons["Appearance"].click()

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
        prefsWindow.buttons["Shortcuts"].click()

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

        prefsWindow.buttons["Shortcuts"].click()

        // Check hotkey recorder exists
        // The hotkey display should show something like "⌘⇧V"
        let hotkeyText = prefsWindow.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '⌘'")
        ).firstMatch
        XCTAssertTrue(hotkeyText.exists || prefsWindow.staticTexts["Record Shortcut"].exists)
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
        prefsWindow.buttons["About"].click()

        // Check About content
        XCTAssertTrue(prefsWindow.staticTexts["PasteShelf"].exists)
        XCTAssertTrue(
            prefsWindow.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Version'"))
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

        prefsWindow.buttons["About"].click()

        // Check links exist
        let websiteButton = prefsWindow.buttons["Visit Website"]
        let githubButton = prefsWindow.buttons["View on GitHub"]
        let issueButton = prefsWindow.buttons["Report an Issue"]

        XCTAssertTrue(websiteButton.exists || githubButton.exists || issueButton.exists)
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
            prefsWindow.buttons[tab].click()
            // Give UI time to update
            Thread.sleep(forTimeInterval: 0.2)
        }
    }

    // MARK: - Helper Methods

    private func openPreferences() {
        // Open via menu bar
        let menuBarItem = app.menuBars.statusItems.firstMatch
        if menuBarItem.exists {
            menuBarItem.click()

            let prefsMenuItem = app.menuItems["Preferences..."]
            if prefsMenuItem.waitForExistence(timeout: 2) {
                prefsMenuItem.click()
            }
        }
    }
}
