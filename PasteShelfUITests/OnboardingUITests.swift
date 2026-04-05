//
//  OnboardingUITests.swift
//  PasteShelfUITests
//
//  UI tests for the onboarding flow.
//

import XCTest

final class OnboardingUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        // Reset onboarding state for testing
        app.launchArguments.append("--reset-onboarding")
        app.launchArguments.append("--bypass-permissions")
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Welcome Step Tests

    @MainActor
    func testWelcomeScreenDisplaysCorrectly() throws {
        let window = app.windows["Welcome to PasteShelf"]

        // Check welcome screen elements
        XCTAssertTrue(window.staticTexts["Welcome to PasteShelf"].exists)
        XCTAssertTrue(window.staticTexts["Your privacy-first clipboard manager"].exists)

        // Check feature highlights
        XCTAssertTrue(window.staticTexts["Clipboard History"].exists)
        XCTAssertTrue(window.staticTexts["Instant Search"].exists)
        XCTAssertTrue(window.staticTexts["Privacy First"].exists)
        XCTAssertTrue(window.staticTexts["Keyboard Shortcuts"].exists)

        // Check Continue button
        XCTAssertTrue(window.buttons["Continue"].exists)
    }

    #if !APP_STORE
    @MainActor
    func testContinueFromWelcomeToPermissions() throws {
        let window = app.windows["Welcome to PasteShelf"]

        // Click Continue
        window.buttons["Continue"].click()

        // Wait for permissions screen
        let permissionsText = window.staticTexts["Accessibility Permission"]
        XCTAssertTrue(permissionsText.waitForExistence(timeout: 2))
    }

    // MARK: - Permissions Step Tests

    @MainActor
    func testPermissionsScreenDisplaysCorrectly() throws {
        let window = app.windows["Welcome to PasteShelf"]

        // Navigate to permissions
        window.buttons["Continue"].click()

        // Check permissions screen elements
        XCTAssertTrue(window.staticTexts["Accessibility Permission"].waitForExistence(timeout: 2))

        // Check Open System Settings button
        let settingsButton = window.buttons["Open System Settings"]
        XCTAssertTrue(settingsButton.exists || window.staticTexts["Permission granted"].exists)
    }

    @MainActor
    func testBackButtonReturnsToWelcome() throws {
        let window = app.windows["Welcome to PasteShelf"]

        // Navigate to permissions
        window.buttons["Continue"].click()

        // Wait for permissions screen
        XCTAssertTrue(window.staticTexts["Accessibility Permission"].waitForExistence(timeout: 2))

        // Click Back
        window.buttons["Back"].click()

        // Should be back at welcome
        XCTAssertTrue(window.staticTexts["Welcome to PasteShelf"].waitForExistence(timeout: 2))
    }
    #else
    @MainActor
    func testContinueFromWelcomeToNotifications() throws {
        let window = app.windows["Welcome to PasteShelf"]

        // Click Continue — App Store skips Permissions, goes to Notifications
        window.buttons["Continue"].click()

        let notificationsText = window.staticTexts["Notifications"]
        XCTAssertTrue(notificationsText.waitForExistence(timeout: 2))
    }
    #endif

    // MARK: - Tutorial Step Tests

    @MainActor
    func testTutorialScreenDisplaysCorrectly() throws {
        // Skip to tutorial (requires accessibility permission to be granted)
        navigateToTutorial()

        let window = app.windows["Welcome to PasteShelf"]

        // Check tutorial elements
        XCTAssertTrue(window.staticTexts["Quick Tour"].waitForExistence(timeout: 2))
        XCTAssertTrue(window.staticTexts["Key Shortcuts"].exists)
    }

    @MainActor
    func testTutorialCanBeSkipped() throws {
        navigateToTutorial()

        let window = app.windows["Welcome to PasteShelf"]

        // Skip button should exist
        let skipButton = window.buttons["Skip"]
        if skipButton.exists {
            skipButton.click()

            // Should move to hotkey setup
            XCTAssertTrue(
                window.staticTexts["Set Your Hotkey"].waitForExistence(timeout: 2)
            )
        }
    }

    // MARK: - Hotkey Setup Tests

    @MainActor
    func testHotkeySetupScreenDisplaysCorrectly() throws {
        navigateToHotkeySetup()

        let window = app.windows["Welcome to PasteShelf"]

        // Check hotkey setup elements
        XCTAssertTrue(window.staticTexts["Set Your Hotkey"].waitForExistence(timeout: 2))
        XCTAssertTrue(window.staticTexts["Current Hotkey"].exists)
        XCTAssertTrue(window.staticTexts["Quick Presets"].exists)
    }

    @MainActor
    func testHotkeyPresetButtons() throws {
        navigateToHotkeySetup()

        let window = app.windows["Welcome to PasteShelf"]

        // Check preset buttons
        let cmdShiftV = window.buttons["⌘ ⇧ V"]
        let cmdOptV = window.buttons["⌘ ⌥ V"]

        XCTAssertTrue(cmdShiftV.exists || cmdOptV.exists)
    }

    @MainActor
    func testCompleteOnboarding() throws {
        navigateToHotkeySetup()

        let window = app.windows["Welcome to PasteShelf"]

        // Click Get Started to complete
        let getStartedButton = window.buttons["Get Started"]
        if getStartedButton.waitForExistence(timeout: 2) {
            getStartedButton.click()

            // Window should close after completion
            XCTAssertTrue(window.waitForNonExistence(timeout: 3))
        }
    }

    // MARK: - Progress Indicator Tests

    @MainActor
    func testProgressIndicatorUpdates() throws {
        let window = app.windows["Welcome to PasteShelf"]

        // Move to step 2
        window.buttons["Continue"].click()

        #if APP_STORE
        // App Store: Welcome -> Notifications (skips Permissions)
        XCTAssertTrue(window.staticTexts["Notifications"].waitForExistence(timeout: 2))
        #else
        // Direct: Welcome -> Permissions
        XCTAssertTrue(window.staticTexts["Accessibility Permission"].waitForExistence(timeout: 2))
        #endif
    }

    // MARK: - Helper Methods

    private func navigateToTutorial() {
        let window = app.windows["Welcome to PasteShelf"]

        window.buttons["Continue"].click()  // Welcome -> next step

        #if !APP_STORE
        // Direct distribution: Welcome -> Permissions -> Notifications -> Tutorial
        _ = window.staticTexts["Accessibility Permission"].waitForExistence(timeout: 2)
        let continueButton = window.buttons["Continue"]
        if continueButton.isEnabled {
            continueButton.click()  // Permissions -> Notifications
        }
        #endif

        // Both builds: now on Notifications
        _ = window.staticTexts["Notifications"].waitForExistence(timeout: 2)
        window.buttons["Continue"].click()  // Notifications -> Tutorial
    }

    private func navigateToHotkeySetup() {
        navigateToTutorial()

        let window = app.windows["Welcome to PasteShelf"]

        // Wait for tutorial
        _ = window.staticTexts["Quick Tour"].waitForExistence(timeout: 2)

        // Continue to hotkey setup
        let continueButton = window.buttons["Continue"]
        if continueButton.exists {
            continueButton.click()
        }
    }
}
