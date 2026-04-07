//
//  StorageManager+Collections.swift
//  PasteShelf
//
//  CRUD operations for Smart Collections.
//

import CoreData
import Foundation
import os.log

extension StorageManager {
    // MARK: - Collection Save Operations

    /// Saves a new smart collection
    /// - Parameters:
    ///   - name: Collection name
    ///   - icon: SF Symbol icon name
    ///   - colorHex: Optional color hex string
    ///   - isAutomatic: Whether this is an automatic (rule-based) collection
    ///   - rules: Optional collection rules (for automatic collections)
    /// - Returns: The created SmartCollection, or nil if save failed
    func saveCollection(
        name: String,
        icon: String,
        colorHex: String? = nil,
        isAutomatic: Bool = true,
        rules: CollectionRules? = nil
    ) async -> SmartCollection? {
        await performBackgroundTaskSafe { context in
            let collection = SmartCollection(context: context)
            collection.id = UUID()
            collection.name = name
            collection.icon = icon
            collection.colorHex = colorHex
            collection.isAutomatic = isAutomatic
            collection.rulesJSON = rules?.toJSON()
            collection.sortOrder = 0
            collection.createdAt = Date()
            collection.modifiedAt = Date()
            return collection
        }
    }

    /// Saves a collection from a display model
    /// - Parameter model: The collection display model
    /// - Returns: The created SmartCollection, or nil if save failed
    func saveCollection(from model: CollectionDisplayModel) async -> SmartCollection? {
        await performBackgroundTaskSafe { context in
            let collection = SmartCollection(context: context)
            collection.id = model.id
            collection.name = model.name
            collection.icon = model.icon
            collection.colorHex = model.colorHex
            collection.isAutomatic = model.isAutomatic
            collection.rulesJSON = model.rules?.toJSON()
            collection.sortOrder = model.sortOrder
            collection.createdAt = Date()
            collection.modifiedAt = Date()
            return collection
        }
    }

    // MARK: - Collection Fetch Operations

    /// Fetches all collections ordered by sortOrder
    /// - Returns: Array of SmartCollection objects
    func fetchCollections() async -> [SmartCollection] {
        await viewContext.perform {
            let request = SmartCollection.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \SmartCollection.sortOrder, ascending: true),
                NSSortDescriptor(keyPath: \SmartCollection.name, ascending: true),
            ]

            do {
                return try self.viewContext.fetch(request)
            } catch {
                return []
            }
        }
    }

    /// Fetches a collection by ID
    /// - Parameter id: The UUID of the collection
    /// - Returns: The SmartCollection, or nil if not found
    func fetchCollection(byId id: UUID) async -> SmartCollection? {
        await viewContext.perform {
            let request = SmartCollection.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            return try? self.viewContext.fetch(request).first
        }
    }

    /// Fetches a collection by name
    /// - Parameter name: The collection name
    /// - Returns: The SmartCollection, or nil if not found
    func fetchCollection(byName name: String) async -> SmartCollection? {
        await viewContext.perform {
            let request = SmartCollection.fetchRequest()
            request.predicate = NSPredicate(format: "name == %@", name)
            request.fetchLimit = 1

            return try? self.viewContext.fetch(request).first
        }
    }

    // MARK: - Collection Update Operations

    /// Updates a collection's properties
    /// - Parameters:
    ///   - id: The collection ID
    ///   - name: Optional new name
    ///   - icon: Optional new icon
    ///   - colorHex: Optional new color
    ///   - rules: Optional new rules
    /// - Returns: True if update succeeded
    func updateCollection(
        _ id: UUID,
        name: String? = nil,
        icon: String? = nil,
        colorHex: String? = nil,
        rules: CollectionRules? = nil
    ) async -> Bool {
        do {
            try await performBackgroundTask { context in
                let request = SmartCollection.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                request.fetchLimit = 1

                guard let collection = try context.fetch(request).first else {
                    throw NSError(domain: "StorageManager", code: 404, userInfo: nil)
                }

                if let name {
                    collection.name = name
                }
                if let icon {
                    collection.icon = icon
                }
                if let colorHex {
                    collection.colorHex = colorHex
                }
                if let rules {
                    collection.rulesJSON = rules.toJSON()
                }
                collection.modifiedAt = Date()
            }
            return true
        } catch {
            return false
        }
    }

    /// Updates a collection's rules
    /// - Parameters:
    ///   - id: The collection ID
    ///   - rules: The new collection rules
    /// - Returns: True if update succeeded
    func updateCollectionRules(_ id: UUID, rules: CollectionRules) async -> Bool {
        await self.updateCollection(id, rules: rules)
    }

    /// Updates a collection's sort order
    /// - Parameters:
    ///   - id: The collection ID
    ///   - sortOrder: The new sort order
    /// - Returns: True if update succeeded
    func updateCollectionSortOrder(_ id: UUID, sortOrder: Int32) async -> Bool {
        do {
            try await performBackgroundTask { context in
                let request = SmartCollection.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                request.fetchLimit = 1

                guard let collection = try context.fetch(request).first else {
                    throw NSError(domain: "StorageManager", code: 404, userInfo: nil)
                }

                collection.sortOrder = sortOrder
                collection.modifiedAt = Date()
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Collection Delete Operations

    /// Deletes a collection
    /// - Parameter id: The collection ID
    /// - Returns: True if deletion succeeded
    func deleteCollection(_ id: UUID) async -> Bool {
        do {
            try await performBackgroundTask { context in
                let request = SmartCollection.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                request.fetchLimit = 1

                guard let collection = try context.fetch(request).first else {
                    throw NSError(domain: "StorageManager", code: 404, userInfo: nil)
                }

                context.delete(collection)
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Collection Items Operations

    /// Fetches items for an automatic collection using its rules
    /// - Parameters:
    ///   - collection: The smart collection
    ///   - limit: Maximum number of items to return
    /// - Returns: Array of ClipboardItem objects matching the rules
    func fetchItemsForCollection(_ collection: SmartCollection, limit: Int = 50) async -> [ClipboardItem] {
        if collection.isAutomatic {
            // Use rules to build predicate
            guard let rulesJSON = collection.rulesJSON,
                  let rules = CollectionRules.fromJSON(rulesJSON)
            else {
                return []
            }

            let predicate = RuleEvaluator.shared.buildPredicate(from: rules)
            return await fetchRecentItems(limit: limit, predicate: predicate)
        } else {
            // Manual collection - fetch directly related items
            return await self.fetchItemsInManualCollection(collection, limit: limit)
        }
    }

    /// Fetches items directly associated with a manual collection
    private func fetchItemsInManualCollection(
        _ collection: SmartCollection,
        limit: Int
    ) async -> [ClipboardItem] {
        guard let collectionId = collection.id else {
            return []
        }

        return await viewContext.perform {
            let request = ClipboardItem.fetchRequest()
            request.predicate = NSPredicate(format: "ANY collections.id == %@", collectionId as CVarArg)
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \ClipboardItem.timestamp, ascending: false),
            ]
            request.fetchLimit = limit

            do {
                return try self.viewContext.fetch(request)
            } catch {
                return []
            }
        }
    }

    /// Fetches the count of items for a collection
    /// - Parameter collection: The smart collection
    /// - Returns: Number of items matching the collection
    func itemCountForCollection(_ collection: SmartCollection) async -> Int {
        if collection.isAutomatic {
            guard let rulesJSON = collection.rulesJSON,
                  let rules = CollectionRules.fromJSON(rulesJSON)
            else {
                return 0
            }

            let predicate = RuleEvaluator.shared.buildPredicate(from: rules)
            return await viewContext.perform {
                let request = ClipboardItem.fetchRequest()
                request.predicate = predicate
                return (try? self.viewContext.count(for: request)) ?? 0
            }
        } else {
            guard let collectionId = collection.id else {
                return 0
            }

            return await viewContext.perform {
                let request = ClipboardItem.fetchRequest()
                request.predicate = NSPredicate(format: "ANY collections.id == %@", collectionId as CVarArg)
                return (try? self.viewContext.count(for: request)) ?? 0
            }
        }
    }

    /// Adds an item to a manual collection
    /// - Parameters:
    ///   - item: The clipboard item to add
    ///   - collection: The manual collection
    /// - Returns: True if addition succeeded
    func addItemToCollection(_ item: ClipboardItem, collection: SmartCollection) async -> Bool {
        guard !collection.isAutomatic,
              let itemId = item.id,
              let collectionId = collection.id
        else {
            return false
        }

        do {
            try await performBackgroundTask { context in
                let itemRequest = ClipboardItem.fetchRequest()
                itemRequest.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)
                itemRequest.fetchLimit = 1

                let collectionRequest = SmartCollection.fetchRequest()
                collectionRequest.predicate = NSPredicate(format: "id == %@", collectionId as CVarArg)
                collectionRequest.fetchLimit = 1

                guard let itemInContext = try context.fetch(itemRequest).first,
                      let collectionInContext = try context.fetch(collectionRequest).first
                else {
                    throw NSError(domain: "StorageManager", code: 404, userInfo: nil)
                }

                itemInContext.addToCollections(collectionInContext)
                collectionInContext.modifiedAt = Date()
            }
            return true
        } catch {
            return false
        }
    }

    /// Removes an item from a manual collection
    /// - Parameters:
    ///   - item: The clipboard item to remove
    ///   - collection: The manual collection
    /// - Returns: True if removal succeeded
    func removeItemFromCollection(_ item: ClipboardItem, collection: SmartCollection) async -> Bool {
        guard !collection.isAutomatic,
              let itemId = item.id,
              let collectionId = collection.id
        else {
            return false
        }

        do {
            try await performBackgroundTask { context in
                let itemRequest = ClipboardItem.fetchRequest()
                itemRequest.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)
                itemRequest.fetchLimit = 1

                let collectionRequest = SmartCollection.fetchRequest()
                collectionRequest.predicate = NSPredicate(format: "id == %@", collectionId as CVarArg)
                collectionRequest.fetchLimit = 1

                guard let itemInContext = try context.fetch(itemRequest).first,
                      let collectionInContext = try context.fetch(collectionRequest).first
                else {
                    throw NSError(domain: "StorageManager", code: 404, userInfo: nil)
                }

                itemInContext.removeFromCollections(collectionInContext)
                collectionInContext.modifiedAt = Date()
            }
            return true
        } catch {
            return false
        }
    }

    /// Checks if an item is in a collection
    /// - Parameters:
    ///   - item: The clipboard item
    ///   - collection: The smart collection
    /// - Returns: True if item is in the collection
    func isItemInCollection(_ item: ClipboardItem, collection: SmartCollection) async -> Bool {
        guard let itemId = item.id, let collectionId = collection.id else {
            return false
        }

        if collection.isAutomatic {
            // Check using rules
            guard let rulesJSON = collection.rulesJSON,
                  let rules = CollectionRules.fromJSON(rulesJSON)
            else {
                return false
            }
            return RuleEvaluator.shared.evaluate(item: item, against: rules)
        } else {
            // Check direct relationship
            return await viewContext.perform {
                let request = ClipboardItem.fetchRequest()
                request.predicate = NSPredicate(
                    format: "id == %@ AND ANY collections.id == %@",
                    itemId as CVarArg,
                    collectionId as CVarArg
                )
                request.fetchLimit = 1
                return ((try? self.viewContext.count(for: request)) ?? 0) > 0
            }
        }
    }
}
