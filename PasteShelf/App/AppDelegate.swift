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

        // Handle test launch arguments
        #if DEBUG
        if CommandLine.arguments.contains("--reset-onboarding") {
            OnboardingViewModel.resetOnboarding()
        }
        #endif

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

        // Start clipboard monitoring (always start timer, then pause if needed)
        clipboardMonitor?.startMonitoring()
        if SettingsManager.shared.privacy.isMonitoringPaused {
            clipboardMonitor?.pause()
            menuBarController?.updateState(.paused)
            logger.info("Clipboard monitoring started in paused state (user preference)")
        }

        // Start auto-cleanup manager
        AutoCleanupManager.shared.start()

        // Initialize automation engine
        initializeAutomation()

        // Start background embedding generation for semantic search
        startBackgroundEmbeddingGeneration()

        // Show onboarding if needed
        #if DEBUG
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if !isRunningTests && !CommandLine.arguments.contains("--skip-onboarding") {
            showOnboardingIfNeeded()
        }

        if CommandLine.arguments.contains("--show-preferences") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showPreferences()
            }
        }
        #else
        showOnboardingIfNeeded()
        #endif

        logger.info("PasteShelf launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("PasteShelf terminating")

        // Stop clipboard monitoring
        clipboardMonitor?.stopMonitoring()

        // Unregister hotkey
        hotkeyManager?.unregisterHotkey()

        // Stop auto-cleanup
        AutoCleanupManager.shared.stop()

        // Tear down menu bar
        menuBarController?.teardown()

        logger.info("PasteShelf terminated")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Show floating panel when dock icon is clicked (if visible)
        floatingPanelController?.show()
        return false
    }

    /// Handle pasteshelf:// URL scheme
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "pasteshelf" {
                logger.info("Handling URL scheme: \(url.absoluteString)")
                URLSchemeHandler.shared.handleURL(url)
            }
        }
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
        // Register the hotkey from SettingsManager (HotkeyManager.init loads from SettingsManager)
        hotkeyManager?.register(configuration: hotkeyManager?.configuration ?? .default)
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

        // Show main window (from URL scheme pasteshelf://show and AppleScript)
        NotificationCenter.default.publisher(for: .showMainWindow)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.floatingPanelController?.show()
            }
            .store(in: &cancellables)

        // Show main window with search (from URL scheme pasteshelf://search)
        NotificationCenter.default.publisher(for: .showMainWindowWithSearch)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.floatingPanelController?.show()
                if let query = notification.userInfo?["query"] as? String {
                    self?.floatingPanelController?.viewModel.searchQuery = query
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
            let config = HotkeyConfiguration.load()
            self?.hotkeyManager?.register(configuration: config)
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

        // Apply theme changes
        applyTheme(settings.appearance.theme)

        // Apply dock visibility changes
        DockVisibilityManager.shared.setVisible(settings.general.showInDock)

        // Apply launch at login changes
        LaunchAtLoginManager.shared.setEnabled(settings.general.launchAtLogin)

        // Apply monitoring pause state
        if settings.privacy.isMonitoringPaused != clipboardMonitor?.isPaused {
            toggleMonitoring()
        }

        // TODO: Wire checkForUpdates setting to an update framework (e.g., Sparkle)
        // settings.general.checkForUpdates is stored but not yet consumed by any service

        // Apply history limit by triggering cleanup if needed
        if let limit = settings.general.historyLimit.limit {
            Task {
                await storageManager.deleteItemsExceedingLimit(limit, keepFavorites: true)
            }
        }

        logger.debug("Settings change handled")
    }

    // MARK: - Semantic Search

    /// Starts background embedding generation for semantic search
    private func startBackgroundEmbeddingGeneration() {
        // Check if semantic search is enabled in settings
        let semanticEnabled = UserDefaults.standard.bool(forKey: "semanticSearchEnabled")
        guard semanticEnabled else {
            logger.debug("Semantic search disabled, skipping embedding generation")
            return
        }

        // Run embedding generation in background
        Task.detached(priority: .background) { [logger] in
            // Clean up outdated embeddings first
            await EmbeddingGenerator.shared.clearOutdatedEmbeddings()

            // Index any items missing embeddings
            let indexed = await EmbeddingGenerator.shared.indexAllMissingEmbeddings()
            if indexed > 0 {
                logger.info("Background embedding generation completed: \(indexed) items indexed")
            }
        }
    }

    /// Generates embedding for a newly captured clipboard item
    private func generateEmbeddingForNewItem(id: UUID) {
        // Check if semantic search is enabled
        let semanticEnabled = UserDefaults.standard.bool(forKey: "semanticSearchEnabled")
        guard semanticEnabled else { return }

        Task.detached(priority: .background) {
            await EmbeddingGenerator.shared.generateEmbedding(for: id)
        }
    }

    // MARK: - Automation

    /// Initializes the automation engine and seeds default rules
    private func initializeAutomation() {
        // Seed default rules if this is first launch
        Task {
            await AutomationRuleStorage.shared.seedDefaultRulesIfNeeded()
        }

        logger.debug("Automation engine initialized")
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

        // Post notification for plugin system
        NotificationCenter.default.post(
            name: .clipboardContentCaptured,
            object: nil,
            userInfo: ["content": content]
        )

        // Run automation rules
        Task {
            await processAutomation(for: content, sourceApp: sourceApp)
        }

        // Reload floating panel if visible
        if floatingPanelController?.isVisible == true {
            Task {
                await floatingPanelController?.viewModel.loadItems()
            }
        }

        // Generate embedding for semantic search
        generateEmbeddingForNewItem(id: content.id)

        logger.debug("Captured: \(content.primaryType.displayName)")
    }

    /// Processes automation rules for captured content
    private func processAutomation(
        for content: ClipboardContent,
        sourceApp: SourceApp?
    ) async {
        let result = await AutomationEngine.shared.evaluateRules(
            for: content,
            trigger: .onCapture,
            sourceApp: sourceApp
        )

        // Log automation results
        if !result.matchedRules.isEmpty {
            let ruleNames = result.matchedRules.map(\.name).joined(separator: ", ")
            logger.info("Automation: \(result.matchedRules.count) rules matched [\(ruleNames)]")
        }

        if !result.errors.isEmpty {
            for error in result.errors {
                logger.warning("Automation error: \(String(describing: error))")
            }
        }

        // If shouldDelete is true, remove the item that was already saved
        if result.shouldDelete {
            let deleted = await storageManager.deleteItem(byId: content.id)
            if deleted {
                logger.info("Automation: deleted item \(content.id) per rule action")
            }
        }
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
