//
//  PluginClipboardAPI.swift
//  PasteShelf
//
//  Extended clipboard API for plugins.
//  Provides search, filtering, and event subscription capabilities.
//

import AppKit
import Combine
import Foundation
import os.log

/// Extended clipboard API providing search and event capabilities
@MainActor
final class PluginClipboardAPI {
    // MARK: - Properties

    private let pluginId: String
    private let canRead: Bool
    private let canWrite: Bool
    private let logger = Logger.plugins

    /// Publisher for clipboard changes
    private let clipboardSubject = PassthroughSubject<PluginClipboardContent, Never>()

    /// Subscription to clipboard monitor
    private var monitorSubscription: AnyCancellable?

    // MARK: - Initialization

    init(pluginId: String, canRead: Bool, canWrite: Bool) {
        self.pluginId = pluginId
        self.canRead = canRead
        self.canWrite = canWrite

        if canRead {
            subscribeToClipboardChanges()
        }
    }

    deinit {
        monitorSubscription?.cancel()
    }

    // MARK: - Clipboard Events

    /// Publisher that emits when new clipboard content is captured
    var clipboardChanges: AnyPublisher<PluginClipboardContent, Never> {
        clipboardSubject.eraseToAnyPublisher()
    }

    private func subscribeToClipboardChanges() {
        // Subscribe to ClipboardMonitor notifications
        monitorSubscription = NotificationCenter.default
            .publisher(for: .clipboardContentCaptured)
            .sink { [weak self] notification in
                guard let self = self,
                      let content = notification.userInfo?["content"] as? ClipboardContent
                else { return }

                let pluginContent = self.convertToPluginContent(content)
                self.clipboardSubject.send(pluginContent)
            }
    }

    // MARK: - Fetch Operations

    /// Fetches recent clipboard items
    /// - Parameter limit: Maximum results to return
    /// - Returns: Recent clipboard items
    func fetchRecent(limit: Int = 50) async -> [PluginClipboardContent] {
        guard canRead else {
            logger.warning("[\(self.pluginId)] Attempted fetch without read permission")
            return []
        }

        let items = await StorageManager.shared.fetchRecentItems(limit: limit)
        return items.map { self.convertItemToPluginContent($0) }
    }

    /// Filters clipboard history by content type
    /// - Parameters:
    ///   - contentType: Content type to filter by
    ///   - limit: Maximum results to return
    /// - Returns: Filtered clipboard items
    func filter(byContentType contentType: ContentType, limit: Int = 50) async -> [PluginClipboardContent] {
        guard canRead else {
            logger.warning("[\(self.pluginId)] Attempted filter without read permission")
            return []
        }

        let items = await StorageManager.shared.fetchItems(byContentType: contentType, limit: limit)
        return items.map { self.convertItemToPluginContent($0) }
    }

    /// Fetches favorite clipboard items
    /// - Parameter limit: Maximum results to return
    /// - Returns: Favorite clipboard items
    func fetchFavorites(limit: Int = 50) async -> [PluginClipboardContent] {
        guard canRead else {
            logger.warning("[\(self.pluginId)] Attempted fetch favorites without read permission")
            return []
        }

        let items = await StorageManager.shared.fetchFavorites(limit: limit)
        return items.map { self.convertItemToPluginContent($0) }
    }

    /// Filters clipboard history by source application
    /// - Parameters:
    ///   - bundleId: Source app bundle identifier
    ///   - limit: Maximum results to return
    /// - Returns: Filtered clipboard items
    func filter(bySourceApp bundleId: String, limit: Int = 50) async -> [PluginClipboardContent] {
        guard canRead else {
            logger.warning("[\(self.pluginId)] Attempted filter without read permission")
            return []
        }

        let predicate = NSPredicate(format: "sourceAppBundleId == %@", bundleId)
        let items = await StorageManager.shared.fetchRecentItems(limit: limit, predicate: predicate)
        return items.map { self.convertItemToPluginContent($0) }
    }

    /// Filters clipboard history by date range
    /// - Parameters:
    ///   - from: Start date
    ///   - to: End date
    ///   - limit: Maximum results to return
    /// - Returns: Filtered clipboard items
    func filter(from: Date, to: Date, limit: Int = 50) async -> [PluginClipboardContent] {
        guard canRead else {
            logger.warning("[\(self.pluginId)] Attempted filter without read permission")
            return []
        }

        let predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@", from as NSDate, to as NSDate)
        let items = await StorageManager.shared.fetchRecentItems(limit: limit, predicate: predicate)
        return items.map { self.convertItemToPluginContent($0) }
    }

    // MARK: - Write Operations

    /// Writes transformed content back to clipboard and optionally stores it
    /// - Parameters:
    ///   - content: Content to write
    ///   - store: Whether to also save to history
    func write(_ content: PluginClipboardContent, store: Bool = false) {
        guard canWrite else {
            logger.warning("[\(self.pluginId)] Attempted write without write permission")
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Write all available content types
        if let text = content.text {
            pasteboard.setString(text, forType: .string)
        }

        if let rtfData = content.rtfData {
            pasteboard.setData(rtfData, forType: .rtf)
        }

        if let html = content.html {
            pasteboard.setString(html, forType: .html)
        }

        if let imageData = content.imageData {
            pasteboard.setData(imageData, forType: .png)
        }

        if let url = content.url {
            pasteboard.setString(url.absoluteString, forType: .URL)
        }

        if let fileURLs = content.fileURLs, !fileURLs.isEmpty {
            pasteboard.writeObjects(fileURLs as [NSURL])
        }

        logger.debug("[\(self.pluginId)] Wrote content to clipboard")

        // Optionally store in history
        if store {
            Task {
                await self.storeContent(content)
            }
        }
    }

    /// Stores content to history without writing to system clipboard
    /// - Parameter content: Content to store
    func storeContent(_ content: PluginClipboardContent) async {
        guard canWrite else {
            logger.warning("[\(self.pluginId)] Attempted store without write permission")
            return
        }

        // Convert to ClipboardContent and save
        let clipboardContent = convertFromPluginContent(content)
        _ = await StorageManager.shared.save(content: clipboardContent, from: nil)
        logger.debug("[\(self.pluginId)] Stored content to history")
    }

    // MARK: - Conversion Helpers

    private func convertToPluginContent(_ content: ClipboardContent) -> PluginClipboardContent {
        let pluginContent = PluginClipboardContent()

        pluginContent.text = content.plainText
        pluginContent.rtfData = content.rtfData
        pluginContent.html = content.html
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

    private func convertItemToPluginContent(_ item: ClipboardItem) -> PluginClipboardContent {
        let pluginContent = PluginClipboardContent()

        pluginContent.text = item.plainTextPreview
        pluginContent.contentTypeIdentifier = item.contentType ?? ContentType.plainText.rawValue
        pluginContent.sourceAppBundleId = item.sourceAppBundleId
        pluginContent.timestamp = item.timestamp ?? Date()

        // Get full content if available
        if let contentData = item.content {
            if let html = contentData.htmlContent {
                pluginContent.html = html
            }

            if let rtfData = contentData.rtfData {
                pluginContent.rtfData = rtfData
            }

            if let imageData = contentData.imageData {
                pluginContent.imageData = imageData
                pluginContent.image = NSImage(data: imageData)
            }

            if let urlString = contentData.urlString, let url = URL(string: urlString) {
                pluginContent.url = url
            }
        }

        return pluginContent
    }

    private func convertFromPluginContent(_ content: PluginClipboardContent) -> ClipboardContent {
        var clipboardContent = ClipboardContent(
            primaryType: content.contentType ?? .plainText,
            availableTypes: [content.contentType ?? .plainText],
            plainText: content.text,
            rtfData: content.rtfData,
            html: content.html,
            imageData: content.imageData,
            url: content.url,
            fileURLs: content.fileURLs
        )

        clipboardContent.sourceApp = content.sourceAppBundleId.map { bundleId in
            SourceApp(bundleId: bundleId, name: "Unknown", iconData: nil)
        }

        return clipboardContent
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// Posted when new clipboard content is captured (for plugin subscription)
    static let clipboardContentCaptured = Notification.Name("com.pasteshelf.clipboardContentCaptured")
}
