//
//  ScreenshotHelper.swift
//  PasteShelfUITests
//
//  Helper utilities for App Store screenshot capture.
//

import XCTest

/// Helper for capturing App Store screenshots with consistent naming and quality.
enum ScreenshotHelper {
    // MARK: - Sample Data

    /// Realistic sample content for screenshots
    enum SampleContent {
        static let textItems = [
            "Meeting notes from the product review: Discussed new features for Q2 release...",
            "Email to send to the design team regarding the updated mockups...",
            "Bug fix: Updated the login validation to handle edge cases with special characters...",
            "Shopping list: milk, eggs, bread, avocados, coffee beans, olive oil...",
            "Draft proposal for the client presentation next Tuesday...",
            "API endpoint documentation: POST /api/v2/users - Creates a new user account...",
            "Password for staging server: [REDACTED]",
            "TODO: Refactor the clipboard monitoring service to reduce CPU usage...",
        ]

        static let codeSnippets = [
            """
            func fetchClipboardItems() async throws -> [ClipboardItem] {
                try await storageManager.fetchRecent(limit: 100)
            }
            """,
            """
            @MainActor
            class ClipboardViewModel: ObservableObject {
                @Published var items: [ClipboardItem] = []
            }
            """,
        ]

        static let urls = [
            "https://developer.apple.com/documentation/swiftui",
            "https://github.com/pasteshelf/pasteshelf/pull/42",
            "https://stackoverflow.com/questions/12345/swift-async-await",
        ]

        static let searchQueries = [
            "email",
            "meeting",
            "api",
        ]
    }

    // MARK: - Screenshot Naming

    /// Screenshot names following App Store conventions
    enum ScreenshotName: String, CaseIterable {
        case floatingPanelOverview = "PasteShelf_Screenshot_1_FloatingPanel"
        case searchInAction = "PasteShelf_Screenshot_2_Search"
        case preferencesPrivacy = "PasteShelf_Screenshot_3_Privacy"
        case menuBarIntegration = "PasteShelf_Screenshot_4_MenuBar"
        case keyboardShortcuts = "PasteShelf_Screenshot_5_Shortcuts"

        // MARK: Internal

        var displayName: String {
            switch self {
            case .floatingPanelOverview:
                "Floating Panel Overview"
            case .searchInAction:
                "Search in Action"
            case .preferencesPrivacy:
                "Preferences - Privacy"
            case .menuBarIntegration:
                "Menu Bar Integration"
            case .keyboardShortcuts:
                "Keyboard Shortcuts"
            }
        }

        func filename(locale: String = "en") -> String {
            "\(rawValue)_\(locale).png"
        }
    }

    // MARK: - Screenshot Capture

    /// Captures a screenshot and attaches it to the test with proper naming.
    /// - Parameters:
    ///   - name: The screenshot name enum value
    ///   - locale: The locale code (default: "en")
    ///   - testCase: The test case to attach the screenshot to
    static func captureScreenshot(
        name: ScreenshotName,
        locale: String = "en",
        testCase: XCTestCase
    ) {
        // Wait for UI to stabilize
        waitForUI()

        // Take screenshot
        let screenshot = XCUIScreen.main.screenshot()

        // Create attachment with proper naming
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name.filename(locale: locale)
        attachment.lifetime = .keepAlways

        // Attach to test
        testCase.add(attachment)
    }

    /// Captures a screenshot of a specific element.
    /// - Parameters:
    ///   - element: The element to screenshot
    ///   - name: The screenshot name enum value
    ///   - locale: The locale code (default: "en")
    ///   - testCase: The test case to attach the screenshot to
    static func captureElementScreenshot(
        element: XCUIElement,
        name: ScreenshotName,
        locale: String = "en",
        testCase: XCTestCase
    ) {
        // Wait for element to be ready
        guard element.waitForExistence(timeout: 5) else {
            XCTFail("Element not found for screenshot: \(name.displayName)")
            return
        }

        waitForUI()

        // Take screenshot of element
        let screenshot = element.screenshot()

        // Create attachment
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name.filename(locale: locale)
        attachment.lifetime = .keepAlways

        testCase.add(attachment)
    }

    // MARK: - UI Helpers

    /// Waits for the UI to stabilize before taking a screenshot.
    static func waitForUI() {
        // Give animations time to complete
        Thread.sleep(forTimeInterval: 0.5)

        // Additional wait for any async operations
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
    }

    /// Waits for a specific element with extended timeout for screenshots.
    /// - Parameters:
    ///   - element: The element to wait for
    ///   - timeout: Maximum time to wait (default: 10 seconds)
    /// - Returns: True if element exists, false otherwise
    @discardableResult
    static func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    // MARK: - App State Helpers

    /// Clears any dialogs or alerts that might interfere with screenshots.
    /// - Parameter app: The application instance
    static func clearDialogs(in app: XCUIApplication) {
        // Dismiss any alerts
        let alerts = app.alerts
        if !alerts.allElementsBoundByIndex.isEmpty {
            alerts.buttons.firstMatch.tap()
            waitForUI()
        }

        // Dismiss any sheets
        let sheets = app.sheets
        if !sheets.allElementsBoundByIndex.isEmpty {
            sheets.buttons.firstMatch.tap()
            waitForUI()
        }
    }

    /// Sets the app appearance mode for screenshots.
    /// Note: This requires system-level access which may not work in UI tests.
    /// - Parameters:
    ///   - darkMode: Whether to use dark mode
    ///   - app: The application instance
    static func setAppearance(darkMode: Bool, app: XCUIApplication) {
        // Set via launch arguments
        if darkMode {
            app.launchArguments.append("-AppleInterfaceStyle")
            app.launchArguments.append("Dark")
        } else {
            app.launchArguments.append("-AppleInterfaceStyle")
            app.launchArguments.append("Light")
        }
    }
}
