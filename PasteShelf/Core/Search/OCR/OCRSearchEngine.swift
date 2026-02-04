//
//  OCRSearchEngine.swift
//  PasteShelf
//
//  Search engine for finding text within images using OCR.
//  Uses Vision framework-extracted text from OCRCache for searching.
//

import CoreData
import Foundation
import os.log

/// Search engine that searches OCR-extracted text from images
final class OCRSearchEngine: SearchEngine, @unchecked Sendable {
    // MARK: - Properties

    /// Storage manager for CoreData access
    private let storageManager: StorageManager

    /// License manager for Pro feature checking
    private let licenseManager: LicenseManager

    /// Logger for search operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "ocr-search"
    )

    /// Task handle for cancellation
    private var currentSearchTask: Task<[SearchResult], Never>?

    /// Lock for thread-safe task management
    private let lock = NSLock()

    /// Image content types to search
    private let imageContentTypes: Set<ContentType> = [.png, .jpeg, .tiff]

    // MARK: - Initialization

    init(
        storageManager: StorageManager = .shared,
        licenseManager: LicenseManager = .shared
    ) {
        self.storageManager = storageManager
        self.licenseManager = licenseManager
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

        // Check Pro license for OCR search
        guard licenseManager.isFeatureAvailable(.ocrSearch) else {
            logger.debug("OCR search requires Pro license")
            return []
        }

        // Create and store the search task
        let task = Task<[SearchResult], Never> { [weak self] in
            guard let self else { return [] }

            logger.debug("Starting OCR search for: \(trimmedQuery)")

            // Fetch candidate image items
            let candidateIds = await fetchCandidateImageItemIds(options: options)

            if Task.isCancelled {
                return []
            }

            guard !candidateIds.isEmpty else {
                logger.debug("No image items found for OCR search")
                return []
            }

            // Fetch OCR texts for candidates
            let ocrTexts = await storageManager.fetchOCRTexts(for: candidateIds)

            if Task.isCancelled {
                return []
            }

            guard !ocrTexts.isEmpty else {
                logger.debug("No OCR texts found for candidates")
                return []
            }

            // Search through OCR texts
            var results: [SearchResult] = []
            let queryLower = trimmedQuery.lowercased()

            for (itemId, ocrText) in ocrTexts {
                if Task.isCancelled {
                    break
                }

                // Check if OCR text contains the query
                let ocrTextLower = ocrText.lowercased()
                guard ocrTextLower.contains(queryLower) else {
                    continue
                }

                // Calculate relevance score based on match quality
                let relevanceScore = calculateRelevanceScore(
                    query: queryLower,
                    ocrText: ocrTextLower
                )

                // Find match ranges in OCR text
                let matchRanges = findMatchRanges(query: trimmedQuery, in: ocrText)

                let result = SearchResult(
                    id: itemId,
                    itemId: itemId,
                    relevanceScore: relevanceScore,
                    matchRanges: matchRanges,
                    matchType: .ocr
                )
                results.append(result)
            }

            // Sort by relevance
            let sortedResults = results
                .sorted { $0.relevanceScore > $1.relevanceScore }
                .prefix(options.limit)

            logger.debug("OCR search completed: \(sortedResults.count) results")
            return Array(sortedResults)
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

    /// Fetches IDs of image clipboard items that match the filter criteria
    private func fetchCandidateImageItemIds(options: SearchOptions) async -> [UUID] {
        // Build filter predicate (only image types)
        var predicates: [NSPredicate] = []

        // Content type filter
        let contentTypePredicate = NSPredicate(
            format: "contentType IN %@",
            imageContentTypes.map { $0.rawValue }
        )
        predicates.append(contentTypePredicate)

        // Add other filters
        if let filterPredicate = buildFilterPredicate(options: options) {
            predicates.append(filterPredicate)
        }

        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        // Fetch matching image item IDs
        let items = await storageManager.fetchRecentItems(
            limit: options.limit * 5, // Fetch more candidates to find OCR matches
            offset: options.offset,
            predicate: combinedPredicate
        )

        return items.compactMap { $0.id }
    }

    /// Builds an NSPredicate from search options (excluding content type, handled separately)
    private func buildFilterPredicate(options: SearchOptions) -> NSPredicate? {
        var predicates: [NSPredicate] = []

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

        if predicates.isEmpty {
            return nil
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    // MARK: - Relevance Scoring

    /// Calculates relevance score based on match quality
    private func calculateRelevanceScore(query: String, ocrText: String) -> Double {
        var score: Double = 0.5 // Base score for contains match

        // Boost for exact word match (not just substring)
        let words = ocrText.components(separatedBy: .whitespacesAndNewlines)
        if words.contains(where: { $0.lowercased() == query }) {
            score += 0.2
        }

        // Boost for earlier position in text
        if let range = ocrText.range(of: query, options: .caseInsensitive) {
            let position = ocrText.distance(from: ocrText.startIndex, to: range.lowerBound)
            let relativePosition = Double(position) / Double(max(1, ocrText.count))
            score += (1.0 - relativePosition) * 0.1
        }

        // Boost for multiple occurrences
        let occurrences = ocrText.components(separatedBy: query).count - 1
        if occurrences > 1 {
            score += min(0.1, Double(occurrences) * 0.02)
        }

        return min(1.0, score)
    }

    /// Finds match ranges in the OCR text
    private func findMatchRanges(query: String, in text: String) -> [MatchRange] {
        var ranges: [MatchRange] = []
        var searchRange = text.startIndex ..< text.endIndex

        while let range = text.range(of: query, options: .caseInsensitive, range: searchRange) {
            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            let length = text.distance(from: range.lowerBound, to: range.upperBound)
            let matchedText = String(text[range])

            ranges.append(MatchRange(start: start, length: length, matchedText: matchedText))

            // Move search range past this match
            searchRange = range.upperBound ..< text.endIndex
        }

        return ranges
    }

    // MARK: - Availability

    /// Whether OCR search is available on this system
    var isAvailable: Bool {
        licenseManager.isFeatureAvailable(.ocrSearch) && OCRManager.shared.isAvailable
    }
}
