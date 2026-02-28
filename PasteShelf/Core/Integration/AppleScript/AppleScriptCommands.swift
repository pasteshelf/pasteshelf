//
//  AppleScriptCommands.swift
//  PasteShelf
//
//  AppleScript command handlers for PasteShelf.
//  Implements the commands defined in PasteShelf.sdef.
//

import AppKit
import CoreData
import Foundation

// MARK: - Get Clipboard History Command

/// Handles the "get clipboard history" AppleScript command
@objc(GetClipboardHistoryCommand)
class GetClipboardHistoryCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        // Get parameters
        let limit = (evaluatedArguments?["limit"] as? Int) ?? 10
        let favoritesOnly = (evaluatedArguments?["favoritesOnly"] as? Bool) ?? false

        // Clamp limit
        let actualLimit = max(1, min(limit, 100))

        let context = StorageManager.shared.viewContext
        var results: [ClipboardItemScriptable] = []

        context.performAndWait {
            let fetchRequest = ClipboardItem.fetchRequest()

            if favoritesOnly {
                fetchRequest.predicate = NSPredicate(format: "isFavorite == YES")
            }

            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \ClipboardItem.timestamp, ascending: false),
            ]
            fetchRequest.fetchLimit = actualLimit

            do {
                let items = try context.fetch(fetchRequest)
                results = items.map { ClipboardItemScriptable(item: $0) }
            } catch {
                results = []
            }
        }

        return results
    }
}

// MARK: - Search Clipboard Command

/// Handles the "search clipboard" AppleScript command
@objc(SearchClipboardCommand)
class SearchClipboardCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        // Get search query from direct parameter
        guard let query = directParameter as? String, !query.isEmpty else {
            scriptErrorNumber = errOSAGeneralError
            scriptErrorString = "Please provide a search query."
            return nil
        }

        // Get limit parameter
        let limit = (evaluatedArguments?["limit"] as? Int) ?? 20
        let actualLimit = max(1, min(limit, 50))

        let context = StorageManager.shared.viewContext
        var results: [ClipboardItemScriptable] = []

        context.performAndWait {
            let fetchRequest = ClipboardItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "plainTextPreview CONTAINS[cd] %@",
                query
            )
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \ClipboardItem.timestamp, ascending: false),
            ]
            fetchRequest.fetchLimit = actualLimit

            do {
                let items = try context.fetch(fetchRequest)
                results = items.map { ClipboardItemScriptable(item: $0) }
            } catch {
                results = []
            }
        }

        return results
    }
}

// MARK: - Copy Item Command

/// Handles the "copy item" AppleScript command
@objc(CopyItemCommand)
class CopyItemCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        // Get the item from direct parameter
        guard let scriptable = directParameter as? ClipboardItemScriptable else {
            scriptErrorNumber = errOSAGeneralError
            scriptErrorString = "Please provide a clipboard item."
            return false
        }

        guard let uuid = UUID(uuidString: scriptable.uniqueID) else {
            scriptErrorNumber = errOSAGeneralError
            scriptErrorString = "Invalid item identifier."
            return false
        }

        let context = StorageManager.shared.viewContext
        var success = false

        context.performAndWait {
            let fetchRequest = ClipboardItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            fetchRequest.fetchLimit = 1

            do {
                guard let item = try context.fetch(fetchRequest).first else {
                    return
                }

                success = copyItemToClipboard(item)
            } catch {
                success = false
            }
        }

        return success
    }

    private func copyItemToClipboard(_ item: ClipboardItem) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Copy based on content type
        if let contentData = item.content {
            // Try URL first
            if let urlString = contentData.urlString {
                pasteboard.setString(urlString, forType: .string)
                return true
            }

            // HTML content
            if let html = contentData.htmlContent {
                pasteboard.setString(html, forType: .html)
                if let plainText = item.plainTextPreview {
                    pasteboard.setString(plainText, forType: .string)
                }
                return true
            }

            // RTF content
            if let rtfData = contentData.rtfData {
                pasteboard.setData(rtfData, forType: .rtf)
                if let plainText = item.plainTextPreview {
                    pasteboard.setString(plainText, forType: .string)
                }
                return true
            }

            // Image content
            if let imageData = contentData.imageData,
               let image = NSImage(data: imageData)
            {
                pasteboard.writeObjects([image])
                return true
            }
        }

        // Fallback to plain text
        if let plainText = item.plainTextPreview {
            pasteboard.setString(plainText, forType: .string)
            return true
        }

        return false
    }
}

// MARK: - Copy Text Command

/// Handles the "copy text" AppleScript command
@objc(CopyTextCommand)
class CopyTextCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        // Get text from direct parameter
        guard let text = directParameter as? String else {
            scriptErrorNumber = errOSAGeneralError
            scriptErrorString = "Please provide text to copy."
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        return true
    }
}

// MARK: - Transform Text Command

/// Handles the "transform text" AppleScript command
@objc(TransformTextCommand)
class TransformTextCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        // Get text from direct parameter
        guard let text = directParameter as? String else {
            scriptErrorNumber = errOSAGeneralError
            scriptErrorString = "Please provide text to transform."
            return nil
        }

        // Get transformation type
        guard let transformationCode = evaluatedArguments?["transformation"] as? String,
              let preset = transformationCodeToPreset(transformationCode)
        else {
            scriptErrorNumber = errOSAGeneralError
            scriptErrorString = "Please specify a valid transformation type."
            return nil
        }

        return preset.transform(text)
    }

    private func transformationCodeToPreset(_ code: String) -> TransformPreset? {
        // Map AppleScript four-char codes to TransformPreset
        switch code {
        case "uppr", "uppercase": return .uppercase
        case "lowr", "lowercase": return .lowercase
        case "titl", "title case": return .titleCase
        case "sent", "sentence case": return .sentenceCase
        case "trim", "trim whitespace": return .trimWhitespace
        case "rmnl", "remove newlines": return .removeNewlines
        case "clsp", "collapse spaces": return .collapseSpaces
        case "srtl", "sort lines": return .sortLines
        case "unql", "unique lines": return .uniqueLines
        case "rvsl", "reverse lines": return .reverseLines
        case "b64e", "base64 encode": return .base64Encode
        case "b64d", "base64 decode": return .base64Decode
        case "urle", "url encode": return .urlEncode
        case "urld", "url decode": return .urlDecode
        case "fmtj", "format json": return .formatJSON
        case "minj", "minify json": return .minifyJSON
        case "esch", "escape html": return .escapeHTML
        case "unsh", "unescape html": return .unescapeHTML
        case "stph", "strip html": return .stripHTMLTags
        case "md5h", "md5 hash": return .md5Hash
        case "s256", "sha256 hash": return .sha256Hash
        default: return nil
        }
    }
}

// MARK: - Delete Item Command

/// Handles the "delete item" AppleScript command
@objc(DeleteItemCommand)
class DeleteItemCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        // Get the item from direct parameter
        guard let scriptable = directParameter as? ClipboardItemScriptable else {
            scriptErrorNumber = errOSAGeneralError
            scriptErrorString = "Please provide a clipboard item to delete."
            return false
        }

        guard let uuid = UUID(uuidString: scriptable.uniqueID) else {
            scriptErrorNumber = errOSAGeneralError
            scriptErrorString = "Invalid item identifier."
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
}

// MARK: - Clear History Command

/// Handles the "clear history" AppleScript command
@objc(ClearHistoryCommand)
class ClearHistoryCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        let keepFavorites = (evaluatedArguments?["keepFavorites"] as? Bool) ?? true

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
}

// MARK: - Show Window Command

/// Handles the "show window" AppleScript command
@objc(ShowWindowCommand)
class ShowWindowCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)

            // Try to show the main window
            if let window = NSApplication.shared.windows.first {
                window.makeKeyAndOrderFront(nil)
            }

            // Post notification for app to handle
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowMainWindow"),
                object: nil
            )
        }

        return nil
    }
}

// MARK: - Hide Window Command

/// Handles the "hide window" AppleScript command
@objc(HideWindowCommand)
class HideWindowCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        DispatchQueue.main.async {
            NSApplication.shared.hide(nil)
        }

        return nil
    }
}
