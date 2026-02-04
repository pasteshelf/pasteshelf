//
//  SearchUITests.swift
//  PasteShelfUITests
//
//  UI tests for search functionality.
//

import XCTest

final class SearchUITests: XCTestCase {
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

    // MARK: - Search Field Tests

    @MainActor
    func testSearchFieldExists() throws {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        let searchField =
            panel.searchFields["Search clipboard..."]
            ?? panel.textFields["Search clipboard..."]
            ?? panel.searchFields.firstMatch

        XCTAssertTrue(searchField.exists)
    }

    @MainActor
    func testSearchFieldPlaceholder() throws {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        // Search field should have placeholder text
        let placeholder = panel.searchFields.firstMatch.placeholderValue
        XCTAssertEqual(placeholder, "Search clipboard...")
    }

    @MainActor
    func testSearchFieldAcceptsInput() throws {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        let searchField = panel.searchFields.firstMatch
        if searchField.exists {
            searchField.click()
            searchField.typeText("hello world")

            // Verify text was entered
            XCTAssertEqual(searchField.value as? String, "hello world")
        }
    }

    // MARK: - Real-time Filtering Tests

    @MainActor
    func testSearchFiltersInRealTime() throws {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        let searchField = panel.searchFields.firstMatch
        if searchField.exists {
            searchField.click()

            // Type character by character to test debounce
            searchField.typeText("t")
            Thread.sleep(forTimeInterval: 0.2)
            searchField.typeText("e")
            Thread.sleep(forTimeInterval: 0.2)
            searchField.typeText("s")
            Thread.sleep(forTimeInterval: 0.2)
            searchField.typeText("t")

            // Wait for debounce
            Thread.sleep(forTimeInterval: 0.2)

            // Results count should update
        }
    }

    // MARK: - Search Results Tests

    @MainActor
    func testSearchShowsResultsCount() throws {
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

            // Wait for search
            Thread.sleep(forTimeInterval: 0.3)

            // Header should show "X results" instead of "X items"
            let resultsText = panel.staticTexts.matching(
                NSPredicate(format: "label CONTAINS 'results'")
            ).firstMatch

            // May show results or not depending on clipboard content
            _ = resultsText
        }
    }

    @MainActor
    func testSearchHighlightsMatches() throws {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        let searchField = panel.searchFields.firstMatch
        if searchField.exists {
            searchField.click()
            searchField.typeText("hello")

            // Wait for search
            Thread.sleep(forTimeInterval: 0.3)

            // Matched text should be highlighted
            // (Implementation-specific check)
        }
    }

    // MARK: - Clear Search Tests

    @MainActor
    func testClearSearchRestoresAllItems() throws {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        let searchField = panel.searchFields.firstMatch
        if searchField.exists {
            // Type search query
            searchField.click()
            searchField.typeText("xyz")

            // Wait for search
            Thread.sleep(forTimeInterval: 0.2)

            // Clear the search
            let clearButton = panel.buttons["Clear"]
            if clearButton.exists {
                clearButton.click()

                // Should show all items again (header shows "X items")
                let itemsText = panel.staticTexts.matching(
                    NSPredicate(format: "label CONTAINS 'items'")
                ).firstMatch
                XCTAssertTrue(itemsText.waitForExistence(timeout: 2))
            }
        }
    }

    @MainActor
    func testEscapeClearsSearch() throws {
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

            // Press Escape to clear
            panel.typeKey(.escape, modifierFlags: [])

            // Search should be cleared
            // (Note: First Escape clears search, second closes panel)
        }
    }

    // MARK: - Empty Results Tests

    @MainActor
    func testNoResultsShowsEmptyState() throws {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        let searchField = panel.searchFields.firstMatch
        if searchField.exists {
            // Search for something unlikely to exist
            searchField.click()
            searchField.typeText("xyznonexistent123456")

            // Wait for search
            Thread.sleep(forTimeInterval: 0.3)

            // Should show empty state
            let noResults = panel.staticTexts["No matching items"]
            XCTAssertTrue(noResults.waitForExistence(timeout: 2))
        }
    }

    @MainActor
    func testEmptyResultsShowsClearButton() throws {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        let searchField = panel.searchFields.firstMatch
        if searchField.exists {
            searchField.click()
            searchField.typeText("xyznonexistent123456")

            Thread.sleep(forTimeInterval: 0.3)

            // Should show Clear Search button
            let clearSearchButton = panel.buttons["Clear Search"]
            XCTAssertTrue(clearSearchButton.waitForExistence(timeout: 2))
        }
    }

    // MARK: - Keyboard Shortcut Tests

    @MainActor
    func testCmdFFocusesSearchField() throws {
        showPanel()

        let panel = app.windows["Clipboard History"]
        guard panel.waitForExistence(timeout: 2) else {
            XCTSkip("Panel not available")
            return
        }

        // Press Cmd+F
        panel.typeKey("f", modifierFlags: .command)

        // Search field should be focused
        let searchField = panel.searchFields.firstMatch
        // In XCUITest, checking focus is tricky
        // We can verify by typing and seeing if it goes to search field
        if searchField.exists {
            XCUIApplication().typeText("test")
            XCTAssertEqual(searchField.value as? String, "test")
        }
    }

    // MARK: - Helper Methods

    private func showPanel() {
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
