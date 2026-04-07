//
//  EmbeddingCache+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch request for EmbeddingCache entity.
//

import CoreData
import Foundation

public extension EmbeddingCache {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<EmbeddingCache> {
        NSFetchRequest<EmbeddingCache>(entityName: "EmbeddingCache")
    }

    // MARK: - Attributes

    /// Unique identifier for this cache entry
    @NSManaged var id: UUID?

    /// ID of the associated clipboard item
    @NSManaged var clipboardItemId: UUID?

    /// Serialized embedding vector (binary data ~4KB for 512 doubles)
    @NSManaged var embedding: Data?

    /// Version of the embedding model (for cache invalidation)
    @NSManaged var embeddingVersion: Int16

    /// SHA256 hash of the text content (for deduplication)
    @NSManaged var textHash: String?

    /// When this embedding was created
    @NSManaged var createdAt: Date?

    /// Language of the text content
    @NSManaged var language: String?
}

// MARK: - Convenience Methods

extension EmbeddingCache {
    /// Returns the embedding as a Double array
    var embeddingVector: [Double]? {
        guard let data = embedding else {
            return nil
        }
        return EmbeddingManager.deserializeEmbedding(data)
    }

    /// Sets the embedding from a Double array
    func setEmbeddingVector(_ vector: [Double]) {
        self.embedding = EmbeddingManager.serializeEmbedding(vector)
    }
}

// MARK: - EmbeddingCache + Identifiable

extension EmbeddingCache: Identifiable {}
