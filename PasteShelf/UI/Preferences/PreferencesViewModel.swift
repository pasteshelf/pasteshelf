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

// MARK: - PreferencesViewModel

/// ViewModel for preferences management
@MainActor
final class PreferencesViewModel: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(settingsManager: SettingsManager = .shared, storageManager: StorageManager = .shared) {
        self.settingsManager = settingsManager
        self.storageManager = storageManager

        // Initialize from current settings
        let settings = settingsManager.settings

        // General
        self.launchAtLogin = settings.general.launchAtLogin
        self.showInDock = settings.general.showInDock
        self.historyLimit = settings.general.historyLimit
        self.captureTextContent = settings.general.captureTextContent
        self.captureImageContent = settings.general.captureImageContent
        self.captureFileContent = settings.general.captureFileContent
        self.captureLinkContent = settings.general.captureLinkContent

        // Privacy
        self.autoDeleteEnabled = settings.privacy.autoDeleteEnabled
        self.autoDeleteDays = settings.privacy.autoDeleteDays
        self.isMonitoringPaused = settings.privacy.isMonitoringPaused

        self.excludedAppBundleIds = settings.privacy.excludedAppBundleIds
        self.sensitiveDetectionEnabled = settings.privacy.sensitiveDetectionEnabled
        self.enabledSensitiveCategories = settings.privacy.enabledSensitiveCategories

        // Appearance
        self.theme = settings.appearance.theme
        self.panelWidth = settings.appearance.panelWidth
        self.previewLines = settings.appearance.previewLines
        self.showThumbnails = settings.appearance.showThumbnails
        self.compactMode = settings.appearance.compactMode
        self.showTagFilters = settings.appearance.showTagFilters

        // Shortcuts
        self.globalHotkey = settings.shortcuts.globalHotkey
        self.quickPasteEnabled = settings.shortcuts.quickPasteEnabled

        self.setupBindings()
    }

    // MARK: Internal

    // MARK: - Published Properties

    /// Currently selected tab
    @Published var selectedTab: PreferencesTab = .general

    // MARK: - General Settings

    @Published var launchAtLogin: Bool {
        didSet { self.updateGeneral() }
    }

    @Published var showInDock: Bool {
        didSet { self.updateGeneral() }
    }

    @Published var historyLimit: HistoryLimit {
        didSet { self.updateGeneral() }
    }

    @Published var captureTextContent: Bool {
        didSet { self.updateGeneral() }
    }

    @Published var captureImageContent: Bool {
        didSet { self.updateGeneral() }
    }

    @Published var captureFileContent: Bool {
        didSet { self.updateGeneral() }
    }

    @Published var captureLinkContent: Bool {
        didSet { self.updateGeneral() }
    }

    // MARK: - Privacy Settings

    @Published var autoDeleteEnabled: Bool {
        didSet { self.updatePrivacy() }
    }

    @Published var autoDeleteDays: Int {
        didSet { self.updatePrivacy() }
    }

    @Published var isMonitoringPaused: Bool {
        didSet { self.updatePrivacy() }
    }

    @Published var excludedAppBundleIds: [String] {
        didSet { self.updatePrivacy() }
    }

    @Published var sensitiveDetectionEnabled: Bool {
        didSet { self.updatePrivacy() }
    }

    @Published var enabledSensitiveCategories: Set<SensitivePatterns.SensitiveCategory> {
        didSet { self.updatePrivacy() }
    }

    // MARK: - Appearance Settings

    @Published var theme: AppTheme {
        didSet { self.updateAppearance() }
    }

    @Published var panelWidth: PanelWidth {
        didSet { self.updateAppearance() }
    }

    @Published var previewLines: Int {
        didSet { self.updateAppearance() }
    }

    @Published var showThumbnails: Bool {
        didSet { self.updateAppearance() }
    }

    @Published var compactMode: Bool {
        didSet { self.updateAppearance() }
    }

    @Published var showTagFilters: Bool {
        didSet { self.updateAppearance() }
    }

    // MARK: - Shortcuts Settings

    @Published var globalHotkey: StoredHotkey {
        didSet { self.updateShortcuts() }
    }

    @Published var quickPasteEnabled: Bool {
        didSet { self.updateShortcuts() }
    }

    /// Resets all settings to defaults
    func resetToDefaults() {
        self.settingsManager.resetToDefaults()
        self.logger.info("Settings reset to defaults")
    }

    /// Adds an app to the exclusion list
    func addExcludedApp(_ bundleId: String) {
        guard !self.excludedAppBundleIds.contains(bundleId) else {
            return
        }
        self.excludedAppBundleIds.append(bundleId)
    }

    /// Removes an app from the exclusion list
    func removeExcludedApp(_ bundleId: String) {
        self.excludedAppBundleIds.removeAll { $0 == bundleId }
    }

    /// Toggles a sensitive data detection category on or off
    func toggleSensitiveCategory(_ category: SensitivePatterns.SensitiveCategory) {
        if self.enabledSensitiveCategories.contains(category) {
            self.enabledSensitiveCategories.remove(category)
        } else {
            self.enabledSensitiveCategories.insert(category)
        }
    }

    /// Clears clipboard history (keeps favorites)
    func clearHistory() {
        Task {
            await self.storageManager.deleteAllItems(keepFavorites: true)
            NotificationCenter.default.post(name: .clipboardHistoryChanged, object: nil)
        }
    }

    // MARK: Private

    // MARK: - Private Properties

    private let settingsManager: SettingsManager
    private let storageManager: StorageManager
    private var cancellables = Set<AnyCancellable>()
    private var isUpdating = false

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "preferences-vm"
    )

    // MARK: - Setup

    private func setupBindings() {
        // Observe external settings changes
        self.settingsManager.$settings
            .dropFirst()
            .sink { [weak self] settings in
                self?.syncFromSettings(settings)
            }
            .store(in: &self.cancellables)
    }

    // MARK: - Update Methods

    private func updateGeneral() {
        guard !self.isUpdating else {
            return
        }

        // Apply launch at login change immediately
        let previousLaunchAtLogin = self.settingsManager.general.launchAtLogin
        if self.launchAtLogin != previousLaunchAtLogin {
            LaunchAtLoginManager.shared.setEnabled(self.launchAtLogin)
        }

        // Apply dock visibility change immediately
        let previousShowInDock = self.settingsManager.general.showInDock
        if self.showInDock != previousShowInDock {
            DockVisibilityManager.shared.setVisible(self.showInDock)
        }

        self.settingsManager.general = GeneralSettings(
            launchAtLogin: self.launchAtLogin,
            showInDock: self.showInDock,
            historyLimit: self.historyLimit,
            captureTextContent: self.captureTextContent,
            captureImageContent: self.captureImageContent,
            captureFileContent: self.captureFileContent,
            captureLinkContent: self.captureLinkContent
        )
    }

    private func updatePrivacy() {
        guard !self.isUpdating else {
            return
        }

        // Write to SettingsManager; AppDelegate.handleSettingsChange() drives monitor
        // state via setMonitoringPaused() when it receives .settingsDidChange.
        self.settingsManager.privacy = PrivacySettings(
            autoDeleteEnabled: self.autoDeleteEnabled,
            autoDeleteDays: self.autoDeleteDays,
            isMonitoringPaused: self.isMonitoringPaused,
            excludedAppBundleIds: self.excludedAppBundleIds,
            sensitiveDetectionEnabled: self.sensitiveDetectionEnabled,
            enabledSensitiveCategories: self.enabledSensitiveCategories
        )
    }

    private func updateAppearance() {
        guard !self.isUpdating else {
            return
        }

        // Apply theme change immediately
        let previousTheme = self.settingsManager.appearance.theme
        if self.theme != previousTheme {
            self.applyTheme(self.theme)
        }

        self.settingsManager.appearance = AppearanceSettings(
            theme: self.theme,
            panelWidth: self.panelWidth,
            previewLines: self.previewLines,
            showThumbnails: self.showThumbnails,
            compactMode: self.compactMode,
            showTagFilters: self.showTagFilters
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
        self.logger.debug("Theme applied: \(theme.rawValue)")
    }

    private func updateShortcuts() {
        guard !self.isUpdating else {
            return
        }

        // Notify about hotkey change so AppDelegate can update registration
        let previousHotkey = self.settingsManager.shortcuts.globalHotkey
        if self.globalHotkey != previousHotkey {
            self.logger.info("Global hotkey changed to: \(self.globalHotkey.displayString)")
        }

        self.settingsManager.shortcuts = ShortcutsSettings(
            globalHotkey: self.globalHotkey,
            quickPasteEnabled: self.quickPasteEnabled
        )
    }

    // MARK: - Sync

    private func syncFromSettings(_ settings: AppSettings) {
        self.isUpdating = true
        defer { isUpdating = false }

        // General
        self.launchAtLogin = settings.general.launchAtLogin
        self.showInDock = settings.general.showInDock
        self.historyLimit = settings.general.historyLimit
        self.captureTextContent = settings.general.captureTextContent
        self.captureImageContent = settings.general.captureImageContent
        self.captureFileContent = settings.general.captureFileContent
        self.captureLinkContent = settings.general.captureLinkContent

        // Privacy
        self.autoDeleteEnabled = settings.privacy.autoDeleteEnabled
        self.autoDeleteDays = settings.privacy.autoDeleteDays
        self.isMonitoringPaused = settings.privacy.isMonitoringPaused

        self.excludedAppBundleIds = settings.privacy.excludedAppBundleIds
        self.sensitiveDetectionEnabled = settings.privacy.sensitiveDetectionEnabled
        self.enabledSensitiveCategories = settings.privacy.enabledSensitiveCategories

        // Appearance
        self.theme = settings.appearance.theme
        self.panelWidth = settings.appearance.panelWidth
        self.previewLines = settings.appearance.previewLines
        self.showThumbnails = settings.appearance.showThumbnails
        self.compactMode = settings.appearance.compactMode
        self.showTagFilters = settings.appearance.showTagFilters

        // Shortcuts
        self.globalHotkey = settings.shortcuts.globalHotkey
        self.quickPasteEnabled = settings.shortcuts.quickPasteEnabled
    }
}

// MARK: - PreferencesTab

/// Available tabs in the preferences window
enum PreferencesTab: String, CaseIterable, Identifiable {
    case general
    case privacy
    case appearance
    case shortcuts
    case search
    case sync
    case automation
    #if !APP_STORE
        case plugins
        case enterprise
    #endif
    case about

    // MARK: Internal

    var id: String {
        rawValue
    }

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
        #if !APP_STORE
            case .plugins: return "Plugins"
            case .enterprise: return "Enterprise"
        #endif
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
        #if !APP_STORE
            case .plugins: return "puzzlepiece.extension"
            case .enterprise: return "building.2"
        #endif
        case .about: return "info.circle"
        }
    }
}
