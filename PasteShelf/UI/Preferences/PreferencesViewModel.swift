//
//  PreferencesViewModel.swift
//  PasteShelf
//
//  ViewModel for the preferences window.
//  Manages settings state and coordinates with SettingsManager.
//

import AppKit
import Combine
import Foundation
import os.log

/// ViewModel for preferences management
@MainActor
final class PreferencesViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Currently selected tab
    @Published var selectedTab: PreferencesTab = .general

    // MARK: - General Settings

    @Published var launchAtLogin: Bool {
        didSet { updateGeneral() }
    }

    @Published var showInDock: Bool {
        didSet { updateGeneral() }
    }

    @Published var historyLimit: HistoryLimit {
        didSet { updateGeneral() }
    }

    @Published var captureTextContent: Bool {
        didSet { updateGeneral() }
    }

    @Published var captureImageContent: Bool {
        didSet { updateGeneral() }
    }

    @Published var captureFileContent: Bool {
        didSet { updateGeneral() }
    }

    @Published var captureLinkContent: Bool {
        didSet { updateGeneral() }
    }

    // MARK: - Privacy Settings

    @Published var autoDeleteEnabled: Bool {
        didSet { updatePrivacy() }
    }

    @Published var autoDeleteDays: Int {
        didSet { updatePrivacy() }
    }

    @Published var isMonitoringPaused: Bool {
        didSet { updatePrivacy() }
    }

    @Published var excludedAppBundleIds: [String] {
        didSet { updatePrivacy() }
    }

    @Published var sensitiveDetectionEnabled: Bool {
        didSet { updatePrivacy() }
    }

    @Published var enabledSensitiveCategories: Set<SensitivePatterns.SensitiveCategory> {
        didSet { updatePrivacy() }
    }

    // MARK: - Appearance Settings

    @Published var theme: AppTheme {
        didSet { updateAppearance() }
    }

    @Published var panelWidth: PanelWidth {
        didSet { updateAppearance() }
    }

    @Published var previewLines: Int {
        didSet { updateAppearance() }
    }

    @Published var showThumbnails: Bool {
        didSet { updateAppearance() }
    }

    @Published var compactMode: Bool {
        didSet { updateAppearance() }
    }

    // MARK: - Shortcuts Settings

    @Published var globalHotkey: StoredHotkey {
        didSet { updateShortcuts() }
    }

    @Published var quickPasteEnabled: Bool {
        didSet { updateShortcuts() }
    }

    // MARK: - Private Properties

    private let settingsManager: SettingsManager
    private let storageManager: StorageManager
    private var cancellables = Set<AnyCancellable>()
    private var isUpdating = false

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "preferences-vm"
    )

    // MARK: - Initialization

    init(settingsManager: SettingsManager = .shared, storageManager: StorageManager = .shared) {
        self.settingsManager = settingsManager
        self.storageManager = storageManager

        // Initialize from current settings
        let settings = settingsManager.settings

        // General
        launchAtLogin = settings.general.launchAtLogin
        showInDock = settings.general.showInDock
        historyLimit = settings.general.historyLimit
        captureTextContent = settings.general.captureTextContent
        captureImageContent = settings.general.captureImageContent
        captureFileContent = settings.general.captureFileContent
        captureLinkContent = settings.general.captureLinkContent

        // Privacy
        autoDeleteEnabled = settings.privacy.autoDeleteEnabled
        autoDeleteDays = settings.privacy.autoDeleteDays
        isMonitoringPaused = settings.privacy.isMonitoringPaused

        excludedAppBundleIds = settings.privacy.excludedAppBundleIds
        sensitiveDetectionEnabled = settings.privacy.sensitiveDetectionEnabled
        enabledSensitiveCategories = settings.privacy.enabledSensitiveCategories

        // Appearance
        theme = settings.appearance.theme
        panelWidth = settings.appearance.panelWidth
        previewLines = settings.appearance.previewLines
        showThumbnails = settings.appearance.showThumbnails
        compactMode = settings.appearance.compactMode

        // Shortcuts
        globalHotkey = settings.shortcuts.globalHotkey
        quickPasteEnabled = settings.shortcuts.quickPasteEnabled

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Observe external settings changes
        settingsManager.$settings
            .dropFirst()
            .sink { [weak self] settings in
                self?.syncFromSettings(settings)
            }
            .store(in: &cancellables)
    }

    // MARK: - Update Methods

    private func updateGeneral() {
        guard !isUpdating else { return }

        // Apply launch at login change immediately
        let previousLaunchAtLogin = settingsManager.general.launchAtLogin
        if launchAtLogin != previousLaunchAtLogin {
            LaunchAtLoginManager.shared.setEnabled(launchAtLogin)
        }

        // Apply dock visibility change immediately
        let previousShowInDock = settingsManager.general.showInDock
        if showInDock != previousShowInDock {
            DockVisibilityManager.shared.setVisible(showInDock)
        }

        settingsManager.general = GeneralSettings(
            launchAtLogin: launchAtLogin,
            showInDock: showInDock,
            historyLimit: historyLimit,
            captureTextContent: captureTextContent,
            captureImageContent: captureImageContent,
            captureFileContent: captureFileContent,
            captureLinkContent: captureLinkContent
        )
    }

    private func updatePrivacy() {
        guard !isUpdating else { return }

        // Write to SettingsManager; AppDelegate.handleSettingsChange() drives monitor
        // state via setMonitoringPaused() when it receives .settingsDidChange.
        settingsManager.privacy = PrivacySettings(
            autoDeleteEnabled: autoDeleteEnabled,
            autoDeleteDays: autoDeleteDays,
            isMonitoringPaused: isMonitoringPaused,
            excludedAppBundleIds: excludedAppBundleIds,
            sensitiveDetectionEnabled: sensitiveDetectionEnabled,
            enabledSensitiveCategories: enabledSensitiveCategories
        )
    }

    private func updateAppearance() {
        guard !isUpdating else { return }

        // Apply theme change immediately
        let previousTheme = settingsManager.appearance.theme
        if theme != previousTheme {
            applyTheme(theme)
        }

        settingsManager.appearance = AppearanceSettings(
            theme: theme,
            panelWidth: panelWidth,
            previewLines: previewLines,
            showThumbnails: showThumbnails,
            compactMode: compactMode
        )
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
        logger.debug("Theme applied: \(theme.rawValue)")
    }

    private func updateShortcuts() {
        guard !isUpdating else { return }

        // Notify about hotkey change so AppDelegate can update registration
        let previousHotkey = settingsManager.shortcuts.globalHotkey
        if self.globalHotkey != previousHotkey {
            logger.info("Global hotkey changed to: \(self.globalHotkey.displayString)")
        }

        settingsManager.shortcuts = ShortcutsSettings(
            globalHotkey: self.globalHotkey,
            quickPasteEnabled: self.quickPasteEnabled
        )
    }

    // MARK: - Sync

    private func syncFromSettings(_ settings: AppSettings) {
        isUpdating = true
        defer { isUpdating = false }

        // General
        launchAtLogin = settings.general.launchAtLogin
        showInDock = settings.general.showInDock
        historyLimit = settings.general.historyLimit
        captureTextContent = settings.general.captureTextContent
        captureImageContent = settings.general.captureImageContent
        captureFileContent = settings.general.captureFileContent
        captureLinkContent = settings.general.captureLinkContent

        // Privacy
        autoDeleteEnabled = settings.privacy.autoDeleteEnabled
        autoDeleteDays = settings.privacy.autoDeleteDays
        isMonitoringPaused = settings.privacy.isMonitoringPaused

        excludedAppBundleIds = settings.privacy.excludedAppBundleIds
        sensitiveDetectionEnabled = settings.privacy.sensitiveDetectionEnabled
        enabledSensitiveCategories = settings.privacy.enabledSensitiveCategories

        // Appearance
        theme = settings.appearance.theme
        panelWidth = settings.appearance.panelWidth
        previewLines = settings.appearance.previewLines
        showThumbnails = settings.appearance.showThumbnails
        compactMode = settings.appearance.compactMode

        // Shortcuts
        globalHotkey = settings.shortcuts.globalHotkey
        quickPasteEnabled = settings.shortcuts.quickPasteEnabled
    }

    // MARK: - Actions

    /// Resets all settings to defaults
    func resetToDefaults() {
        settingsManager.resetToDefaults()
        logger.info("Settings reset to defaults")
    }

    /// Adds an app to the exclusion list
    func addExcludedApp(_ bundleId: String) {
        guard !excludedAppBundleIds.contains(bundleId) else { return }
        excludedAppBundleIds.append(bundleId)
    }

    /// Removes an app from the exclusion list
    func removeExcludedApp(_ bundleId: String) {
        excludedAppBundleIds.removeAll { $0 == bundleId }
    }

    /// Toggles a sensitive data detection category on or off
    func toggleSensitiveCategory(_ category: SensitivePatterns.SensitiveCategory) {
        if enabledSensitiveCategories.contains(category) {
            enabledSensitiveCategories.remove(category)
        } else {
            enabledSensitiveCategories.insert(category)
        }
    }

    /// Clears clipboard history (keeps favorites)
    func clearHistory() {
        Task {
            await storageManager.deleteAllItems(keepFavorites: true)
            NotificationCenter.default.post(name: .clipboardHistoryChanged, object: nil)
        }
    }
}

// MARK: - Preferences Tab

/// Available tabs in the preferences window
enum PreferencesTab: String, CaseIterable, Identifiable {
    case general
    case privacy
    case appearance
    case shortcuts
    case search
    case sync
    case automation
    case plugins
    case enterprise
    case about

    var id: String { rawValue }

    /// Display name for the tab
    var displayName: String {
        switch self {
        case .general: return "General"
        case .privacy: return "Privacy"
        case .appearance: return "Appearance"
        case .shortcuts: return "Shortcuts"
        case .search: return "Search"
        case .sync: return "Sync"
        case .automation: return "Automation"
        case .plugins: return "Plugins"
        case .enterprise: return "Enterprise"
        case .about: return "About"
        }
    }

    /// SF Symbol name for the tab icon
    var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .privacy: return "hand.raised"
        case .appearance: return "paintbrush"
        case .shortcuts: return "keyboard"
        case .search: return "magnifyingglass"
        case .sync: return "icloud"
        case .automation: return "wand.and.stars"
        case .plugins: return "puzzlepiece.extension"
        case .enterprise: return "building.2"
        case .about: return "info.circle"
        }
    }
}
