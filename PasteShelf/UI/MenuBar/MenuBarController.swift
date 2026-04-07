//
//  MenuBarController.swift
//  PasteShelf
//
//  Manages the NSStatusItem in the menu bar with click handling,
//  recent items menu, and context menu options.
//

import AppKit
import Combine
import os.log

// MARK: - MenuBarController

/// Manages the menu bar status item and its interactions
@MainActor
final class MenuBarController: NSObject, ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(storageManager: StorageManager = .shared) {
        self.storageManager = storageManager
        super.init()
    }

    // MARK: Internal

    /// Current menu bar state
    @Published private(set) var state: MenuBarState = .idle

    /// Reference to the floating panel controller
    weak var panelController: FloatingPanelController?

    // MARK: - Setup

    /// Sets up the status item in the menu bar
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else {
            logger.error("Failed to get status item button")
            return
        }

        // Configure button appearance
        button.image = MenuBarIconProvider.idleImage
        button.toolTip = "PasteShelf"

        // Set up click handling
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        #if !APP_STORE
            // Observe plugin changes to refresh menu when plugin items change
            NotificationCenter.default.publisher(for: .pluginMenuItemsChanged)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.logger.debug("Plugin menu items changed, menu will refresh on next open")
                }
                .store(in: &cancellables)

            NotificationCenter.default.publisher(for: .pluginActionsChanged)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.logger.debug("Plugin actions changed, menu will refresh on next open")
                }
                .store(in: &cancellables)
        #endif

        logger.info("Menu bar status item configured")
    }

    /// Removes the status item from the menu bar
    func teardown() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        logger.info("Menu bar status item removed")
    }

    // MARK: - State Management

    /// Updates the menu bar icon based on state
    func updateState(_ newState: MenuBarState) {
        state = newState
        statusItem?.button?.image = newState.image
        statusItem?.button?.toolTip = newState.accessibilityDescription
    }

    /// Shows a brief active state animation when content is captured
    func flashActive() {
        let previousState = state
        updateState(.active)

        // Return to previous state after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateState(previousState == .active ? .idle : previousState)
        }
    }

    // MARK: Private

    /// The status item displayed in the menu bar
    private var statusItem: NSStatusItem?

    /// Storage manager for fetching recent items
    private let storageManager: StorageManager

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Maximum number of recent items to show in menu
    private let maxRecentItems = 5

    /// Logger for menu bar operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "menubar"
    )

    // MARK: - Click Handling

    @objc
    private func statusItemClicked(_ sender: NSStatusBarButton) {
        showContextMenu()
    }

    /// Shows the context menu with options
    private func showContextMenu() {
        Task {
            let menu = await buildContextMenu()
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil // Clear to allow left-click handling again
        }
    }

    // MARK: - Menu Building

    /// Builds the context menu with recent items and options
    private func buildContextMenu() async -> NSMenu {
        let menu = NSMenu()
        menu.minimumWidth = 200

        // Recent items section
        let recentItems = await storageManager.fetchRecentItems(limit: maxRecentItems)

        if recentItems.isEmpty {
            let emptyItem = NSMenuItem(title: "No recent items", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (index, item) in recentItems.enumerated() {
                let menuItem = createMenuItem(for: item, index: index)
                menu.addItem(menuItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Show Panel item
        let showPanelItem = NSMenuItem(
            title: "Show PasteShelf",
            action: #selector(showPanelAction),
            keyEquivalent: "v"
        )
        showPanelItem.keyEquivalentModifierMask = [.command, .shift]
        showPanelItem.target = self
        menu.addItem(showPanelItem)

        menu.addItem(NSMenuItem.separator())

        // Pause/Resume monitoring
        let isPaused = state == .paused
        let pauseItem = NSMenuItem(
            title: isPaused ? "Resume Monitoring" : "Pause Monitoring",
            action: #selector(togglePauseAction),
            keyEquivalent: ""
        )
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences
        let prefsItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(showPreferencesAction),
            keyEquivalent: ","
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit PasteShelf",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    /// Creates a menu item for a clipboard item
    private func createMenuItem(for clipboardItem: ClipboardItem, index: Int) -> NSMenuItem {
        let title = menuItemTitle(for: clipboardItem)
        let keyEquivalent = index < 9 ? String(index + 1) : ""

        let menuItem = NSMenuItem(
            title: title,
            action: #selector(recentItemClicked(_:)),
            keyEquivalent: keyEquivalent
        )
        menuItem.target = self
        menuItem.representedObject = clipboardItem.id
        menuItem.toolTip = clipboardItem.plainTextPreview

        // Add content type icon
        if let contentTypeRaw = clipboardItem.contentType,
           let contentType = ContentType(rawValue: contentTypeRaw),
           let image = NSImage(systemSymbolName: contentType.icon, accessibilityDescription: nil)
        {
            menuItem.image = image
        }

        return menuItem
    }

    /// Generates a truncated title for a clipboard item.
    /// Titles are capped to keep the menu compact.
    private func menuItemTitle(for item: ClipboardItem) -> String {
        let maxLength = 10

        if let preview = item.plainTextPreview, !preview.isEmpty {
            // Clean up whitespace and truncate
            let cleaned = preview
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\t", with: " ")
                .trimmingCharacters(in: .whitespaces)

            let result: String = if cleaned.count <= maxLength {
                cleaned
            } else {
                String(cleaned.prefix(maxLength - 3)) + "..."
            }

            // Also cap by rendered pixel width to handle wide glyphs (em dashes, CJK)
            let maxWidth: CGFloat = 160
            let font = NSFont.menuFont(ofSize: 0)
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            if (result as NSString).size(withAttributes: attrs).width > maxWidth {
                var end = result.count
                while end > 1 {
                    end -= 1
                    let candidate = String(result.prefix(end)) + "..."
                    if (candidate as NSString).size(withAttributes: attrs).width <= maxWidth {
                        return candidate
                    }
                }
            }
            return result
        }

        // Fallback to content type description
        if let contentTypeRaw = item.contentType,
           let contentType = ContentType(rawValue: contentTypeRaw)
        {
            return "[\(contentType.displayName)]"
        }

        return "[Unknown Content]"
    }

    // MARK: - Menu Actions

    @objc
    private func showPanelAction() {
        panelController?.show()
    }

    @objc
    private func togglePauseAction() {
        NotificationCenter.default.post(
            name: .toggleClipboardMonitoring,
            object: nil
        )
    }

    @objc
    private func showPreferencesAction() {
        NotificationCenter.default.post(
            name: .showPreferences,
            object: nil
        )
    }

    @objc
    private func quitAction() {
        NSApp.terminate(nil)
    }

    @objc
    private func recentItemClicked(_ sender: NSMenuItem) {
        guard let itemId = sender.representedObject as? UUID else {
            return
        }

        // Post notification to paste the item
        NotificationCenter.default.post(
            name: .pasteClipboardItem,
            object: itemId
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted to toggle clipboard monitoring pause state
    static let toggleClipboardMonitoring = Notification.Name("toggleClipboardMonitoring")

    /// Posted to show preferences window
    static let showPreferences = Notification.Name("showPreferences")

    /// Posted to paste a specific clipboard item
    static let pasteClipboardItem = Notification.Name("pasteClipboardItem")

    /// Posted to show the main window (from URL scheme and AppleScript)
    static let showMainWindow = Notification.Name("ShowMainWindow")

    /// Posted to show the main window with a search query
    static let showMainWindowWithSearch = Notification.Name("ShowMainWindowWithSearch")

    /// Posted when new clipboard content is captured (for plugin subscription)
    static let clipboardContentCaptured = Notification.Name("com.pasteshelf.clipboardContentCaptured")

    /// Posted when clipboard history items are deleted (single or bulk)
    static let clipboardHistoryChanged = Notification.Name("com.pasteshelf.clipboardHistoryChanged")
}
