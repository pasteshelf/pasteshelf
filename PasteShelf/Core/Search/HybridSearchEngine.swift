//
//  HybridSearchEngine.swift
//  PasteShelf
//
//  Combines full-text and semantic search for optimal results.
//  Uses a weighted merge strategy to rank results.
//

import Foundation
import os.log

/// Search engine that combines full-text and semantic search
final class HybridSearchEngine: SearchEngine, @unchecked Sendable {
    // MARK: - Configuration

    /// Weight for full-text search results (0.0 to 1.0)
    private let fullTextWeight: Double = 0.4

    /// Weight for semantic search results (0.0 to 1.0)
    private let semanticWeight: Double = 0.6

    // MARK: - Properties

    /// Full-text search engine
    private let fullTextEngine: FullTextSearchEngine

    /// Semantic search engine
    private let semanticEngine: SemanticSearchEngine

    /// License manager for Pro feature checking
    private let licenseManager: LicenseManager

    /// Query parser for natural language understanding
    private let queryParser: NaturalLanguageQueryParser.Type

    /// Logger for search operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "hybrid-search"
    )

    /// Task handle for cancellation
    private var currentSearchTask: Task<[SearchResult], Never>?

    /// Lock for thread-safe task management
    private let lock = NSLock()

    // MARK: - Initialization

    init(
        storageManager: StorageManager = .shared,
        licenseManager: LicenseManager = .shared
    ) {
        self.fullTextEngine = FullTextSearchEngine(storageManager: storageManager)
        self.semanticEngine = SemanticSearchEngine(storageManager: storageManager)
        self.licenseManager = licenseManager
        self.queryParser = NaturalLanguageQueryParser.self
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

        // Create and store the search task
        let task = Task<[SearchResult], Never> { [weak self] in
            guard let self else { return [] }

            // Parse the natural language query
            let parsedQuery = queryParser.parse(trimmedQuery)

            // Build options from parsed query
            var enhancedOptions = applyParsedQueryFilters(parsedQuery, to: options)

            // Determine if semantic search should be used
            let useSemanticSearch = shouldUseSemanticSearch(options: enhancedOptions)

            logger.debug("Hybrid search: query='\(trimmedQuery)', semantic=\(useSemanticSearch)")

            if useSemanticSearch {
                // Run both searches in parallel
                let semanticText = parsedQuery.semanticText.isEmpty ? trimmedQuery : parsedQuery.semanticText

                async let fullTextResults = fullTextEngine.search(query: trimmedQuery, options: enhancedOptions)
                async let semanticResults = semanticEngine.search(query: semanticText, options: enhancedOptions)

                let (fullText, semantic) = await (fullTextResults, semanticResults)

                // Check for cancellation
                if Task.isCancelled {
                    return []
                }

                // Merge results
                let merged = mergeResults(fullText: fullText, semantic: semantic, limit: options.limit)
                logger.debug("Hybrid search completed: \(merged.count) results (FT: \(fullText.count), Semantic: \(semantic.count))")
                return merged
            } else {
                // Fall back to full-text only
                let results = await fullTextEngine.search(query: trimmedQuery, options: enhancedOptions)
                logger.debug("Full-text search completed: \(results.count) results")
                return results
            }
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

        await fullTextEngine.cancelSearch()
        await semanticEngine.cancelSearch()
    }

    // MARK: - Query Processing

    /// Applies filters extracted from parsed natural language query
    private func applyParsedQueryFilters(_ parsed: ParsedQuery, to options: SearchOptions) -> SearchOptions {
        var enhanced = options

        // Apply date range if not already set
        if enhanced.dateRange == nil, let parsedDateRange = parsed.dateRange {
            enhanced.dateRange = parsedDateRange
        }

        // Apply content type hints if not already set
        if enhanced.contentTypes == nil, !parsed.contentTypeHints.isEmpty {
            enhanced.contentTypes = parsed.contentTypeHints
        }

        // Apply source app hints
        if !parsed.sourceAppHints.isEmpty {
            enhanced.sourceAppHints = parsed.sourceAppHints
        }

        return enhanced
    }

    // MARK: - Semantic Search Decision

    /// Determines whether semantic search should be used
    private func shouldUseSemanticSearch(options: SearchOptions) -> Bool {
        // Check if explicitly disabled
        guard options.enableSemanticSearch else {
            return false
        }

        // Check Pro license
        guard licenseManager.isFeatureAvailable(.semanticSearch) else {
            logger.debug("Semantic search requires Pro license")
            return false
        }

        // Check if semantic engine is available
        guard semanticEngine.isAvailable else {
            logger.debug("Semantic search engine not available")
            return false
        }

        return true
    }

    // MARK: - Result Merging

    /// Merges full-text and semantic results using weighted scoring
    private func mergeResults(
        fullText: [SearchResult],
        semantic: [SearchResult],
        limit: Int
    ) -> [SearchResult] {
        // Create lookup dictionaries
        var fullTextScores: [UUID: SearchResult] = [:]
        for result in fullText {
            fullTextScores[result.itemId] = result
        }

        var semanticScores: [UUID: SearchResult] = [:]
        for result in semantic {
            semanticScores[result.itemId] = result
        }

        // Get all unique item IDs
        let allIds = Set(fullTextScores.keys).union(semanticScores.keys)

        // Calculate merged scores
        var mergedResults: [SearchResult] = []

        for itemId in allIds {
            let ftResult = fullTextScores[itemId]
            let semResult = semanticScores[itemId]

            let combinedScore: Double
            let matchType: MatchType
            let matchRanges: [MatchRange]

            if let ft = ftResult, let sem = semResult {
                // Item found by both engines - hybrid match
                combinedScore = (ft.relevanceScore * fullTextWeight) + (sem.relevanceScore * semanticWeight)
                matchType = .hybrid
                matchRanges = ft.matchRanges // Use full-text ranges for highlighting
            } else if let ft = ftResult {
                // Full-text only match
                combinedScore = ft.relevanceScore * fullTextWeight
                matchType = ft.matchType
                matchRanges = ft.matchRanges
            } else if let sem = semResult {
                // Semantic only match
                combinedScore = sem.relevanceScore * semanticWeight
                matchType = .semantic
                matchRanges = []
            } else {
                continue
            }

            mergedResults.append(SearchResult(
                id: itemId,
                itemId: itemId,
                relevanceScore: combinedScore,
                matchRanges: matchRanges,
                matchType: matchType
            ))
        }

        // Sort by combined score and limit
        return mergedResults
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Availability

    /// Whether semantic search is available (Pro license and system support)
    var isSemanticSearchAvailable: Bool {
        licenseManager.isFeatureAvailable(.semanticSearch) && semanticEngine.isAvailable
    }
}
