//
//  URLSchemeHandler.swift
//  PasteShelf
//
//  Handles pasteshelf:// URL scheme for external integration.
//  Supports copy, search, show, and other automation actions.
//

import AppKit
import CoreData
import Foundation

// MARK: - URL Scheme Handler

/// Handles pasteshelf:// URL scheme
final class URLSchemeHandler {
    // MARK: - Singleton

    static let shared = URLSchemeHandler()
    private init() {}

    // MARK: - URL Scheme Constants

    enum URLScheme {
        static let scheme = "pasteshelf"

        enum Host: String {
            case copy
            case search
            case show
            case hide
            case clear
            case transform
            case favorite
            case delete
        }
    }

    // MARK: - Handle URL

    /// Handle incoming URL
    /// - Parameter url: The pasteshelf:// URL to handle
    /// - Returns: Whether the URL was handled successfully
    @discardableResult
    func handleURL(_ url: URL) -> Bool {
        guard url.scheme == URLScheme.scheme else {
            return false
        }

        guard let host = url.host,
              let action = URLScheme.Host(rawValue: host)
        else {
            showInvalidURLAlert(url)
            return false
        }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let parameters = queryItems.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        }

        switch action {
        case .copy:
            return handleCopy(parameters: parameters)
        case .search:
            return handleSearch(parameters: parameters)
        case .show:
            return handleShow(parameters: parameters)
        case .hide:
            return handleHide()
        case .clear:
            return handleClear(parameters: parameters)
        case .transform:
            return handleTransform(parameters: parameters)
        case .favorite:
            return handleFavorite(parameters: parameters)
        case .delete:
            return handleDelete(parameters: parameters)
        }
    }

    // MARK: - Copy Action

    /// Handle pasteshelf://copy?text=...&id=...
    private func handleCopy(parameters: [String: String]) -> Bool {
        // Copy by text
        if let text = parameters["text"] {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            return true
        }

        // Copy by item ID
        if let idString = parameters["id"],
           let uuid = UUID(uuidString: idString)
        {
            return copyItemByID(uuid)
        }

        // Copy most recent item
        if parameters["recent"] != nil {
            return copyMostRecentItem()
        }

        return false
    }

    private func copyItemByID(_ id: UUID) -> Bool {
        let context = StorageManager.shared.viewContext
        var success = false

        context.performAndWait {
            let fetchRequest = ClipboardItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            do {
                if let item = try context.fetch(fetchRequest).first {
                    success = copyItemToClipboard(item)
                }
            } catch {
                success = false
            }
        }

        return success
    }

    private func copyMostRecentItem() -> Bool {
        let context = StorageManager.shared.viewContext
        var success = false

        context.performAndWait {
            let fetchRequest = ClipboardItem.fetchRequest()
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \ClipboardItem.timestamp, ascending: false),
            ]
            fetchRequest.fetchLimit = 1

            do {
                if let item = try context.fetch(fetchRequest).first {
                    success = copyItemToClipboard(item)
                }
            } catch {
                success = false
            }
        }

        return success
    }

    private func copyItemToClipboard(_ item: ClipboardItem) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if let contentData = item.content {
            if let urlString = contentData.urlString {
                pasteboard.setString(urlString, forType: .string)
                return true
            }

            if let html = contentData.htmlContent {
                pasteboard.setString(html, forType: .html)
                if let plainText = item.plainTextPreview {
                    pasteboard.setString(plainText, forType: .string)
                }
                return true
            }

            if let rtfData = contentData.rtfData {
                pasteboard.setData(rtfData, forType: .rtf)
                if let plainText = item.plainTextPreview {
                    pasteboard.setString(plainText, forType: .string)
                }
                return true
            }

            if let imageData = contentData.imageData,
               let image = NSImage(data: imageData)
            {
                pasteboard.writeObjects([image])
                return true
            }
        }

        if let plainText = item.plainTextPreview {
            pasteboard.setString(plainText, forType: .string)
            return true
        }

        return false
    }

    // MARK: - Search Action

    /// Handle pasteshelf://search?query=...&limit=...
    private func handleSearch(parameters: [String: String]) -> Bool {
        guard let query = parameters["query"], !query.isEmpty else {
            return false
        }

        let limit = parameters["limit"].flatMap { Int($0) } ?? 20
        let actualLimit = max(1, min(limit, 50))

        // Show main window with search
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)

            // Post notification with search query
            NotificationCenter.default.post(
                name: .showMainWindowWithSearch,
                object: nil,
                userInfo: ["query": query, "limit": actualLimit]
            )
        }

        return true
    }

    // MARK: - Show Action

    /// Handle pasteshelf://show?view=...&id=...
    private func handleShow(parameters: [String: String]) -> Bool {
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)

            var userInfo: [String: Any] = [:]

            // Optional view parameter
            if let view = parameters["view"] {
                userInfo["view"] = view
            }

            // Optional item ID to highlight
            if let idString = parameters["id"],
               let uuid = UUID(uuidString: idString)
            {
                userInfo["highlightItem"] = uuid
            }

            NotificationCenter.default.post(
                name: .showMainWindow,
                object: nil,
                userInfo: userInfo.isEmpty ? nil : userInfo
            )
        }

        return true
    }

    // MARK: - Hide Action

    /// Handle pasteshelf://hide
    private func handleHide() -> Bool {
        DispatchQueue.main.async {
            NSApplication.shared.hide(nil)
        }
        return true
    }

    // MARK: - Clear Action

    /// Handle pasteshelf://clear?keepFavorites=true
    private func handleClear(parameters: [String: String]) -> Bool {
        let keepFavorites = parameters["keepFavorites"]?.lowercased() != "false"

        let context = StorageManager.shared.viewContext
        var success = false

        context.performAndWait {
            let fetchRequest = ClipboardItem.fetchRequest()

            if keepFavorites {
                fetchRequest.predicate = NSPredicate(format: "isFavorite == NO")
            }

            do {
                let items = try context.fetch(fetchRequest)
                for item in items {
                    context.delete(item)
                }
                try context.save()
                success = true
            } catch {
                success = false
            }
        }

        return success
    }

    // MARK: - Transform Action

    /// Handle pasteshelf://transform?text=...&preset=...
    private func handleTransform(parameters: [String: String]) -> Bool {
        guard let text = parameters["text"],
              let presetName = parameters["preset"],
              let preset = TransformPreset(rawValue: presetName)
        else {
            return false
        }

        let transformed = preset.transform(text)

        // Copy result to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(transformed, forType: .string)

        return true
    }

    // MARK: - Favorite Action

    /// Handle pasteshelf://favorite?id=...&set=true/false
    private func handleFavorite(parameters: [String: String]) -> Bool {
        guard let idString = parameters["id"],
              let uuid = UUID(uuidString: idString)
        else {
            return false
        }

        let setFavorite = parameters["set"]?.lowercased() != "false"

        let context = StorageManager.shared.viewContext
        var success = false

        context.performAndWait {
            let fetchRequest = ClipboardItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            fetchRequest.fetchLimit = 1

            do {
                if let item = try context.fetch(fetchRequest).first {
                    item.isFavorite = setFavorite
                    try context.save()
                    success = true
                }
            } catch {
                success = false
            }
        }

        return success
    }

    // MARK: - Delete Action

    /// Handle pasteshelf://delete?id=...
    private func handleDelete(parameters: [String: String]) -> Bool {
        guard let idString = parameters["id"],
              let uuid = UUID(uuidString: idString)
        else {
            return false
        }

        let context = StorageManager.shared.viewContext
        var success = false

        context.performAndWait {
            let fetchRequest = ClipboardItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            fetchRequest.fetchLimit = 1

            do {
                if let item = try context.fetch(fetchRequest).first {
                    context.delete(item)
                    try context.save()
                    success = true
                }
            } catch {
                success = false
            }
        }

        return success
    }

    // MARK: - Error Alerts

    private func showInvalidURLAlert(_ url: URL) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Invalid URL"
            alert.informativeText = "The URL '\(url.absoluteString)' is not a valid PasteShelf URL."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

// MARK: - URL Builder

extension URLSchemeHandler {
    /// Build a pasteshelf:// URL for copying text
    static func copyTextURL(text: String) -> URL? {
        var components = URLComponents()
        components.scheme = URLScheme.scheme
        components.host = URLScheme.Host.copy.rawValue
        components.queryItems = [URLQueryItem(name: "text", value: text)]
        return components.url
    }

    /// Build a pasteshelf:// URL for copying an item by ID
    static func copyItemURL(id: UUID) -> URL? {
        var components = URLComponents()
        components.scheme = URLScheme.scheme
        components.host = URLScheme.Host.copy.rawValue
        components.queryItems = [URLQueryItem(name: "id", value: id.uuidString)]
        return components.url
    }

    /// Build a pasteshelf:// URL for searching
    static func searchURL(query: String, limit: Int? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = URLScheme.scheme
        components.host = URLScheme.Host.search.rawValue
        var queryItems = [URLQueryItem(name: "query", value: query)]
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        components.queryItems = queryItems
        return components.url
    }

    /// Build a pasteshelf:// URL for showing the window
    static func showURL(view: String? = nil, highlightItem: UUID? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = URLScheme.scheme
        components.host = URLScheme.Host.show.rawValue

        var queryItems: [URLQueryItem] = []
        if let view = view {
            queryItems.append(URLQueryItem(name: "view", value: view))
        }
        if let id = highlightItem {
            queryItems.append(URLQueryItem(name: "id", value: id.uuidString))
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        return components.url
    }

    /// Build a pasteshelf:// URL for transforming text
    static func transformURL(text: String, preset: TransformPreset) -> URL? {
        var components = URLComponents()
        components.scheme = URLScheme.scheme
        components.host = URLScheme.Host.transform.rawValue
        components.queryItems = [
            URLQueryItem(name: "text", value: text),
            URLQueryItem(name: "preset", value: preset.rawValue),
        ]
        return components.url
    }
}
