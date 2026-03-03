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

    /// Retained reference to plugin context factory for re-initialization on re-enable.
    private var pluginContextFactory: PluginContextFactoryImpl?

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

        // Eagerly bootstrap SyncManager so sync starts if previously enabled
        // (gated by enterprise settings — local-only mode disables sync)
        let enterpriseSettings = SettingsManager.shared.enterprise
        if enterpriseSettings.cloudSyncEnabled && !enterpriseSettings.localStorageOnly {
            _ = SyncManager.shared
        }

        // Start auto-cleanup manager
        AutoCleanupManager.shared.start()

        // Initialize automation engine
        initializeAutomation()

        // Initialize plugin system (gated by enterprise settings)
        if SettingsManager.shared.enterprise.pluginsEnabled {
            initializePluginSystem()
        }

        // Start background embedding generation for semantic search
        startBackgroundEmbeddingGeneration()

        // Start background OCR processing for image items
        startBackgroundOCRProcessing()

        // Configure general security lock (biometric auth, auto-lock timeout)
        SecurityLockService.shared.configure()

        // Initialize enterprise services (DLP, compliance, MDM monitoring)
        initializeEnterpriseServices()

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

        // Clear clipboard history on quit if security setting is enabled
        if SettingsManager.shared.security.clearOnQuit {
            Task {
                await storageManager.deleteAllItems(keepFavorites: false)
            }
            logger.info("Clipboard history cleared on quit (security policy)")
        }

        // Stop clipboard monitoring
        clipboardMonitor?.stopMonitoring()

        // Unregister hotkey
        hotkeyManager?.unregisterHotkey()

        // Stop auto-cleanup
        AutoCleanupManager.shared.stop()

        // Stop admin monitoring (health reporting, policy sync, analytics, audit)
        AdminManager.shared.stopMonitoring()

        // Stop enterprise monitoring
        MDMManager.shared.stopMonitoring()

        // Stop sync engine (cancels auto-sync task, network monitor, WebSocket)
        SyncManager.shared.stop()

        // Shut down plugin system (calls willUnload on active plugins)
        Task {
            await PluginManager.shared.shutdown()
        }

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
        let config = HotkeyConfiguration.load()
        hotkeyManager = HotkeyManager(configuration: config)
        hotkeyManager?.onHotkeyPressed = { [weak self] in
            self?.floatingPanelController?.toggle()
        }
        hotkeyManager?.register(configuration: config)
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
            SettingsManager.shared.update { $0.privacy.isMonitoringPaused = false }
        } else {
            monitor.pause()
            menuBarController?.updateState(.paused)
            SettingsManager.shared.update { $0.privacy.isMonitoringPaused = true }
        }
    }

    /// Explicitly sets monitoring pause state to prevent drift
    private func setMonitoringPaused(_ paused: Bool) {
        guard let monitor = clipboardMonitor else { return }

        if paused && !monitor.isPaused {
            monitor.pause()
            menuBarController?.updateState(.paused)
        } else if !paused && monitor.isPaused {
            monitor.resume()
            menuBarController?.updateState(.idle)
        }
    }

    private func showPreferences() {
        PreferencesWindowController.shared.show()
        logger.debug("Preferences window shown")
    }

    private func pasteItem(id: UUID) {
        Task {
            await floatingPanelController?.viewModel.paste(itemId: id)

            // Log paste as audit event
            await AuditManager.shared.logClipboardEvent(
                action: .pastePerformed,
                resourceId: id.uuidString
            )
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

        // Apply OCR confidence threshold
        OCRManager.shared.setConfidenceThreshold(Float(settings.search.ocrConfidenceThreshold))

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

        // Apply monitoring pause state explicitly to prevent drift
        setMonitoringPaused(settings.privacy.isMonitoringPaused)

        // Apply OCR confidence threshold
        OCRManager.shared.setConfidenceThreshold(Float(settings.search.ocrConfidenceThreshold))

        // Handle semantic search toggle: start or cancel background indexing
        if settings.search.semanticSearchEnabled {
            startBackgroundEmbeddingGeneration()
        } else {
            EmbeddingGenerator.shared.cancelIndexing()
        }

        // Handle OCR search toggle: start or cancel background processing
        if settings.search.ocrSearchEnabled {
            startBackgroundOCRProcessing()
        } else {
            OCRGenerator.shared.cancelProcessing()
        }

        // Apply history limit by triggering cleanup if needed
        if let limit = settings.general.historyLimit.limit {
            Task {
                await storageManager.deleteItemsExceedingLimit(limit, keepFavorites: true)
            }
        }

        // Re-configure security lock service when security settings change
        SecurityLockService.shared.configure()

        // Refresh HIPAA and GDPR/SOC2 compliance state on settings change
        ComplianceManager.shared.refreshHIPAAState()
        ComplianceManager.shared.refreshComplianceSettings()

        // Propagate sync settings changes (for all users, not just MDM-managed)
        let syncShouldRun = settings.enterprise.cloudSyncEnabled && !settings.enterprise.localStorageOnly
        if syncShouldRun {
            let syncManager = SyncManager.shared
            if !syncManager.isEnabled {
                syncManager.isEnabled = true
            }
            Task { try? await syncManager.start() }
        } else {
            SyncManager.shared.stop()
        }

        // Propagate plugin enable/disable for all devices (not just MDM-managed)
        if settings.enterprise.pluginsEnabled, !PluginManager.shared.isInitialized {
            if let factory = pluginContextFactory {
                Task {
                    await PluginManager.shared.initialize(contextFactory: factory)
                    logger.info("Plugin system re-initialized after settings re-enable")
                }
            } else {
                initializePluginSystem()
            }
        } else if !settings.enterprise.pluginsEnabled, PluginManager.shared.isInitialized {
            Task { await PluginManager.shared.shutdown() }
            logger.info("Plugin system disabled via settings")
        }

        // Re-apply MDM enterprise key overrides on settings change
        applyMDMEnterpriseKeys()

        // Re-check admin console configuration (MDM URL may have changed mid-session)
        configureAdminConsoleIfNeeded()

        logger.debug("Settings change handled")
    }

    // MARK: - Semantic Search

    /// Starts background embedding generation for semantic search
    private func startBackgroundEmbeddingGeneration() {
        // Check if semantic search is enabled in settings
        guard SettingsManager.shared.search.semanticSearchEnabled else {
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

    // MARK: - OCR

    /// Starts background OCR processing for existing image items
    private func startBackgroundOCRProcessing() {
        guard SettingsManager.shared.search.ocrSearchEnabled else {
            logger.debug("OCR search disabled, skipping background OCR processing")
            return
        }

        Task.detached(priority: .background) { [logger] in
            let processed = await OCRGenerator.shared.processAllMissingOCR()
            if processed > 0 {
                logger.info("Background OCR processing completed: \(processed) items processed")
            }
        }
    }

    /// Generates OCR text for a newly captured clipboard item (if it's an image)
    private func generateOCRForNewItem(id: UUID, contentType: ContentType) {
        guard SettingsManager.shared.search.ocrSearchEnabled,
              contentType.isImageType else { return }

        Task.detached(priority: .background) {
            await OCRGenerator.shared.generateOCR(for: id)
        }
    }

    /// Generates embedding for a newly captured clipboard item
    private func generateEmbeddingForNewItem(id: UUID) {
        // Check if semantic search is enabled
        guard SettingsManager.shared.search.semanticSearchEnabled else { return }

        Task.detached(priority: .background) {
            await EmbeddingGenerator.shared.generateEmbedding(for: id)
        }
    }

    // MARK: - Enterprise Services

    /// Initializes enterprise services: DLP, compliance, MDM monitoring, and admin console.
    ///
    /// AdminManager/AuditManager require an `AdminConsoleConfiguration` with a server URL
    /// to activate — they are configured lazily when the admin console URL is set (via MDM
    /// or user configuration). DLPManager and ComplianceManager are self-contained.
    private func initializeEnterpriseServices() {
        // Configure SSO with storage backends
        SSOManager.shared.configure(
            sessionStore: KeychainSSOSessionStore(),
            providerStore: UserDefaultsIdentityProviderStore()
        )

        // Configure DLP (self-contained, loads rules from CoreData)
        DLPManager.shared.configure()

        // Configure compliance (enables HIPAA/GDPR/SOC2 subsystem)
        ComplianceManager.shared.configure()

        // Load MDM configuration and start monitoring for profile changes
        MDMManager.shared.loadConfiguration()
        MDMManager.shared.startMonitoring()

        // Apply MDM enterprise key overrides that affect enterprise services
        applyMDMEnterpriseKeys()

        // Configure admin console if URL is available (from MDM or prior setup)
        configureAdminConsoleIfNeeded()

        logger.debug("Enterprise services initialized")
    }

    /// Applies MDM enterprise keys that affect services outside of AppSettings.
    ///
    /// Handles keys that control runtime services (DLP, SSO, sync, plugins) rather
    /// than simple preference values already mapped by `MDMPolicyEnforcer`.
    private func applyMDMEnterpriseKeys() {
        let config = MDMManager.shared.configuration
        guard config.isManaged else { return }

        // --- DLP enable/disable via MDM ---
        if let value = config.effectiveValue(for: .dlpEnabled), case .bool(let enabled) = value {
            if enabled {
                DLPManager.shared.configure()
                Task { await DLPManager.shared.installDefaultRulesIfNeeded() }
            } else {
                DLPManager.shared.disable()
            }
        }

        // DLP: block/unblock credit card patterns via MDM
        if let value = config.effectiveValue(for: .blockCreditCards), case .bool(let enabled) = value {
            Task { await setDLPDefaultRule(named: "Credit Card", enabled: enabled) }
        }

        // DLP: block/unblock API key patterns via MDM
        if let value = config.effectiveValue(for: .blockAPIKeys), case .bool(let enabled) = value {
            Task { await setDLPDefaultRule(named: "API Key", enabled: enabled) }
        }

        // --- SSO configuration via MDM ---
        applySSOConfiguration(from: config)

        // --- Sync / storage gating via MDM ---
        let settings = SettingsManager.shared.settings
        if settings.enterprise.localStorageOnly || !settings.enterprise.cloudSyncEnabled {
            SyncManager.shared.stop()
            logger.info("MDM: sync disabled (localStorageOnly=\(settings.enterprise.localStorageOnly), cloudSyncEnabled=\(settings.enterprise.cloudSyncEnabled))")
        }

        // --- Plugin gating via MDM ---
        if !settings.enterprise.pluginsEnabled, PluginManager.shared.isInitialized {
            Task { await PluginManager.shared.shutdown() }
            logger.info("MDM: plugin system disabled")
        } else if settings.enterprise.pluginsEnabled, !PluginManager.shared.isInitialized {
            // Re-enable: re-initialize with stored context factory
            if let factory = pluginContextFactory {
                Task {
                    await PluginManager.shared.initialize(contextFactory: factory)
                    logger.info("Plugin system re-initialized after re-enable")
                }
            } else {
                initializePluginSystem()
                logger.info("Plugin system initialized on first enable")
            }
        }

        // --- Security: clear on quit ---
        // clearOnQuit, requireBiometricAuth, autoLockTimeout are now persisted
        // in AppSettings.security via MDMPolicyEnforcer and consumed at runtime
        // (clearOnQuit is handled in applicationWillTerminate)
    }

    /// Configures SSO from MDM-pushed provider configuration.
    private func applySSOConfiguration(from config: MDMConfiguration) {
        guard let ssoValue = config.effectiveValue(for: .ssoEnabled),
              case .bool(let ssoEnabled) = ssoValue, ssoEnabled else { return }

        // Read provider type and domain from MDM
        let providerType: IdentityProviderType
        if let provValue = config.effectiveValue(for: .ssoProvider),
           case .string(let provString) = provValue {
            providerType = IdentityProviderType(rawValue: provString)
        } else {
            providerType = .oidc // Default to OIDC
        }

        let domain: String
        if let domValue = config.effectiveValue(for: .ssoDomain),
           case .string(let domString) = domValue {
            domain = domString
        } else {
            logger.warning("MDM: SSO enabled but no SSODomain configured — skipping SSO setup")
            return
        }

        // Check if a provider with this domain already exists in the store
        Task {
            guard let providerStore = SSOManager.shared.providerStore else { return }
            let existing = try? await providerStore.loadAll()
            let alreadyConfigured = existing?.contains { $0.entityId == domain } ?? false

            if !alreadyConfigured {
                // Create a minimal MDM-provisioned provider entry
                let provider = IdentityProvider(
                    name: "MDM SSO (\(domain))",
                    type: providerType,
                    entityId: domain,
                    isEnabled: true
                )
                try? await providerStore.save(provider)
                logger.info("MDM: SSO provider created for domain '\(domain)' (type: \(providerType.rawValue))")
            }
        }
    }

    /// Sets a default DLP rule to enabled or disabled by partial name match (MDM enforcement).
    private func setDLPDefaultRule(named partialName: String, enabled: Bool) async {
        // Ensure default rules are installed first
        await DLPManager.shared.installDefaultRulesIfNeeded()

        for rule in DLPManager.shared.rules where rule.name.localizedCaseInsensitiveContains(partialName) {
            if rule.isEnabled != enabled {
                var updated = rule
                updated.isEnabled = enabled
                try? await DLPManager.shared.updateRule(updated)
            }
        }
    }

    /// Configures AdminManager (and by extension AuditManager) if an admin console URL is available.
    private func configureAdminConsoleIfNeeded() {
        // Check MDM for admin console URL
        var serverURL: URL?
        if case .string(let mdmURL) = MDMManager.shared.configuration.effectiveValue(for: .adminConsoleURL),
           let url = URL(string: mdmURL) {
            serverURL = url
        }

        // Also check if admin console was previously configured by the user
        if serverURL == nil, let storedURL = UserDefaults.standard.string(forKey: "com.pasteshelf.admin.serverURL"),
           let url = URL(string: storedURL) {
            serverURL = url
        }

        guard let url = serverURL else {
            logger.debug("Admin console not configured — AuditManager will remain dormant")
            return
        }

        let orgID = MDMManager.shared.organizationID ?? ""
        let config = AdminConsoleConfiguration(
            serverURL: url,
            organizationID: orgID,
            apiKey: nil,
            isEnabled: true,
            pollingInterval: 300
        )

        AdminManager.shared.configure(with: config)
        logger.info("Admin console configured via MDM/stored URL")
    }

    // MARK: - Automation

    /// Initializes the plugin system
    private func initializePluginSystem() {
        let factory = PluginContextFactoryImpl()
        pluginContextFactory = factory
        Task {
            await PluginManager.shared.initialize(contextFactory: factory)
            logger.debug("Plugin system initialized")
        }
    }

    /// Initializes the automation engine and seeds default rules
    private func initializeAutomation() {
        // Eagerly initialize the automation engine to avoid lazy-init timing window
        _ = AutomationEngine.shared

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
        // Flash menu bar icon (UI — always runs immediately)
        menuBarController?.flashActive()

        // Reload floating panel if visible (UI — always runs immediately)
        if floatingPanelController?.isVisible == true {
            Task {
                await floatingPanelController?.viewModel.loadItems()
            }
        }

        // Sequential pipeline: DLP → automation → plugins → audit → webhooks → embeddings/OCR
        Task {
            do {
                // GDPR consent gate: skip entire pipeline if clipboard monitoring consent revoked
                if ComplianceManager.shared.isGDPRActive,
                   !GDPRConsentManager.shared.isConsentGranted(for: .clipboardMonitoring) {
                    logger.info("Pipeline skipped: GDPR clipboardMonitoring consent not granted")
                    return
                }

                // Stage 1: DLP evaluation — may block, redact, or pass through.
                // Returns the (possibly redacted) content for downstream stages.
                let dlpResult = await processDLPEvaluation(for: content, sourceApp: sourceApp)
                if dlpResult.blocked { return }
                let pipelineContent = dlpResult.content

                // Stage 2: Run automation rules — may delete the item or transform content
                let automationResult = await processAutomation(for: pipelineContent, sourceApp: sourceApp)
                if automationResult.deleted { return }
                let finalContent = automationResult.content

                // Stage 3: Post notification for plugin system (gated by GDPR thirdPartyPlugins consent)
                if !ComplianceManager.shared.isGDPRActive
                    || GDPRConsentManager.shared.isConsentGranted(for: .thirdPartyPlugins) {
                    NotificationCenter.default.post(
                        name: .clipboardContentCaptured,
                        object: nil,
                        userInfo: ["content": finalContent]
                    )
                }

                // Stage 4: Log clipboard capture as audit event (gated by GDPR auditLogging consent)
                if !ComplianceManager.shared.isGDPRActive
                    || GDPRConsentManager.shared.isConsentGranted(for: .auditLogging) {
                    await AuditManager.shared.logClipboardEvent(
                        action: .copyCaptured,
                        resourceId: finalContent.id.uuidString,
                        detail: ["contentType": finalContent.primaryType.displayName]
                    )
                }

                // Stage 5: Fire webhook events for clipboard capture (gated by GDPR thirdPartyPlugins consent)
                if !ComplianceManager.shared.isGDPRActive
                    || GDPRConsentManager.shared.isConsentGranted(for: .thirdPartyPlugins) {
                    await WebhookManager.shared.sendClipboardCreated(content: finalContent)
                }

                // Stage 6: Generate embedding for semantic search
                generateEmbeddingForNewItem(id: finalContent.id)

                // Stage 7: Generate OCR for image content
                generateOCRForNewItem(id: finalContent.id, contentType: finalContent.primaryType)
            } catch {
                logger.error("Pipeline error for item \(content.id): \(error.localizedDescription)")
            }
        }

        logger.debug("Captured: \(content.primaryType.displayName)")
    }

    /// Result of DLP evaluation indicating whether content was blocked and providing
    /// the (possibly redacted) content for downstream pipeline stages.
    private struct DLPPipelineResult {
        let blocked: Bool
        let content: ClipboardContent
    }

    /// Evaluates DLP rules against captured content and enforces block/redact actions.
    ///
    /// Returns a `DLPPipelineResult` indicating whether the item was blocked and
    /// providing the (possibly redacted) content for downstream stages.
    private func processDLPEvaluation(for content: ClipboardContent, sourceApp: SourceApp? = nil) async -> DLPPipelineResult {
        guard DLPManager.shared.isEnabled else {
            return DLPPipelineResult(blocked: false, content: content)
        }

        let result = await DLPManager.shared.evaluate(content, sourceApp: sourceApp)

        guard result.hasViolations else {
            return DLPPipelineResult(blocked: false, content: content)
        }

        // Block: delete the already-saved item and log audit event
        if result.shouldBlock {
            let deleted = await storageManager.deleteItem(byId: content.id)
            if deleted {
                logger.info("DLP: blocked and deleted item \(content.id)")

                // Audit: log that clipboard content was blocked by DLP
                await AuditManager.shared.logClipboardEvent(
                    action: .copyBlocked,
                    resourceId: content.id.uuidString,
                    detail: [
                        "contentType": content.primaryType.displayName,
                        "reason": "dlp_blocked",
                    ]
                )
            }

            return DLPPipelineResult(blocked: true, content: content)
        }

        // Redact: update the stored text and propagate redacted content downstream
        if result.shouldRedact, let redactedText = result.redactedContent {
            let redactSuccess = await storageManager.updatePlainText(itemId: content.id, text: redactedText, stripOtherRepresentations: true)
            if !redactSuccess {
                logger.error("DLP: failed to persist redacted content for item \(content.id) — deleting to prevent sensitive data leak")
                _ = await storageManager.deleteItem(byId: content.id)
                return DLPPipelineResult(blocked: true, content: content)
            }
            logger.info("DLP: redacted content for item \(content.id)")

            // Audit: log that clipboard content was redacted by DLP
            await AuditManager.shared.logClipboardEvent(
                action: .copyRedacted,
                resourceId: content.id.uuidString,
                detail: [
                    "contentType": content.primaryType.displayName,
                    "reason": "dlp_redacted",
                ]
            )

            // Create a copy with redacted text so downstream stages don't see sensitive data
            var redactedContent = content
            redactedContent.plainText = redactedText
            redactedContent.html = nil
            redactedContent.url = nil
            redactedContent.rtfData = nil
            return DLPPipelineResult(blocked: false, content: redactedContent)
        }

        return DLPPipelineResult(blocked: false, content: content)
    }

    /// Result of automation processing indicating whether content was deleted and providing
    /// the (possibly transformed) content for downstream pipeline stages.
    private struct AutomationPipelineResult {
        let deleted: Bool
        let content: ClipboardContent
    }

    /// Processes automation rules for captured content.
    ///
    /// Returns an `AutomationPipelineResult` with the (possibly transformed) content
    /// for downstream stages, or `deleted: true` if the item was removed.
    private func processAutomation(
        for content: ClipboardContent,
        sourceApp: SourceApp?
    ) async -> AutomationPipelineResult {
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

                // Audit: log that automation deleted the item
                let ruleNames = result.matchedRules.map(\.name).joined(separator: ", ")
                await AuditManager.shared.logClipboardEvent(
                    action: .automationDeleted,
                    resourceId: content.id.uuidString,
                    detail: [
                        "contentType": content.primaryType.displayName,
                        "matchedRules": ruleNames,
                    ]
                )
            }
            return AutomationPipelineResult(deleted: true, content: content)
        }

        // Persist transformed content if text was changed by automation rules
        let transformed = result.transformedContent
        if transformed.plainText != content.plainText, let newText = transformed.plainText {
            await storageManager.updatePlainText(itemId: content.id, text: newText)
            logger.info("Automation: persisted transformed text for item \(content.id)")
        }

        return AutomationPipelineResult(deleted: false, content: transformed)
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
