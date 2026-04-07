#if !APP_STORE
//
    //  PluginUIAPI.swift
    //  PasteShelf
//
    //  UI extension API for plugins.
    //  Manages menu items and context menu contributions.
//

    import AppKit
    import Foundation
    import os.log
    import SwiftUI

    /// Manages plugin UI extensions (menu items, context menus)
    @MainActor
    final class PluginUIAPI {
        // MARK: Lifecycle

        // MARK: - Initialization

        private init() {
            logger.info("PluginUIAPI initialized")
        }

        // MARK: Internal

        // MARK: - Menu Items

        struct PluginMenuGroup {
            let pluginId: String
            let pluginName: String
            let items: [PluginMenuItem]
        }

        // MARK: - Singleton

        static let shared = PluginUIAPI()

        /// Gets all menu items from all plugins
        var allMenuItems: [PluginMenuGroup] {
            menuItemsByPlugin
                .compactMap { pluginId, items -> PluginMenuGroup? in
                    guard !items.isEmpty,
                          let plugin = PluginManager.shared.plugins[pluginId]
                    else {
                        return nil
                    }
                    return PluginMenuGroup(
                        pluginId: pluginId,
                        pluginName: plugin.bundle.manifest.name,
                        items: items
                    )
                }
                .sorted { $0.pluginName < $1.pluginName }
        }

        /// Registers menu items for a plugin
        /// - Parameters:
        ///   - items: Menu items to register
        ///   - pluginId: Plugin identifier
        func registerMenuItems(_ items: [PluginMenuItem], for pluginId: String) {
            menuItemsByPlugin[pluginId] = items
            logger.debug("Registered \(items.count) menu items for plugin \(pluginId)")
            NotificationCenter.default.post(name: .pluginMenuItemsChanged, object: nil)
        }

        /// Unregisters all menu items for a plugin
        /// - Parameter pluginId: Plugin identifier
        func unregisterMenuItems(for pluginId: String) {
            menuItemsByPlugin.removeValue(forKey: pluginId)
            NotificationCenter.default.post(name: .pluginMenuItemsChanged, object: nil)
        }

        /// Gets menu items for a specific plugin
        /// - Parameter pluginId: Plugin identifier
        /// - Returns: Menu items registered by the plugin
        func menuItems(for pluginId: String) -> [PluginMenuItem] {
            menuItemsByPlugin[pluginId] ?? []
        }

        /// Gets menu items applicable to a content type
        /// - Parameter contentType: Content type to filter by
        /// - Returns: Menu items that support the content type
        func menuItems(for contentType: ContentType) -> [(pluginId: String, item: PluginMenuItem)] {
            var result: [(String, PluginMenuItem)] = []

            for (pluginId, items) in menuItemsByPlugin {
                for item in items where item.isEnabled {
                    // Check if plugin supports this content type
                    if let plugin = PluginManager.shared.plugins[pluginId],
                       plugin.bundle.manifest.supportedContentTypes.isEmpty ||
                       plugin.bundle.manifest.supportedContentTypes.contains(contentType.rawValue)
                    {
                        result.append((pluginId, item))
                    }
                }
            }

            return result
        }

        // MARK: - Context Menu Items

        /// Registers context menu items for a plugin
        /// - Parameters:
        ///   - items: Context menu items to register
        ///   - pluginId: Plugin identifier
        func registerContextMenuItems(_ items: [PluginContextMenuItem], for pluginId: String) {
            contextMenusByPlugin[pluginId] = items
            logger.debug("Registered \(items.count) context menu items for plugin \(pluginId)")
        }

        /// Gets context menu items for a clipboard item
        /// - Parameter content: The clipboard content being right-clicked
        /// - Returns: Applicable context menu items
        func contextMenuItems(for content: PluginClipboardContent) -> [(
            pluginId: String,
            item: PluginContextMenuItem
        )] {
            var result: [(String, PluginContextMenuItem)] = []

            for (pluginId, items) in contextMenusByPlugin {
                for item in items {
                    // Check if item applies to this content type
                    if item.supportedTypes.isEmpty ||
                        (content.contentType.map { item.supportedTypes.contains($0) } ?? false)
                    {
                        result.append((pluginId, item))
                    }
                }
            }

            return result.sorted { lhs, rhs -> Bool in
                lhs.1.priority > rhs.1.priority
            }
        }

        // MARK: - Action Execution

        /// Executes a menu item action
        /// - Parameters:
        ///   - item: The menu item to execute
        ///   - content: The clipboard content to process
        ///   - pluginId: The plugin identifier
        /// - Returns: Transformed content, or nil if no transformation
        func executeMenuItem(
            _ item: PluginMenuItem,
            content: PluginClipboardContent,
            pluginId: String
        ) async throws -> PluginClipboardContent? {
            try await PluginHost.shared.executeAction(
                item: item,
                content: content,
                pluginId: pluginId
            )
        }

        // MARK: Private

        private let logger = Logger.plugins

        /// Registered menu items by plugin ID
        private var menuItemsByPlugin: [String: [PluginMenuItem]] = [:]

        /// Registered context menu items by plugin ID
        private var contextMenusByPlugin: [String: [PluginContextMenuItem]] = [:]
    }

    // MARK: - Context Menu Item

    /// Context menu item registered by a plugin
    struct PluginContextMenuItem: Identifiable {
        // MARK: Lifecycle

        init(
            title: String,
            iconName: String? = nil,
            supportedTypes: Set<ContentType> = [],
            priority: Int = 0,
            action: ((PluginClipboardContent) async throws -> PluginClipboardContent?)? = nil
        ) {
            id = UUID()
            self.title = title
            self.iconName = iconName
            self.supportedTypes = supportedTypes
            self.priority = priority
            self.action = action
        }

        // MARK: Internal

        let id: UUID
        let title: String
        let iconName: String?
        let supportedTypes: Set<ContentType>
        let priority: Int

        /// Action closure
        nonisolated(unsafe) var action: ((PluginClipboardContent) async throws -> PluginClipboardContent?)?
    }

    // MARK: - Notifications

    extension Notification.Name {
        static let pluginMenuItemsChanged = Notification.Name("pluginMenuItemsChanged")
    }

#endif
