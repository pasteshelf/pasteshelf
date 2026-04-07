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
    // MARK: Lifecycle

    // MARK: - Initialization

    private init(
        storageManager: StorageManager = .shared,
        embeddingManager: EmbeddingManager = .shared
    ) {
        self.storageManager = storageManager
        self.embeddingManager = embeddingManager
    }

    // MARK: Internal

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
        guard self.totalToIndex > 0 else {
            return 0.0
        }
        return Double(self.indexedCount) / Double(self.totalToIndex)
    }

    /// Whether semantic search is available
    var isAvailable: Bool {
        self.embeddingManager.isAvailable
    }

    /// Creates an EmbeddingGenerator for testing
    static func forTesting(storageManager: StorageManager) -> EmbeddingGenerator {
        EmbeddingGenerator()
    }

    // MARK: - Single Item Indexing

    /// Generates embedding for a single clipboard item
    /// - Parameter itemId: The clipboard item ID
    /// - Returns: True if embedding was generated successfully
    @discardableResult
    func generateEmbedding(for itemId: UUID) async -> Bool {
        // Check if embedding manager is available
        guard self.embeddingManager.isAvailable else {
            self.logger.warning("Embedding manager not available")
            return false
        }

        // Fetch the item's full text content (fall back to preview, then OCR text for images)
        guard let item = await storageManager.fetchItem(byId: itemId) else {
            return false
        }

        var text = item.content?.textContent ?? item.plainTextPreview

        // For image items without text, try OCR-extracted text
        if text.flatMap({ embeddingManager.canEmbed($0) ? $0 : nil }) == nil {
            if let ocrText = await storageManager.fetchOCRText(for: itemId),
               embeddingManager.canEmbed(ocrText)
            {
                text = ocrText
            }
        }

        guard let text, embeddingManager.canEmbed(text) else {
            return false
        }

        // Check if embedding already exists
        if await self.storageManager.fetchEmbedding(for: itemId) != nil {
            self.logger.debug("Embedding already exists for item: \(itemId)")
            return true
        }

        // Check for duplicate text (reuse existing embedding)
        if let existingEmbedding = await storageManager.findEmbeddingByTextHash(text) {
            let saved = await storageManager.saveEmbedding(
                for: itemId,
                text: text,
                embedding: existingEmbedding
            )
            self.logger.debug("Reused existing embedding for item: \(itemId)")
            return saved
        }

        // Generate new embedding
        guard let embedding = embeddingManager.generateEmbedding(for: text) else {
            self.logger.warning("Failed to generate embedding for item: \(itemId)")
            return false
        }

        // Save embedding
        let saved = await storageManager.saveEmbedding(
            for: itemId,
            text: text,
            embedding: embedding
        )

        if saved {
            self.logger.debug("Generated embedding for item: \(itemId)")
        }

        return saved
    }

    // MARK: - Batch Indexing

    /// Indexes all clipboard items that don't have embeddings
    /// - Returns: Number of items indexed
    @discardableResult
    func indexAllMissingEmbeddings() async -> Int { // swiftlint:disable:this function_body_length
        // Check if already indexing
        guard !self.isIndexing else {
            self.logger.debug("Indexing already in progress")
            return 0
        }

        // Check if embedding manager is available
        guard self.embeddingManager.isAvailable else {
            self.logger.warning("Embedding manager not available")
            return 0
        }

        // Cancel any existing task
        self.indexingTask?.cancel()

        self.isIndexing = true
        self.indexedCount = 0
        self.totalToIndex = 0

        let task = Task<Int, Never>(priority: .background) { [weak self] in
            guard let self else {
                return 0
            }

            var totalIndexed = 0

            // Fetch items without embeddings in batches
            var offset = 0

            while !Task.isCancelled {
                // Fetch a batch of recent items
                let items = await storageManager.fetchRecentItems(
                    limit: self.batchSize,
                    offset: offset
                )

                if items.isEmpty {
                    break
                }

                // Get items without embeddings
                let itemIds = items.compactMap(\.id)
                let missingIds = await storageManager.findItemsWithoutEmbeddings(from: itemIds)

                if missingIds.isEmpty {
                    offset += self.batchSize
                    continue
                }

                // Update progress
                await MainActor.run {
                    self.totalToIndex += missingIds.count
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
                            self.indexedCount += 1
                        }
                    }

                    // Check session limit
                    if totalIndexed >= self.maxItemsPerSession {
                        self.logger.info("Reached session limit: \(totalIndexed) items indexed")
                        break
                    }
                }

                if totalIndexed >= self.maxItemsPerSession {
                    break
                }

                offset += self.batchSize

                // Brief delay between batches to avoid overwhelming the system
                try? await Task.sleep(for: .milliseconds(self.batchDelayMs))
            }

            await MainActor.run {
                self.isIndexing = false
            }

            self.logger.info("Indexing completed: \(totalIndexed) items indexed")
            return totalIndexed
        }

        self.indexingTask = task
        return await task.value
    }

    // MARK: - Control

    /// Cancels the current indexing operation
    func cancelIndexing() {
        self.indexingTask?.cancel()
        self.indexingTask = nil
        self.isIndexing = false
    }

    /// Clears all embeddings and resets progress
    func clearAllEmbeddings() async {
        self.cancelIndexing()
        let deleted = await storageManager.deleteAllEmbeddings()
        self.logger.info("Cleared \(deleted) embeddings")
        self.indexedCount = 0
        self.totalToIndex = 0
    }

    /// Deletes outdated embeddings (different version)
    func clearOutdatedEmbeddings() async {
        let deleted = await storageManager.deleteOutdatedEmbeddings()
        if deleted > 0 {
            self.logger.info("Cleared \(deleted) outdated embeddings")
        }
    }

    // MARK: - Statistics

    /// Returns the number of indexed items
    func indexedItemCount() async -> Int {
        await self.storageManager.embeddingCount()
    }

    // MARK: Private

    // MARK: - Configuration

    /// Number of items to process in each batch
    private let batchSize: Int = 50

    /// Delay between batches in milliseconds
    private let batchDelayMs: Int = 100

    /// Maximum items to index in a single session
    private let maxItemsPerSession: Int = 500

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

    /// Processes a single item for embedding
    private func processItem(itemId: UUID) async -> Bool {
        // Fetch the item
        guard let item = await storageManager.fetchItem(byId: itemId) else {
            return false
        }

        // Use plain text preview, or fall back to OCR text for images
        var text = item.plainTextPreview
        if text.flatMap({ embeddingManager.canEmbed($0) ? $0 : nil }) == nil {
            if let ocrText = await storageManager.fetchOCRText(for: itemId),
               embeddingManager.canEmbed(ocrText)
            {
                text = ocrText
            }
        }

        guard let text, embeddingManager.canEmbed(text) else {
            return false
        }

        // Check for duplicate text (reuse existing embedding)
        if let existingEmbedding = await storageManager.findEmbeddingByTextHash(text) {
            return await self.storageManager.saveEmbedding(
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
        return await self.storageManager.saveEmbedding(
            for: itemId,
            text: text,
            embedding: embedding
        )
    }
}
