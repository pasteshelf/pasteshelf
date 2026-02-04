//
//  SemanticSearchEngine.swift
//  PasteShelf
//
//  Semantic search engine using NaturalLanguage embeddings.
//  Uses vector similarity to find semantically related clipboard items.
//

import CoreData
import Foundation
import os.log

/// Search engine that uses AI embeddings for semantic similarity search
final class SemanticSearchEngine: SearchEngine, @unchecked Sendable {
    // MARK: - Properties

    /// Storage manager for CoreData access
    private let storageManager: StorageManager

    /// Embedding manager for generating query embeddings
    private let embeddingManager: EmbeddingManager

    /// Logger for search operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "semantic-search"
    )

    /// Task handle for cancellation
    private var currentSearchTask: Task<[SearchResult], Never>?

    /// Lock for thread-safe task management
    private let lock = NSLock()

    // MARK: - Initialization

    init(
        storageManager: StorageManager = .shared,
        embeddingManager: EmbeddingManager = .shared
    ) {
        self.storageManager = storageManager
        self.embeddingManager = embeddingManager
    }

    // MARK: - SearchEngine Protocol

    func search(query: String, options: SearchOptions) async -> [SearchResult] {
        // Cancel any existing search
        await cancelSearch()

        // Trim and validate query
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return []
        }

        // Check if embeddings are available
        guard embeddingManager.isAvailable else {
            logger.warning("Semantic search unavailable: NLEmbedding not loaded")
            return []
        }

        // Create and store the search task
        let task = Task<[SearchResult], Never> { [weak self] in
            guard let self else { return [] }

            logger.debug("Starting semantic search for: \(trimmedQuery)")

            // Generate embedding for the query
            guard let queryEmbedding = embeddingManager.generateEmbedding(for: trimmedQuery) else {
                logger.debug("Could not generate embedding for query")
                return []
            }

            // Check for cancellation
            if Task.isCancelled {
                return []
            }

            // Fetch candidate items
            let candidateIds = await fetchCandidateItemIds(options: options)

            if Task.isCancelled {
                return []
            }

            // Fetch embeddings for candidates
            let embeddings = await storageManager.fetchEmbeddings(for: candidateIds)

            if Task.isCancelled {
                return []
            }

            // No embeddings available
            guard !embeddings.isEmpty else {
                logger.debug("No embeddings found for candidates")
                return []
            }

            // Calculate similarities
            let candidates = embeddings.map { (id: $0.key, vector: $0.value) }
            let similarities = VectorSimilarityCalculator.findTopK(
                to: queryEmbedding,
                in: candidates,
                k: options.limit,
                threshold: options.semanticThreshold
            )

            // Convert to search results
            let results = similarities.map { similarity in
                SearchResult(
                    id: similarity.id,
                    itemId: similarity.id,
                    relevanceScore: similarity.similarity,
                    matchRanges: [], // No specific match ranges for semantic search
                    matchType: .semantic
                )
            }

            logger.debug("Semantic search completed: \(results.count) results")
            return results
        }

        lock.lock()
        currentSearchTask = task
        lock.unlock()

        return await task.value
    }

    func cancelSearch() async {
        lock.lock()
        currentSearchTask?.cancel()
        currentSearchTask = nil
        lock.unlock()
    }

    // MARK: - Candidate Selection

    /// Fetches IDs of clipboard items that match the filter criteria
    private func fetchCandidateItemIds(options: SearchOptions) async -> [UUID] {
        // Build filter predicate
        let predicate = buildFilterPredicate(options: options)

        // Fetch matching item IDs
        let items = await storageManager.fetchRecentItems(
            limit: options.limit * 3, // Fetch more candidates for better semantic matches
            offset: options.offset,
            predicate: predicate
        )

        return items.compactMap(\.id)
    }

    /// Builds an NSPredicate from search options
    private func buildFilterPredicate(options: SearchOptions) -> NSPredicate? {
        var predicates: [NSPredicate] = []

        // Content type filter
        if let contentTypes = options.contentTypes, !contentTypes.isEmpty {
            let typeStrings = contentTypes.map { $0.rawValue }
            predicates.append(NSPredicate(format: "contentType IN %@", typeStrings))
        }

        // Favorites filter
        if options.favoritesOnly {
            predicates.append(NSPredicate(format: "isFavorite == YES"))
        }

        // Sensitive items filter
        if !options.includeSensitive {
            predicates.append(NSPredicate(format: "isSensitive == NO"))
        }

        // Date range filter
        if let dateRange = options.dateRange {
            if let start = dateRange.start {
                predicates.append(NSPredicate(format: "timestamp >= %@", start as NSDate))
            }
            if let end = dateRange.end {
                predicates.append(NSPredicate(format: "timestamp <= %@", end as NSDate))
            }
        }

        // Tag filter
        if let tagIds = options.tagIds, !tagIds.isEmpty {
            predicates.append(NSPredicate(format: "ANY tags.id IN %@", tagIds))
        }

        // Source app hints filter
        if let appHints = options.sourceAppHints, !appHints.isEmpty {
            var appPredicates: [NSPredicate] = []
            for hint in appHints {
                appPredicates.append(NSPredicate(format: "sourceAppName CONTAINS[cd] %@", hint))
                appPredicates.append(NSPredicate(format: "sourceAppBundleId CONTAINS[cd] %@", hint))
            }
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: appPredicates))
        }

        if predicates.isEmpty {
            return nil
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    // MARK: - Availability

    /// Whether semantic search is available on this system
    var isAvailable: Bool {
        embeddingManager.isAvailable
    }
}
