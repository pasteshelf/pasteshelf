//
//  StorageManager+Delete.swift
//  PasteShelf
//
//  Delete operations for StorageManager.
//

import CoreData
import Foundation
import os.log

extension StorageManager {
    // MARK: - Clipboard Item Deletion

    /// Deletes a single clipboard item
    /// - Parameter item: The item to delete
    /// - Returns: True if deletion succeeded
    func delete(item: ClipboardItem) async -> Bool {
        guard let itemId = item.id else { return false }

        do {
            try await performBackgroundTask { context in
                let request = ClipboardItem.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)
                request.fetchLimit = 1

                if let itemInContext = try context.fetch(request).first {
                    context.delete(itemInContext)
                }
            }
            return true
        } catch {
            return false
        }
    }

    /// Deletes a clipboard item by ID
    /// - Parameter id: The UUID of the item to delete
    /// - Returns: True if deletion succeeded
    func deleteItem(byId id: UUID) async -> Bool {
        do {
            try await performBackgroundTask { context in
                let request = ClipboardItem.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                request.fetchLimit = 1

                if let item = try context.fetch(request).first {
                    context.delete(item)
                }
            }
            return true
        } catch {
            return false
        }
    }

    /// Deletes items older than a specified date
    /// - Parameters:
    ///   - date: Delete items older than this date
    ///   - keepFavorites: If true, favorite items are preserved
    /// - Returns: Number of items deleted
    func deleteItems(olderThan date: Date, keepFavorites: Bool = true) async -> Int {
        let context = newBackgroundContext()

        return await context.perform {
            let request = ClipboardItem.fetchRequest()

            var predicates: [NSPredicate] = [
                NSPredicate(format: "timestamp < %@", date as NSDate)
            ]

            if keepFavorites {
                predicates.append(NSPredicate(format: "isFavorite == NO"))
            }

            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

            do {
                let items = try context.fetch(request)
                let count = items.count

                for item in items {
                    context.delete(item)
                }

                try context.save()
                return count
            } catch {
                return 0
            }
        }
    }

    /// Deletes all clipboard items (for clearing history)
    /// - Parameter keepFavorites: If true, favorite items are preserved
    /// - Returns: Number of items deleted
    func deleteAllItems(keepFavorites: Bool = true) async -> Int {
        let context = newBackgroundContext()

        return await context.perform {
            let request = ClipboardItem.fetchRequest()

            if keepFavorites {
                request.predicate = NSPredicate(format: "isFavorite == NO")
            }

            do {
                let items = try context.fetch(request)
                let count = items.count

                for item in items {
                    context.delete(item)
                }

                try context.save()
                return count
            } catch {
                return 0
            }
        }
    }

    /// Deletes items exceeding a limit (oldest first)
    /// - Parameters:
    ///   - limit: Maximum number of items to keep
    ///   - keepFavorites: If true, favorite items don't count toward limit
    /// - Returns: Number of items deleted
    func deleteItemsExceedingLimit(_ limit: Int, keepFavorites: Bool = true) async -> Int {
        let context = newBackgroundContext()

        return await context.perform {
            let request = ClipboardItem.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.timestamp, ascending: false)]

            if keepFavorites {
                request.predicate = NSPredicate(format: "isFavorite == NO")
            }

            do {
                let items = try context.fetch(request)

                if items.count <= limit {
                    return 0
                }

                let itemsToDelete = Array(items.dropFirst(limit))
                let count = itemsToDelete.count

                for item in itemsToDelete {
                    context.delete(item)
                }

                try context.save()
                return count
            } catch {
                return 0
            }
        }
    }

    // MARK: - Tag Deletion

    /// Deletes a tag
    /// - Parameter tag: The tag to delete
    /// - Returns: True if deletion succeeded
    func delete(tag: Tag) async -> Bool {
        guard let tagId = tag.id else { return false }

        do {
            try await performBackgroundTask { context in
                let request = Tag.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", tagId as CVarArg)
                request.fetchLimit = 1

                if let tagInContext = try context.fetch(request).first {
                    context.delete(tagInContext)
                }
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Folder Deletion

    /// Deletes a folder (items are moved to no folder)
    /// - Parameter folder: The folder to delete
    /// - Returns: True if deletion succeeded
    func delete(folder: Folder) async -> Bool {
        guard let folderId = folder.id else { return false }

        do {
            try await performBackgroundTask { context in
                let request = Folder.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
                request.fetchLimit = 1

                if let folderInContext = try context.fetch(request).first {
                    // Move items to no folder
                    if let items = folderInContext.items as? Set<ClipboardItem> {
                        for item in items {
                            item.folder = nil
                        }
                    }

                    // Move subfolders to parent (or no parent)
                    if let subfolders = folderInContext.subfolders as? Set<Folder> {
                        for subfolder in subfolders {
                            subfolder.parentFolder = folderInContext.parentFolder
                        }
                    }

                    context.delete(folderInContext)
                }
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Application Deletion

    /// Deletes an application record
    /// - Parameter bundleId: The bundle identifier of the application
    /// - Returns: True if deletion succeeded
    func deleteApplication(bundleId: String) async -> Bool {
        do {
            try await performBackgroundTask { context in
                let request = Application.fetchRequest()
                request.predicate = NSPredicate(format: "bundleId == %@", bundleId)
                request.fetchLimit = 1

                if let app = try context.fetch(request).first {
                    context.delete(app)
                }
            }
            return true
        } catch {
            return false
        }
    }
}
