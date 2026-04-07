//
//  FullTextSearchEngine.swift
//  PasteShelf
//
//  NSPredicate-based full-text search engine implementation.
//  Provides case-insensitive, diacritic-insensitive search with prefix and contains matching.
//

import CoreData
import Foundation
import os.log

// MARK: - FullTextSearchEngine

/// Full-text search engine using CoreData NSPredicate
final class FullTextSearchEngine: SearchEngine, @unchecked Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(storageManager: StorageManager = .shared) {
        self.storageManager = storageManager
    }

    // MARK: Internal

    // MARK: - SearchEngine Protocol

    func search(query: String, options: SearchOptions) async -> [SearchResult] {
        // Cancel any existing search
        await self.cancelSearch()

        // Trim and validate query
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty query returns no results (caller should handle this by showing all items)
        guard !trimmedQuery.isEmpty else {
            return []
        }

        // Create and store the search task
        let task = Task<[SearchResult], Never> { [weak self] in
            guard let self else {
                return []
            }

            self.logger.debug("Starting search for: \(trimmedQuery)")

            // Build the search predicate
            let predicate = self.buildPredicate(query: trimmedQuery, options: options)

            // Fetch matching items
            let items = await storageManager.fetchRecentItems(
                limit: options.limit,
                offset: options.offset,
                predicate: predicate
            )

            // Check for cancellation
            if Task.isCancelled {
                self.logger.debug("Search cancelled")
                return []
            }

            // Convert to search results with relevance scoring
            let results = items.compactMap { item -> SearchResult? in
                guard let id = item.id else {
                    return nil
                }
                return self.createSearchResult(
                    for: item,
                    query: trimmedQuery,
                    options: options
                )
            }

            // Sort by relevance
            let sortedResults = results.sorted { $0.relevanceScore > $1.relevanceScore }

            self.logger.debug("Search completed: \(sortedResults.count) results")
            return sortedResults
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
    }

    // MARK: - Simple Text Matching (for testing)

    /// Checks if text matches the given query using case-insensitive, diacritic-insensitive comparison
    /// - Parameters:
    ///   - text: The text to search in
    ///   - query: The search query
    ///   - options: Search options (optional, uses default if not provided)
    /// - Returns: True if the text contains or matches the query
    func matches(text: String, query: String, options: SearchOptions = .default) -> Bool {
        let normalizedText = text.searchNormalized
        let normalizedQuery = query.searchNormalized

        // Empty query never matches
        guard !normalizedQuery.isEmpty else {
            return false
        }

        // Check for exact, prefix, or contains match based on options
        if normalizedText == normalizedQuery {
            return true
        }
        if normalizedText.hasPrefix(normalizedQuery) {
            return true
        }
        return normalizedText.contains(normalizedQuery)
    }

    // MARK: Private

    /// Storage manager for CoreData access
    private let storageManager: StorageManager

    /// Logger for search operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "search"
    )

    /// Task handle for cancellation
    private var currentSearchTask: Task<[SearchResult], Never>?

    /// Lock for thread-safe task management
    private let lock = NSLock()

    // MARK: - Predicate Building

    /// Builds an NSPredicate for the search query and options
    private func buildPredicate(query: String, options: SearchOptions) -> NSPredicate {
        var predicates: [NSPredicate] = []

        // Text search predicate (case-insensitive, diacritic-insensitive)
        let searchPredicates = self.buildTextSearchPredicates(query: query)
        if !searchPredicates.isEmpty {
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: searchPredicates))
        }

        // Content type filter
        if let contentTypes = options.contentTypes, !contentTypes.isEmpty {
            let typeStrings = contentTypes.map(\.rawValue)
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
            predicates.append(self.buildDateRangePredicate(dateRange))
        }

        // Tag filter
        if let tagIds = options.tagIds, !tagIds.isEmpty {
            predicates.append(NSPredicate(format: "ANY tags.id IN %@", tagIds))
        }

        // Combine all predicates with AND
        if predicates.isEmpty {
            return NSPredicate(value: true)
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    /// Builds text search predicates for plainTextPreview and sourceAppName
    private func buildTextSearchPredicates(query: String) -> [NSPredicate] {
        // Use [cd] for case-insensitive, diacritic-insensitive matching
        let safeQuery = query.predicateSafe

        return [
            // Search in plain text preview
            NSPredicate(format: "plainTextPreview CONTAINS[cd] %@", safeQuery),
            // Search in source app name
            NSPredicate(format: "sourceAppName CONTAINS[cd] %@", safeQuery),
        ]
    }

    /// Builds a date range predicate
    private func buildDateRangePredicate(_ range: DateRange) -> NSPredicate {
        var predicates: [NSPredicate] = []

        if let start = range.start {
            predicates.append(NSPredicate(format: "timestamp >= %@", start as NSDate))
        }

        if let end = range.end {
            predicates.append(NSPredicate(format: "timestamp <= %@", end as NSDate))
        }

        if predicates.isEmpty {
            return NSPredicate(value: true)
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    // MARK: - Result Creation

    /// Creates a SearchResult from a ClipboardItem with relevance scoring
    private func createSearchResult(
        for item: ClipboardItem,
        query: String,
        options _: SearchOptions
    ) -> SearchResult? {
        guard let id = item.id else {
            return nil
        }

        let preview = item.plainTextPreview ?? ""
        let appName = item.sourceAppName ?? ""

        // Find match ranges and determine match type
        var matchRanges: [MatchRange] = []
        var matchType: MatchType = .contains
        var relevanceScore = 0.5

        // Check for exact match
        if preview.searchNormalized == query.searchNormalized {
            matchType = .exact
            relevanceScore = 1.0
            matchRanges = [MatchRange(start: 0, length: preview.count, matchedText: preview)]
        }
        // Check for prefix match
        else if preview.startsWithIgnoringCase(query) {
            matchType = .prefix
            relevanceScore = 0.9
            matchRanges = preview.findMatchRanges(for: query)
        }
        // Check for contains match in preview
        else if preview.containsIgnoringCase(query) {
            matchType = .contains
            relevanceScore = 0.7
            matchRanges = preview.findMatchRanges(for: query)
        }
        // Check for match in app name (metadata match)
        else if appName.containsIgnoringCase(query) {
            matchType = .metadata
            relevanceScore = 0.6
            // No text ranges since match is in metadata
        }

        // Boost favorites slightly
        if item.isFavorite {
            relevanceScore = min(1.0, relevanceScore + 0.05)
        }

        // Boost more recent items slightly
        if let timestamp = item.timestamp {
            let hoursSince = Date().timeIntervalSince(timestamp) / 3600
            if hoursSince < 1 {
                relevanceScore = min(1.0, relevanceScore + 0.03)
            } else if hoursSince < 24 {
                relevanceScore = min(1.0, relevanceScore + 0.01)
            }
        }

        return SearchResult(
            id: id,
            itemId: id,
            relevanceScore: relevanceScore,
            matchRanges: matchRanges,
            matchType: matchType
        )
    }
}

// MARK: - StorageManager Extension

extension StorageManager {
    /// Fetches clipboard items by their IDs
    /// - Parameter ids: Array of UUIDs to fetch
    /// - Returns: Array of matching ClipboardItem objects (order not guaranteed)
    func fetchItems(byIds ids: [UUID]) async -> [ClipboardItem] {
        guard !ids.isEmpty else {
            return []
        }

        return await viewContext.perform {
            let request = ClipboardItem.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", ids)

            do {
                return try self.viewContext.fetch(request)
            } catch {
                return []
            }
        }
    }
}
