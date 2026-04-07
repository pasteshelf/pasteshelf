//
//  String+Localization.swift
//  PasteShelf
//
//  Extension for easy string localization using String Catalogs.
//

import Foundation

extension String {
    /// Returns a localized version of this string using String Catalogs
    var localized: String {
        String(localized: LocalizationValue(self))
    }

    /// Returns a localized version with format arguments
    func localized(with arguments: CVarArg...) -> String {
        let format = String(localized: LocalizationValue(self))
        return String(format: format, arguments: arguments)
    }
}

// MARK: - LocalizedString

/// Centralized localization keys for type-safe access
enum LocalizedString {
    // MARK: - Onboarding

    enum Onboarding {
        static let welcomeTitle = "Welcome to PasteShelf"
        static let welcomeSubtitle = "Your privacy-first clipboard manager"
        static let permissionTitle = "Accessibility Permission"
        static let permissionDescription =
            "PasteShelf needs accessibility permission to paste items into other apps. "
                + "Your data stays private and is never shared."
        static let permissionGranted = "Permission granted"
        static let permissionRequired = "Permission required"
        static let openSystemSettings = "Open System Settings"
        static let tutorialTitle = "Quick Tour"
        static let hotkeyTitle = "Set Your Hotkey"
        static let hotkeyDescription =
            "Choose a keyboard shortcut to quickly open PasteShelf from anywhere."
        static let currentHotkey = "Current Hotkey"
        static let quickPresets = "Quick Presets"
        static let getStarted = "Get Started"
        static let continueButton = "Continue"
        static let back = "Back"
        static let skip = "Skip"
    }

    // MARK: - Floating Panel

    enum FloatingPanel {
        static let title = "Clipboard History"
        static let searchPlaceholder = "Search clipboard..."
        static let itemsCount = "%d items"
        static let resultsCount = "%d results"
        static let searching = "Searching \"%@\"..."
    }

    // MARK: - Filters

    enum Filters {
        static let all = "All"
        static let text = "Text"
        static let images = "Images"
        static let links = "Links"
        static let files = "Files"
        static let favorites = "Favorites"
    }

    // MARK: - Empty States

    enum EmptyState {
        static let noItems = "No clipboard items"
        static let noItemsMessage = "Copy something to see it here"
        static let noResults = "No matching items"
        static let noResultsMessage = "Try a different search term"
        static let noFilteredResults = "No matching items"
        static let noFilteredResultsMessage = "Try different filter settings"
        static let clearSearch = "Clear Search"
        static let clearFilters = "Clear Filters"
    }

    // MARK: - Preferences

    enum Preferences {
        static let title = "PasteShelf Preferences"
        static let general = "General"
        static let privacy = "Privacy"
        static let appearance = "Appearance"
        static let shortcuts = "Shortcuts"
        static let about = "About"
    }

    // MARK: - General Settings

    enum GeneralSettings {
        static let launchAtLogin = "Launch at Login"
        static let launchAtLoginDescription = "Start PasteShelf when you log in"
        static let showInDock = "Show in Dock"
        static let showInDockDescription = "Display PasteShelf icon in the Dock"
        static let historyLimit = "History Limit"
        static let historyLimitDescription = "Maximum number of items to keep"
        static let unlimited = "Unlimited"
    }

    // MARK: - Privacy Settings

    enum PrivacySettings {
        static let excludedApps = "Excluded Apps"
        static let excludedAppsDescription = "Apps that won't have their clipboard content saved"
        static let clearHistory = "Clear History"
        static let clearHistoryDescription = "Delete all clipboard history"
        static let clearHistoryConfirmation = "Are you sure you want to clear all clipboard history?"
        static let autoDelete = "Auto-delete after"
        static let autoDeleteDescription = "Automatically delete items older than specified days"
        static let pauseMonitoring = "Pause Monitoring"
        static let pauseMonitoringDescription = "Temporarily stop capturing clipboard content"
        static let days = "days"
        static let never = "Never"
    }

    // MARK: - Appearance Settings

    enum AppearanceSettings {
        static let theme = "Theme"
        static let themeDescription = "Choose the app appearance"
        static let system = "System"
        static let light = "Light"
        static let dark = "Dark"
        static let panelWidth = "Panel Width"
        static let panelWidthDescription = "Width of the clipboard panel"
        static let narrow = "Narrow"
        static let normal = "Normal"
        static let wide = "Wide"
        static let previewLines = "Preview Lines"
        static let previewLinesDescription = "Number of lines to show in item preview"
        static let showThumbnails = "Show Thumbnails"
        static let showThumbnailsDescription = "Display image thumbnails in the list"
        static let compactMode = "Compact Mode"
        static let compactModeDescription = "Use smaller item rows for more items on screen"
    }

    // MARK: - Shortcuts Settings

    enum ShortcutsSettings {
        static let globalHotkey = "Global Hotkey"
        static let globalHotkeyDescription = "Keyboard shortcut to open PasteShelf"
        static let recordShortcut = "Record Shortcut"
        static let pressShortcut = "Press shortcut..."
        static let quickPaste = "Quick Paste"
        static let quickPasteDescription = "Use ⌘1-9 to paste recent items"
        static let navigationShortcuts = "Navigation Shortcuts"
    }

    // MARK: - About

    enum About {
        static let version = "Version"
        static let copyright = "Copyright"
        static let visitWebsite = "Visit Website"
        static let viewOnGitHub = "View on GitHub"
        static let reportIssue = "Report an Issue"
    }

    // MARK: - Menu Bar

    enum MenuBar {
        static let showPanel = "Show Clipboard Panel"
        static let preferences = "Preferences..."
        static let pause = "Pause Monitoring"
        static let resume = "Resume Monitoring"
        static let quit = "Quit PasteShelf"
        static let recentItems = "Recent Items"
        static let noRecentItems = "No Recent Items"
    }

    enum Actions {
        static let paste = "Paste"
        static let copy = "Copy"
        static let delete = "Delete"
        static let favorite = "Favorite"
        static let unfavorite = "Unfavorite"
        static let cancel = "Cancel"
        static let confirm = "Confirm"
        static let save = "Save"
        static let reset = "Reset"
        static let add = "Add"
        static let remove = "Remove"
        static let edit = "Edit"
        static let done = "Done"
    }

    // MARK: - Content Types

    enum ContentTypes {
        static let text = "Text"
        static let richText = "Rich Text"
        static let html = "HTML"
        static let image = "Image"
        static let file = "File"
        static let url = "URL"
        static let unknown = "Unknown"
    }

    // MARK: - Time

    enum Time {
        static let today = "Today"
        static let yesterday = "Yesterday"
        static let thisWeek = "This Week"
        static let older = "Older"
        static let justNow = "Just now"
        static let minutesAgo = "%d minutes ago"
        static let hoursAgo = "%d hours ago"
        static let daysAgo = "%d days ago"
    }

    // MARK: - Errors

    enum Errors {
        static let genericError = "An error occurred"
        static let loadingError = "Unable to load"
        static let savingError = "Unable to save"
        static let tryAgain = "Try Again"
    }

    // MARK: - Features

    enum Features {
        static let clipboardHistory = "Clipboard History"
        static let clipboardHistoryDescription = "Access everything you've copied"
        static let instantSearch = "Instant Search"
        static let instantSearchDescription = "Find any item in seconds"
        static let privacyFirst = "Privacy First"
        static let privacyFirstDescription = "All data stays on your Mac"
        static let keyboardShortcuts = "Keyboard Shortcuts"
        static let keyboardShortcutsDescription = "Quick access with a single keystroke"
    }

    // MARK: - Tutorial

    enum Tutorial {
        static let floatingPanel = "Floating Panel"
        static let floatingPanelDescription =
            "Press your hotkey to open the clipboard panel. Use arrow keys to navigate and Enter to paste."
        // swiftlint:disable:next line_length
        static let searchDescription = "Start typing to search through your clipboard history. Use filters to narrow down results."
        // swiftlint:disable:next line_length
        static let favoritesDescription = "Press ⌘S to mark items as favorites. They'll be preserved even when auto-cleanup runs."
        static let menuBarDescription = "Click the menu bar icon to quickly access recent items or open preferences."
        static let keyShortcuts = "Key Shortcuts"
    }

    // MARK: - App

    static let appName = "PasteShelf"
}
