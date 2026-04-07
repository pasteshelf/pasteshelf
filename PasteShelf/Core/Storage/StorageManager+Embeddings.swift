//
//  StorageManager+Embeddings.swift
//  PasteShelf
//
//  Embedding cache CRUD operations for semantic search.
//

import CoreData
import CryptoKit
import Foundation
import os.log

extension StorageManager {
    // MARK: - Create Operations

    /// Saves an embedding for a clipboard item
    /// - Parameters:
    ///   - itemId: The clipboard item ID
    ///   - text: The text that was embedded
    ///   - embedding: The embedding vector
    ///   - language: The language of the text (default: "en")
    /// - Returns: True if save succeeded
    func saveEmbedding(
        for itemId: UUID,
        text: String,
        embedding: [Double],
        language: String = "en"
    ) async -> Bool {
        do {
            try await performBackgroundTask { context in
                // Check for existing embedding
                let request = EmbeddingCache.fetchRequest()
                request.predicate = NSPredicate(format: "clipboardItemId == %@", itemId as CVarArg)
                request.fetchLimit = 1

                // Delete existing if present
                if let existing = try context.fetch(request).first {
                    context.delete(existing)
                }

                // Create new embedding cache entry
                let cache = EmbeddingCache(context: context)
                cache.id = UUID()
                cache.clipboardItemId = itemId
                cache.setEmbeddingVector(embedding)
                cache.embeddingVersion = EmbeddingManager.embeddingVersion
                cache.textHash = Self.hashText(text)
                cache.createdAt = Date()
                cache.language = language
            }
            return true
        } catch {
            return false
        }
    }

    /// Saves multiple embeddings in batch
    /// - Parameter embeddings: Array of (itemId, text, embedding) tuples
    /// - Returns: Number of embeddings saved
    func saveEmbeddings(_ embeddings: [(itemId: UUID, text: String, embedding: [Double])]) async -> Int {
        let result = await performBackgroundTaskSafe { context -> Int in
            var savedCount = 0

            for (itemId, text, embedding) in embeddings {
                // Check for existing
                let request = EmbeddingCache.fetchRequest()
                request.predicate = NSPredicate(format: "clipboardItemId == %@", itemId as CVarArg)
                request.fetchLimit = 1

                if let existing = try? context.fetch(request).first {
                    context.delete(existing)
                }

                let cache = EmbeddingCache(context: context)
                cache.id = UUID()
                cache.clipboardItemId = itemId
                cache.setEmbeddingVector(embedding)
                cache.embeddingVersion = EmbeddingManager.embeddingVersion
                cache.textHash = Self.hashText(text)
                cache.createdAt = Date()
                cache.language = "en"

                savedCount += 1
            }

            return savedCount
        }
        return result ?? 0
    }

    // MARK: - Read Operations

    /// Fetches the embedding for a clipboard item
    /// - Parameter itemId: The clipboard item ID
    /// - Returns: The embedding vector, or nil if not found
    func fetchEmbedding(for itemId: UUID) async -> [Double]? {
        let context = newBackgroundContext()

        return await context.perform {
            let request = EmbeddingCache.fetchRequest()
            request.predicate = NSPredicate(
                format: "clipboardItemId == %@ AND embeddingVersion == %d",
                itemId as CVarArg,
                EmbeddingManager.embeddingVersion
            )
            request.fetchLimit = 1

            guard let cache = try? context.fetch(request).first else {
                return nil
            }
            return cache.embeddingVector
        }
    }

    /// Fetches embeddings for multiple clipboard items
    /// - Parameter itemIds: Array of clipboard item IDs
    /// - Returns: Dictionary mapping item ID to embedding vector
    func fetchEmbeddings(for itemIds: [UUID]) async -> [UUID: [Double]] {
        guard !itemIds.isEmpty else {
            return [:]
        }

        let context = newBackgroundContext()

        return await context.perform {
            let request = EmbeddingCache.fetchRequest()
            request.predicate = NSPredicate(
                format: "clipboardItemId IN %@ AND embeddingVersion == %d",
                itemIds,
                EmbeddingManager.embeddingVersion
            )

            guard let caches = try? context.fetch(request) else {
                return [:]
            }

            var results: [UUID: [Double]] = [:]
            for cache in caches {
                if let itemId = cache.clipboardItemId, let vector = cache.embeddingVector {
                    results[itemId] = vector
                }
            }
            return results
        }
    }

    /// Fetches all embeddings with their clipboard item IDs
    /// - Parameter limit: Maximum number of embeddings to fetch
    /// - Returns: Array of (itemId, embedding) tuples
    func fetchAllEmbeddings(limit: Int = 1000) async -> [(itemId: UUID, embedding: [Double])] {
        let context = newBackgroundContext()

        return await context.perform {
            let request = EmbeddingCache.fetchRequest()
            request.predicate = NSPredicate(format: "embeddingVersion == %d", EmbeddingManager.embeddingVersion)
            request.fetchLimit = limit
            request.sortDescriptors = [NSSortDescriptor(keyPath: \EmbeddingCache.createdAt, ascending: false)]

            guard let caches = try? context.fetch(request) else {
                return []
            }

            return caches.compactMap { cache in
                guard let itemId = cache.clipboardItemId, let vector = cache.embeddingVector else {
                    return nil
                }
                return (itemId, vector)
            }
        }
    }

    /// Finds an existing embedding by text hash (for deduplication)
    /// - Parameter text: The text to find embedding for
    /// - Returns: The embedding vector if found
    func findEmbeddingByTextHash(_ text: String) async -> [Double]? {
        let hash = Self.hashText(text)
        let context = newBackgroundContext()

        return await context.perform {
            let request = EmbeddingCache.fetchRequest()
            request.predicate = NSPredicate(
                format: "textHash == %@ AND embeddingVersion == %d",
                hash,
                EmbeddingManager.embeddingVersion
            )
            request.fetchLimit = 1

            guard let cache = try? context.fetch(request).first else {
                return nil
            }
            return cache.embeddingVector
        }
    }

    /// Returns IDs of clipboard items that don't have embeddings
    /// - Parameter itemIds: Array of item IDs to check
    /// - Returns: Array of item IDs without embeddings
    func findItemsWithoutEmbeddings(from itemIds: [UUID]) async -> [UUID] {
        guard !itemIds.isEmpty else {
            return []
        }

        let context = newBackgroundContext()

        return await context.perform {
            let request = EmbeddingCache.fetchRequest()
            request.predicate = NSPredicate(
                format: "clipboardItemId IN %@ AND embeddingVersion == %d",
                itemIds,
                EmbeddingManager.embeddingVersion
            )
            request.propertiesToFetch = ["clipboardItemId"]

            guard let caches = try? context.fetch(request) else {
                return itemIds
            }

            let embeddedIds = Set(caches.compactMap(\.clipboardItemId))
            return itemIds.filter { !embeddedIds.contains($0) }
        }
    }

    // MARK: - Delete Operations

    /// Deletes the embedding for a clipboard item
    /// - Parameter itemId: The clipboard item ID
    /// - Returns: True if deletion succeeded
    func deleteEmbedding(for itemId: UUID) async -> Bool {
        do {
            try await performBackgroundTask { context in
                let request = EmbeddingCache.fetchRequest()
                request.predicate = NSPredicate(format: "clipboardItemId == %@", itemId as CVarArg)

                let caches = try context.fetch(request)
                for cache in caches {
                    context.delete(cache)
                }
            }
            return true
        } catch {
            return false
        }
    }

    /// Deletes embeddings for multiple clipboard items
    /// - Parameter itemIds: Array of clipboard item IDs
    /// - Returns: Number of embeddings deleted
    func deleteEmbeddings(for itemIds: [UUID]) async -> Int {
        guard !itemIds.isEmpty else {
            return 0
        }

        let result = await performBackgroundTaskSafe { context -> Int in
            let request = EmbeddingCache.fetchRequest()
            request.predicate = NSPredicate(format: "clipboardItemId IN %@", itemIds)

            guard let caches = try? context.fetch(request) else {
                return 0
            }

            let count = caches.count
            for cache in caches {
                context.delete(cache)
            }
            return count
        }
        return result ?? 0
    }

    /// Deletes all embeddings with outdated versions
    /// - Returns: Number of embeddings deleted
    func deleteOutdatedEmbeddings() async -> Int {
        let result = await performBackgroundTaskSafe { context -> Int in
            let request = EmbeddingCache.fetchRequest()
            request.predicate = NSPredicate(format: "embeddingVersion != %d", EmbeddingManager.embeddingVersion)

            guard let caches = try? context.fetch(request) else {
                return 0
            }

            let count = caches.count
            for cache in caches {
                context.delete(cache)
            }
            return count
        }
        return result ?? 0
    }

    /// Deletes all embeddings
    /// - Returns: Number of embeddings deleted
    func deleteAllEmbeddings() async -> Int {
        let result = await performBackgroundTaskSafe { context -> Int in
            let request = EmbeddingCache.fetchRequest()

            guard let caches = try? context.fetch(request) else {
                return 0
            }

            let count = caches.count
            for cache in caches {
                context.delete(cache)
            }
            return count
        }
        return result ?? 0
    }

    // MARK: - Statistics

    /// Returns the total number of cached embeddings
    func embeddingCount() async -> Int {
        let context = newBackgroundContext()

        return await context.perform {
            let request = EmbeddingCache.fetchRequest()
            request.predicate = NSPredicate(format: "embeddingVersion == %d", EmbeddingManager.embeddingVersion)
            return (try? context.count(for: request)) ?? 0
        }
    }

    // MARK: - Helpers

    /// Creates a SHA256 hash of the text for deduplication
    private static func hashText(_ text: String) -> String {
        let data = Data(text.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
