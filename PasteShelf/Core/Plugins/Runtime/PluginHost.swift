#if !APP_STORE
//
    //  PluginHost.swift
    //  PasteShelf
//
    //  Provides the host environment for running plugins.
    //  Routes API calls through sandboxed implementations.
//

    import Combine
    import Foundation
    import os.log

    /// Host environment that manages plugin execution
    @MainActor
    final class PluginHost: ObservableObject {
        // MARK: Lifecycle

        // MARK: - Initialization

        private init() {
            logger.info("PluginHost initialized")
        }

        // MARK: Internal

        // MARK: - Singleton

        static let shared = PluginHost()

        // MARK: - Resource Management

        /// Gets resource usage for all plugins
        var allResourceUsage: [String: PluginResourceUsage] {
            get async {
                var usage: [String: PluginResourceUsage] = [:]
                for (pluginId, sandbox) in sandboxes {
                    usage[pluginId] = await sandbox.resourceUsage
                }
                return usage
            }
        }

        // MARK: - Plugin Lifecycle

        /// Creates the host environment for a plugin
        /// - Parameter bundle: The plugin bundle
        /// - Returns: The plugin context for this plugin
        func createEnvironment(for bundle: PluginBundle) -> PluginContextImpl {
            let pluginId = bundle.manifest.identifier

            // Create sandbox with appropriate config
            let sandboxConfig = sandboxConfig(for: bundle)
            let sandbox = PluginSandbox(pluginId: pluginId, config: sandboxConfig)
            sandboxes[pluginId] = sandbox

            // Create context
            let context = PluginContextImpl(
                pluginId: pluginId,
                bundle: bundle,
                sandbox: sandbox
            )
            contexts[pluginId] = context

            logger.debug("Created host environment for plugin: \(pluginId)")
            return context
        }

        /// Destroys the host environment for a plugin
        /// - Parameter pluginId: The plugin identifier
        func destroyEnvironment(for pluginId: String) {
            sandboxes.removeValue(forKey: pluginId)
            contexts.removeValue(forKey: pluginId)
            logger.debug("Destroyed host environment for plugin: \(pluginId)")
        }

        /// Gets the context for a loaded plugin
        /// - Parameter pluginId: The plugin identifier
        /// - Returns: The plugin context, or nil if not loaded
        func context(for pluginId: String) -> PluginContextImpl? {
            contexts[pluginId]
        }

        // MARK: - Action Execution

        /// Executes a plugin menu action
        /// - Parameters:
        ///   - item: The menu item to execute
        ///   - content: The clipboard content to process
        ///   - pluginId: The plugin identifier
        /// - Returns: Transformed content, or nil if no transformation
        func executeAction(
            item: PluginMenuItem,
            content: PluginClipboardContent,
            pluginId: String
        ) async throws -> PluginClipboardContent? {
            guard let sandbox = sandboxes[pluginId] else {
                throw PluginHostError.pluginNotLoaded(pluginId)
            }

            guard let action = item.action else {
                logger.warning("Menu item '\(item.title)' has no action")
                return nil
            }

            logger.debug("Executing action '\(item.title)' for plugin \(pluginId)")

            do {
                return try await sandbox.execute {
                    try await action(content)
                }
            } catch let error as PluginSandboxError {
                logger.error("Action '\(item.title)' failed: \(error.localizedDescription ?? "Unknown")")
                throw PluginHostError.actionFailed(item.title, error.localizedDescription ?? "Unknown")
            }
        }

        /// Executes a plugin transformation
        /// - Parameters:
        ///   - plugin: The plugin instance
        ///   - content: The content to transform
        ///   - pluginId: The plugin identifier
        /// - Returns: Transformed content, or nil if no transformation
        func executeTransform(
            plugin: any PasteShelfPluginExtended,
            content: PluginClipboardContent,
            pluginId: String
        ) async throws -> PluginClipboardContent? {
            guard let sandbox = sandboxes[pluginId] else {
                throw PluginHostError.pluginNotLoaded(pluginId)
            }

            logger.debug("Executing transform for plugin \(pluginId)")

            do {
                return try await sandbox.execute {
                    try await plugin.transform(content: content)
                }
            } catch let error as PluginSandboxError {
                logger.error("Transform failed for \(pluginId): \(error.localizedDescription ?? "Unknown")")
                throw PluginHostError.transformFailed(pluginId, error.localizedDescription ?? "Unknown")
            }
        }

        /// Checks resource limits for all plugins
        func checkAllResourceLimits() async {
            for (pluginId, sandbox) in sandboxes {
                do {
                    try await sandbox.checkResourceLimits()
                } catch {
                    logger.warning("Plugin \(pluginId) exceeded resource limits: \(error.localizedDescription)")
                    // Could disable the plugin here if needed
                }
            }
        }

        // MARK: Private

        private let logger = Logger.plugins

        /// Sandboxes for each loaded plugin
        private var sandboxes: [String: PluginSandbox] = [:]

        /// Contexts for each loaded plugin
        private var contexts: [String: PluginContextImpl] = [:]

        // MARK: - Sandbox Configuration

        /// Determines sandbox configuration for a plugin based on its signature and permissions
        private func sandboxConfig(for bundle: PluginBundle) -> PluginSandboxConfig {
            let permissions = bundle.manifest.requiredPermissions

            // Check if plugin is signed by trusted developer
            let isTrusted = PluginValidator.shared.getTeamIdentifier(bundle) != nil

            // Build config based on declared permissions
            return PluginSandboxConfig(
                maxExecutionTime: isTrusted ? 60.0 : 30.0,
                maxMemoryUsage: isTrusted ? 256 * 1024 * 1024 : 100 * 1024 * 1024,
                allowNetwork: permissions.contains(.network),
                allowFileSystem: false, // Always false for security
                allowSubprocesses: false, // Always false for security
                allowedURLSchemes: permissions.contains(.network) ? ["https", "http"] : [],
                blockedHosts: []
            )
        }
    }

    // MARK: - Host Errors

    /// Errors from plugin host operations
    enum PluginHostError: Error, LocalizedError {
        case pluginNotLoaded(String)
        case actionFailed(String, String)
        case transformFailed(String, String)

        // MARK: Internal

        var errorDescription: String? {
            switch self {
            case let .pluginNotLoaded(pluginId):
                "Plugin '\(pluginId)' is not loaded"
            case let .actionFailed(action, reason):
                "Action '\(action)' failed: \(reason)"
            case let .transformFailed(pluginId, reason):
                "Transform failed for '\(pluginId)': \(reason)"
            }
        }
    }

#endif
