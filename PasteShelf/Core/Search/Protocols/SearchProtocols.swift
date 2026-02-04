//
//  SearchProtocols.swift
//  PasteShelf
//
//  Protocol definitions for the search engine components.
//  These protocols enable dependency injection and testability.
//

import Foundation

// MARK: - Search Engine Protocol

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

// MARK: - Search Options

/// Configuration options for search operations
struct SearchOptions: Sendable, Equatable {
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

    /// Enable semantic/AI-powered search (Pro feature)
    var enableSemanticSearch: Bool

    /// Minimum similarity threshold for semantic matches (0.0 to 1.0)
    var semanticThreshold: Double

    /// Source app name hints for filtering (from natural language query)
    var sourceAppHints: [String]?

    // MARK: - OCR Search Options

    /// Enable OCR text extraction search from images (Pro feature)
    var enableOCRSearch: Bool

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

    /// Default search options
    static let `default` = SearchOptions()

    /// Options for favorites-only search
    static func favorites(limit: Int = 50) -> SearchOptions {
        SearchOptions(limit: limit, favoritesOnly: true)
    }

    /// Options for content type filtered search
    static func byType(_ types: Set<ContentType>, limit: Int = 50) -> SearchOptions {
        SearchOptions(limit: limit, contentTypes: types)
    }
}

// MARK: - Date Range

/// Represents a date range for filtering
struct DateRange: Sendable, Equatable {
    /// Start date (inclusive)
    let start: Date?

    /// End date (inclusive)
    let end: Date?

    /// Creates a date range
    init(start: Date? = nil, end: Date? = nil) {
        self.start = start
        self.end = end
    }

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
}

// MARK: - Search Result

/// Represents a single search result with match information
struct SearchResult: Identifiable, Sendable, Equatable {
    // MARK: - Properties

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

    // MARK: - Computed Properties

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

// MARK: - Match Range

/// Represents a range in text where a search match was found
struct MatchRange: Sendable, Equatable, Hashable {
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

// MARK: - Match Type

/// Type of match found during search
enum MatchType: String, Sendable, Equatable {
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

    /// Semantic/AI-powered similarity match (Pro feature)
    case semantic

    /// Hybrid match (combined full-text and semantic)
    case hybrid

    /// Match found in OCR-extracted text from image (Pro feature)
    case ocr

    /// Score multiplier for ranking
    var scoreMultiplier: Double {
        switch self {
        case .exact: return 1.0
        case .prefix: return 0.9
        case .hybrid: return 0.85
        case .contains: return 0.7
        case .ocr: return 0.68
        case .semantic: return 0.65
        case .metadata: return 0.6
        case .fuzzy: return 0.5
        }
    }
}

// MARK: - Search State

/// Represents the current state of a search operation
enum SearchState: Sendable, Equatable {
    /// No search in progress
    case idle

    /// Search is currently running
    case searching(query: String)

    /// Search completed with results
    case completed(resultCount: Int)

    /// Search failed with error
    case failed(message: String)

    /// Whether a search is currently in progress
    var isSearching: Bool {
        if case .searching = self {
            return true
        }
        return false
    }
}

// MARK: - Search Error

/// Errors that can occur during search operations
enum SearchError: Error, Sendable {
    /// The search was cancelled
    case cancelled

    /// Query is too short
    case queryTooShort(minimumLength: Int)

    /// Storage access failed
    case storageError(String)

    /// Invalid search options
    case invalidOptions(String)

    var localizedDescription: String {
        switch self {
        case .cancelled:
            return "Search was cancelled"
        case let .queryTooShort(minLength):
            return "Query must be at least \(minLength) characters"
        case let .storageError(message):
            return "Storage error: \(message)"
        case let .invalidOptions(message):
            return "Invalid options: \(message)"
        }
    }
}
