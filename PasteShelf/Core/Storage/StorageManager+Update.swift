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

    // MARK: - Folder Operations

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
