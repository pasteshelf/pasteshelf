#if !APP_STORE
//
    //  PluginActionRegistry.swift
    //  PasteShelf
//
    //  Action registry for plugin automation integration.
    //  Allows plugins to register actions for use in automation rules.
//

    import Foundation
    import os.log

    /// Registered plugin action for automation
    struct PluginAction: Identifiable, Sendable {
        let id: UUID
        let pluginId: String
        let name: String
        let description: String?
        let iconName: String?
        let supportedTypes: Set<ContentType>

        /// Action execution closure
        nonisolated(unsafe) var execute: ((PluginClipboardContent) async throws -> PluginClipboardContent?)?
    }

    /// Registry for plugin actions used in automation
    @MainActor
    final class PluginActionRegistry {
        // MARK: Lifecycle

        // MARK: - Initialization

        private init() {
            logger.info("PluginActionRegistry initialized")
        }

        // MARK: Internal

        // MARK: - Singleton

        static let shared = PluginActionRegistry()

        /// All registered actions
        var allActions: [PluginAction] {
            actionsByPlugin.values.flatMap { $0 }
        }

        // MARK: - Action Registration

        /// Registers an action for a plugin
        /// - Parameters:
        ///   - pluginId: Plugin identifier
        ///   - name: Display name for the action
        ///   - description: Optional description
        ///   - iconName: SF Symbol icon name
        ///   - supportedTypes: Content types this action supports
        ///   - execute: Execution closure
        /// - Returns: The registered action
        @discardableResult
        func registerAction(
            pluginId: String,
            name: String,
            description: String? = nil,
            iconName: String? = nil,
            supportedTypes: Set<ContentType> = [],
            execute: @escaping (PluginClipboardContent) async throws -> PluginClipboardContent?
        ) -> PluginAction {
            var action = PluginAction(
                id: UUID(),
                pluginId: pluginId,
                name: name,
                description: description,
                iconName: iconName,
                supportedTypes: supportedTypes
            )
            action.execute = execute

            var existing = actionsByPlugin[pluginId] ?? []
            existing.append(action)
            actionsByPlugin[pluginId] = existing

            logger.debug("Registered action '\(name)' for plugin \(pluginId)")
            NotificationCenter.default.post(name: .pluginActionsChanged, object: nil)

            return action
        }

        /// Unregisters all actions for a plugin
        /// - Parameter pluginId: Plugin identifier
        func unregisterActions(for pluginId: String) {
            let count = actionsByPlugin[pluginId]?.count ?? 0
            actionsByPlugin.removeValue(forKey: pluginId)
            logger.debug("Unregistered \(count) actions for plugin \(pluginId)")
            NotificationCenter.default.post(name: .pluginActionsChanged, object: nil)
        }

        // MARK: - Action Queries

        /// Gets actions for a specific plugin
        /// - Parameter pluginId: Plugin identifier
        /// - Returns: Actions registered by the plugin
        func actions(for pluginId: String) -> [PluginAction] {
            actionsByPlugin[pluginId] ?? []
        }

        /// Gets actions that support a content type
        /// - Parameter contentType: Content type to filter by
        /// - Returns: Matching actions
        func actions(for contentType: ContentType) -> [PluginAction] {
            allActions.filter { action in
                action.supportedTypes.isEmpty || action.supportedTypes.contains(contentType)
            }
        }

        /// Finds an action by ID
        /// - Parameter id: Action ID
        /// - Returns: Action if found
        func findAction(id: UUID) -> PluginAction? {
            allActions.first { $0.id == id }
        }

        // MARK: - Action Execution

        /// Executes a plugin action
        /// - Parameters:
        ///   - actionId: Action identifier
        ///   - content: Content to process
        /// - Returns: Transformed content
        func executeAction(
            actionId: UUID,
            content: PluginClipboardContent
        ) async throws -> PluginClipboardContent? {
            guard let action = findAction(id: actionId) else {
                throw PluginActionError.actionNotFound(actionId)
            }

            guard let executeFunc = action.execute else {
                throw PluginActionError.noExecuteFunction
            }

            // Check content type support
            if let contentType = content.contentType,
               !action.supportedTypes.isEmpty,
               !action.supportedTypes.contains(contentType)
            {
                throw PluginActionError.unsupportedContentType(contentType)
            }

            logger.debug("Executing action '\(action.name)' for plugin \(action.pluginId)")

            do {
                return try await executeFunc(content)
            } catch {
                throw PluginActionError.executionFailed(error.localizedDescription)
            }
        }

        // MARK: Private

        private let logger = Logger.plugins

        /// Registered actions by plugin ID
        private var actionsByPlugin: [String: [PluginAction]] = [:]
    }

    // MARK: - Action Errors

    /// Errors from action operations
    enum PluginActionError: Error, LocalizedError, Sendable {
        case actionNotFound(UUID)
        case noExecuteFunction
        case unsupportedContentType(ContentType)
        case executionFailed(String)

        // MARK: Internal

        var errorDescription: String? {
            switch self {
            case let .actionNotFound(id):
                "Action with ID \(id) not found"
            case .noExecuteFunction:
                "Action has no execute function"
            case let .unsupportedContentType(type):
                "Content type '\(type.displayName)' is not supported by this action"
            case let .executionFailed(reason):
                "Action execution failed: \(reason)"
            }
        }
    }

    // MARK: - Automation Integration

    extension PluginActionRegistry {
        /// Creates an AutomationAction from a plugin action
        /// - Parameter actionId: Plugin action ID
        /// - Returns: Automation action that wraps the plugin action
        /// Returns the action info for creating automation integrations
        /// Plugin actions can't be directly converted to AutomationAction
        /// but the action ID can be stored for later execution
        func getActionInfo(id: UUID) -> (pluginId: String, name: String)? {
            guard let action = findAction(id: id) else {
                return nil
            }
            return (action.pluginId, action.name)
        }
    }

    // MARK: - Notifications

    extension Notification.Name {
        static let pluginActionsChanged = Notification.Name("pluginActionsChanged")
    }

#endif
