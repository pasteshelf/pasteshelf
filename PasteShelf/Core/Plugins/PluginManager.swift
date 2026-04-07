// swiftlint:disable file_length
#if !APP_STORE
//
    //  PluginManager.swift
    //  PasteShelf
//
    //  Central manager for plugin lifecycle, state, and coordination.
//

    // swiftformat:disable organizeDeclarations

    import Combine
    import Foundation
    import os.log

    /// Central manager for all plugin operations
    @MainActor
    final class PluginManager: ObservableObject { // swiftlint:disable:this type_body_length
        // MARK: Lifecycle

        // MARK: - Initialization

        private init() {
            logger.info("PluginManager initialized")
        }

        // MARK: Internal

        // MARK: - Singleton

        static let shared = PluginManager()

        // MARK: - Published State

        /// All discovered plugins with their current state
        @Published private(set) var plugins: [String: LoadedPlugin] = [:]

        /// Currently active (loaded) plugins
        @Published private(set) var activePlugins: [String: any PasteShelfPlugin] = [:]

        /// Whether the plugin system is initialized
        @Published private(set) var isInitialized = false

        /// Current loading status
        @Published private(set) var loadingStatus: PluginLoadingStatus = .idle

        // MARK: - Plugin Queries

        /// Returns all available plugins (discovered + active)
        var allPlugins: [LoadedPlugin] {
            Array(plugins.values).sorted { $0.bundle.manifest.name < $1.bundle.manifest.name }
        }

        /// Returns only active plugins
        var loadedPlugins: [LoadedPlugin] {
            allPlugins.filter { $0.state == .active }
        }

        // MARK: - Menu Items

        /// Collects menu items from all active plugins
        var allMenuItems: [(pluginId: String, items: [PluginMenuItem])] {
            activePlugins.compactMap { id, plugin in
                guard let items = plugin.menuItems?(), !items.isEmpty else {
                    return nil
                }
                return (id, items)
            }
        }

        // MARK: - Initialization

        /// Initializes the plugin system
        /// - Parameter contextFactory: Factory for creating plugin contexts
        func initialize(contextFactory: PluginContextFactory) async {
            guard !isInitialized else {
                logger.warning("Plugin system already initialized")
                return
            }

            self.contextFactory = contextFactory
            loadingStatus = .discovering

            // Discover plugins
            let bundles = loader.discoverPlugins()
            logger.info("Discovered \(bundles.count) plugins")

            // Validate and register plugins
            loadingStatus = .validating
            for bundle in bundles {
                let validationResult = validator.validate(bundle)
                var plugin = LoadedPlugin(bundle: bundle, state: .discovered)

                if case let .failure(error) = validationResult {
                    plugin.state = .failed
                    plugin.loadError = error.localizedDescription
                    logger
                        .warning(
                            // swiftlint:disable:next line_length
                            "Plugin \(bundle.manifest.identifier) failed validation: \(error.localizedDescription ?? "Unknown")"
                        )
                }

                plugins[bundle.manifest.identifier] = plugin
            }

            // Register and load built-in plugins
            await registerBuiltInPlugins()

            // Load enabled plugins
            loadingStatus = .loading
            await loadEnabledPlugins()

            // Set up directory watching
            setupDirectoryWatching()

            isInitialized = true
            loadingStatus = .ready
            logger.info("Plugin system initialized with \(activePlugins.count) active plugins")
        }

        /// Loads a specific plugin
        /// - Parameter id: Plugin identifier
        func loadPlugin(id: String) async throws {
            guard var plugin = plugins[id] else {
                throw PluginManagerError.pluginNotFound(id)
            }

            guard plugin.state.canLoad else {
                throw PluginManagerError.invalidState(current: plugin.state, expected: .discovered)
            }

            guard let factory = contextFactory else {
                throw PluginManagerError.notInitialized
            }

            plugin.state = .loading
            plugins[id] = plugin

            do {
                // Load principal class
                let instance = try plugin.bundle.loadPrincipalClass()

                guard let pluginInstance = instance as? any PasteShelfPlugin else {
                    throw PluginLoadError.invalidPrincipalClass(
                        String(describing: type(of: instance))
                    )
                }

                // Create context for this plugin
                let context = factory.createContext(for: plugin.bundle)

                // Initialize the plugin
                pluginInstance.didLoad(with: context)

                // Update state
                activePlugins[id] = pluginInstance
                plugin.state = .active
                plugins[id] = LoadedPlugin(
                    bundle: plugin.bundle,
                    instance: pluginInstance,
                    state: .active
                )

                // Add to enabled set
                var enabled = enabledPluginIds
                enabled.insert(id)
                enabledPluginIds = enabled

                logger.info("Loaded plugin: \(plugin.bundle.manifest.name)")
            } catch {
                plugin.state = .failed
                plugin.loadError = error.localizedDescription
                plugins[id] = plugin
                throw error
            }
        }

        /// Unloads a specific plugin
        /// - Parameter id: Plugin identifier
        func unloadPlugin(id: String) async {
            guard var plugin = plugins[id] else {
                logger.warning("Cannot unload unknown plugin: \(id)")
                return
            }

            guard plugin.state == .active else {
                logger.warning("Plugin \(id) is not active")
                return
            }

            plugin.state = .unloading

            // Call willUnload if implemented
            if let instance = activePlugins[id] {
                instance.willUnload?()
            }

            // Remove from active plugins
            activePlugins.removeValue(forKey: id)

            // Update state
            plugin.state = .disabled
            plugins[id] = LoadedPlugin(bundle: plugin.bundle, state: .disabled)

            // Remove from enabled set
            var enabled = enabledPluginIds
            enabled.remove(id)
            enabledPluginIds = enabled

            logger.info("Unloaded plugin: \(plugin.bundle.manifest.name)")
        }

        /// Enables a plugin (loads it if not already loaded)
        /// - Parameter id: Plugin identifier
        func enablePlugin(id: String) async throws {
            guard let plugin = plugins[id] else {
                throw PluginManagerError.pluginNotFound(id)
            }

            if plugin.state != .active {
                try await loadPlugin(id: id)
            }
        }

        /// Disables a plugin (unloads it)
        /// - Parameter id: Plugin identifier
        func disablePlugin(id: String) async {
            await unloadPlugin(id: id)
        }

        /// Gets a loaded plugin instance by ID
        /// - Parameter id: Plugin identifier
        /// - Returns: Plugin instance if loaded
        func plugin(id: String) -> (any PasteShelfPlugin)? {
            activePlugins[id]
        }

        /// Checks if a plugin is enabled
        /// - Parameter id: Plugin identifier
        /// - Returns: True if enabled
        func isEnabled(id: String) -> Bool {
            plugins[id]?.state == .active
        }

        // MARK: - Permissions

        /// Checks if a plugin has a specific permission granted
        /// - Parameters:
        ///   - pluginId: Plugin identifier
        ///   - permission: Permission to check
        /// - Returns: True if permission is granted
        func hasPermission(_ permission: PluginPermission, for pluginId: String) -> Bool {
            permissionGrants.contains { $0.pluginId == pluginId && $0.permission == permission }
        }

        /// Grants a permission to a plugin
        /// - Parameters:
        ///   - permission: Permission to grant
        ///   - pluginId: Plugin identifier
        ///   - permanent: Whether the grant persists across sessions
        func grantPermission(_ permission: PluginPermission, to pluginId: String, permanent: Bool = true) {
            let grant = PluginPermissionGrant(pluginId: pluginId, permission: permission, isPermanent: permanent)
            var grants = permissionGrants.filter { !($0.pluginId == pluginId && $0.permission == permission) }
            grants.append(grant)
            permissionGrants = grants
            logger.info("Granted \(permission.displayName) to plugin \(pluginId)")
        }

        /// Revokes a permission from a plugin
        /// - Parameters:
        ///   - permission: Permission to revoke
        ///   - pluginId: Plugin identifier
        func revokePermission(_ permission: PluginPermission, from pluginId: String) {
            permissionGrants = permissionGrants.filter { !($0.pluginId == pluginId && $0.permission == permission) }
            logger.info("Revoked \(permission.displayName) from plugin \(pluginId)")
        }

        /// Gets all granted permissions for a plugin
        /// - Parameter pluginId: Plugin identifier
        /// - Returns: Set of granted permissions
        func grantedPermissions(for pluginId: String) -> Set<PluginPermission> {
            Set(permissionGrants.filter { $0.pluginId == pluginId }.map(\.permission))
        }

        /// Refreshes the plugin list (re-discovers and validates)
        func refreshPlugins() async {
            guard isInitialized else {
                return
            }

            logger.debug("Refreshing plugins...")
            loadingStatus = .discovering

            // Keep track of active plugins
            let previouslyActive = Set(activePlugins.keys)

            // Re-discover
            let bundles = loader.discoverPlugins()
            var newPlugins: [String: LoadedPlugin] = [:]

            // Process discovered bundles
            loadingStatus = .validating
            for bundle in bundles {
                let id = bundle.manifest.identifier
                let validationResult = validator.validate(bundle)

                if case let .failure(error) = validationResult {
                    newPlugins[id] = LoadedPlugin(bundle: bundle, state: .failed)
                    newPlugins[id]?.loadError = error.localizedDescription
                } else if previouslyActive.contains(id) {
                    // Keep previously active plugins
                    newPlugins[id] = plugins[id]
                } else if enabledPluginIds.contains(id) {
                    // Plugin should be enabled
                    newPlugins[id] = LoadedPlugin(bundle: bundle, state: .discovered)
                } else {
                    newPlugins[id] = LoadedPlugin(bundle: bundle, state: .discovered)
                }
            }

            // Find removed plugins
            let removedIds = Set(plugins.keys).subtracting(Set(newPlugins.keys))
            for id in removedIds where activePlugins[id] != nil {
                await unloadPlugin(id: id)
            }

            plugins = newPlugins

            // Load newly enabled plugins
            loadingStatus = .loading
            await loadEnabledPlugins()

            loadingStatus = .ready
            logger.info("Plugin refresh complete: \(plugins.count) plugins")
        }

        // MARK: - Cleanup

        /// Shuts down the plugin system
        func shutdown() async {
            logger.info("Shutting down plugin system...")

            // Unload all active plugins
            for id in activePlugins.keys {
                await unloadPlugin(id: id)
            }

            // Cancel directory watcher
            directoryWatcher?.cancel()
            directoryWatcher = nil

            isInitialized = false
            loadingStatus = .idle
            logger.info("Plugin system shut down")
        }

        // MARK: Private

        // MARK: - Built-In Plugin Registration

        private struct BuiltInPluginDefinition {
            let id: String
            let name: String
            let pluginClass: String
            let description: String
            let categories: [PluginCategory]
        }

        /// Definitions of built-in plugins compiled into the app
        private static let builtInPluginDefinitions: [BuiltInPluginDefinition] = [
            BuiltInPluginDefinition(
                id: "com.pasteshelf.plugins.jsonbeautifier",
                name: "JSON Beautifier",
                pluginClass: "JSONBeautifier",
                description: "Formats, minifies, and validates JSON content",
                categories: [.formatting, .developer]
            ),
            BuiltInPluginDefinition(
                id: "com.pasteshelf.plugins.markdownformatter",
                name: "Markdown Formatter",
                pluginClass: "MarkdownFormatter",
                description: "Formats and cleans up Markdown text",
                categories: [.formatting]
            ),
            BuiltInPluginDefinition(
                id: "com.pasteshelf.plugins.urlshortener",
                name: "URL Shortener",
                pluginClass: "URLShortener",
                description: "Shortens URLs using popular services",
                categories: [.utility]
            ),
            BuiltInPluginDefinition(
                id: "com.pasteshelf.plugins.githubgist",
                name: "GitHub Gist",
                pluginClass: "GitHubGist",
                description: "Create GitHub Gists from clipboard content",
                categories: [.integration, .developer]
            ),
            BuiltInPluginDefinition(
                id: "com.pasteshelf.plugins.notion",
                name: "Notion",
                pluginClass: "Notion",
                description: "Send clipboard content to Notion",
                categories: [.integration, .productivity]
            ),
        ]

        // MARK: - Dependencies

        private let loader = PluginLoader.shared
        private let validator = PluginValidator.shared
        private let logger = Logger.plugins

        // MARK: - Storage

        private let enabledPluginsKey = "EnabledPlugins"
        /// Permission grants storage
        private let permissionGrantsKey = "PluginPermissionGrants"

        // MARK: - File System Watching

        private var directoryWatcher: DispatchSourceFileSystemObject?

        // MARK: - Plugin Context Factory

        private var contextFactory: PluginContextFactory?

        private var enabledPluginIds: Set<String> {
            get {
                let array = UserDefaults.standard.stringArray(forKey: enabledPluginsKey) ?? []
                return Set(array)
            }
            set {
                UserDefaults.standard.set(Array(newValue), forKey: enabledPluginsKey)
            }
        }

        private var permissionGrants: [PluginPermissionGrant] {
            get {
                guard let data = UserDefaults.standard.data(forKey: permissionGrantsKey),
                      let grants = try? JSONDecoder().decode([PluginPermissionGrant].self, from: data)
                else {
                    return []
                }
                return grants
            }
            set {
                if let data = try? JSONEncoder().encode(newValue) {
                    UserDefaults.standard.set(data, forKey: permissionGrantsKey)
                }
            }
        }

        /// Registers built-in plugins that are compiled into the app binary
        private func registerBuiltInPlugins() async {
            guard let factory = contextFactory else {
                return
            }

            for def in Self.builtInPluginDefinitions {
                let manifest = PluginManifest(
                    identifier: def.id,
                    name: def.name,
                    version: "1.0.0",
                    shortVersion: "1.0.0",
                    pluginClass: def.pluginClass,
                    pluginDescription: def.description,
                    author: "PasteShelf",
                    categories: def.categories
                )

                let bundle = PluginBundle(builtIn: manifest)

                // Try to instantiate the plugin class from the main bundle
                guard let pluginClass = Bundle.main.classNamed(def.pluginClass) as? NSObject.Type,
                      let instance = pluginClass.init() as? any PasteShelfPlugin
                else {
                    logger.warning("Built-in plugin class '\(def.pluginClass)' not found or invalid")
                    plugins[def.id] = LoadedPlugin(bundle: bundle, state: .failed)
                    continue
                }

                // Create context and initialize
                let context = factory.createContext(for: bundle)
                instance.didLoad(with: context)

                // Register as active
                activePlugins[def.id] = instance
                plugins[def.id] = LoadedPlugin(bundle: bundle, instance: instance, state: .active)

                logger.info("Registered built-in plugin: \(def.name)")
            }
        }

        // MARK: - Plugin Loading

        /// Loads all enabled plugins
        private func loadEnabledPlugins() async {
            let enabled = enabledPluginIds

            for (id, var plugin) in plugins {
                if enabled.contains(id), plugin.state == .discovered {
                    do {
                        try await loadPlugin(id: id)
                    } catch {
                        logger.error("Failed to load plugin \(id): \(error.localizedDescription)")
                        plugin.state = .failed
                        plugin.loadError = error.localizedDescription
                        plugins[id] = plugin
                    }
                }
            }
        }

        // MARK: - Directory Watching

        private func setupDirectoryWatching() {
            directoryWatcher = loader.watchForChanges { [weak self] in
                Task { @MainActor in
                    await self?.refreshPlugins()
                }
            }
        }
    }

    // MARK: - Loading Status

    /// Status of plugin loading operations
    enum PluginLoadingStatus: Sendable {
        case idle
        case discovering
        case validating
        case loading
        case ready
        case error(String)

        // MARK: Internal

        var description: String {
            switch self {
            case .idle:
                "Idle"
            case .discovering:
                "Discovering plugins..."
            case .validating:
                "Validating plugins..."
            case .loading:
                "Loading plugins..."
            case .ready:
                "Ready"
            case let .error(message):
                "Error: \(message)"
            }
        }
    }

    // MARK: - Manager Errors

    /// Errors from PluginManager operations
    enum PluginManagerError: Error, LocalizedError, Sendable {
        case notInitialized
        case pluginNotFound(String)
        case invalidState(current: PluginState, expected: PluginState)

        // MARK: Internal

        var errorDescription: String? {
            switch self {
            case .notInitialized:
                "Plugin system is not initialized"
            case let .pluginNotFound(id):
                "Plugin '\(id)' not found"
            case let .invalidState(current, expected):
                "Plugin is in state '\(current.rawValue)' but expected '\(expected.rawValue)'"
            }
        }
    }

    // MARK: - Plugin Context Factory

    /// Factory protocol for creating plugin contexts
    protocol PluginContextFactory {
        func createContext(for bundle: PluginBundle) -> any PluginContext
    }

#endif
