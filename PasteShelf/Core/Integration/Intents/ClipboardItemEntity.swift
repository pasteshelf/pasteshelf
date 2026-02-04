//
//  ClipboardItemEntity.swift
//  PasteShelf
//
//  App Intents entity for Shortcuts integration.
//  Represents clipboard items in the Shortcuts app.
//

import AppIntents
import CoreData
import Foundation

/// App Intents entity representing a clipboard item
@available(macOS 13.0, *)
struct ClipboardItemEntity: AppEntity, Identifiable {
    // MARK: - Properties

    /// Unique identifier
    var id: UUID

    /// Display title for the item
    var displayTitle: String

    /// Content type display name
    var contentType: String

    /// Source application name
    var sourceApp: String?

    /// Capture timestamp
    var timestamp: Date

    /// Whether the item is a favorite
    var isFavorite: Bool

    /// Whether the item is sensitive
    var isSensitive: Bool

    /// Plain text preview (truncated)
    var preview: String?

    // MARK: - AppEntity Conformance

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource("Clipboard Item"),
            numericFormat: LocalizedStringResource("\(placeholder: .int) clipboard items")
        )
    }

    var displayRepresentation: DisplayRepresentation {
        let subtitle: String
        if let sourceApp = sourceApp {
            subtitle = "\(contentType) from \(sourceApp)"
        } else {
            subtitle = contentType
        }

        return DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: displayTitle),
            subtitle: LocalizedStringResource(stringLiteral: subtitle),
            image: .init(systemName: iconName)
        )
    }

    static var defaultQuery = ClipboardItemQuery()

    // MARK: - Computed Properties

    /// SF Symbol icon based on content type
    var iconName: String {
        switch contentType.lowercased() {
        case "text", "plain text":
            return "doc.text"
        case "rich text", "rtf":
            return "doc.richtext"
        case "html":
            return "chevron.left.forwardslash.chevron.right"
        case "image", "png", "jpeg", "tiff":
            return "photo"
        case "url", "link":
            return "link"
        case "file", "files":
            return "folder"
        case "pdf":
            return "doc.text.fill"
        default:
            return "doc"
        }
    }

    // MARK: - Initialization

    init(
        id: UUID,
        displayTitle: String,
        contentType: String,
        sourceApp: String? = nil,
        timestamp: Date = Date(),
        isFavorite: Bool = false,
        isSensitive: Bool = false,
        preview: String? = nil
    ) {
        self.id = id
        self.displayTitle = displayTitle
        self.contentType = contentType
        self.sourceApp = sourceApp
        self.timestamp = timestamp
        self.isFavorite = isFavorite
        self.isSensitive = isSensitive
        self.preview = preview
    }

    /// Creates an entity from a CoreData ClipboardItem
    init(from item: ClipboardItem) {
        self.id = item.id ?? UUID()
        self.displayTitle = Self.generateTitle(from: item)
        self.contentType = ContentType(rawValue: item.contentType ?? "")?.displayName ?? "Unknown"
        self.sourceApp = item.sourceAppName
        self.timestamp = item.timestamp ?? Date()
        self.isFavorite = item.isFavorite
        self.isSensitive = item.isSensitive
        self.preview = item.plainTextPreview
    }

    // MARK: - Helpers

    private static func generateTitle(from item: ClipboardItem) -> String {
        if let preview = item.plainTextPreview, !preview.isEmpty {
            // Use first line or first 50 chars
            let firstLine = preview.components(separatedBy: .newlines).first ?? preview
            if firstLine.count > 50 {
                return String(firstLine.prefix(50)) + "..."
            }
            return firstLine
        }

        // Fallback to content type
        if let contentType = item.contentType,
           let type = ContentType(rawValue: contentType)
        {
            return type.displayName
        }

        return "Clipboard Item"
    }
}

// MARK: - Entity Query

/// Query for fetching clipboard items
@available(macOS 13.0, *)
struct ClipboardItemQuery: EntityQuery {
    // MARK: - EntityQuery Conformance

    /// Fetches entities by their identifiers
    func entities(for identifiers: [UUID]) async throws -> [ClipboardItemEntity] {
        let storageManager = await StorageManager.shared
        let context = await storageManager.viewContext

        return await context.perform {
            let fetchRequest = ClipboardItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id IN %@", identifiers)

            do {
                let items = try context.fetch(fetchRequest)
                return items.map { ClipboardItemEntity(from: $0) }
            } catch {
                return []
            }
        }
    }

    /// Fetches suggested entities for the user
    func suggestedEntities() async throws -> [ClipboardItemEntity] {
        let storageManager = await StorageManager.shared
        let context = await storageManager.viewContext

        return await context.perform {
            let fetchRequest = ClipboardItem.fetchRequest()
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \ClipboardItem.timestamp, ascending: false)
            ]
            fetchRequest.fetchLimit = 10

            do {
                let items = try context.fetch(fetchRequest)
                return items.map { ClipboardItemEntity(from: $0) }
            } catch {
                return []
            }
        }
    }
}

// MARK: - Extended Query

/// Extended query with search and filter support
@available(macOS 13.0, *)
extension ClipboardItemQuery: EntityStringQuery {
    /// Searches entities matching the given string
    func entities(matching string: String) async throws -> [ClipboardItemEntity] {
        let storageManager = await StorageManager.shared
        let context = await storageManager.viewContext

        return await context.perform {
            let fetchRequest = ClipboardItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "plainTextPreview CONTAINS[cd] %@",
                string
            )
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \ClipboardItem.timestamp, ascending: false)
            ]
            fetchRequest.fetchLimit = 20

            do {
                let items = try context.fetch(fetchRequest)
                return items.map { ClipboardItemEntity(from: $0) }
            } catch {
                return []
            }
        }
    }
}

// MARK: - Fetch Helpers

@available(macOS 13.0, *)
extension ClipboardItemEntity {
    /// Fetches recent clipboard items
    static func fetchRecent(limit: Int = 10) async -> [ClipboardItemEntity] {
        let context = await MainActor.run { StorageManager.shared.viewContext }

        return await context.perform {
            let fetchRequest = ClipboardItem.fetchRequest()
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \ClipboardItem.timestamp, ascending: false)
            ]
            fetchRequest.fetchLimit = limit

            do {
                let items = try context.fetch(fetchRequest)
                return items.map { ClipboardItemEntity(from: $0) }
            } catch {
                return []
            }
        }
    }

    /// Fetches favorite clipboard items
    static func fetchFavorites(limit: Int = 20) async -> [ClipboardItemEntity] {
        let context = await MainActor.run { StorageManager.shared.viewContext }

        return await context.perform {
            let fetchRequest = ClipboardItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "isFavorite == YES")
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \ClipboardItem.timestamp, ascending: false)
            ]
            fetchRequest.fetchLimit = limit

            do {
                let items = try context.fetch(fetchRequest)
                return items.map { ClipboardItemEntity(from: $0) }
            } catch {
                return []
            }
        }
    }

    /// Searches clipboard items by query
    static func search(query: String, limit: Int = 20) async -> [ClipboardItemEntity] {
        let context = await MainActor.run { StorageManager.shared.viewContext }

        return await context.perform {
            let fetchRequest = ClipboardItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "plainTextPreview CONTAINS[cd] %@",
                query
            )
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \ClipboardItem.timestamp, ascending: false)
            ]
            fetchRequest.fetchLimit = limit

            do {
                let items = try context.fetch(fetchRequest)
                return items.map { ClipboardItemEntity(from: $0) }
            } catch {
                return []
            }
        }
    }

    /// Fetches a single item by ID
    static func fetch(id: UUID) async -> ClipboardItemEntity? {
        let context = await MainActor.run { StorageManager.shared.viewContext }

        return await context.perform {
            let fetchRequest = ClipboardItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            do {
                if let item = try context.fetch(fetchRequest).first {
                    return ClipboardItemEntity(from: item)
                }
                return nil
            } catch {
                return nil
            }
        }
    }
}
