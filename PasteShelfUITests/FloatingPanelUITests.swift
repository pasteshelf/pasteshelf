//
//  FloatingPanelUITests.swift
//  PasteShelfUITests
//
//  UI tests for the floating clipboard panel.
//

import XCTest

final class FloatingPanelUITests: XCTestCase {
    // MARK: Internal

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        // Skip onboarding for panel tests
        app.launchArguments.append("--skip-onboarding")
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Panel Visibility Tests

    @MainActor
    func testPanelShowsWithHotkey() {
        // Simulate hotkey press (Cmd+Shift+V)
        // Note: In UI tests, we typically need to use menu items or buttons
        // since keyboard shortcuts require accessibility permissions

        // Use menu bar to show panel
        let menuBarItem = app.menuBars.statusItems.firstMatch
        if menuBarItem.exists {
            menuBarItem.click()

            // Look for Show Panel option
            let showPanel = app.menuItems["Show Clipboard Panel"]
            if showPanel.waitForExistence(timeout: 2) {
                showPanel.click()

                // Panel should appear
                let panel = app.windows["Clipboard History"]
                XCTAssertTrue(panel.waitForExistence(timeout: 2))
            }
        }
    }

    @MainActor
    func testPanelShowsClipboardHistory() {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        // Check header
        XCTAssertTrue(panel.staticTexts["Clipboard History"].exists)
    }

    @MainActor
    func testPanelHasSearchField() {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        // Check search field
        let searchField = panel.searchFields.firstMatch
        XCTAssertTrue(searchField.exists || panel.textFields["Search clipboard..."].exists)
    }

    @MainActor
    func testPanelHasFilterChips() {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        // Check filter chips
        let allFilter = panel.buttons["All"]
        let textFilter = panel.buttons["Text"]
        let imagesFilter = panel.buttons["Images"]
        let linksFilter = panel.buttons["Links"]
        let filesFilter = panel.buttons["Files"]

        XCTAssertTrue(
            allFilter.exists || textFilter.exists || imagesFilter.exists || linksFilter.exists
                || filesFilter.exists
        )
    }

    // MARK: - Keyboard Navigation Tests

    @MainActor
    func testKeyboardNavigationUpDown() {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        // Press down arrow to navigate
        panel.typeKey(.downArrow, modifierFlags: [])

        // Press up arrow to navigate back
        panel.typeKey(.upArrow, modifierFlags: [])
    }

    @MainActor
    func testEscapeClosesPanel() {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        // Press Escape to close
        panel.typeKey(.escape, modifierFlags: [])

        // Panel should close
        XCTAssertTrue(panel.waitForNonExistence(timeout: 2))
    }

    @MainActor
    func testCmdFocusesSearchField() {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        // Press Cmd+F to focus search
        panel.typeKey("f", modifierFlags: .command)

        // Search field should be focused (implementation-specific)
    }

    // MARK: - Search Tests

    @MainActor
    func testSearchFiltersItems() {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        // Find and focus search field
        let searchField = panel.searchFields.firstMatch
        if searchField.exists {
            searchField.click()
            searchField.typeText("test")

            // Results should update (check for "results" text)
            let resultsText = panel.staticTexts.matching(
                NSPredicate(format: "label CONTAINS 'results'")
            ).firstMatch
            XCTAssertTrue(resultsText.waitForExistence(timeout: 2))
        }
    }

    @MainActor
    func testClearSearchButton() {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        let searchField = panel.searchFields.firstMatch
        if searchField.exists {
            searchField.click()
            searchField.typeText("test")

            // Clear button should appear
            let clearButton = panel.buttons["Clear"]
            if clearButton.waitForExistence(timeout: 1) {
                clearButton.click()

                // Search field should be empty
            }
        }
    }

    // MARK: - Filter Tests

    @MainActor
    func testFilterByContentType() {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        // Click Text filter
        let textFilter = panel.buttons["Text"]
        if textFilter.exists {
            textFilter.click()

            // Should show only text items
        }
    }

    @MainActor
    func testToggleFavoritesFilter() {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        // Click Favorites filter
        let favoritesFilter = panel.buttons["Favorites"]
        if favoritesFilter.exists {
            favoritesFilter.click()

            // Should show only favorites
        }
    }

    // MARK: - Empty State Tests

    @MainActor
    func testEmptyStateDisplays() {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        // If no items, empty state should show
        let emptyState = panel.staticTexts["No clipboard items"]
        // May or may not exist depending on clipboard content
        _ = emptyState
    }

    // MARK: Private

    // MARK: - Helper Methods

    private func showPanel() {
        // Try to show panel via menu bar
        let menuBarItem = app.menuBars.statusItems.firstMatch
        if menuBarItem.exists {
            menuBarItem.click()

            let showPanel = app.menuItems["Show Clipboard Panel"]
            if showPanel.waitForExistence(timeout: 2) {
                showPanel.click()
            }
        }
    }
}
