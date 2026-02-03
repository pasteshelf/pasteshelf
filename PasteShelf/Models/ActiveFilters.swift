//
//  ActiveFilters.swift
//  PasteShelf
//
//  Model representing the active search and filter state in the floating panel.
//  Combines search query, content type filters, favorites, and tags.
//

import Foundation

/// Represents the current active filters in the floating panel
struct ActiveFilters: Equatable, Sendable {
    // MARK: - Properties

    /// The search query text
    var searchQuery: String

    /// Selected content type filter (nil = all types)
    var contentTypeFilter: ContentTypeFilter?

    /// Whether to show only favorites
    var favoritesOnly: Bool

    /// Selected tag IDs for filtering (empty = no tag filter)
    var selectedTagIds: Set<UUID>

    /// Date range filter (nil = no date filter)
    var dateRange: DateRange?

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

    /// Default filters (no filtering)
    static let none = ActiveFilters()

    // MARK: - Computed Properties

    /// Whether any filters are currently active
    var hasActiveFilters: Bool {
        !searchQuery.isEmpty ||
            contentTypeFilter != nil ||
            favoritesOnly ||
            !selectedTagIds.isEmpty ||
            dateRange != nil
    }

    /// Whether only search is active (no other filters)
    var isSearchOnly: Bool {
        !searchQuery.isEmpty &&
            contentTypeFilter == nil &&
            !favoritesOnly &&
            selectedTagIds.isEmpty &&
            dateRange == nil
    }

    /// Human-readable description of active filters
    var description: String {
        var parts: [String] = []

        if !searchQuery.isEmpty {
            parts.append("Search: \"\(searchQuery)\"")
        }
        if let filter = contentTypeFilter {
            parts.append("Type: \(filter.displayName)")
        }
        if favoritesOnly {
            parts.append("Favorites")
        }
        if !selectedTagIds.isEmpty {
            parts.append("Tags: \(selectedTagIds.count)")
        }
        if dateRange != nil {
            parts.append("Date Range")
        }

        return parts.isEmpty ? "No filters" : parts.joined(separator: ", ")
    }

    // MARK: - Mutations

    /// Clears all filters
    mutating func clearAll() {
        searchQuery = ""
        contentTypeFilter = nil
        favoritesOnly = false
        selectedTagIds = []
        dateRange = nil
    }

    /// Clears the search query only
    mutating func clearSearch() {
        searchQuery = ""
    }

    /// Clears all filters except search
    mutating func clearFiltersKeepSearch() {
        contentTypeFilter = nil
        favoritesOnly = false
        selectedTagIds = []
        dateRange = nil
    }

    /// Toggles the favorites filter
    mutating func toggleFavoritesFilter() {
        favoritesOnly.toggle()
    }

    /// Sets or toggles a content type filter
    mutating func toggleContentTypeFilter(_ filter: ContentTypeFilter) {
        if contentTypeFilter == filter {
            contentTypeFilter = nil
        } else {
            contentTypeFilter = filter
        }
    }

    /// Adds a tag to the filter
    mutating func addTag(_ tagId: UUID) {
        selectedTagIds.insert(tagId)
    }

    /// Removes a tag from the filter
    mutating func removeTag(_ tagId: UUID) {
        selectedTagIds.remove(tagId)
    }

    /// Toggles a tag in the filter
    mutating func toggleTag(_ tagId: UUID) {
        if selectedTagIds.contains(tagId) {
            selectedTagIds.remove(tagId)
        } else {
            selectedTagIds.insert(tagId)
        }
    }

    // MARK: - Conversion to SearchOptions

    /// Converts active filters to SearchOptions for the search engine
    func toSearchOptions(limit: Int = 50) -> SearchOptions {
        SearchOptions(
            limit: limit,
            offset: 0,
            contentTypes: contentTypeFilter?.contentTypes,
            favoritesOnly: favoritesOnly,
            tagIds: selectedTagIds.isEmpty ? nil : Array(selectedTagIds),
            dateRange: dateRange,
            fuzzyMatching: true,
            fuzzyThreshold: 0.6,
            includeSensitive: true
        )
    }
}

// MARK: - Content Type Filter

/// Grouped content type filter for simpler UI
enum ContentTypeFilter: String, CaseIterable, Identifiable, Sendable {
    case text
    case images
    case files
    case links

    var id: String { rawValue }

    /// Display name for the filter
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .images: return "Images"
        case .files: return "Files"
        case .links: return "Links"
        }
    }

    /// SF Symbol icon name
    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .images: return "photo"
        case .files: return "folder"
        case .links: return "link"
        }
    }

    /// The content types included in this filter
    var contentTypes: Set<ContentType> {
        switch self {
        case .text:
            return [.plainText, .richText, .html]
        case .images:
            return [.png, .jpeg, .tiff, .pdf]
        case .files:
            return [.fileURL]
        case .links:
            return [.url]
        }
    }

    /// Creates a filter from a ContentType
    static func from(_ contentType: ContentType) -> ContentTypeFilter {
        switch contentType {
        case .plainText, .richText, .html:
            return .text
        case .png, .jpeg, .tiff, .pdf:
            return .images
        case .fileURL:
            return .files
        case .url:
            return .links
        }
    }
}
