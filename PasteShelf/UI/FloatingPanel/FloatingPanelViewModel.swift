//
//  FloatingPanelViewModel.swift
//  PasteShelf
//
//  State management for the floating clipboard history panel.
//  Handles item loading, selection, keyboard navigation, search, and paste actions.
//

import AppKit
import Combine
import Foundation
import os.log

/// ViewModel for the floating panel displaying clipboard history
@MainActor
final class FloatingPanelViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Clipboard items to display (filtered if search/filters active)
    @Published private(set) var items: [ClipboardItemDisplayModel] = []

    /// Currently selected item index (-1 for no selection)
    @Published var selectedIndex: Int = -1

    /// Whether the panel is currently visible
    @Published var isVisible: Bool = false

    /// Loading state
    @Published private(set) var isLoading: Bool = false

    /// Error message if something went wrong
    @Published var errorMessage: String?

    // MARK: - Search & Filter Properties

    /// Current search query
    @Published var searchQuery: String = "" {
        didSet {
            searchQuerySubject.send(searchQuery)
        }
    }

    /// Active filters
    @Published var activeFilters: ActiveFilters = .none

    /// Current search state
    @Published private(set) var searchState: SearchState = .idle

    /// Search results with match information (keyed by item ID)
    @Published private(set) var searchResults: [UUID: SearchResult] = [:]

    /// Whether search is currently active
    var isSearchActive: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Whether any filters are active (search or filter chips)
    var hasActiveFilters: Bool {
        isSearchActive || activeFilters.hasActiveFilters
    }

    // MARK: - Date Grouping

    /// Whether to show items grouped by date
    @Published var showDateGrouping: Bool = true

    /// Items grouped by date for display
    var groupedItems: [DateGroupedSection<ClipboardItemDisplayModel>] {
        // Don't group when searching (search results are sorted by relevance)
        guard showDateGrouping, !isSearchActive else {
            return []
        }
        return items.groupedByDate()
    }

    /// Whether grouped view should be used
    var shouldShowGroupedView: Bool {
        showDateGrouping && !isSearchActive && !items.isEmpty
    }

    // MARK: - Dependencies

    /// Storage manager for fetching items
    private let storageManager: StorageManager

    /// Search engine for full-text search
    private let searchEngine: FullTextSearchEngine

    /// Clipboard monitor for pause/resume during paste
    weak var clipboardMonitor: ClipboardMonitor?

    /// Paste simulator for Cmd+V simulation
    private let pasteSimulator = PasteSimulator()

    // MARK: - Configuration

    /// Maximum number of items to display
    private let maxItems = 50

    /// Debounce delay for search (milliseconds)
    private let searchDebounceMs: Int = 150

    // MARK: - Private Properties

    /// Logger for viewmodel operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "panel-vm"
    )

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Subject for debouncing search queries
    private let searchQuerySubject = PassthroughSubject<String, Never>()

    /// All items (unfiltered) for use when clearing search
    private var allItems: [ClipboardItemDisplayModel] = []

    // MARK: - Initialization

    init(storageManager: StorageManager = .shared) {
        self.storageManager = storageManager
        self.searchEngine = FullTextSearchEngine(storageManager: storageManager)
        setupSearchDebounce()
    }

    // MARK: - Search Setup

    /// Sets up debounced search subscription
    private func setupSearchDebounce() {
        searchQuerySubject
            .debounce(for: .milliseconds(searchDebounceMs), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                guard let self else { return }
                Task {
                    await self.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    /// Loads clipboard items from storage
    func loadItems() async {
        isLoading = true
        errorMessage = nil

        // Build predicate from active filters
        let predicate = buildFilterPredicate()

        let clipboardItems = await storageManager.fetchRecentItems(
            limit: maxItems,
            predicate: predicate
        )
        allItems = ClipboardItemDisplayModel.from(clipboardItems)

        // If search is active, perform search; otherwise show all items
        if isSearchActive {
            await performSearch(query: searchQuery)
        } else {
            items = allItems
            searchResults = [:]
        }

        // Reset selection if needed
        if selectedIndex >= items.count {
            selectedIndex = items.isEmpty ? -1 : 0
        } else if selectedIndex < 0, !items.isEmpty {
            selectedIndex = 0
        }

        isLoading = false
        logger.debug("Loaded \(self.items.count) items")
    }

    /// Refreshes the items list
    func refresh() async {
        await loadItems()
    }

    // MARK: - Search

    /// Performs a search with the given query
    func performSearch(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty query - show all items
        if trimmedQuery.isEmpty {
            searchState = .idle
            items = allItems
            searchResults = [:]
            resetSelectionIfNeeded()
            return
        }

        searchState = .searching(query: trimmedQuery)
        logger.debug("Searching for: \(trimmedQuery)")

        // Build search options from active filters
        let options = activeFilters.toSearchOptions(limit: maxItems)

        // Execute search
        let results = await searchEngine.search(query: trimmedQuery, options: options)

        // Store search results for highlighting
        searchResults = Dictionary(uniqueKeysWithValues: results.map { ($0.itemId, $0) })

        // Filter items to only those with search results
        let matchingIds = Set(results.map { $0.itemId })
        items = allItems.filter { matchingIds.contains($0.id) }

        // Sort by relevance score
        items.sort { item1, item2 in
            let score1 = searchResults[item1.id]?.relevanceScore ?? 0
            let score2 = searchResults[item2.id]?.relevanceScore ?? 0
            return score1 > score2
        }

        searchState = .completed(resultCount: items.count)
        resetSelectionIfNeeded()
        logger.debug("Search completed: \(items.count) results")
    }

    /// Clears the search query
    func clearSearch() {
        searchQuery = ""
        searchState = .idle
        searchResults = [:]
        items = allItems
        resetSelectionIfNeeded()
    }

    /// Gets match ranges for an item (for highlighting)
    func matchRanges(for itemId: UUID) -> [MatchRange] {
        searchResults[itemId]?.matchRanges ?? []
    }

    /// Gets the search result for an item
    func searchResult(for itemId: UUID) -> SearchResult? {
        searchResults[itemId]
    }

    // MARK: - Filtering

    /// Applies the current filters and reloads items
    func applyFilters() async {
        await loadItems()
    }

    /// Toggles the content type filter
    func toggleContentTypeFilter(_ filter: ContentTypeFilter) async {
        activeFilters.toggleContentTypeFilter(filter)
        await loadItems()
    }

    /// Toggles the favorites filter
    func toggleFavoritesFilter() async {
        activeFilters.toggleFavoritesFilter()
        await loadItems()
    }

    /// Clears all filters
    func clearAllFilters() async {
        activeFilters.clearAll()
        searchQuery = ""
        await loadItems()
    }

    /// Builds an NSPredicate from active filters (excluding search)
    private func buildFilterPredicate() -> NSPredicate? {
        var predicates: [NSPredicate] = []

        // Content type filter
        if let contentTypeFilter = activeFilters.contentTypeFilter {
            let typeStrings = contentTypeFilter.contentTypes.map { $0.rawValue }
            predicates.append(NSPredicate(format: "contentType IN %@", typeStrings))
        }

        // Favorites filter
        if activeFilters.favoritesOnly {
            predicates.append(NSPredicate(format: "isFavorite == YES"))
        }

        // Tag filter
        if !activeFilters.selectedTagIds.isEmpty {
            predicates.append(NSPredicate(
                format: "ANY tags.id IN %@",
                Array(activeFilters.selectedTagIds)
            ))
        }

        // Date range filter
        if let dateRange = activeFilters.dateRange {
            if let start = dateRange.start {
                predicates.append(NSPredicate(format: "timestamp >= %@", start as NSDate))
            }
            if let end = dateRange.end {
                predicates.append(NSPredicate(format: "timestamp <= %@", end as NSDate))
            }
        }

        if predicates.isEmpty {
            return nil
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    /// Resets selection if needed after filtering
    private func resetSelectionIfNeeded() {
        if selectedIndex >= items.count {
            selectedIndex = items.isEmpty ? -1 : 0
        } else if selectedIndex < 0, !items.isEmpty {
            selectedIndex = 0
        }
    }

    // MARK: - Selection

    /// Currently selected item, if any
    var selectedItem: ClipboardItemDisplayModel? {
        guard selectedIndex >= 0, selectedIndex < items.count else { return nil }
        return items[selectedIndex]
    }

    /// Selects the previous item in the list
    func selectPrevious() {
        guard !items.isEmpty else { return }

        if selectedIndex <= 0 {
            selectedIndex = items.count - 1 // Wrap to bottom
        } else {
            selectedIndex -= 1
        }
    }

    /// Selects the next item in the list
    func selectNext() {
        guard !items.isEmpty else { return }

        if selectedIndex >= items.count - 1 {
            selectedIndex = 0 // Wrap to top
        } else {
            selectedIndex += 1
        }
    }

    /// Selects an item at a specific index
    func select(at index: Int) {
        guard index >= 0, index < items.count else { return }
        selectedIndex = index
    }

    /// Clears the current selection
    func clearSelection() {
        selectedIndex = -1
    }

    // MARK: - Paste Actions

    /// Pastes the currently selected item
    func pasteSelected() async {
        guard let item = selectedItem else {
            logger.warning("No item selected for paste")
            return
        }
        await paste(item: item)
    }

    /// Pastes a specific item by ID
    func paste(itemId: UUID) async {
        guard let item = items.first(where: { $0.id == itemId }) else {
            logger.warning("Item not found: \(itemId)")
            return
        }
        await paste(item: item)
    }

    /// Pastes the specified item
    func paste(item: ClipboardItemDisplayModel) async {
        logger.info("Pasting item: \(item.id)")

        // Step 1: Pause clipboard monitoring to avoid re-capture
        clipboardMonitor?.pause()

        // Step 2: Copy item content to clipboard
        let success = await copyToClipboard(item: item)
        guard success else {
            clipboardMonitor?.resume()
            errorMessage = "Failed to copy item to clipboard"
            return
        }

        // Step 3: Hide the panel
        isVisible = false

        // Step 4: Simulate paste after a short delay
        try? await Task.sleep(for: .milliseconds(100))
        pasteSimulator.simulatePaste()

        // Step 5: Resume monitoring after paste completes
        try? await Task.sleep(for: .milliseconds(300))
        clipboardMonitor?.resume()

        logger.info("Paste completed for item: \(item.id)")
    }

    /// Copies the item content to the system clipboard
    private func copyToClipboard(item: ClipboardItemDisplayModel) async -> Bool {
        // Fetch the full item from storage to get the actual content
        guard let clipboardItem = await storageManager.fetchItem(byId: item.id),
              let contentData = clipboardItem.content
        else {
            logger.error("Failed to fetch item content: \(item.id)")
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Write content based on type
        switch item.contentType {
        case .plainText:
            if let text = contentData.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .richText:
            if let rtfData = contentData.rtfData {
                pasteboard.setData(rtfData, forType: .rtf)
            }
            // Also write plain text fallback
            if let text = contentData.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .html:
            if let htmlData = contentData.htmlData {
                pasteboard.setData(htmlData, forType: .html)
            }
            // Also write plain text fallback
            if let text = contentData.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .png, .jpeg, .tiff:
            if let imageData = contentData.imageData,
               let image = NSImage(data: imageData)
            {
                pasteboard.writeObjects([image])
            }
        case .url:
            if let urlString = contentData.textContent,
               let url = URL(string: urlString)
            {
                pasteboard.writeObjects([url as NSURL])
            }
        case .fileURL:
            if let urlString = contentData.textContent,
               let url = URL(string: urlString)
            {
                pasteboard.writeObjects([url as NSURL])
            }
        case .pdf:
            if let pdfData = contentData.pdfData {
                pasteboard.setData(pdfData, forType: .pdf)
            }
        }

        return true
    }

    // MARK: - Visibility

    /// Shows the panel and loads items
    func show() async {
        isVisible = true
        // Reset search state when showing panel
        searchQuery = ""
        searchState = .idle
        searchResults = [:]
        await loadItems()
        if !items.isEmpty, selectedIndex < 0 {
            selectedIndex = 0
        }
    }

    /// Hides the panel
    func hide() {
        isVisible = false
        clearSelection()
        // Clear search when hiding
        searchQuery = ""
        searchState = .idle
        searchResults = [:]
    }

    /// Toggles panel visibility
    func toggle() async {
        if isVisible {
            hide()
        } else {
            await show()
        }
    }

    // MARK: - Favorites

    /// Toggles favorite status for the selected item
    func toggleFavorite() async {
        guard let item = selectedItem else { return }

        let result = await storageManager.toggleFavorite(itemId: item.id)
        if result != nil {
            // Update local model
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                // Reload items to get updated state
                await loadItems()
                selectedIndex = index
            }
        }
    }

    // MARK: - Deletion

    /// Deletes the selected item
    func deleteSelected() async {
        guard let item = selectedItem else { return }

        let success = await storageManager.deleteItem(byId: item.id)
        if success {
            // Remove from local list
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items.remove(at: index)
                // Adjust selection
                if selectedIndex >= items.count {
                    selectedIndex = max(0, items.count - 1)
                }
            }
        }
    }
}
