//
//  PasteShelfPluginKit.swift
//  PasteShelfPluginKit
//
//  Public SDK for creating PasteShelf plugins.
//  Import this package to build plugins that integrate with PasteShelf.
//
//  Copyright © 2026 PasteShelf. All rights reserved.
//

import AppKit
import Foundation
import SwiftUI

// MARK: - Main Plugin Protocol

/// Main protocol that all PasteShelf plugins must implement.
///
/// Your plugin class must:
/// - Be a subclass of `NSObject`
/// - Be marked with `@objc(YourClassName)` for runtime loading
/// - Implement `didLoad(with:)` to initialize your plugin
///
/// Example:
/// ```swift
/// @objc(MyPlugin)
/// public final class MyPlugin: NSObject, PasteShelfPlugin {
///     public func didLoad(with context: any PluginContext) {
///         context.logger.info("My plugin loaded!")
///     }
/// }
/// ```
@objc public protocol PasteShelfPlugin: NSObjectProtocol {
    /// Called when the plugin is loaded by PasteShelf.
    ///
    /// Use this method to:
    /// - Store a reference to the context
    /// - Initialize your plugin state
    /// - Register transformers and actions
    ///
    /// - Parameter context: The plugin context providing access to host APIs
    @objc func didLoad(with context: any PluginContext)

    /// Called before the plugin is unloaded.
    ///
    /// Use this to clean up resources and unregister any handlers.
    @objc optional func willUnload()

    /// Returns menu items to add to the PasteShelf UI.
    ///
    /// These items appear in the plugin menu and can be triggered by users.
    ///
    /// - Returns: Array of menu items, or empty array if none
    @objc optional func menuItems() -> [PluginMenuItem]
}

/// Extended protocol for plugins that transform clipboard content.
///
/// Implement this protocol to add content transformation capabilities
/// to your plugin.
public protocol PasteShelfPluginExtended: PasteShelfPlugin {
    /// Transforms clipboard content.
    ///
    /// - Parameter content: The content to transform
    /// - Returns: Transformed content, or nil to indicate no transformation
    func transform(content: PluginClipboardContent) async throws -> PluginClipboardContent?

    /// Checks if the plugin supports the given content type.
    ///
    /// - Parameter contentType: The content type to check
    /// - Returns: True if the plugin can handle this content type
    func supports(contentType: ContentType) -> Bool
}

/// Default implementations for extended protocol
public extension PasteShelfPluginExtended {
    func transform(content: PluginClipboardContent) async throws -> PluginClipboardContent? {
        nil
    }

    func supports(contentType: ContentType) -> Bool {
        false
    }
}

/// Protocol for plugins that provide a settings view.
public protocol PasteShelfPluginWithSettings: PasteShelfPlugin {
    /// Returns a SwiftUI view for plugin settings.
    ///
    /// This view is displayed in PasteShelf's plugin settings panel.
    ///
    /// - Returns: A SwiftUI view wrapped in AnyView, or nil if no settings
    func settingsView() -> AnyView?
}

// MARK: - Plugin Context

/// Context provided to plugins, giving access to host APIs.
///
/// The context is passed to your plugin in `didLoad(with:)` and provides
/// access to storage, logging, network, and clipboard APIs.
@objc public protocol PluginContext: NSObjectProtocol {
    /// Persistent storage for your plugin's data.
    var storage: any PluginStorage { get }

    /// Logger for debugging and diagnostics.
    var logger: PluginLogger { get }

    /// Current PasteShelf version string.
    var hostVersion: String { get }

    /// Network access (requires `network` permission).
    ///
    /// Returns nil if network permission was not granted.
    var network: (any PluginNetwork)? { get }

    /// Clipboard access (requires `clipboard.read` or `clipboard.write` permission).
    ///
    /// Returns nil if clipboard permissions were not granted.
    var clipboard: (any PluginClipboardAccess)? { get }

    /// Request an additional permission at runtime.
    ///
    /// Only permissions declared in your Info.plist can be requested.
    ///
    /// - Parameter permission: The permission identifier string (e.g., "clipboard.read")
    /// - Returns: True if permission was granted
    @objc(requestPermission:completionHandler:)
    func requestPermission(_ permission: String) async -> Bool

    /// Checks if a permission is currently granted.
    ///
    /// - Parameter permission: The permission identifier string (e.g., "clipboard.read")
    /// - Returns: True if the permission is granted
    @objc func hasPermission(_ permission: String) -> Bool
}

/// Swift-friendly permission methods.
public extension PluginContext {
    /// Request an additional permission at runtime.
    ///
    /// - Parameter permission: The permission to request
    /// - Returns: True if permission was granted
    func requestPermission(_ permission: PluginPermission) async -> Bool {
        await requestPermission(permission.rawValue)
    }

    /// Checks if a permission is currently granted.
    ///
    /// - Parameter permission: The permission to check
    /// - Returns: True if the permission is granted
    func hasPermission(_ permission: PluginPermission) -> Bool {
        hasPermission(permission.rawValue)
    }
}

// MARK: - Plugin Storage

/// Persistent storage for plugin data.
///
/// Data is stored in the user's Application Support directory,
/// isolated per-plugin.
@objc public protocol PluginStorage: NSObjectProtocol {
    func string(forKey key: String) -> String?
    func data(forKey key: String) -> Data?
    func bool(forKey key: String) -> Bool
    func integer(forKey key: String) -> Int
    func double(forKey key: String) -> Double

    @objc(setString:forKey:)
    func setString(_ value: String?, forKey key: String)

    @objc(setData:forKey:)
    func setData(_ value: Data?, forKey key: String)

    @objc(setBool:forKey:)
    func setBool(_ value: Bool, forKey key: String)

    @objc(setInteger:forKey:)
    func setInteger(_ value: Int, forKey key: String)

    @objc(setDouble:forKey:)
    func setDouble(_ value: Double, forKey key: String)

    func removeObject(forKey key: String)
    func clear()
}

/// Swift-friendly storage extension for Codable types.
public extension PluginStorage {
    /// Gets a Codable value for the key.
    func get<T: Codable>(_ key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// Sets a Codable value for the key.
    func set<T: Codable>(_ key: String, value: T?) {
        guard let value else {
            removeObject(forKey: key)
            return
        }
        guard let data = try? JSONEncoder().encode(value) else { return }
        setData(data, forKey: key)
    }
}

// MARK: - Plugin Network

/// Network access for plugins.
///
/// Requires the `network` permission in your Info.plist.
@objc public protocol PluginNetwork: NSObjectProtocol {
    /// Performs an HTTP request.
    ///
    /// - Parameter request: The URL request to perform
    /// - Returns: Response data and URL response
    func request(_ request: URLRequest) async throws -> (Data, URLResponse)
}

/// Convenience methods for common network operations.
public extension PluginNetwork {
    /// Performs a GET request.
    func get(_ url: URL) async throws -> Data {
        let (data, _) = try await request(URLRequest(url: url))
        return data
    }

    /// Performs a POST request with JSON body.
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

/// Clipboard access for plugins.
///
/// Requires `clipboard.read` and/or `clipboard.write` permissions.
@objc public protocol PluginClipboardAccess: NSObjectProtocol {
    /// Gets recent clipboard items.
    func recentItems(limit: Int) async -> [PluginClipboardContent]

    /// Gets the current clipboard content.
    func currentContent() -> PluginClipboardContent?

    /// Writes content to the clipboard.
    func writeToClipboard(_ content: PluginClipboardContent)
}

// MARK: - Plugin Logger

/// Logger for plugin diagnostics.
@objc public final class PluginLogger: NSObject, Sendable {
    private let pluginId: String

    public init(pluginId: String) {
        self.pluginId = pluginId
        super.init()
    }

    @objc public func debug(_ message: String) {
        print("[\(pluginId)] DEBUG: \(message)")
    }

    @objc public func info(_ message: String) {
        print("[\(pluginId)] INFO: \(message)")
    }

    @objc public func warning(_ message: String) {
        print("[\(pluginId)] WARNING: \(message)")
    }

    @objc public func error(_ message: String) {
        print("[\(pluginId)] ERROR: \(message)")
    }
}

// MARK: - Plugin Content

/// Clipboard content representation for plugins.
@objc public class PluginClipboardContent: NSObject, @unchecked Sendable {
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

    /// Custom metadata
    @objc public var metadata: [String: Any]

    /// Creates content with plain text.
    @objc public init(text: String) {
        self.text = text
        self.contentTypeIdentifier = ContentType.plainText.rawValue
        self.timestamp = Date()
        self.metadata = [:]
        super.init()
    }

    /// Creates content with an image.
    @objc public init(image: NSImage) {
        self.image = image
        self.imageData = image.tiffRepresentation
        self.contentTypeIdentifier = ContentType.png.rawValue
        self.timestamp = Date()
        self.metadata = [:]
        super.init()
    }

    /// Creates content with a URL.
    @objc public init(url: URL) {
        self.url = url
        self.text = url.absoluteString
        self.contentTypeIdentifier = ContentType.url.rawValue
        self.timestamp = Date()
        self.metadata = [:]
        super.init()
    }

    /// Creates empty content.
    @objc public override init() {
        self.contentTypeIdentifier = ContentType.plainText.rawValue
        self.timestamp = Date()
        self.metadata = [:]
        super.init()
    }

    /// Content type enum value
    public var contentType: ContentType? {
        ContentType(rawValue: contentTypeIdentifier)
    }
}

// MARK: - Plugin Menu Item

/// Menu item for the PasteShelf UI.
@objc public class PluginMenuItem: NSObject, @unchecked Sendable {
    @objc public let title: String
    @objc public let iconName: String?
    @objc public let shortcutKey: String?
    @objc public var isEnabled: Bool
    @objc public var submenuItems: [PluginMenuItem]?

    internal let actionId: UUID
    internal var action: ((PluginClipboardContent) async throws -> PluginClipboardContent?)?

    @objc public init(title: String, iconName: String? = nil, shortcutKey: String? = nil, isEnabled: Bool = true) {
        self.title = title
        self.iconName = iconName
        self.shortcutKey = shortcutKey
        self.isEnabled = isEnabled
        self.actionId = UUID()
        super.init()
    }

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
        self.actionId = UUID()
        self.action = action
        super.init()
    }
}

// MARK: - Content Type

/// Supported clipboard content types.
public enum ContentType: String, CaseIterable, Codable, Sendable {
    case plainText = "public.utf8-plain-text"
    case richText = "public.rtf"
    case html = "public.html"
    case png = "public.png"
    case jpeg = "public.jpeg"
    case tiff = "public.tiff"
    case pdf = "com.adobe.pdf"
    case fileURL = "public.file-url"
    case url = "public.url"

    public var displayName: String {
        switch self {
        case .plainText: return "Plain Text"
        case .richText: return "Rich Text"
        case .html: return "HTML"
        case .png: return "PNG Image"
        case .jpeg: return "JPEG Image"
        case .tiff: return "TIFF Image"
        case .pdf: return "PDF Document"
        case .fileURL: return "File"
        case .url: return "URL"
        }
    }
}

// MARK: - Plugin Permission

/// Permissions that plugins can request.
public enum PluginPermission: String, Codable, Hashable, CaseIterable, Sendable {
    case clipboardRead = "clipboard.read"
    case clipboardWrite = "clipboard.write"
    case network = "network"
    case notifications = "notifications"
    case storage = "storage"
    case automation = "automation"

    public var displayName: String {
        switch self {
        case .clipboardRead: return "Read Clipboard"
        case .clipboardWrite: return "Write Clipboard"
        case .network: return "Network Access"
        case .notifications: return "Notifications"
        case .storage: return "Storage"
        case .automation: return "Automation"
        }
    }
}
