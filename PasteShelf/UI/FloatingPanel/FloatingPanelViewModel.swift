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

    // MARK: - Collections Properties

    /// Available smart collections
    @Published private(set) var collections: [CollectionDisplayModel] = []

    /// Currently selected collection ID (nil = All Items)
    @Published var selectedCollectionId: UUID? {
        didSet {
            Task { await applyCollectionFilter() }
        }
    }

    /// Currently selected collection
    var selectedCollection: CollectionDisplayModel? {
        guard let id = selectedCollectionId else { return nil }
        return collections.first { $0.id == id }
    }

    /// Whether the collections sidebar is visible
    @Published var showCollectionsSidebar: Bool = false

    /// Whether the collection editor sheet is visible
    @Published var showCollectionEditor: Bool = false

    /// Collection being edited (nil for new collection)
    @Published var editingCollection: CollectionDisplayModel?

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

    /// Search engine for full-text and semantic search
    private let searchEngine: HybridSearchEngine

    /// Whether semantic search is active for the current results
    @Published private(set) var isSemanticSearchActive: Bool = false

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
        self.searchEngine = HybridSearchEngine(storageManager: storageManager)
        setupSearchDebounce()
    }

    /// Whether semantic search is available (Pro license and system support)
    var isSemanticSearchAvailable: Bool {
        searchEngine.isSemanticSearchAvailable
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

        // Load OCR text for image items (Pro feature)
        await loadOCRTextForItems()

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

    /// Loads OCR text for image items and updates display models
    private func loadOCRTextForItems() async {
        // Get IDs of image items
        let imageItemIds = allItems
            .filter { $0.contentType.isImageType }
            .map(\.id)

        guard !imageItemIds.isEmpty else { return }

        // Fetch OCR text for all image items
        let ocrTexts = await storageManager.fetchOCRTexts(for: imageItemIds)

        // Update display models with OCR text
        allItems = allItems.map { item in
            if let ocrText = ocrTexts[item.id] {
                return item.withOCRText(ocrText)
            }
            return item
        }
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
            isSemanticSearchActive = false
            resetSelectionIfNeeded()
            return
        }

        searchState = .searching(query: trimmedQuery)
        logger.debug("Searching for: \(trimmedQuery)")

        // Build search options from active filters
        var options = activeFilters.toSearchOptions(limit: maxItems)

        // Enable semantic search if available and user has enabled it
        let semanticEnabled = UserDefaults.standard.bool(forKey: "semanticSearchEnabled")
        options.enableSemanticSearch = semanticEnabled && isSemanticSearchAvailable
        options.semanticThreshold = UserDefaults.standard.double(forKey: "semanticThreshold") == 0 ? 0.5 : UserDefaults.standard.double(forKey: "semanticThreshold")

        // Execute search
        let results = await searchEngine.search(query: trimmedQuery, options: options)

        // Check if any results used semantic matching
        isSemanticSearchActive = results.contains { $0.matchType == .semantic || $0.matchType == .hybrid }

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

        // Collection filter (if automatic collection selected)
        if let collection = selectedCollection, collection.isAutomatic,
           let rules = collection.rules, !rules.isEmpty
        {
            let collectionPredicate = RuleEvaluator.shared.buildPredicate(from: rules)
            predicates.append(collectionPredicate)
        } else if let collectionId = selectedCollectionId {
            // Manual collection - filter by relationship
            predicates.append(NSPredicate(
                format: "ANY collections.id == %@",
                collectionId as CVarArg
            ))
        }

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
        await delete(item: item)
    }

    /// Deletes a specific item
    func delete(item: ClipboardItemDisplayModel) async {
        let success = await storageManager.deleteItem(byId: item.id)
        if success {
            // Remove from local list
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items.remove(at: index)
                allItems.removeAll { $0.id == item.id }
                // Adjust selection
                if selectedIndex >= items.count {
                    selectedIndex = max(0, items.count - 1)
                }
            }
            logger.debug("Deleted item: \(item.id)")
        }
    }

    // MARK: - Favorites (Item-Specific)

    /// Toggles favorite status for a specific item
    func toggleFavorite(for item: ClipboardItemDisplayModel) async {
        let result = await storageManager.toggleFavorite(itemId: item.id)
        if result != nil {
            // Reload items to get updated state
            await loadItems()
            // Try to maintain the same selection position
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                selectedIndex = index
            }
            logger.debug("Toggled favorite for item: \(item.id)")
        }
    }

    // MARK: - OCR Text

    /// Copies the OCR-extracted text for an image item to the clipboard
    func copyOCRText(for item: ClipboardItemDisplayModel) async {
        guard let ocrText = item.ocrText, !ocrText.isEmpty else {
            logger.warning("No OCR text available for item: \(item.id)")
            return
        }

        // Copy OCR text to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(ocrText, forType: .string)

        logger.info("Copied OCR text for item: \(item.id)")
    }

    // MARK: - Collections

    /// Loads all smart collections
    func loadCollections() async {
        let smartCollections = await storageManager.fetchCollections()

        // Load item counts for each collection
        var displayModels: [CollectionDisplayModel] = []
        for collection in smartCollections {
            let count = await storageManager.itemCountForCollection(collection)
            if let model = CollectionDisplayModel.from(collection, itemCount: count) {
                displayModels.append(model)
            }
        }

        collections = displayModels
        logger.debug("Loaded \(collections.count) collections")
    }

    /// Applies the current collection filter and reloads items
    func applyCollectionFilter() async {
        // Clear search when changing collection
        if isSearchActive {
            clearSearch()
        }

        await loadItems()
    }

    /// Creates a new collection
    func createCollection(_ model: CollectionDisplayModel) async {
        _ = await storageManager.saveCollection(from: model)
        await loadCollections()
        showCollectionEditor = false
        editingCollection = nil
        logger.debug("Created collection: \(model.name)")
    }

    /// Updates an existing collection
    func updateCollection(_ model: CollectionDisplayModel) async {
        let success = await storageManager.updateCollection(
            model.id,
            name: model.name,
            icon: model.icon,
            colorHex: model.colorHex,
            rules: model.rules
        )

        if success {
            await loadCollections()
            // Reload items if this is the selected collection
            if selectedCollectionId == model.id {
                await loadItems()
            }
        }

        showCollectionEditor = false
        editingCollection = nil
        logger.debug("Updated collection: \(model.name)")
    }

    /// Deletes a collection
    func deleteCollection(_ collection: CollectionDisplayModel) async {
        let success = await storageManager.deleteCollection(collection.id)
        if success {
            // Clear selection if we deleted the selected collection
            if selectedCollectionId == collection.id {
                selectedCollectionId = nil
            }
            await loadCollections()
            logger.debug("Deleted collection: \(collection.name)")
        }
    }

    /// Shows the editor for creating a new collection
    func showNewCollectionEditor() {
        editingCollection = nil
        showCollectionEditor = true
    }

    /// Shows the editor for editing an existing collection
    func showEditCollectionEditor(_ collection: CollectionDisplayModel) {
        editingCollection = collection
        showCollectionEditor = true
    }

    /// Toggles the collections sidebar visibility
    func toggleCollectionsSidebar() {
        showCollectionsSidebar.toggle()
        if showCollectionsSidebar {
            Task { await loadCollections() }
        }
    }

    /// Adds an item to a manual collection
    func addItemToCollection(_ item: ClipboardItemDisplayModel, collection: CollectionDisplayModel) async {
        guard !collection.isAutomatic else { return }

        // Fetch the actual ClipboardItem
        guard let clipboardItem = await storageManager.fetchItem(byId: item.id),
              let smartCollection = await storageManager.fetchCollection(byId: collection.id)
        else {
            return
        }

        let success = await storageManager.addItemToCollection(clipboardItem, collection: smartCollection)
        if success {
            await loadCollections() // Update item counts
            logger.debug("Added item \(item.id) to collection \(collection.name)")
        }
    }

    /// Removes an item from a manual collection
    func removeItemFromCollection(_ item: ClipboardItemDisplayModel, collection: CollectionDisplayModel) async {
        guard !collection.isAutomatic else { return }

        guard let clipboardItem = await storageManager.fetchItem(byId: item.id),
              let smartCollection = await storageManager.fetchCollection(byId: collection.id)
        else {
            return
        }

        let success = await storageManager.removeItemFromCollection(clipboardItem, collection: smartCollection)
        if success {
            await loadCollections()
            // Reload items if viewing this collection
            if selectedCollectionId == collection.id {
                await loadItems()
            }
            logger.debug("Removed item \(item.id) from collection \(collection.name)")
        }
    }
}
