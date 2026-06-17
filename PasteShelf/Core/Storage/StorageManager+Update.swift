//
//  StorageManager+Update.swift
//  PasteShelf
//
//  Update operations for StorageManager.
//

import CoreData
import Foundation

extension StorageManager {
    // MARK: - Favorite Operations

    /// Toggles the favorite status of a clipboard item
    /// - Parameter item: The item to toggle
    /// - Returns: The new favorite status, or nil if update failed
    func toggleFavorite(item: ClipboardItem) async -> Bool? {
        guard let itemId = item.id else { return nil }
        return await toggleFavorite(itemId: itemId)
    }

    /// Toggles the favorite status of a clipboard item by ID
    /// - Parameter itemId: The UUID of the item to toggle
    /// - Returns: The new favorite status, or nil if update failed
    func toggleFavorite(itemId: UUID) async -> Bool? {
        return await performBackgroundTaskSafe { context -> Bool? in
            let request = ClipboardItem.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)
            request.fetchLimit = 1

            guard let itemInContext = try? context.fetch(request).first else {
                return nil
            }

            itemInContext.isFavorite.toggle()
            return itemInContext.isFavorite
        }
    }

    /// Sets the favorite status of a clipboard item
    /// - Parameters:
    ///   - item: The item to update
    ///   - isFavorite: The new favorite status
    /// - Returns: True if update succeeded
    func setFavorite(item: ClipboardItem, isFavorite: Bool) async -> Bool {
        guard let itemId = item.id else { return false }

        do {
            try await performBackgroundTask { context in
                let request = ClipboardItem.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)
                request.fetchLimit = 1

                if let itemInContext = try context.fetch(request).first {
                    itemInContext.isFavorite = isFavorite
                }
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Tag Operations

    /// Adds tags to a clipboard item
    /// - Parameters:
    ///   - tags: The tags to add
    ///   - item: The item to add tags to
    /// - Returns: True if update succeeded
    func addTags(_ tags: [Tag], to item: ClipboardItem) async -> Bool {
        guard let itemId = item.id else { return false }
        let tagIds = tags.compactMap(\.id)

        do {
            try await performBackgroundTask { context in
                let itemRequest = ClipboardItem.fetchRequest()
                itemRequest.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)
                itemRequest.fetchLimit = 1

                guard let itemInContext = try context.fetch(itemRequest).first else {
                    return
                }

                let tagRequest = Tag.fetchRequest()
                tagRequest.predicate = NSPredicate(format: "id IN %@", tagIds)

                let tagsInContext = try context.fetch(tagRequest)
                for tag in tagsInContext {
                    itemInContext.addToTags(tag)
                }
            }
            return true
        } catch {
            return false
        }
    }

    /// Removes a tag from a clipboard item
    /// - Parameters:
    ///   - tag: The tag to remove
    ///   - item: The item to remove the tag from
    /// - Returns: True if update succeeded
    func removeTag(_ tag: Tag, from item: ClipboardItem) async -> Bool {
        guard let itemId = item.id, let tagId = tag.id else { return false }

        do {
            try await performBackgroundTask { context in
                let itemRequest = ClipboardItem.fetchRequest()
                itemRequest.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)
                itemRequest.fetchLimit = 1

                guard let itemInContext = try context.fetch(itemRequest).first else {
                    return
                }

                let tagRequest = Tag.fetchRequest()
                tagRequest.predicate = NSPredicate(format: "id == %@", tagId as CVarArg)
                tagRequest.fetchLimit = 1

                if let tagInContext = try context.fetch(tagRequest).first {
                    itemInContext.removeFromTags(tagInContext)
                }
            }
            return true
        } catch {
            return false
        }
    }

    /// Replaces all tags on a clipboard item
    /// - Parameters:
    ///   - item: The item to update
    ///   - tags: The new tags
    /// - Returns: True if update succeeded
    func setTags(_ tags: [Tag], on item: ClipboardItem) async -> Bool {
        guard let itemId = item.id else { return false }
        let tagIds = tags.compactMap(\.id)

        do {
            try await performBackgroundTask { context in
                let itemRequest = ClipboardItem.fetchRequest()
                itemRequest.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)
                itemRequest.fetchLimit = 1

                guard let itemInContext = try context.fetch(itemRequest).first else {
                    return
                }

                // Remove all existing tags
                if let existingTags = itemInContext.tags {
                    itemInContext.removeFromTags(existingTags)
                }

                // Add new tags
                let tagRequest = Tag.fetchRequest()
                tagRequest.predicate = NSPredicate(format: "id IN %@", tagIds)

                let tagsInContext = try context.fetch(tagRequest)
                for tag in tagsInContext {
                    itemInContext.addToTags(tag)
                }
            }
            return true
        } catch {
            return false
        }
    }

    /// Toggles a tag on a clipboard item (adds if absent, removes if present)
    /// - Parameters:
    ///   - tagId: The tag's UUID
    ///   - itemId: The clipboard item's UUID
    /// - Returns: True if update succeeded
    func toggleTag(tagId: UUID, onItemId itemId: UUID) async -> Bool {
        do {
            try await performBackgroundTask { context in
                let itemRequest = ClipboardItem.fetchRequest()
                itemRequest.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)
                itemRequest.fetchLimit = 1

                guard let item = try context.fetch(itemRequest).first else { return }

                let tagRequest = Tag.fetchRequest()
                tagRequest.predicate = NSPredicate(format: "id == %@", tagId as CVarArg)
                tagRequest.fetchLimit = 1

                guard let tag = try context.fetch(tagRequest).first else { return }

                let currentTags = item.tags as? Set<Tag> ?? []
                if currentTags.contains(tag) {
                    item.removeFromTags(tag)
                } else {
                    item.addToTags(tag)
                }
            }
            return true
        } catch {
            return false
        }
    }

    /// Fetches the tag IDs assigned to a clipboard item
    /// - Parameter itemId: The clipboard item's UUID
    /// - Returns: Set of tag UUIDs
    func fetchTagIds(forItemId itemId: UUID) async -> Set<UUID> {
        await viewContext.perform {
            let request = ClipboardItem.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)
            request.fetchLimit = 1

            guard let item = try? self.viewContext.fetch(request).first,
                  let tags = item.tags as? Set<Tag>
            else { return [] }

            return Set(tags.compactMap(\.id))
        }
    }

    // MARK: - Tag Update

    /// Updates the name and color of a tag
    /// - Parameters:
    ///   - tagId: The UUID of the tag to update
    ///   - name: The new name (nil to keep unchanged)
    ///   - color: The new color hex string (nil to keep unchanged)
    /// - Returns: True if update succeeded
    func updateTag(id tagId: UUID, name: String? = nil, color: String? = nil) async -> Bool {
        do {
            try await performBackgroundTask { context in
                let request = Tag.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", tagId as CVarArg)
                request.fetchLimit = 1

                guard let tag = try context.fetch(request).first else {
                    return
                }

                if let name = name {
                    tag.name = name
                }
                if let color = color {
                    tag.color = color
                }
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Folder Operations

    /// Updates the name and icon of a folder
    /// - Parameters:
    ///   - folderId: The UUID of the folder to update
    ///   - name: The new name (nil to keep unchanged)
    ///   - icon: The new icon (nil to keep unchanged)
    /// - Returns: True if update succeeded
    func updateFolder(id folderId: UUID, name: String? = nil, icon: String? = nil) async -> Bool {
        do {
            try await performBackgroundTask { context in
                let request = Folder.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
                request.fetchLimit = 1

                guard let folder = try context.fetch(request).first else {
                    return
                }

                if let name = name {
                    folder.name = name
                }
                if let icon = icon {
                    folder.icon = icon
                }
            }
            return true
        } catch {
            return false
        }
    }

    /// Moves a clipboard item to a folder
    /// - Parameters:
    ///   - item: The item to move
    ///   - folder: The destination folder (nil to remove from folder)
    /// - Returns: True if update succeeded
    func moveItem(_ item: ClipboardItem, to folder: Folder?) async -> Bool {
        guard let itemId = item.id else { return false }

        do {
            try await performBackgroundTask { context in
                let itemRequest = ClipboardItem.fetchRequest()
                itemRequest.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)
                itemRequest.fetchLimit = 1

                guard let itemInContext = try context.fetch(itemRequest).first else {
                    return
                }

                if let folderId = folder?.id {
                    let folderRequest = Folder.fetchRequest()
                    folderRequest.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
                    folderRequest.fetchLimit = 1

                    itemInContext.folder = try context.fetch(folderRequest).first
                } else {
                    itemInContext.folder = nil
                }
            }
            return true
        } catch {
            return false
        }
    }

    /// Moves multiple clipboard items to a folder
    /// - Parameters:
    ///   - items: The items to move
    ///   - folder: The destination folder (nil to remove from folder)
    /// - Returns: Number of items moved
    func moveItems(_ items: [ClipboardItem], to folder: Folder?) async -> Int {
        let itemIds = items.compactMap(\.id)
        if itemIds.isEmpty { return 0 }

        let result = await performBackgroundTaskSafe { context -> Int in
            let itemRequest = ClipboardItem.fetchRequest()
            itemRequest.predicate = NSPredicate(format: "id IN %@", itemIds)

            guard let itemsInContext = try? context.fetch(itemRequest) else {
                return 0
            }

            var folderInContext: Folder?
            if let folderId = folder?.id {
                let folderRequest = Folder.fetchRequest()
                folderRequest.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
                folderRequest.fetchLimit = 1
                folderInContext = try? context.fetch(folderRequest).first
            }

            for item in itemsInContext {
                item.folder = folderInContext
            }

            return itemsInContext.count
        }

        return result ?? 0
    }

    // MARK: - Access Count

    /// Updates the plain text content of a clipboard item and optionally strips
    /// other text representations (used by DLP redaction and automation transforms).
    /// - Parameters:
    ///   - itemId: The UUID of the item to update
    ///   - text: The new plain text content
    ///   - stripOtherRepresentations: When `true`, clears HTML, URL, and RTF fields
    ///     so that sensitive data does not remain in alternate representations.
    /// - Returns: True if update succeeded
    @discardableResult
    func updatePlainText(itemId: UUID, text: String, stripOtherRepresentations: Bool = false) async -> Bool {
        do {
            try await performBackgroundTask { context in
                let request = ClipboardItem.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)
                request.fetchLimit = 1

                if let item = try context.fetch(request).first {
                    item.plainTextPreview = String(text.prefix(500))
                    item.content?.plainTextData = text

                    if stripOtherRepresentations {
                        item.content?.htmlContent = nil
                        item.content?.urlString = nil
                        item.content?.rtfData = nil
                    }
                }
            }
            return true
        } catch {
            return false
        }
    }

    /// Increments the access count of a clipboard item
    /// - Parameter item: The item to update
    /// - Returns: True if update succeeded
    func incrementAccessCount(for item: ClipboardItem) async -> Bool {
        guard let itemId = item.id else { return false }

        do {
            try await performBackgroundTask { context in
                let request = ClipboardItem.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)
                request.fetchLimit = 1

                if let itemInContext = try context.fetch(request).first {
                    itemInContext.accessCount += 1
                }
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Recency (Move to Top)

    /// Refreshes an item's timestamp so it sorts to the top of history.
    /// - Parameter id: The item's identifier
    /// - Returns: True if the item was found and updated
    func touchItem(byId id: UUID) async -> Bool {
        await touchItem(matching: NSPredicate(format: "id == %@", id as CVarArg))
    }

    /// Refreshes the timestamp of the item with the given content hash so it
    /// sorts to the top of history. Used when duplicate content is re-copied.
    ///
    /// When `sourceApp` is provided, the item's source app is also updated to
    /// reflect the app the content was most recently copied from (the row now
    /// presents as "just copied", so its source should match the latest copy).
    /// - Parameters:
    ///   - hash: The content hash to match
    ///   - sourceApp: The app the content was just copied from, or `nil` to leave it unchanged
    /// - Returns: True if an item was found and updated
    func touchItem(byHash hash: String, sourceApp: SourceApp? = nil) async -> Bool {
        await touchItem(matching: NSPredicate(format: "contentHash == %@", hash), sourceApp: sourceApp)
    }

    /// Shared implementation: refreshes `timestamp` (and `modifiedAt`) for the
    /// first item matching the predicate, optionally updating its source app.
    private func touchItem(matching predicate: NSPredicate, sourceApp: SourceApp? = nil) async -> Bool {
        do {
            return try await performBackgroundTask { context in
                let request = ClipboardItem.fetchRequest()
                request.predicate = predicate
                request.fetchLimit = 1

                guard let item = try context.fetch(request).first else { return false }
                // Favorites keep their place in history — re-using one should
                // not bump it to the top, since favorites are retrieved via the
                // Favorites filter, not by recency. Skip the timestamp (and
                // source-app) refresh entirely.
                if item.isFavorite { return false }
                let now = Date()
                item.timestamp = now
                item.modifiedAt = now
                if let sourceApp = sourceApp {
                    item.sourceAppBundleId = sourceApp.bundleId
                    item.sourceAppName = sourceApp.name
                }
                return true
            }
        } catch {
            return false
        }
    }

    // MARK: - Application Exclusion Update

    /// Updates the exclusion status of an application
    /// - Parameters:
    ///   - bundleId: The bundle identifier
    ///   - isExcluded: The new exclusion status
    /// - Returns: True if update succeeded
    func setApplicationExcluded(bundleId: String, isExcluded: Bool) async -> Bool {
        do {
            try await performBackgroundTask { context in
                let request = Application.fetchRequest()
                request.predicate = NSPredicate(format: "bundleId == %@", bundleId)
                request.fetchLimit = 1

                if let app = try context.fetch(request).first {
                    app.isExcluded = isExcluded
                }
            }
            return true
        } catch {
            return false
        }
    }
}
