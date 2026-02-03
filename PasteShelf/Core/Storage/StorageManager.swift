//
//  StorageManager.swift
//  PasteShelf
//
//  Core storage manager for clipboard item persistence.
//  Provides thread-safe access to CoreData with background write support.
//

import CoreData
import Foundation
import os.log

/// Manages CoreData persistence for clipboard items
@MainActor
final class StorageManager: ObservableObject {
    // MARK: - Singleton

    static let shared = StorageManager()

    // MARK: - Properties

    private let persistenceController: PersistenceController
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf", category: "storage")

    /// Main context for UI reads (main queue only)
    var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }

    // MARK: - Initialization

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    /// Creates a StorageManager for testing with in-memory store
    static func forTesting() -> StorageManager {
        StorageManager(persistenceController: PersistenceController(inMemory: true))
    }

    // MARK: - Context Management

    /// Creates a new background context for write operations
    func newBackgroundContext() -> NSManagedObjectContext {
        persistenceController.newBackgroundContext()
    }

    /// Performs work on a background context and saves
    /// - Parameter block: The work to perform on the background context
    /// - Returns: True if save succeeded, false otherwise
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = newBackgroundContext()

        return try await context.perform {
            let result = try block(context)

            if context.hasChanges {
                try context.save()
            }

            return result
        }
    }

    /// Performs work on a background context without throwing
    /// - Parameter block: The work to perform
    /// - Returns: The result, or nil if an error occurred
    func performBackgroundTaskSafe<T>(_ block: @escaping (NSManagedObjectContext) -> T?) async -> T? {
        let context = newBackgroundContext()

        return await context.perform {
            let result = block(context)

            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    self.logger.error("Failed to save background context: \(error.localizedDescription)")
                    return nil
                }
            }

            return result
        }
    }
}

// MARK: - ClipboardItemStoring Conformance

extension StorageManager: ClipboardItemStoring {
    func save(content: ClipboardContent, from sourceApp: SourceApp?) async -> Bool {
        do {
            try await performBackgroundTask { context in
                _ = ClipboardContentMapper.mapToEntities(content, sourceApp: sourceApp, context: context)
            }
            logger.debug("Saved clipboard item: \(content.id)")
            return true
        } catch {
            logger.error("Failed to save clipboard item: \(error.localizedDescription)")
            return false
        }
    }

    func fetchRecentHashes(limit: Int) async -> [String] {
        let context = newBackgroundContext()

        return await context.perform {
            let request = ClipboardItem.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.timestamp, ascending: false)]
            request.fetchLimit = limit
            request.propertiesToFetch = ["contentHash"]

            do {
                let items = try context.fetch(request)
                return items.compactMap(\.contentHash)
            } catch {
                self.logger.error("Failed to fetch recent hashes: \(error.localizedDescription)")
                return []
            }
        }
    }
}
