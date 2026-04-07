//
//  HybridSearchEngine.swift
//  PasteShelf
//
//  Combines full-text, semantic, and OCR search for optimal results.
//  Uses a weighted merge strategy to rank results.
//

import Foundation
import os.log

/// Search engine that combines full-text, semantic, and OCR search
final class HybridSearchEngine: SearchEngine, @unchecked Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        storageManager: StorageManager = .shared,
        fuzzyMatcher: FuzzyMatcher = .default
    ) {
        self.storageManager = storageManager
        self.fullTextEngine = FullTextSearchEngine(storageManager: storageManager)
        self.semanticEngine = SemanticSearchEngine(storageManager: storageManager)
        self.ocrEngine = OCRSearchEngine(storageManager: storageManager)
        self.fuzzyMatcher = fuzzyMatcher
        self.queryParser = NaturalLanguageQueryParser.self
    }

    // MARK: Internal

    // MARK: - Availability

    /// Whether semantic search is available (system support)
    var isSemanticSearchAvailable: Bool {
        self.semanticEngine.isAvailable
    }

    /// Whether OCR search is available (system support)
    var isOCRSearchAvailable: Bool {
        self.ocrEngine.isAvailable
    }

    // MARK: - SearchEngine Protocol

    // swiftlint:disable:next function_body_length
    func search(query: String, options: SearchOptions) async -> [SearchResult] {
        // Cancel any existing search
        await self.cancelSearch()

        // Trim and validate query
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return []
        }

        // Create and store the search task
        let task = Task<[SearchResult], Never> { [weak self] in
            guard let self else {
                return []
            }

            // Parse the natural language query
            let parsedQuery = self.queryParser.parse(trimmedQuery)

            // Build options from parsed query
            let enhancedOptions = self.applyParsedQueryFilters(parsedQuery, to: options)

            // Determine which engines to use
            let useSemanticSearch = self.shouldUseSemanticSearch(options: enhancedOptions)
            let useOCRSearch = self.shouldUseOCRSearch(options: enhancedOptions)

            self.logger
                .debug("Hybrid search: query='\(trimmedQuery)', semantic=\(useSemanticSearch), ocr=\(useOCRSearch)")

            // Always run full-text search
            async let fullTextResults = self.fullTextEngine.search(query: trimmedQuery, options: enhancedOptions)

            // Conditionally run semantic search
            let semanticText = parsedQuery.semanticText.isEmpty ? trimmedQuery : parsedQuery.semanticText
            let semanticResults: [SearchResult] = if useSemanticSearch {
                await self.semanticEngine.search(query: semanticText, options: enhancedOptions)
            } else {
                []
            }

            // Conditionally run OCR search
            let ocrResults: [SearchResult] = if useOCRSearch {
                await self.ocrEngine.search(query: trimmedQuery, options: enhancedOptions)
            } else {
                []
            }

            let fullText = await fullTextResults

            // Check for cancellation
            if Task.isCancelled {
                return []
            }

            // Run fuzzy search as fallback when full-text returns few results
            let fuzzyResults: [SearchResult]
            if enhancedOptions.fuzzyMatching, fullText.count < enhancedOptions.limit / 2 {
                let existingIds = Set(fullText.map(\.itemId))
                    .union(semanticResults.map(\.itemId))
                    .union(ocrResults.map(\.itemId))
                fuzzyResults = await self.performFuzzySearch(
                    query: trimmedQuery,
                    options: enhancedOptions,
                    excluding: existingIds
                )
            } else {
                fuzzyResults = []
            }

            // Merge results from all engines
            let merged = self.mergeResults(
                fullText: fullText,
                semantic: semanticResults,
                ocr: ocrResults,
                fuzzy: fuzzyResults,
                limit: options.limit
            )

            self.logger
                .debug(
                    // swiftlint:disable:next line_length
                    "Hybrid search completed: \(merged.count) results (FT: \(fullText.count), Semantic: \(semanticResults.count), OCR: \(ocrResults.count), Fuzzy: \(fuzzyResults.count))"
                )
            return merged
        }

        self.lock.lock()
        self.currentSearchTask = task
        self.lock.unlock()

        return await task.value
    }

    func cancelSearch() async {
        self.lock.lock()
        self.currentSearchTask?.cancel()
        self.currentSearchTask = nil
        self.lock.unlock()

        await self.fullTextEngine.cancelSearch()
        await self.semanticEngine.cancelSearch()
        await self.ocrEngine.cancelSearch()
    }

    // MARK: Private

    // MARK: - Configuration

    /// Weight for full-text search results (0.0 to 1.0)
    private let fullTextWeight: Double = 0.4

    /// Weight for semantic search results (0.0 to 1.0)
    private let semanticWeight: Double = 0.5

    /// Weight for OCR search results (0.0 to 1.0)
    private let ocrWeight: Double = 0.5

    /// Weight for fuzzy search results (0.0 to 1.0)
    private let fuzzyWeight: Double = 0.3

    /// Full-text search engine
    private let fullTextEngine: FullTextSearchEngine

    /// Semantic search engine
    private let semanticEngine: SemanticSearchEngine

    /// OCR search engine for text in images
    private let ocrEngine: OCRSearchEngine

    /// Fuzzy matcher for approximate string matching
    private let fuzzyMatcher: FuzzyMatcher

    /// Storage manager for fuzzy search item fetching
    private let storageManager: StorageManager

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

    // MARK: - Search Engine Decisions

    /// Determines whether semantic search should be used
    private func shouldUseSemanticSearch(options: SearchOptions) -> Bool {
        // Check if explicitly disabled
        guard options.enableSemanticSearch else {
            return false
        }

        // Check if semantic engine is available
        guard self.semanticEngine.isAvailable else {
            self.logger.debug("Semantic search engine not available")
            return false
        }

        return true
    }

    /// Determines whether OCR search should be used
    private func shouldUseOCRSearch(options: SearchOptions) -> Bool {
        // Check if explicitly disabled
        guard options.enableOCRSearch else {
            return false
        }

        // Check if OCR engine is available
        guard self.ocrEngine.isAvailable else {
            self.logger.debug("OCR search engine not available")
            return false
        }

        return true
    }

    // MARK: - Result Merging

    /// Merges full-text, semantic, OCR, and fuzzy results using weighted scoring
    private func mergeResults( // swiftlint:disable:this cyclomatic_complexity function_body_length
        fullText: [SearchResult],
        semantic: [SearchResult],
        ocr: [SearchResult],
        fuzzy: [SearchResult] = [],
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

        var ocrScores: [UUID: SearchResult] = [:]
        for result in ocr {
            ocrScores[result.itemId] = result
        }

        var fuzzyScores: [UUID: SearchResult] = [:]
        for result in fuzzy {
            fuzzyScores[result.itemId] = result
        }

        // Get all unique item IDs
        let allIds = Set(fullTextScores.keys)
            .union(semanticScores.keys)
            .union(ocrScores.keys)
            .union(fuzzyScores.keys)

        // Calculate merged scores
        var mergedResults: [SearchResult] = []

        for itemId in allIds {
            let ftResult = fullTextScores[itemId]
            let semResult = semanticScores[itemId]
            let ocrResult = ocrScores[itemId]

            var combinedScore: Double = 0
            var matchType: MatchType = .contains
            var matchRanges: [MatchRange] = []
            var matchCount = 0

            // Add full-text contribution
            if let ft = ftResult {
                combinedScore += ft.relevanceScore * self.fullTextWeight
                matchRanges = ft.matchRanges
                matchType = ft.matchType
                matchCount += 1
            }

            // Add semantic contribution
            if let sem = semResult {
                combinedScore += sem.relevanceScore * self.semanticWeight
                if matchType != .hybrid {
                    matchType = .semantic
                }
                matchCount += 1
            }

            // Add OCR contribution
            if let ocr = ocrResult {
                combinedScore += ocr.relevanceScore * self.ocrWeight
                // Prefer OCR match ranges if no full-text ranges
                if matchRanges.isEmpty {
                    matchRanges = ocr.matchRanges
                }
                if matchType != .hybrid, ftResult == nil {
                    matchType = .ocr
                }
                matchCount += 1
            }

            // Add fuzzy contribution
            if let fuz = fuzzyScores[itemId] {
                combinedScore += fuz.relevanceScore * self.fuzzyWeight
                if matchRanges.isEmpty {
                    matchRanges = fuz.matchRanges
                }
                if matchCount == 0 {
                    matchType = .fuzzy
                }
                matchCount += 1
            }

            // Upgrade to hybrid if multiple engines matched
            if matchCount > 1 {
                matchType = .hybrid
            }

            // Skip if no matches
            guard matchCount > 0 else {
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
        return Array(
            mergedResults
                .sorted { $0.relevanceScore > $1.relevanceScore }
                .prefix(limit)
        )
    }

    // MARK: - Fuzzy Search

    /// Performs fuzzy matching against recent clipboard items
    private func performFuzzySearch(
        query: String,
        options: SearchOptions,
        excluding existingIds: Set<UUID>
    ) async -> [SearchResult] {
        let matcher = FuzzyMatcher(threshold: options.fuzzyThreshold)

        // Fetch recent items to fuzzy match against
        let items = await storageManager.fetchRecentItems(
            limit: options.limit * 2,
            offset: 0
        )

        var results: [SearchResult] = []
        for item in items {
            guard let id = item.id, !existingIds.contains(id) else {
                continue
            }

            let preview = item.plainTextPreview ?? ""
            guard !preview.isEmpty else {
                continue
            }

            if let match = matcher.findBestMatch(in: preview, for: query) {
                let matchRange = matcher.toMatchRange(match, in: preview)
                results.append(SearchResult(
                    id: id,
                    itemId: id,
                    relevanceScore: match.similarity,
                    matchRanges: [matchRange],
                    matchType: .fuzzy
                ))
            }
        }

        // Sort by relevance and limit
        return Array(
            results
                .sorted { $0.relevanceScore > $1.relevanceScore }
                .prefix(options.limit)
        )
    }
}
