#if !APP_STORE
//
    //  PluginTransformAPI.swift
    //  PasteShelf
//
    //  Content transformation API for plugins.
    //  Manages transform registration and execution.
//

    import Foundation
    import os.log

    /// Result of a content transformation
    struct PluginTransformResult {
        /// Original content before transformation
        let original: PluginClipboardContent

        /// Transformed content (or original if transformation returned nil)
        let transformed: PluginClipboardContent

        /// Plugin that performed the transformation
        let pluginId: String

        /// Whether the content was actually modified
        var wasModified: Bool {
            original.text != transformed.text ||
                original.imageData != transformed.imageData ||
                original.url != transformed.url
        }
    }

    /// Registered content transformer
    struct PluginTransformer: Identifiable {
        let id: UUID
        let pluginId: String
        let name: String
        let description: String?
        let supportedTypes: Set<ContentType>
        let iconName: String?

        /// Transform function (stored separately due to closure)
        nonisolated(unsafe) var transform: ((PluginClipboardContent) async throws -> PluginClipboardContent?)?
    }

    /// Manages content transformations from plugins
    @MainActor
    final class PluginTransformAPI {
        // MARK: Lifecycle

        // MARK: - Initialization

        private init() {
            logger.info("PluginTransformAPI initialized")
        }

        // MARK: Internal

        // MARK: - Singleton

        static let shared = PluginTransformAPI()

        /// All registered transformers
        var allTransformers: [PluginTransformer] {
            transformersByPlugin.values.flatMap { $0 }
        }

        // MARK: - Transformer Registration

        /// Registers a content transformer for a plugin
        /// - Parameters:
        ///   - pluginId: Plugin identifier
        ///   - name: Display name for the transformer
        ///   - description: Optional description
        ///   - supportedTypes: Content types this transformer supports
        ///   - iconName: SF Symbol icon name
        ///   - transform: Transform function
        /// - Returns: The registered transformer
        @discardableResult
        func registerTransformer(
            pluginId: String,
            name: String,
            description: String? = nil,
            supportedTypes: Set<ContentType>,
            iconName: String? = nil,
            transform: @escaping (PluginClipboardContent) async throws -> PluginClipboardContent?
        ) -> PluginTransformer {
            var transformer = PluginTransformer(
                id: UUID(),
                pluginId: pluginId,
                name: name,
                description: description,
                supportedTypes: supportedTypes,
                iconName: iconName
            )
            transformer.transform = transform

            // Add to plugin's transformers
            var existing = transformersByPlugin[pluginId] ?? []
            existing.append(transformer)
            transformersByPlugin[pluginId] = existing

            logger.debug("Registered transformer '\(name)' for plugin \(pluginId)")
            return transformer
        }

        /// Unregisters all transformers for a plugin
        /// - Parameter pluginId: Plugin identifier
        func unregisterTransformers(for pluginId: String) {
            let count = transformersByPlugin[pluginId]?.count ?? 0
            transformersByPlugin.removeValue(forKey: pluginId)
            logger.debug("Unregistered \(count) transformers for plugin \(pluginId)")
        }

        /// Unregisters a specific transformer
        /// - Parameter transformerId: Transformer identifier
        func unregisterTransformer(id transformerId: UUID) {
            for (pluginId, transformers) in transformersByPlugin {
                transformersByPlugin[pluginId] = transformers.filter { $0.id != transformerId }
            }
        }

        // MARK: - Transform Execution

        /// Executes a specific transformer
        /// - Parameters:
        ///   - transformerId: Transformer to execute
        ///   - content: Content to transform
        /// - Returns: Transform result
        func executeTransform(
            transformerId: UUID,
            content: PluginClipboardContent
        ) async throws -> PluginTransformResult {
            guard let transformer = findTransformer(id: transformerId) else {
                throw PluginTransformError.transformerNotFound(transformerId)
            }

            guard let transformFunc = transformer.transform else {
                throw PluginTransformError.noTransformFunction
            }

            // Check content type support
            if let contentType = content.contentType,
               !transformer.supportedTypes.isEmpty,
               !transformer.supportedTypes.contains(contentType)
            {
                throw PluginTransformError.unsupportedContentType(contentType)
            }

            // Execute through sandbox
            let sandbox = await PluginHost.shared.context(for: transformer.pluginId)
            let result: PluginClipboardContent?

            do {
                result = try await transformFunc(content)
            } catch {
                throw PluginTransformError.transformFailed(error.localizedDescription)
            }

            return PluginTransformResult(
                original: content,
                transformed: result ?? content,
                pluginId: transformer.pluginId
            )
        }

        /// Finds transformers that support a content type
        /// - Parameter contentType: Content type to filter by
        /// - Returns: Matching transformers
        func transformers(for contentType: ContentType) -> [PluginTransformer] {
            allTransformers.filter { transformer in
                transformer.supportedTypes.isEmpty || transformer.supportedTypes.contains(contentType)
            }
        }

        /// Finds a transformer by ID
        /// - Parameter id: Transformer ID
        /// - Returns: Transformer if found
        func findTransformer(id: UUID) -> PluginTransformer? {
            allTransformers.first { $0.id == id }
        }

        /// Gets transformers for a specific plugin
        /// - Parameter pluginId: Plugin identifier
        /// - Returns: Transformers registered by the plugin
        func transformers(for pluginId: String) -> [PluginTransformer] {
            transformersByPlugin[pluginId] ?? []
        }

        // MARK: - Batch Transform

        /// Applies multiple transformers in sequence
        /// - Parameters:
        ///   - transformerIds: Ordered list of transformers to apply
        ///   - content: Initial content
        /// - Returns: Final transform result
        func applyTransformers(
            _ transformerIds: [UUID],
            to content: PluginClipboardContent
        ) async throws -> PluginTransformResult {
            var currentContent = content
            var lastPluginId = ""

            for transformerId in transformerIds {
                let result = try await executeTransform(
                    transformerId: transformerId,
                    content: currentContent
                )
                currentContent = result.transformed
                lastPluginId = result.pluginId
            }

            return PluginTransformResult(
                original: content,
                transformed: currentContent,
                pluginId: lastPluginId
            )
        }

        // MARK: Private

        private let logger = Logger.plugins

        /// Registered transformers by plugin ID
        private var transformersByPlugin: [String: [PluginTransformer]] = [:]
    }

    // MARK: - Transform Errors

    /// Errors from transform operations
    enum PluginTransformError: Error, LocalizedError {
        case transformerNotFound(UUID)
        case noTransformFunction
        case unsupportedContentType(ContentType)
        case transformFailed(String)

        // MARK: Internal

        var errorDescription: String? {
            switch self {
            case let .transformerNotFound(id):
                "Transformer with ID \(id) not found"
            case .noTransformFunction:
                "Transformer has no transform function"
            case let .unsupportedContentType(type):
                "Content type '\(type.displayName)' is not supported by this transformer"
            case let .transformFailed(reason):
                "Transform failed: \(reason)"
            }
        }
    }

#endif
