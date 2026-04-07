//
//  ActiveFilters.swift
//  PasteShelf
//
//  Model representing the active search and filter state in the floating panel.
//  Combines search query, content type filters, favorites, and tags.
//

import Foundation

// MARK: - ActiveFilters

/// Represents the current active filters in the floating panel
struct ActiveFilters: Equatable {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        searchQuery: String = "",
        contentTypeFilter: ContentTypeFilter? = nil,
        favoritesOnly: Bool = false,
        selectedTagIds: Set<UUID> = [],
        dateRange: DateRange? = nil
    ) {
        self.searchQuery = searchQuery
        self.contentTypeFilter = contentTypeFilter
        self.favoritesOnly = favoritesOnly
        self.selectedTagIds = selectedTagIds
        self.dateRange = dateRange
    }

    // MARK: Internal

    /// Default filters (no filtering)
    static let none = ActiveFilters()

    /// The search query text
    var searchQuery: String

    /// Selected content type filter (nil = all types)
    var contentTypeFilter: ContentTypeFilter?

    /// Whether to show only favorites
    var favoritesOnly: Bool

    /// Selected tag IDs for filtering
    var selectedTagIds: Set<UUID>

    /// Date range filter (nil = no date filter)
    var dateRange: DateRange?

    /// Whether any filters are currently active
    var hasActiveFilters: Bool {
        !self.searchQuery.isEmpty ||
            self.contentTypeFilter != nil ||
            self.favoritesOnly ||
            !self.selectedTagIds.isEmpty ||
            self.dateRange != nil
    }

    /// Whether only search is active (no other filters)
    var isSearchOnly: Bool {
        !self.searchQuery.isEmpty &&
            self.contentTypeFilter == nil &&
            !self.favoritesOnly &&
            self.selectedTagIds.isEmpty &&
            self.dateRange == nil
    }

    /// Human-readable description of active filters
    var description: String {
        var parts: [String] = []

        if !self.searchQuery.isEmpty {
            parts.append("Search: \"\(self.searchQuery)\"")
        }
        if let filter = contentTypeFilter {
            parts.append("Type: \(filter.displayName)")
        }
        if self.favoritesOnly {
            parts.append("Favorites")
        }
        if !self.selectedTagIds.isEmpty {
            parts.append("\(self.selectedTagIds.count) tag(s)")
        }
        if self.dateRange != nil {
            parts.append("Date Range")
        }

        return parts.isEmpty ? "No filters" : parts.joined(separator: ", ")
    }

    // MARK: - Mutations

    /// Clears all filters
    mutating func clearAll() {
        self.searchQuery = ""
        self.contentTypeFilter = nil
        self.favoritesOnly = false
        self.selectedTagIds = []
        self.dateRange = nil
    }

    /// Clears the search query only
    mutating func clearSearch() {
        self.searchQuery = ""
    }

    /// Clears all filters except search
    mutating func clearFiltersKeepSearch() {
        self.contentTypeFilter = nil
        self.favoritesOnly = false
        self.selectedTagIds = []
        self.dateRange = nil
    }

    /// Toggles the favorites filter
    mutating func toggleFavoritesFilter() {
        self.favoritesOnly.toggle()
    }

    /// Sets or toggles a content type filter
    mutating func toggleContentTypeFilter(_ filter: ContentTypeFilter) {
        if self.contentTypeFilter == filter {
            self.contentTypeFilter = nil
        } else {
            self.contentTypeFilter = filter
        }
    }

    /// Toggles a tag filter
    mutating func toggleTag(_ tagId: UUID) {
        if self.selectedTagIds.contains(tagId) {
            self.selectedTagIds.remove(tagId)
        } else {
            self.selectedTagIds.insert(tagId)
        }
    }

    // MARK: - Conversion to SearchOptions

    /// Converts active filters to SearchOptions for the search engine
    @MainActor
    func toSearchOptions(limit: Int = 50) -> SearchOptions {
        SearchOptions(
            limit: limit,
            offset: 0,
            contentTypes: self.contentTypeFilter?.contentTypes,
            favoritesOnly: self.favoritesOnly,
            tagIds: self.selectedTagIds.isEmpty ? nil : Array(self.selectedTagIds),
            dateRange: self.dateRange,
            fuzzyMatching: SettingsManager.shared.search.fuzzyMatchEnabled,
            fuzzyThreshold: 0.6,
            includeSensitive: true,
            enableSemanticSearch: SettingsManager.shared.search.semanticSearchEnabled,
            semanticThreshold: SettingsManager.shared.search.semanticThreshold,
            enableOCRSearch: SettingsManager.shared.search.ocrSearchEnabled
        )
    }
}

// MARK: - ContentTypeFilter

/// Grouped content type filter for simpler UI
enum ContentTypeFilter: String, CaseIterable, Identifiable {
    case text
    case images
    case files
    case links

    // MARK: Internal

    var id: String {
        rawValue
    }

    /// Display name for the filter
    var displayName: String {
        switch self {
        case .text: "Text"
        case .images: "Images"
        case .files: "Files"
        case .links: "Links"
        }
    }

    /// SF Symbol icon name
    var icon: String {
        switch self {
        case .text: "doc.text"
        case .images: "photo"
        case .files: "folder"
        case .links: "link"
        }
    }

    /// The content types included in this filter
    var contentTypes: Set<ContentType> {
        switch self {
        case .text:
            [.plainText, .richText, .html]
        case .images:
            [.png, .jpeg, .tiff, .pdf]
        case .files:
            [.fileURL]
        case .links:
            [.url]
        }
    }

    /// Creates a filter from a ContentType
    static func from(_ contentType: ContentType) -> ContentTypeFilter {
        switch contentType {
        case .plainText,
             .richText,
             .html:
            .text
        case .png,
             .jpeg,
             .tiff,
             .pdf:
            .images
        case .fileURL:
            .files
        case .url:
            .links
        }
    }
}
