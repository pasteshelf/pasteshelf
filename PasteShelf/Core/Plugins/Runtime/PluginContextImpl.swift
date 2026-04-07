#if !APP_STORE
//
    //  PluginContextImpl.swift
    //  PasteShelf
//
    //  Concrete implementation of PluginContext protocol.
    //  Provides sandboxed access to host APIs for plugins.
//

    import AppKit
    import Foundation
    import os.log

    /// Concrete implementation of PluginContext for running plugins
    @MainActor @objc
    public final class PluginContextImpl: NSObject, PluginContext, @unchecked Sendable {
        // MARK: Lifecycle

        // MARK: - Initialization

        init(pluginId: String, bundle: PluginBundle, sandbox: PluginSandbox) {
            self.pluginId = pluginId
            self.bundle = bundle
            self.sandbox = sandbox

            // Create storage
            storage = PluginStorageImpl(pluginId: pluginId)

            // Create logger
            logger = PluginLogger(pluginId: pluginId)

            // Initialize permissions from manager
            grantedPermissions = PluginManager.shared.grantedPermissions(for: pluginId)

            super.init()

            // Initialize APIs based on permissions
            initializeAPIs()
        }

        // MARK: Public

        /// Per-plugin storage
        public let storage: any PluginStorage

        /// Plugin logger
        public let logger: PluginLogger

        /// Host app version
        public var hostVersion: String {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        }

        public var network: (any PluginNetwork)? {
            _network
        }

        public var clipboard: (any PluginClipboardAccess)? {
            _clipboard
        }

        // MARK: - Permission Management

        /// Requests an additional permission at runtime (String-based for @objc compatibility)
        @MainActor
        @objc(requestPermission:completionHandler:)
        public func requestPermission(_ permissionString: String) async -> Bool {
            guard let permission = PluginPermission(rawValue: permissionString) else {
                Logger.plugins.warning("[\(pluginId)] Unknown permission requested: \(permissionString)")
                return false
            }

            // Check if already granted
            if grantedPermissions.contains(permission) {
                return true
            }

            // Check if permission was declared in manifest
            guard bundle.manifest.requiredPermissions.contains(permission) else {
                Logger.plugins.warning("[\(pluginId)] Requested undeclared permission: \(permissionString)")
                return false
            }

            // Show permission dialog (simplified - in real app would show UI)
            // For now, auto-grant declared permissions
            let granted = await showPermissionDialog(for: permission)

            if granted {
                grantedPermissions.insert(permission)
                PluginManager.shared.grantPermission(permission, to: pluginId)
                initializeAPIs() // Reinitialize with new permissions
                Logger.plugins.info("[\(pluginId)] Permission granted: \(permissionString)")
            }

            return granted
        }

        /// Checks if a permission is currently granted (String-based for @objc compatibility)
        @objc public func hasPermission(_ permissionString: String) -> Bool {
            guard let permission = PluginPermission(rawValue: permissionString) else {
                return false
            }
            return grantedPermissions.contains(permission)
        }

        // MARK: Private

        private let pluginId: String
        private let bundle: PluginBundle
        private let sandbox: PluginSandbox

        /// Network API (requires permission)
        private var _network: PluginNetworkImpl?

        /// Clipboard API (requires permission)
        private var _clipboard: PluginClipboardAccessImpl?

        /// Granted permissions for this plugin
        private var grantedPermissions: Set<PluginPermission>

        // MARK: - API Initialization

        private func initializeAPIs() {
            // Network API
            if grantedPermissions.contains(.network) {
                _network = PluginNetworkImpl(pluginId: pluginId, sandbox: sandbox)
            }

            // Clipboard API
            if grantedPermissions.contains(.clipboardRead) || grantedPermissions.contains(.clipboardWrite) {
                _clipboard = PluginClipboardAccessImpl(
                    pluginId: pluginId,
                    canRead: grantedPermissions.contains(.clipboardRead),
                    canWrite: grantedPermissions.contains(.clipboardWrite)
                )
            }
        }

        // MARK: - Permission Dialog

        @MainActor
        private func showPermissionDialog(for permission: PluginPermission) async -> Bool {
            // In a real implementation, this would show a system dialog
            // For now, we auto-grant permissions that were declared in the manifest
            // The user already reviewed these during plugin installation

            Logger.plugins.debug("[\(pluginId)] Auto-granting declared permission: \(permission.rawValue)")
            return true
        }
    }

    // MARK: - Plugin Context Factory Implementation

    /// Factory for creating plugin contexts
    @MainActor
    final class PluginContextFactoryImpl: PluginContextFactory {
        func createContext(for bundle: PluginBundle) -> any PluginContext {
            PluginHost.shared.createEnvironment(for: bundle)
        }
    }

    // MARK: - Plugin Network Implementation

    /// Implementation of PluginNetwork with sandboxing
    @objc
    public final class PluginNetworkImpl: NSObject, PluginNetwork, @unchecked Sendable {
        // MARK: Lifecycle

        init(pluginId: String, sandbox: PluginSandbox) {
            self.pluginId = pluginId
            self.sandbox = sandbox

            // Create dedicated session for this plugin
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 60
            session = URLSession(configuration: config)

            super.init()
        }

        // MARK: Public

        public func request(_ request: URLRequest) async throws -> (Data, URLResponse) {
            // Validate request against sandbox policy
            try await sandbox.validateNetworkRequest(request)

            // Execute with timeout from sandbox
            return try await sandbox.execute {
                try await self.session.data(for: request)
            }
        }

        // MARK: Private

        private let pluginId: String
        private let sandbox: PluginSandbox
        private let session: URLSession
    }

    // MARK: - Plugin Clipboard Access Implementation

    /// Implementation of PluginClipboardAccess
    @MainActor @objc
    public final class PluginClipboardAccessImpl: NSObject, PluginClipboardAccess,
        @unchecked Sendable
    {
        // MARK: Lifecycle

        init(pluginId: String, canRead: Bool, canWrite: Bool) {
            self.pluginId = pluginId
            self.canRead = canRead
            self.canWrite = canWrite
            super.init()

            if canRead {
                subscribeToClipboardChanges()
            }
        }

        deinit {
            if let observer = clipboardObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        // MARK: Public

        public func recentItems(limit: Int) async -> [PluginClipboardContent] {
            guard canRead else {
                Logger.plugins.warning("[\(pluginId)] Attempted clipboard read without permission")
                return []
            }

            // Get items from StorageManager
            let items = await StorageManager.shared.fetchRecentItems(limit: limit)
            return items.map { item in
                self.convertToPluginContent(item)
            }
        }

        public func currentContent() -> PluginClipboardContent? {
            guard canRead else {
                Logger.plugins.warning("[\(pluginId)] Attempted clipboard read without permission")
                return nil
            }

            // Get current pasteboard content
            let pasteboard = NSPasteboard.general
            guard pasteboard.changeCount > 0 else {
                return nil
            }

            let content = PluginClipboardContent()

            // Try to get text
            if let text = pasteboard.string(forType: .string) {
                content.text = text
                content.contentTypeIdentifier = ContentType.plainText.rawValue
            }

            // Try to get URL
            if let url = pasteboard.string(forType: .URL).flatMap({ URL(string: $0) }) {
                content.url = url
                content.contentTypeIdentifier = ContentType.url.rawValue
            }

            // Try to get image
            if let imageData = pasteboard.data(forType: .png) {
                content.imageData = imageData
                content.image = NSImage(data: imageData)
                content.contentTypeIdentifier = ContentType.png.rawValue
            }

            return content
        }

        public func writeToClipboard(_ content: PluginClipboardContent) {
            guard canWrite else {
                Logger.plugins.warning("[\(pluginId)] Attempted clipboard write without permission")
                return
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            // Write content based on what's available
            if let text = content.text {
                pasteboard.setString(text, forType: .string)
            }

            if let url = content.url {
                pasteboard.setString(url.absoluteString, forType: .URL)
            }

            if let imageData = content.imageData {
                pasteboard.setData(imageData, forType: .png)
            }

            Logger.plugins.debug("[\(pluginId)] Wrote to clipboard")
        }

        // MARK: Internal

        /// Callback for clipboard changes (set by plugin via onChange handler)
        var onClipboardChange: ((PluginClipboardContent) -> Void)?

        // MARK: Private

        private let pluginId: String
        private let canRead: Bool
        private let canWrite: Bool

        /// Subscription to clipboard capture notifications
        private var clipboardObserver: NSObjectProtocol?

        private func subscribeToClipboardChanges() {
            clipboardObserver = NotificationCenter.default.addObserver(
                forName: .clipboardContentCaptured,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self,
                      let content = notification.userInfo?["content"] as? ClipboardContent,
                      let handler = onClipboardChange
                else {
                    return
                }

                let pluginContent = convertClipboardToPluginContent(content)
                handler(pluginContent)
            }
        }

        private func convertClipboardToPluginContent(_ content: ClipboardContent) -> PluginClipboardContent {
            let pluginContent = PluginClipboardContent()
            pluginContent.text = content.plainText
            pluginContent.contentTypeIdentifier = content.primaryType.rawValue
            pluginContent.sourceAppBundleId = content.sourceApp?.bundleId
            if let imageData = content.imageData {
                pluginContent.imageData = imageData
                pluginContent.image = NSImage(data: imageData)
            }
            if let url = content.url {
                pluginContent.url = url
            }
            return pluginContent
        }

        // MARK: - Helpers

        private func convertToPluginContent(_ item: ClipboardItem) -> PluginClipboardContent {
            let pluginContent = PluginClipboardContent()

            pluginContent.text = item.plainTextPreview
            pluginContent.contentTypeIdentifier = item.contentType ?? ContentType.plainText.rawValue
            pluginContent.sourceAppBundleId = item.sourceAppBundleId
            pluginContent.timestamp = item.timestamp ?? Date()

            // Get full content if available
            if let contentData = item.content {
                // HTML content
                if let html = contentData.htmlContent {
                    pluginContent.html = html
                }

                // RTF data
                if let rtfData = contentData.rtfData {
                    pluginContent.rtfData = rtfData
                }

                // Image data
                if let imageData = contentData.imageData {
                    pluginContent.imageData = imageData
                    pluginContent.image = NSImage(data: imageData)
                }

                // URL
                if let urlString = contentData.urlString, let url = URL(string: urlString) {
                    pluginContent.url = url
                }
            }

            return pluginContent
        }
    }

#endif
