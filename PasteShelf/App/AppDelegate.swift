//
//  AppDelegate.swift
//  PasteShelf
//
//  Main application delegate that coordinates menu bar, floating panel,
//  clipboard monitoring, and global hotkey registration.
//

import AppKit
import Combine
import os.log

/// Main application delegate for PasteShelf
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Controllers

    /// Menu bar status item controller
    var menuBarController: MenuBarController?

    /// Floating panel controller
    var floatingPanelController: FloatingPanelController?

    /// Global hotkey manager
    var hotkeyManager: HotkeyManager?

    // MARK: - Core Services

    /// Clipboard monitor instance
    var clipboardMonitor: ClipboardMonitor?

    /// Storage manager reference
    let storageManager = StorageManager.shared

    // MARK: - Private Properties

    /// Logger for app delegate operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "app"
    )

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("PasteShelf launching")

        // Apply saved settings on launch
        applySettingsOnLaunch()

        // Set up core services
        setupClipboardMonitor()

        // Set up UI controllers
        setupMenuBar()
        setupFloatingPanel()

        // Set up global hotkey
        setupHotkey()

        // Set up notification observers
        setupNotificationObservers()

        // Set up settings observers
        setupSettingsObservers()

        // Start clipboard monitoring
        clipboardMonitor?.startMonitoring()

        // Start auto-cleanup manager
        AutoCleanupManager.shared.start()

        // Show onboarding if needed
        showOnboardingIfNeeded()

        logger.info("PasteShelf launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("PasteShelf terminating")

        // Stop clipboard monitoring
        clipboardMonitor?.stopMonitoring()

        // Unregister hotkey
        hotkeyManager?.unregisterHotkey()

        // Tear down menu bar
        menuBarController?.teardown()

        logger.info("PasteShelf terminated")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Show floating panel when dock icon is clicked (if visible)
        floatingPanelController?.show()
        return false
    }

    // MARK: - Setup Methods

    private func setupClipboardMonitor() {
        clipboardMonitor = ClipboardMonitor(storage: storageManager)
        clipboardMonitor?.delegate = self
    }

    private func setupMenuBar() {
        menuBarController = MenuBarController(storageManager: storageManager)
        menuBarController?.setup()
    }

    private func setupFloatingPanel() {
        floatingPanelController = FloatingPanelController(storageManager: storageManager)
        floatingPanelController?.clipboardMonitor = clipboardMonitor

        // Connect menu bar to panel
        menuBarController?.panelController = floatingPanelController
    }

    private func setupHotkey() {
        hotkeyManager = HotkeyManager()
        hotkeyManager?.onHotkeyPressed = { [weak self] in
            self?.floatingPanelController?.toggle()
        }
        hotkeyManager?.registerDefaultHotkey()
    }

    private func setupNotificationObservers() {
        // Toggle clipboard monitoring
        NotificationCenter.default.publisher(for: .toggleClipboardMonitoring)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.toggleMonitoring()
            }
            .store(in: &cancellables)

        // Show preferences
        NotificationCenter.default.publisher(for: .showPreferences)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.showPreferences()
            }
            .store(in: &cancellables)

        // Paste specific item
        NotificationCenter.default.publisher(for: .pasteClipboardItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let itemId = notification.object as? UUID {
                    self?.pasteItem(id: itemId)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    private func toggleMonitoring() {
        guard let monitor = clipboardMonitor else { return }

        if monitor.isPaused {
            monitor.resume()
            menuBarController?.updateState(.idle)
        } else {
            monitor.pause()
            menuBarController?.updateState(.paused)
        }
    }

    private func showPreferences() {
        PreferencesWindowController.shared.show()
        logger.debug("Preferences window shown")
    }

    private func pasteItem(id: UUID) {
        Task {
            await floatingPanelController?.viewModel.paste(itemId: id)
        }
    }

    // MARK: - Onboarding

    private func showOnboardingIfNeeded() {
        guard OnboardingWindowController.shared.shouldShowOnboarding() else {
            logger.debug("Onboarding already completed")
            return
        }

        logger.info("Showing onboarding")
        OnboardingWindowController.shared.show { [weak self] in
            self?.logger.info("Onboarding completed")
            // Reload hotkey after onboarding in case user changed it
            self?.hotkeyManager?.registerDefaultHotkey()
        }
    }

    // MARK: - Settings

    private func applySettingsOnLaunch() {
        let settings = SettingsManager.shared.settings

        // Apply dock visibility setting
        DockVisibilityManager.shared.setVisible(settings.general.showInDock)

        // Apply theme setting
        applyTheme(settings.appearance.theme)

        // Refresh launch at login status (to ensure UI matches actual state)
        LaunchAtLoginManager.shared.refreshStatus()

        logger.debug("Settings applied on launch")
    }

    private func applyTheme(_ theme: AppTheme) {
        switch theme {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func setupSettingsObservers() {
        // Observe settings changes
        NotificationCenter.default.publisher(for: .settingsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let settings = notification.object as? AppSettings else { return }
                self?.handleSettingsChange(settings)
            }
            .store(in: &cancellables)
    }

    private func handleSettingsChange(_ settings: AppSettings) {
        // Apply hotkey changes
        let hotkeyConfig = settings.shortcuts.globalHotkey.toHotkeyConfiguration
        hotkeyManager?.updateHotkey(hotkeyConfig)

        // Apply history limit by triggering cleanup if needed
        if let limit = settings.general.historyLimit.limit {
            Task {
                await storageManager.deleteItemsExceedingLimit(limit, keepFavorites: true)
            }
        }

        logger.debug("Settings change handled")
    }
}

// MARK: - ClipboardMonitorDelegate

extension AppDelegate: ClipboardMonitorDelegate {
    func clipboardMonitor(
        _ monitor: ClipboardMonitoring,
        didCapture content: ClipboardContent,
        from sourceApp: SourceApp?
    ) {
        // Flash menu bar icon
        menuBarController?.flashActive()

        // Reload floating panel if visible
        if floatingPanelController?.isVisible == true {
            Task {
                await floatingPanelController?.viewModel.loadItems()
            }
        }

        logger.debug("Captured: \(content.primaryType.displayName)")
    }

    func clipboardMonitor(
        _ monitor: ClipboardMonitoring,
        didExcludeContentWithReason reason: ExclusionReason
    ) {
        logger.debug("Excluded: \(String(describing: reason))")
    }

    func clipboardMonitor(
        _ monitor: ClipboardMonitoring,
        didEncounterError error: Error
    ) {
        menuBarController?.updateState(.error)
        logger.error("Monitor error: \(error.localizedDescription)")
    }
}
