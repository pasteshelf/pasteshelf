//
//  StorageManager+Fetch.swift
//  PasteShelf
//
//  Fetch operations for StorageManager.
//

import CoreData
import Foundation
import os.log

extension StorageManager {
    // MARK: - Clipboard Item Fetch

    /// Fetches recent clipboard items with pagination
    /// - Parameters:
    ///   - limit: Maximum number of items to return
    ///   - offset: Number of items to skip (for pagination)
    ///   - predicate: Optional predicate to filter results
    /// - Returns: Array of ClipboardItem objects
    func fetchRecentItems(
        limit: Int = 50,
        offset: Int = 0,
        predicate: NSPredicate? = nil
    ) async -> [ClipboardItem] {
        await viewContext.perform {
            let request = ClipboardItem.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.timestamp, ascending: false)]
            request.fetchLimit = limit
            request.fetchOffset = offset
            request.predicate = predicate

            do {
                return try self.viewContext.fetch(request)
            } catch {
                self.logger.error("Failed to fetch recent items: \(error.localizedDescription)")
                return []
            }
        }
    }

    /// Fetches clipboard items by content type
    /// - Parameters:
    ///   - contentType: The content type to filter by
    ///   - limit: Maximum number of items to return
    /// - Returns: Array of ClipboardItem objects
    func fetchItems(byContentType contentType: ContentType, limit: Int = 50) async -> [ClipboardItem] {
        let predicate = NSPredicate(format: "contentType == %@", contentType.rawValue)
        return await self.fetchRecentItems(limit: limit, predicate: predicate)
    }

    /// Fetches favorite clipboard items
    /// - Parameter limit: Maximum number of items to return
    /// - Returns: Array of favorite ClipboardItem objects
    func fetchFavorites(limit: Int = 50) async -> [ClipboardItem] {
        let predicate = NSPredicate(format: "isFavorite == YES")
        return await self.fetchRecentItems(limit: limit, predicate: predicate)
    }

    /// Fetches a clipboard item by ID
    /// - Parameter id: The UUID of the item
    /// - Returns: The ClipboardItem, or nil if not found
    func fetchItem(byId id: UUID) async -> ClipboardItem? {
        await viewContext.perform {
            let request = ClipboardItem.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            return try? self.viewContext.fetch(request).first
        }
    }

    /// Fetches a clipboard item by content hash
    /// - Parameter hash: The SHA256 content hash
    /// - Returns: The ClipboardItem, or nil if not found
    func fetchItem(byHash hash: String) async -> ClipboardItem? {
        await viewContext.perform {
            let request = ClipboardItem.fetchRequest()
            request.predicate = NSPredicate(format: "contentHash == %@", hash)
            request.fetchLimit = 1

            return try? self.viewContext.fetch(request).first
        }
    }

    /// Checks if a clipboard item with the given hash exists
    /// - Parameter hash: The SHA256 content hash
    /// - Returns: True if an item with this hash exists
    func itemExists(withHash hash: String) async -> Bool {
        let context = newBackgroundContext()

        return await context.perform {
            let request = ClipboardItem.fetchRequest()
            request.predicate = NSPredicate(format: "contentHash == %@", hash)
            request.fetchLimit = 1

            let count = (try? context.count(for: request)) ?? 0
            return count > 0
        }
    }

    // MARK: - Tag Fetch

    /// Fetches all tags
    /// - Returns: Array of Tag objects
    func fetchTags() async -> [Tag] {
        await viewContext.perform {
            let request = Tag.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]

            do {
                return try self.viewContext.fetch(request)
            } catch {
                self.logger.error("Failed to fetch tags: \(error.localizedDescription)")
                return []
            }
        }
    }

    /// Fetches a tag by name
    /// - Parameter name: The tag name
    /// - Returns: The Tag, or nil if not found
    func fetchTag(byName name: String) async -> Tag? {
        await viewContext.perform {
            let request = Tag.fetchRequest()
            request.predicate = NSPredicate(format: "name == %@", name)
            request.fetchLimit = 1

            return try? self.viewContext.fetch(request).first
        }
    }

    // MARK: - Folder Fetch

    /// Fetches all top-level folders (no parent)
    /// - Returns: Array of root Folder objects
    func fetchFolders() async -> [Folder] {
        await viewContext.perform {
            let request = Folder.fetchRequest()
            request.predicate = NSPredicate(format: "parentFolder == nil")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.sortOrder, ascending: true)]

            do {
                return try self.viewContext.fetch(request)
            } catch {
                self.logger.error("Failed to fetch folders: \(error.localizedDescription)")
                return []
            }
        }
    }

    /// Fetches a folder by ID
    /// - Parameter id: The UUID of the folder
    /// - Returns: The Folder, or nil if not found
    func fetchFolder(byId id: UUID) async -> Folder? {
        await viewContext.perform {
            let request = Folder.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            return try? self.viewContext.fetch(request).first
        }
    }

    /// Fetches items in a specific folder
    /// - Parameters:
    ///   - folder: The folder to fetch items from
    ///   - limit: Maximum number of items to return
    /// - Returns: Array of ClipboardItem objects
    func fetchItems(inFolder folder: Folder, limit: Int = 50) async -> [ClipboardItem] {
        guard let folderId = folder.id else {
            return []
        }

        let predicate = NSPredicate(format: "folder.id == %@", folderId as CVarArg)
        return await self.fetchRecentItems(limit: limit, predicate: predicate)
    }

    // MARK: - Application Fetch

    /// Fetches all excluded applications
    /// - Returns: Array of Application objects that are excluded
    func fetchExcludedApplications() async -> [Application] {
        await viewContext.perform {
            let request = Application.fetchRequest()
            request.predicate = NSPredicate(format: "isExcluded == YES")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Application.name, ascending: true)]

            do {
                return try self.viewContext.fetch(request)
            } catch {
                self.logger.error("Failed to fetch excluded apps: \(error.localizedDescription)")
                return []
            }
        }
    }

    /// Fetches an application by bundle ID
    /// - Parameter bundleId: The bundle identifier
    /// - Returns: The Application, or nil if not found
    func fetchApplication(byBundleId bundleId: String) async -> Application? {
        await viewContext.perform {
            let request = Application.fetchRequest()
            request.predicate = NSPredicate(format: "bundleId == %@", bundleId)
            request.fetchLimit = 1

            return try? self.viewContext.fetch(request).first
        }
    }

    /// Checks if an application is excluded
    /// - Parameter bundleId: The bundle identifier
    /// - Returns: True if the application is excluded
    func isApplicationExcluded(bundleId: String) async -> Bool {
        let context = newBackgroundContext()

        return await context.perform {
            let request = Application.fetchRequest()
            request.predicate = NSPredicate(format: "bundleId == %@ AND isExcluded == YES", bundleId)
            request.fetchLimit = 1

            let count = (try? context.count(for: request)) ?? 0
            return count > 0
        }
    }

    // MARK: - Statistics

    /// Returns the total count of clipboard items
    /// - Returns: Total number of items
    func totalItemCount() async -> Int {
        await viewContext.perform {
            let request = ClipboardItem.fetchRequest()
            return (try? self.viewContext.count(for: request)) ?? 0
        }
    }

    /// Returns the count of items by content type
    /// - Parameter contentType: The content type to count
    /// - Returns: Number of items with this content type
    func itemCount(byContentType contentType: ContentType) async -> Int {
        await viewContext.perform {
            let request = ClipboardItem.fetchRequest()
            request.predicate = NSPredicate(format: "contentType == %@", contentType.rawValue)
            return (try? self.viewContext.count(for: request)) ?? 0
        }
    }
}
