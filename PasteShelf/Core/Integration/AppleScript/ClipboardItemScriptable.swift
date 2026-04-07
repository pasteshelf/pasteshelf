//
//  ClipboardItemScriptable.swift
//  PasteShelf
//
//  Scriptable wrapper for ClipboardItem for AppleScript integration.
//  Exposes clipboard items as scriptable objects.
//

import AppKit
import CoreData
import Foundation

// MARK: - ClipboardItemScriptable

/// Scriptable wrapper for ClipboardItem that provides AppleScript access
@MainActor
@objc(ClipboardItemScriptable)
class ClipboardItemScriptable: NSObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(item: ClipboardItem) {
        self.item = item
        self.itemID = item.id
        super.init()
    }

    init(id: UUID) {
        self.itemID = id
        super.init()
    }

    // MARK: Internal

    // MARK: - Object Specifier

    override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let uniqueID = itemID?.uuidString else {
            return nil
        }

        guard let appDescription = NSApplication.shared.classDescription as? NSScriptClassDescription
            ?? NSScriptClassDescription(for: NSApplication.self)
        else {
            return nil
        }

        return NSUniqueIDSpecifier(
            containerClassDescription: appDescription,
            containerSpecifier: nil,
            key: "clipboardItems",
            uniqueID: uniqueID
        )
    }

    // MARK: - Scriptable Properties

    /// Unique identifier as a string
    @objc var uniqueID: String {
        self.itemID?.uuidString ?? ""
    }

    /// Text content of the item
    @objc var textContent: String {
        guard let item = loadItem() else {
            return ""
        }
        return item.plainTextPreview ?? ""
    }

    /// Content type display name
    @objc var contentType: String {
        guard let item = loadItem(),
              let typeString = item.contentType,
              let type = ContentType(rawValue: typeString)
        else {
            return "Unknown"
        }
        return type.displayName
    }

    /// Source application name
    @objc var sourceApplication: String {
        guard let item = loadItem() else {
            return ""
        }
        return item.sourceAppName ?? ""
    }

    /// Capture date
    @objc var captureDate: Date {
        guard let item = loadItem() else {
            return Date()
        }
        return item.timestamp ?? Date()
    }

    /// Whether item is a favorite
    @objc var isFavorite: Bool {
        get {
            guard let item = loadItem() else {
                return false
            }
            return item.isFavorite
        }
        set {
            guard let item = loadItem() else {
                return
            }
            let context = StorageManager.shared.viewContext
            context.perform {
                item.isFavorite = newValue
                try? context.save()
            }
        }
    }

    /// Whether item is sensitive
    @objc var isSensitive: Bool {
        guard let item = loadItem() else {
            return false
        }
        return item.isSensitive
    }

    /// Preview text
    @objc var previewText: String {
        guard let item = loadItem() else {
            return ""
        }

        if let preview = item.plainTextPreview {
            let firstLine = preview.components(separatedBy: .newlines).first ?? preview
            if firstLine.count > 100 {
                return String(firstLine.prefix(100)) + "..."
            }
            return firstLine
        }

        return self.contentType
    }

    // MARK: Private

    private var item: ClipboardItem?
    private var itemID: UUID?

    // MARK: - Lazy Loading

    private func loadItem() -> ClipboardItem? {
        if let item {
            return item
        }

        guard let id = itemID else {
            return nil
        }

        let context = StorageManager.shared.viewContext
        let fetchRequest = ClipboardItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            item = try context.fetch(fetchRequest).first
            return item
        } catch {
            return nil
        }
    }
}

// MARK: - NSApplication Extension for Scripting

extension NSApplication {
    /// Clipboard items for AppleScript access
    @objc var clipboardItems: [ClipboardItemScriptable] {
        let context = StorageManager.shared.viewContext
        var results: [ClipboardItemScriptable] = []

        context.performAndWait {
            let fetchRequest = ClipboardItem.fetchRequest()
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \ClipboardItem.timestamp, ascending: false),
            ]
            fetchRequest.fetchLimit = 100

            do {
                let items = try context.fetch(fetchRequest)
                results = items.map { ClipboardItemScriptable(item: $0) }
            } catch {
                results = []
            }
        }

        return results
    }

    /// Get a clipboard item by unique ID
    @objc
    func clipboardItem(withUniqueID uniqueID: String) -> ClipboardItemScriptable? {
        guard let uuid = UUID(uuidString: uniqueID) else {
            return nil
        }

        let context = StorageManager.shared.viewContext
        var result: ClipboardItemScriptable?

        context.performAndWait {
            let fetchRequest = ClipboardItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            fetchRequest.fetchLimit = 1

            do {
                if let item = try context.fetch(fetchRequest).first {
                    result = ClipboardItemScriptable(item: item)
                }
            } catch {
                result = nil
            }
        }

        return result
    }
}
