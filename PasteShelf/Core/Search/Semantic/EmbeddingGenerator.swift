//
//  EmbeddingGenerator.swift
//  PasteShelf
//
//  Background embedding generation for semantic search.
//  Handles batch processing of new items and indexing of existing items.
//

import Combine
import Foundation
import os.log

/// Manages background generation of text embeddings for semantic search
@MainActor
final class EmbeddingGenerator: ObservableObject {
    // MARK: - Singleton

    static let shared = EmbeddingGenerator()

    // MARK: - Published Properties

    /// Whether indexing is currently in progress
    @Published private(set) var isIndexing: Bool = false

    /// Number of items indexed in the current/last batch
    @Published private(set) var indexedCount: Int = 0

    /// Total items to index in the current batch
    @Published private(set) var totalToIndex: Int = 0

    /// Progress percentage (0.0 to 1.0)
    var progress: Double {
        guard totalToIndex > 0 else { return 0.0 }
        return Double(indexedCount) / Double(totalToIndex)
    }

    // MARK: - Configuration

    /// Number of items to process in each batch
    private let batchSize: Int = 50

    /// Delay between batches in milliseconds
    private let batchDelayMs: Int = 100

    /// Maximum items to index in a single session
    private let maxItemsPerSession: Int = 500

    // MARK: - Properties

    /// Storage manager for item and embedding access
    private let storageManager: StorageManager

    /// Embedding manager for generating embeddings
    private let embeddingManager: EmbeddingManager

    /// Logger for indexing operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "embedding-gen"
    )

    /// Current indexing task
    private var indexingTask: Task<Int, Never>?

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init(
        storageManager: StorageManager = .shared,
        embeddingManager: EmbeddingManager = .shared
    ) {
        self.storageManager = storageManager
        self.embeddingManager = embeddingManager
    }

    /// Creates an EmbeddingGenerator for testing
    static func forTesting(storageManager: StorageManager) -> EmbeddingGenerator {
        let generator = EmbeddingGenerator()
        return generator
    }

    // MARK: - Single Item Indexing

    /// Generates embedding for a single clipboard item
    /// - Parameter itemId: The clipboard item ID
    /// - Returns: True if embedding was generated successfully
    @discardableResult
    func generateEmbedding(for itemId: UUID) async -> Bool {
        // Check if embedding manager is available
        guard embeddingManager.isAvailable else {
            logger.warning("Embedding manager not available")
            return false
        }

        // Fetch the item's text content
        guard let item = await storageManager.fetchItem(byId: itemId),
              let text = item.plainTextPreview,
              embeddingManager.canEmbed(text)
        else {
            return false
        }

        // Check if embedding already exists
        if let _ = await storageManager.fetchEmbedding(for: itemId) {
            logger.debug("Embedding already exists for item: \(itemId)")
            return true
        }

        // Check for duplicate text (reuse existing embedding)
        if let existingEmbedding = await storageManager.findEmbeddingByTextHash(text) {
            let saved = await storageManager.saveEmbedding(
                for: itemId,
                text: text,
                embedding: existingEmbedding
            )
            logger.debug("Reused existing embedding for item: \(itemId)")
            return saved
        }

        // Generate new embedding
        guard let embedding = embeddingManager.generateEmbedding(for: text) else {
            logger.warning("Failed to generate embedding for item: \(itemId)")
            return false
        }

        // Save embedding
        let saved = await storageManager.saveEmbedding(
            for: itemId,
            text: text,
            embedding: embedding
        )

        if saved {
            logger.debug("Generated embedding for item: \(itemId)")
        }

        return saved
    }

    // MARK: - Batch Indexing

    /// Indexes all clipboard items that don't have embeddings
    /// - Returns: Number of items indexed
    @discardableResult
    func indexAllMissingEmbeddings() async -> Int {
        // Check if already indexing
        guard !isIndexing else {
            logger.debug("Indexing already in progress")
            return 0
        }

        // Check if embedding manager is available
        guard embeddingManager.isAvailable else {
            logger.warning("Embedding manager not available")
            return 0
        }

        // Cancel any existing task
        indexingTask?.cancel()

        isIndexing = true
        indexedCount = 0
        totalToIndex = 0

        let task = Task<Int, Never>(priority: .background) { [weak self] in
            guard let self else { return 0 }

            var totalIndexed = 0

            // Fetch items without embeddings in batches
            var offset = 0

            while !Task.isCancelled {
                // Fetch a batch of recent items
                let items = await storageManager.fetchRecentItems(
                    limit: batchSize,
                    offset: offset
                )

                if items.isEmpty {
                    break
                }

                // Get items without embeddings
                let itemIds = items.compactMap(\.id)
                let missingIds = await storageManager.findItemsWithoutEmbeddings(from: itemIds)

                if missingIds.isEmpty {
                    offset += batchSize
                    continue
                }

                // Update progress
                await MainActor.run {
                    totalToIndex += missingIds.count
                }

                // Process items without embeddings
                for itemId in missingIds {
                    if Task.isCancelled {
                        break
                    }

                    let success = await processItem(itemId: itemId)
                    if success {
                        totalIndexed += 1
                        await MainActor.run {
                            indexedCount += 1
                        }
                    }

                    // Check session limit
                    if totalIndexed >= maxItemsPerSession {
                        logger.info("Reached session limit: \(totalIndexed) items indexed")
                        break
                    }
                }

                if totalIndexed >= maxItemsPerSession {
                    break
                }

                offset += batchSize

                // Brief delay between batches to avoid overwhelming the system
                try? await Task.sleep(for: .milliseconds(batchDelayMs))
            }

            await MainActor.run {
                isIndexing = false
            }

            logger.info("Indexing completed: \(totalIndexed) items indexed")
            return totalIndexed
        }

        indexingTask = task
        return await task.value
    }

    /// Processes a single item for embedding
    private func processItem(itemId: UUID) async -> Bool {
        // Fetch the item
        guard let item = await storageManager.fetchItem(byId: itemId),
              let text = item.plainTextPreview,
              embeddingManager.canEmbed(text)
        else {
            return false
        }

        // Check for duplicate text (reuse existing embedding)
        if let existingEmbedding = await storageManager.findEmbeddingByTextHash(text) {
            return await storageManager.saveEmbedding(
                for: itemId,
                text: text,
                embedding: existingEmbedding
            )
        }

        // Generate new embedding
        guard let embedding = embeddingManager.generateEmbedding(for: text) else {
            return false
        }

        // Save embedding
        return await storageManager.saveEmbedding(
            for: itemId,
            text: text,
            embedding: embedding
        )
    }

    // MARK: - Control

    /// Cancels the current indexing operation
    func cancelIndexing() {
        indexingTask?.cancel()
        indexingTask = nil
        isIndexing = false
    }

    /// Clears all embeddings and resets progress
    func clearAllEmbeddings() async {
        cancelIndexing()
        let deleted = await storageManager.deleteAllEmbeddings()
        logger.info("Cleared \(deleted) embeddings")
        indexedCount = 0
        totalToIndex = 0
    }

    /// Deletes outdated embeddings (different version)
    func clearOutdatedEmbeddings() async {
        let deleted = await storageManager.deleteOutdatedEmbeddings()
        if deleted > 0 {
            logger.info("Cleared \(deleted) outdated embeddings")
        }
    }

    // MARK: - Statistics

    /// Returns the number of indexed items
    func indexedItemCount() async -> Int {
        await storageManager.embeddingCount()
    }

    /// Whether semantic search is available
    var isAvailable: Bool {
        embeddingManager.isAvailable
    }
}
