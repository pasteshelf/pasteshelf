// swiftlint:disable file_length
#if !APP_STORE
//
    //  PluginProtocols.swift
    //  PasteShelf
//
    //  Defines the core protocols for the plugin system.
    //  Plugins implement PasteShelfPlugin to integrate with the host app.
//

    import AppKit
    import Foundation
    import os.log
    import SwiftUI

    // MARK: - Main Plugin Protocol

    /// Main protocol that all PasteShelf plugins must implement
    @objc
    public protocol PasteShelfPlugin: NSObjectProtocol {
        /// Called when the plugin is loaded
        /// - Parameter context: The plugin context providing access to host APIs
        @objc
        func didLoad(with context: any PluginContext)

        /// Called before the plugin is unloaded
        @objc
        optional func willUnload()

        /// Returns menu items to add to the PasteShelf UI
        /// - Returns: Array of menu items, or empty array if none
        @objc
        optional func menuItems() -> [PluginMenuItem]
    }

    /// Extended protocol for Swift plugins that can provide settings views
    public protocol PasteShelfPluginWithSettings: PasteShelfPlugin {
        /// Returns a settings view for the plugin
        /// - Returns: A SwiftUI view wrapped in AnyView, or nil if no settings
        func settingsView() -> AnyView?
    }

    /// Default implementation for settings
    public extension PasteShelfPluginWithSettings {
        func settingsView() -> AnyView? {
            nil
        }
    }

    /// Protocol extension for Swift-only plugin features
    protocol PasteShelfPluginExtended: PasteShelfPlugin {
        /// Transforms clipboard content
        /// - Parameter content: The content to transform
        /// - Returns: Transformed content, or nil to indicate no transformation
        func transform(content: PluginClipboardContent) async throws -> PluginClipboardContent?

        /// Checks if the plugin supports the given content type
        /// - Parameter contentType: The content type to check
        /// - Returns: True if the plugin can handle this content type
        func supports(contentType: ContentType) -> Bool
    }

    /// Default implementations for extended protocol
    extension PasteShelfPluginExtended {
        func transform(content: PluginClipboardContent) async throws -> PluginClipboardContent? {
            nil
        }

        func supports(contentType: ContentType) -> Bool {
            false
        }
    }

    // MARK: - Plugin Context

    /// Context provided to plugins on load, giving access to host APIs
    @objc
    public protocol PluginContext: NSObjectProtocol {
        /// Persistent storage for the plugin
        var storage: any PluginStorage { get }

        /// Logger for the plugin
        var logger: PluginLogger { get }

        /// Current PasteShelf version
        var hostVersion: String { get }

        /// Network access (if permission granted)
        var network: (any PluginNetwork)? { get }

        /// Clipboard access (if permission granted)
        var clipboard: (any PluginClipboardAccess)? { get }

        /// Request an additional permission at runtime
        /// - Parameter permission: The permission identifier string (e.g., "clipboard.read")
        /// - Returns: True if permission was granted
        @objc(requestPermission:completionHandler:)
        func requestPermission(_ permission: String) async -> Bool

        /// Checks if a permission is currently granted
        /// - Parameter permission: The permission identifier string
        /// - Returns: True if the permission is granted
        @objc
        func hasPermission(_ permission: String) -> Bool
    }

    /// Swift-friendly permission methods
    public extension PluginContext {
        /// Request an additional permission at runtime
        /// - Parameter permission: The permission to request
        /// - Returns: True if permission was granted
        func requestPermission(_ permission: PluginPermission) async -> Bool {
            await requestPermission(permission.rawValue)
        }

        /// Checks if a permission is currently granted
        /// - Parameter permission: The permission to check
        /// - Returns: True if the permission is granted
        func hasPermission(_ permission: PluginPermission) -> Bool {
            hasPermission(permission.rawValue)
        }
    }

    // MARK: - Plugin Storage

    /// Per-plugin persistent storage
    @objc
    public protocol PluginStorage: NSObjectProtocol {
        /// Gets a string value for the key
        func string(forKey key: String) -> String?

        /// Gets a data value for the key
        func data(forKey key: String) -> Data?

        /// Gets a boolean value for the key
        func bool(forKey key: String) -> Bool

        /// Gets an integer value for the key
        func integer(forKey key: String) -> Int

        /// Gets a double value for the key
        func double(forKey key: String) -> Double

        /// Sets a string value for the key
        @objc(setString:forKey:)
        func setString(_ value: String?, forKey key: String)

        /// Sets a data value for the key
        @objc(setData:forKey:)
        func setData(_ value: Data?, forKey key: String)

        /// Sets a boolean value for the key
        @objc(setBool:forKey:)
        func setBool(_ value: Bool, forKey key: String)

        /// Sets an integer value for the key
        @objc(setInteger:forKey:)
        func setInteger(_ value: Int, forKey key: String)

        /// Sets a double value for the key
        @objc(setDouble:forKey:)
        func setDouble(_ value: Double, forKey key: String)

        /// Removes the value for the key
        func removeObject(forKey key: String)

        /// Removes all stored values
        func clear()
    }

    /// Swift-friendly storage extension
    public extension PluginStorage {
        /// Gets a Codable value for the key
        func get<T: Codable>(_ key: String) -> T? {
            guard let data = data(forKey: key) else {
                return nil
            }
            return try? JSONDecoder().decode(T.self, from: data)
        }

        /// Sets a Codable value for the key
        func set(_ key: String, value: (some Codable)?) {
            guard let value else {
                removeObject(forKey: key)
                return
            }
            guard let data = try? JSONEncoder().encode(value) else {
                return
            }
            setData(data, forKey: key)
        }
    }

    // MARK: - Plugin Network

    /// Network access for plugins (requires network permission)
    @objc
    public protocol PluginNetwork: NSObjectProtocol {
        /// Performs an HTTP request
        /// - Parameter request: The URL request to perform
        /// - Returns: Response data and URL response
        func request(_ request: URLRequest) async throws -> (Data, URLResponse)
    }

    /// Swift-friendly network extension
    public extension PluginNetwork {
        /// Performs a GET request
        /// - Parameter url: The URL to fetch
        /// - Returns: Response data
        func get(_ url: URL) async throws -> Data {
            let (data, _) = try await request(URLRequest(url: url))
            return data
        }

        /// Performs a POST request with JSON body
        /// - Parameters:
        ///   - url: The URL to post to
        ///   - body: The data to send
        ///   - contentType: The content type header (defaults to application/json)
        /// - Returns: Response data
        func post(_ url: URL, body: Data, contentType: String = "application/json") async throws -> Data {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            let (data, _) = try await self.request(request)
            return data
        }
    }

    // MARK: - Plugin Clipboard Access

    /// Clipboard access for plugins (requires clipboard.read/write permissions)
    @objc
    public protocol PluginClipboardAccess: NSObjectProtocol {
        /// Gets recent clipboard items
        /// - Parameter limit: Maximum number of items to return
        /// - Returns: Array of clipboard content items
        func recentItems(limit: Int) async -> [PluginClipboardContent]

        /// Gets the current clipboard content
        /// - Returns: Current clipboard content, or nil if empty
        func currentContent() -> PluginClipboardContent?

        /// Writes content to the clipboard
        /// - Parameter content: The content to write
        func writeToClipboard(_ content: PluginClipboardContent)
    }

    // MARK: - Plugin Logger

    /// Logger for plugin use
    @objc
    public final class PluginLogger: NSObject, Sendable {
        // MARK: Lifecycle

        init(pluginId: String) {
            self.pluginId = pluginId
            super.init()
        }

        // MARK: Public

        @objc
        public func debug(_ message: String) {
            log(level: .debug, message: message)
        }

        @objc
        public func info(_ message: String) {
            log(level: .info, message: message)
        }

        @objc
        public func warning(_ message: String) {
            log(level: .warning, message: message)
        }

        @objc
        public func error(_ message: String) {
            log(level: .error, message: message)
        }

        // MARK: Private

        private enum LogLevel {
            case debug
            case info
            case warning
            case error
        }

        private let pluginId: String

        private func log(level: LogLevel, message: String) {
            let prefix = "[\(pluginId)]"
            switch level {
            case .debug:
                Logger.plugins.debug("\(prefix, privacy: .public) \(message, privacy: .public)")
            case .info:
                Logger.plugins.info("\(prefix, privacy: .public) \(message, privacy: .public)")
            case .warning:
                Logger.plugins.warning("\(prefix, privacy: .public) \(message, privacy: .public)")
            case .error:
                Logger.plugins.error("\(prefix, privacy: .public) \(message, privacy: .public)")
            }
        }
    }

    // MARK: - Plugin Clipboard Content

    /// Clipboard content representation for plugins
    @objc
    public class PluginClipboardContent: NSObject, @unchecked Sendable {
        // MARK: Lifecycle

        /// Creates content with plain text
        @objc
        public init(text: String) {
            self.text = text
            contentTypeIdentifier = ContentType.plainText.rawValue
            timestamp = Date()
            metadata = [:]
            super.init()
        }

        /// Creates content with an image
        @objc
        public init(image: NSImage) {
            self.image = image
            imageData = image.tiffRepresentation
            contentTypeIdentifier = ContentType.png.rawValue
            timestamp = Date()
            metadata = [:]
            super.init()
        }

        /// Creates content with a URL
        @objc
        public init(url: URL) {
            self.url = url
            text = url.absoluteString
            contentTypeIdentifier = ContentType.url.rawValue
            timestamp = Date()
            metadata = [:]
            super.init()
        }

        /// Creates empty content
        @objc
        override public init() {
            contentTypeIdentifier = ContentType.plainText.rawValue
            timestamp = Date()
            metadata = [:]
            super.init()
        }

        // MARK: Public

        /// Plain text content
        @objc public var text: String?

        /// Rich text data (RTF)
        @objc public var rtfData: Data?

        /// HTML content
        @objc public var html: String?

        /// Image data
        @objc public var imageData: Data?

        /// Image representation
        @objc public var image: NSImage?

        /// File URLs
        @objc public var fileURLs: [URL]?

        /// Web URL
        @objc public var url: URL?

        /// Primary content type identifier
        @objc public var contentTypeIdentifier: String

        /// Source application bundle ID
        @objc public var sourceAppBundleId: String?

        /// Timestamp when content was captured
        @objc public var timestamp: Date

        /// Custom metadata (key-value pairs)
        @objc public var metadata: [String: Any]

        /// Content type enum value
        public var contentType: ContentType? {
            ContentType(rawValue: contentTypeIdentifier)
        }
    }

    // MARK: - Plugin Menu Item

    /// Menu item that plugins can add to the PasteShelf UI
    @objc
    public class PluginMenuItem: NSObject, @unchecked Sendable {
        // MARK: Lifecycle

        /// Creates a menu item (Objective-C compatible)
        /// - Parameters:
        ///   - title: Display title
        ///   - iconName: SF Symbol name
        ///   - shortcutKey: Keyboard shortcut string
        ///   - isEnabled: Whether enabled (default true)
        @objc
        public init(
            title: String,
            iconName: String? = nil,
            shortcutKey: String? = nil,
            isEnabled: Bool = true
        ) {
            self.title = title
            self.iconName = iconName
            self.shortcutKey = shortcutKey
            self.isEnabled = isEnabled
            actionId = UUID()
            action = nil
            super.init()
        }

        /// Creates a menu item with action (Swift only)
        /// - Parameters:
        ///   - title: Display title
        ///   - iconName: SF Symbol name
        ///   - shortcutKey: Keyboard shortcut string
        ///   - isEnabled: Whether enabled (default true)
        ///   - action: Action to perform when selected
        public init(
            title: String,
            iconName: String? = nil,
            shortcutKey: String? = nil,
            isEnabled: Bool = true,
            action: @escaping (PluginClipboardContent) async throws -> PluginClipboardContent?
        ) {
            self.title = title
            self.iconName = iconName
            self.shortcutKey = shortcutKey
            self.isEnabled = isEnabled
            actionId = UUID()
            self.action = action
            super.init()
        }

        /// Creates a submenu item
        @objc
        public init(title: String, iconName: String? = nil, submenuItems: [PluginMenuItem]) {
            self.title = title
            self.iconName = iconName
            shortcutKey = nil
            isEnabled = true
            self.submenuItems = submenuItems
            actionId = UUID()
            super.init()
        }

        // MARK: Public

        /// Menu item title
        @objc public let title: String

        /// SF Symbol icon name (optional)
        @objc public let iconName: String?

        /// Keyboard shortcut (optional) - format: "key+modifiers" e.g., "U+command+shift"
        @objc public let shortcutKey: String?

        /// Whether the menu item is currently enabled
        @objc public var isEnabled: Bool

        /// Submenu items (optional)
        @objc public var submenuItems: [PluginMenuItem]?

        // MARK: Internal

        /// Action identifier for routing
        let actionId: UUID

        /// Action closure (stored internally)
        var action: ((PluginClipboardContent) async throws -> PluginClipboardContent?)?
    }

    // MARK: - Plugin State

    /// Represents the current state of a plugin
    enum PluginState: String, Codable {
        /// Plugin is discovered but not loaded
        case discovered

        /// Plugin is being loaded
        case loading

        /// Plugin is loaded and active
        case active

        /// Plugin is disabled by user
        case disabled

        /// Plugin failed to load
        case failed

        /// Plugin is being unloaded
        case unloading

        // MARK: Internal

        var isLoaded: Bool {
            self == .active
        }

        var canLoad: Bool {
            self == .discovered || self == .disabled || self == .failed
        }
    }

    /// Information about a loaded plugin
    struct LoadedPlugin: Identifiable {
        // MARK: Lifecycle

        init(bundle: PluginBundle, instance: (any PasteShelfPlugin)? = nil, state: PluginState = .discovered) {
            id = bundle.manifest.identifier
            self.bundle = bundle
            self.instance = instance
            self.state = state
        }

        // MARK: Internal

        let id: String
        let bundle: PluginBundle
        nonisolated(unsafe) let instance: (any PasteShelfPlugin)?
        var state: PluginState
        var loadError: String?
    }

#endif
