//
//  SearchProtocols.swift
//  PasteShelf
//
//  Protocol definitions for the search engine components.
//  These protocols enable dependency injection and testability.
//

import Foundation

// MARK: - SearchEngine

/// Protocol for search engine implementations
protocol SearchEngine: Sendable {
    /// Search for items matching the query
    /// - Parameters:
    ///   - query: The search query string
    ///   - options: Search configuration options
    /// - Returns: Array of search results ordered by relevance
    func search(query: String, options: SearchOptions) async -> [SearchResult]

    /// Cancel any ongoing search operation
    func cancelSearch() async
}

// MARK: - SearchOptions

/// Configuration options for search operations
struct SearchOptions: Equatable {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        limit: Int = 50,
        offset: Int = 0,
        contentTypes: Set<ContentType>? = nil,
        favoritesOnly: Bool = false,
        tagIds: [UUID]? = nil,
        dateRange: DateRange? = nil,
        fuzzyMatching: Bool = true,
        fuzzyThreshold: Double = 0.6,
        includeSensitive: Bool = true,
        enableSemanticSearch: Bool = false,
        semanticThreshold: Double = 0.5,
        sourceAppHints: [String]? = nil,
        enableOCRSearch: Bool = false
    ) {
        self.limit = limit
        self.offset = offset
        self.contentTypes = contentTypes
        self.favoritesOnly = favoritesOnly
        self.tagIds = tagIds
        self.dateRange = dateRange
        self.fuzzyMatching = fuzzyMatching
        self.fuzzyThreshold = fuzzyThreshold
        self.includeSensitive = includeSensitive
        self.enableSemanticSearch = enableSemanticSearch
        self.semanticThreshold = semanticThreshold
        self.sourceAppHints = sourceAppHints
        self.enableOCRSearch = enableOCRSearch
    }

    // MARK: Internal

    /// Default search options
    static let `default` = SearchOptions()

    // MARK: - Result Limits

    /// Maximum number of results to return
    var limit: Int

    /// Offset for pagination
    var offset: Int

    // MARK: - Filters

    /// Filter by specific content types (nil = all types)
    var contentTypes: Set<ContentType>?

    /// Filter by favorite status
    var favoritesOnly: Bool

    /// Filter by specific tags (nil = no tag filter)
    var tagIds: [UUID]?

    /// Filter by date range (nil = no date filter)
    var dateRange: DateRange?

    // MARK: - Search Behavior

    /// Enable fuzzy/approximate matching
    var fuzzyMatching: Bool

    /// Fuzzy matching threshold (0.0 to 1.0, higher = stricter)
    var fuzzyThreshold: Double

    /// Search in sensitive items
    var includeSensitive: Bool

    // MARK: - Semantic Search Options

    /// Enable semantic/AI-powered search
    var enableSemanticSearch: Bool

    /// Minimum similarity threshold for semantic matches (0.0 to 1.0)
    var semanticThreshold: Double

    /// Source app name hints for filtering (from natural language query)
    var sourceAppHints: [String]?

    // MARK: - OCR Search Options

    /// Enable OCR text extraction search from images
    var enableOCRSearch: Bool

    /// Options for favorites-only search
    static func favorites(limit: Int = 50) -> SearchOptions {
        SearchOptions(limit: limit, favoritesOnly: true)
    }

    /// Options for content type filtered search
    static func byType(_ types: Set<ContentType>, limit: Int = 50) -> SearchOptions {
        SearchOptions(limit: limit, contentTypes: types)
    }
}

// MARK: - DateRange

/// Represents a date range for filtering
struct DateRange: Equatable {
    // MARK: Lifecycle

    /// Creates a date range
    init(start: Date? = nil, end: Date? = nil) {
        self.start = start
        self.end = end
    }

    // MARK: Internal

    /// Today only
    static var today: DateRange {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)
        return DateRange(start: startOfDay, end: endOfDay)
    }

    /// Last 7 days
    static var lastWeek: DateRange {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -7, to: end)
        return DateRange(start: start, end: end)
    }

    /// Last 30 days
    static var lastMonth: DateRange {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -30, to: end)
        return DateRange(start: start, end: end)
    }

    /// Start date (inclusive)
    let start: Date?

    /// End date (inclusive)
    let end: Date?
}

// MARK: - SearchResult

/// Represents a single search result with match information
struct SearchResult: Identifiable, Equatable {
    /// Unique identifier for the result (same as item ID)
    let id: UUID

    /// The ID of the matched clipboard item
    let itemId: UUID

    /// Relevance score (0.0 to 1.0, higher = more relevant)
    let relevanceScore: Double

    /// Ranges in the text where matches were found
    let matchRanges: [MatchRange]

    /// Type of match that was found
    let matchType: MatchType

    /// Whether this result has highlighted matches
    var hasHighlights: Bool {
        !matchRanges.isEmpty
    }

    /// Primary match range (first match)
    var primaryMatchRange: MatchRange? {
        matchRanges.first
    }

    // MARK: - Equatable

    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id &&
            lhs.itemId == rhs.itemId &&
            lhs.relevanceScore == rhs.relevanceScore &&
            lhs.matchType == rhs.matchType
    }
}

// MARK: - MatchRange

/// Represents a range in text where a search match was found
struct MatchRange: Equatable, Hashable {
    /// Start index in the string
    let start: Int

    /// Length of the match
    let length: Int

    /// The matched text
    let matchedText: String

    /// End index (exclusive)
    var end: Int {
        start + length
    }

    /// Creates a Range<String.Index> for a given string
    func range(in string: String) -> Range<String.Index>? {
        guard start >= 0,
              let startIndex = string.index(string.startIndex, offsetBy: start, limitedBy: string.endIndex),
              let endIndex = string.index(startIndex, offsetBy: length, limitedBy: string.endIndex)
        else {
            return nil
        }
        return startIndex ..< endIndex
    }
}

// MARK: - MatchType

/// Type of match found during search
enum MatchType: String, Equatable {
    /// Exact match of the query
    case exact

    /// Prefix match (query is a prefix of the word)
    case prefix

    /// Contains match (query is contained in the text)
    case contains

    /// Fuzzy/approximate match
    case fuzzy

    /// Match in metadata (app name, type, etc.)
    case metadata

    /// Semantic/AI-powered similarity match
    case semantic

    /// Hybrid match (combined full-text and semantic)
    case hybrid

    /// Match found in OCR-extracted text from image
    case ocr

    // MARK: Internal

    /// Score multiplier for ranking
    var scoreMultiplier: Double {
        switch self {
        case .exact: 1.0
        case .prefix: 0.9
        case .hybrid: 0.85
        case .contains: 0.7
        case .ocr: 0.68
        case .semantic: 0.65
        case .metadata: 0.6
        case .fuzzy: 0.5
        }
    }
}

// MARK: - SearchState

/// Represents the current state of a search operation
enum SearchState: Equatable {
    /// No search in progress
    case idle

    /// Search is currently running
    case searching(query: String)

    /// Search completed with results
    case completed(resultCount: Int)

    /// Search failed with error
    case failed(message: String)

    // MARK: Internal

    /// Whether a search is currently in progress
    var isSearching: Bool {
        if case .searching = self {
            return true
        }
        return false
    }
}

// MARK: - SearchError

/// Errors that can occur during search operations
enum SearchError: Error {
    /// The search was cancelled
    case cancelled

    /// Query is too short
    case queryTooShort(minimumLength: Int)

    /// Storage access failed
    case storageError(String)

    /// Invalid search options
    case invalidOptions(String)

    // MARK: Internal

    var localizedDescription: String {
        switch self {
        case .cancelled:
            "Search was cancelled"
        case let .queryTooShort(minLength):
            "Query must be at least \(minLength) characters"
        case let .storageError(message):
            "Storage error: \(message)"
        case let .invalidOptions(message):
            "Invalid options: \(message)"
        }
    }
}
