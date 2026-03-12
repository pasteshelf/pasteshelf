//
//  PreferencesWindowController.swift
//  PasteShelf
//
//  Controller for the preferences window.
//  Uses NSTabViewController for native macOS toolbar-style tabs.
//

import AppKit
import os.log
import SwiftUI

/// Controller for the preferences window
@MainActor
final class PreferencesWindowController: NSObject {
    // MARK: - Singleton

    /// Shared instance
    static let shared = PreferencesWindowController()

    // MARK: - Properties

    /// The preferences window
    private var window: NSWindow?

    /// Logger for preferences operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "preferences"
    )

    // MARK: - Initialization

    override private init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Shows the preferences window
    func show() {
        if window == nil {
            createWindow()
        }

        window?.center()
        window?.orderFrontRegardless()
        window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)

        logger.debug("Preferences window shown")
    }

    /// Hides the preferences window
    func hide() {
        window?.orderOut(nil)
        logger.debug("Preferences window hidden")
    }

    /// Closes the preferences window
    func close() {
        window?.close()
        window = nil
        logger.debug("Preferences window closed")
    }

    // MARK: - Private Methods

    private func createWindow() {
        let viewModel = PreferencesViewModel()

        // Build the tab view controller with native toolbar tabs
        let tabViewController = NSTabViewController()
        tabViewController.tabStyle = .toolbar
        tabViewController.title = "Preferences"

        for tab in PreferencesTab.allCases {
            let tabViewItem = NSTabViewItem(viewController: makeHostingController(for: tab, viewModel: viewModel))
            tabViewItem.label = tab.displayName
            tabViewItem.image = NSImage(systemSymbolName: tab.iconName, accessibilityDescription: tab.displayName)
            tabViewController.addTabViewItem(tabViewItem)
        }

        let window = NSWindow(contentViewController: tabViewController)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.delegate = self

        // Wide enough to fit all 10 toolbar tabs without overflow chevron
        let width: CGFloat = 950
        let height: CGFloat = 600
        window.setContentSize(NSSize(width: width, height: height))
        window.minSize = NSSize(width: width, height: 500)
        window.center()

        self.window = window

        logger.info("Preferences window created")
    }

    private func makeHostingController(for tab: PreferencesTab, viewModel: PreferencesViewModel) -> NSViewController {
        let view: AnyView
        switch tab {
        case .general:
            view = AnyView(GeneralTabView(viewModel: viewModel))
        case .privacy:
            view = AnyView(PrivacyTabView(viewModel: viewModel))
        case .appearance:
            view = AnyView(AppearanceTabView(viewModel: viewModel))
        case .shortcuts:
            view = AnyView(ShortcutsTabView(viewModel: viewModel))
        case .search:
            view = AnyView(SearchTabView())
        case .sync:
            view = AnyView(SyncTabView())
        case .automation:
            view = AnyView(AutomationTabView())
        #if !APP_STORE
        case .plugins:
            view = AnyView(PluginSettingsView())
        case .enterprise:
            view = AnyView(EnterpriseTabView())
        #endif
        case .about:
            view = AnyView(AboutTabView())
        }

        let wrapped = view
            .formStyle(.grouped)
            .environmentObject(SettingsManager.shared)
            .frame(minWidth: 500, minHeight: 500)

        return NSHostingController(rootView: wrapped)
    }
}

// MARK: - NSWindowDelegate

extension PreferencesWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        window = nil
        logger.debug("Preferences window closed")
    }
}
