// swiftlint:disable file_length
//
//  FloatingPanelViewModel.swift
//  PasteShelf
//
//  State management for the floating clipboard history panel.
//  Handles item loading, selection, keyboard navigation, search, and paste actions.
//

// swiftformat:disable organizeDeclarations

import AppKit
import Combine
import Foundation
import os.log

/// ViewModel for the floating panel displaying clipboard history
@MainActor
final class FloatingPanelViewModel: ObservableObject { // swiftlint:disable:this type_body_length
    // MARK: Lifecycle

    // MARK: - Initialization

    init(storageManager: StorageManager = .shared, settingsManager: SettingsManager = .shared) {
        self.storageManager = storageManager
        self.settingsManager = settingsManager
        self.searchEngine = HybridSearchEngine(storageManager: storageManager)
        self.setupSearchDebounce()
    }

    // MARK: Internal

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

    /// Active filters
    @Published var activeFilters: ActiveFilters = .none

    /// Current search state
    @Published private(set) var searchState: SearchState = .idle

    /// Search results with match information (keyed by item ID)
    @Published private(set) var searchResults: [UUID: SearchResult] = [:]

    // MARK: - Collections Properties

    /// Available smart collections
    @Published private(set) var collections: [CollectionDisplayModel] = []

    /// Whether the collections sidebar is visible
    @Published var showCollectionsSidebar: Bool = false

    /// Whether the collection editor sheet is visible
    @Published var showCollectionEditor: Bool = false

    /// Collection being edited (nil for new collection)
    @Published var editingCollection: CollectionDisplayModel?

    // MARK: - Date Grouping

    /// Whether to show items grouped by date
    @Published var showDateGrouping: Bool = true

    /// Whether semantic search is active for the current results
    @Published private(set) var isSemanticSearchActive: Bool = false

    /// Clipboard monitor for pause/resume during paste
    weak var clipboardMonitor: ClipboardMonitor?

    /// Callback to restore focus to the previous app (set by FloatingPanelController)
    var restorePreviousAppFocus: (@MainActor () -> Void)?

    /// Available tags for filtering
    @Published private(set) var availableTags: [TagDisplayModel] = []

    // MARK: - Search & Filter Properties

    /// Current search query
    @Published var searchQuery: String = "" {
        didSet {
            self.searchQuerySubject.send(self.searchQuery)
        }
    }

    /// Whether search is currently active
    var isSearchActive: Bool {
        !self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Whether any filters are active (search or filter chips)
    var hasActiveFilters: Bool {
        self.isSearchActive || self.activeFilters.hasActiveFilters
    }

    /// Currently selected collection ID (nil = All Items)
    @Published var selectedCollectionId: UUID? {
        didSet {
            Task { await self.applyCollectionFilter() }
        }
    }

    /// Currently selected collection
    var selectedCollection: CollectionDisplayModel? {
        guard let id = selectedCollectionId else {
            return nil
        }
        return self.collections.first { $0.id == id }
    }

    /// Items grouped by date for display
    var groupedItems: [DateGroupedSection<ClipboardItemDisplayModel>] {
        // Don't group when searching (search results are sorted by relevance)
        guard self.showDateGrouping, !self.isSearchActive else {
            return []
        }
        return self.items.groupedByDate()
    }

    /// Whether grouped view should be used
    var shouldShowGroupedView: Bool {
        self.showDateGrouping && !self.isSearchActive && !self.items.isEmpty
    }

    /// Whether semantic search is available (system support required)
    var isSemanticSearchAvailable: Bool {
        self.searchEngine.isSemanticSearchAvailable
    }

    // MARK: - Selection

    /// Currently selected item, if any
    var selectedItem: ClipboardItemDisplayModel? {
        guard self.selectedIndex >= 0, self.selectedIndex < self.items.count else {
            return nil
        }
        return self.items[self.selectedIndex]
    }

    // MARK: - Data Loading

    /// Loads clipboard items from storage
    func loadItems() async {
        self.isLoading = true
        self.errorMessage = nil

        // Build predicate from active filters
        let predicate = self.buildFilterPredicate()

        let clipboardItems = await storageManager.fetchRecentItems(
            limit: self.maxItems,
            predicate: predicate
        )
        self.allItems = ClipboardItemDisplayModel.from(clipboardItems)

        // Load OCR text for image items
        await self.loadOCRTextForItems()

        // If search is active, perform search; otherwise show all items
        if self.isSearchActive {
            await self.performSearch(query: self.searchQuery)
        } else {
            self.items = self.allItems
            self.searchResults = [:]
        }

        // Reset selection if needed
        if self.selectedIndex >= self.items.count {
            self.selectedIndex = self.items.isEmpty ? -1 : 0
        } else if self.selectedIndex < 0, !self.items.isEmpty {
            self.selectedIndex = 0
        }

        self.isLoading = false
        self.logger.debug("Loaded \(self.items.count) items")
    }

    /// Refreshes the items list
    func refresh() async {
        await self.loadItems()
    }

    // MARK: - Search

    /// Performs a search with the given query
    func performSearch(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty query - show all items
        if trimmedQuery.isEmpty {
            self.searchState = .idle
            self.items = self.allItems
            self.searchResults = [:]
            self.isSemanticSearchActive = false
            self.resetSelectionIfNeeded()
            return
        }

        self.searchState = .searching(query: trimmedQuery)
        self.logger.debug("Searching for: \(trimmedQuery)")

        // Build search options from active filters
        var options = self.activeFilters.toSearchOptions(limit: self.maxItems)

        // Enable semantic search if available and user has enabled it
        let searchSettings = self.settingsManager.search
        options.enableSemanticSearch = searchSettings.semanticSearchEnabled && self.isSemanticSearchAvailable
        options.semanticThreshold = searchSettings.semanticThreshold

        // Enable OCR search if user has enabled it
        options.enableOCRSearch = searchSettings.ocrSearchEnabled

        // Execute search
        let results = await searchEngine.search(query: trimmedQuery, options: options)

        // Check if any results used semantic matching
        self.isSemanticSearchActive = results.contains { $0.matchType == .semantic || $0.matchType == .hybrid }

        // Store search results for highlighting
        self.searchResults = Dictionary(uniqueKeysWithValues: results.map { ($0.itemId, $0) })

        // Filter items to only those with search results
        let matchingIds = Set(results.map(\.itemId))
        self.items = self.allItems.filter { matchingIds.contains($0.id) }

        // Sort by relevance score
        self.items.sort { item1, item2 in
            let score1 = self.searchResults[item1.id]?.relevanceScore ?? 0
            let score2 = self.searchResults[item2.id]?.relevanceScore ?? 0
            return score1 > score2
        }

        self.searchState = .completed(resultCount: self.items.count)
        self.resetSelectionIfNeeded()
        self.logger.debug("Search completed: \(self.items.count) results")
    }

    /// Clears the search query
    func clearSearch() {
        self.searchQuery = ""
        self.searchState = .idle
        self.searchResults = [:]
        self.items = self.allItems
        self.resetSelectionIfNeeded()
    }

    /// Gets match ranges for an item (for highlighting)
    func matchRanges(for itemId: UUID) -> [MatchRange] {
        self.searchResults[itemId]?.matchRanges ?? []
    }

    /// Gets the search result for an item
    func searchResult(for itemId: UUID) -> SearchResult? {
        self.searchResults[itemId]
    }

    // MARK: - Filtering

    /// Applies the current filters and reloads items
    func applyFilters() async {
        await self.loadItems()
    }

    /// Toggles the content type filter
    func toggleContentTypeFilter(_ filter: ContentTypeFilter) async {
        self.activeFilters.toggleContentTypeFilter(filter)
        await self.loadItems()
    }

    /// Toggles the favorites filter
    func toggleFavoritesFilter() async {
        self.activeFilters.toggleFavoritesFilter()
        await self.loadItems()
    }

    /// Loads available tags from storage
    func loadAvailableTags() async {
        let tags = await storageManager.fetchTags()
        self.availableTags = TagDisplayModel.from(tags)
    }

    /// Toggles a tag filter
    func toggleTagFilter(_ tagId: UUID) async {
        self.activeFilters.toggleTag(tagId)
        await self.loadItems()
    }

    /// Clears all filters
    func clearAllFilters() async {
        self.activeFilters.clearAll()
        self.searchQuery = ""
        await self.loadItems()
    }

    /// Selects the previous item in the list
    func selectPrevious() {
        guard !self.items.isEmpty else {
            return
        }

        if self.selectedIndex <= 0 {
            self.selectedIndex = self.items.count - 1 // Wrap to bottom
        } else {
            self.selectedIndex -= 1
        }
    }

    /// Selects the next item in the list
    func selectNext() {
        guard !self.items.isEmpty else {
            return
        }

        if self.selectedIndex >= self.items.count - 1 {
            self.selectedIndex = 0 // Wrap to top
        } else {
            self.selectedIndex += 1
        }
    }

    /// Selects an item at a specific index
    func select(at index: Int) {
        guard index >= 0, index < self.items.count else {
            return
        }
        self.selectedIndex = index
    }

    /// Clears the current selection
    func clearSelection() {
        self.selectedIndex = -1
    }

    // MARK: - Paste Actions

    /// Pastes the currently selected item
    func pasteSelected() async {
        guard let item = selectedItem else {
            self.logger.warning("No item selected for paste")
            return
        }
        await self.paste(item: item)
    }

    /// Pastes a specific item by ID
    func paste(itemId: UUID) async {
        // Try local items first, then fetch from storage (for menu-bar quick-paste)
        if let item = items.first(where: { $0.id == itemId }) {
            await self.paste(item: item)
        } else if let clipboardItem = await storageManager.fetchItem(byId: itemId) {
            let displayModel = ClipboardItemDisplayModel.from([clipboardItem]).first
            if let item = displayModel {
                await self.paste(item: item)
            } else {
                self.logger.warning("Item not found: \(itemId)")
            }
        } else {
            self.logger.warning("Item not found: \(itemId)")
        }
    }

    /// Pastes the specified item
    func paste(item: ClipboardItemDisplayModel) async {
        self.logger.info("Pasting item: \(item.id)")

        // Step 1: Pause clipboard monitoring to avoid re-capture
        self.clipboardMonitor?.pause()

        // Step 2: Copy item content to clipboard
        let success = await copyToClipboard(item: item)
        guard success else {
            self.clipboardMonitor?.resume()
            self.errorMessage = "Failed to copy item to clipboard"
            return
        }

        // Step 3: Hide the panel
        self.isVisible = false

        // Step 3.5: Restore focus to the previous app
        self.restorePreviousAppFocus?()

        #if APP_STORE
            // App Store: show "Copied" toast — user presses Cmd+V themselves.
            // Pause monitoring for 2s to avoid re-capturing the user's manual Cmd+V paste.
            CopiedConfirmationWindow.show()
            try? await Task.sleep(for: .milliseconds(2000))
            self.clipboardMonitor?.resume()
        #else
            // Direct distribution: simulate Cmd+V paste via Accessibility
            try? await Task.sleep(for: .milliseconds(200))
            let pasted = self.pasteSimulator.simulatePaste()

            if !pasted {
                self.errorMessage = "Item copied to clipboard. "
                    + "Grant Accessibility permission in System Settings to enable auto-paste."
            }

            // Resume monitoring after paste completes
            try? await Task.sleep(for: .milliseconds(300))
            self.clipboardMonitor?.resume()
        #endif

        self.logger.info("Paste completed for item: \(item.id)")
    }

    // MARK: - Visibility

    /// Shows the panel and loads items
    func show() async {
        self.isVisible = true
        // Reset search state when showing panel
        self.searchQuery = ""
        self.searchState = .idle
        self.searchResults = [:]
        await self.loadAvailableTags()
        await self.loadItems()
        if !self.items.isEmpty, self.selectedIndex < 0 {
            self.selectedIndex = 0
        }
    }

    /// Hides the panel
    func hide() {
        self.isVisible = false
        self.clearSelection()
        // Clear search when hiding
        self.searchQuery = ""
        self.searchState = .idle
        self.searchResults = [:]
    }

    /// Toggles panel visibility
    func toggle() async {
        if self.isVisible {
            self.hide()
        } else {
            await self.show()
        }
    }

    // MARK: - Favorites

    /// Toggles favorite status for the selected item
    func toggleFavorite() async {
        guard let item = selectedItem else {
            return
        }

        let result = await storageManager.toggleFavorite(itemId: item.id)
        if result != nil {
            // Update local model
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                // Reload items to get updated state
                await self.loadItems()
                self.selectedIndex = index
            }
        }
    }

    // MARK: - Deletion

    /// Deletes the selected item
    func deleteSelected() async {
        guard let item = selectedItem else {
            return
        }
        await self.delete(item: item)
    }

    /// Deletes a specific item
    func delete(item: ClipboardItemDisplayModel) async {
        let success = await storageManager.deleteItem(byId: item.id)
        if success {
            // Remove from local list
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                self.items.remove(at: index)
                self.allItems.removeAll { $0.id == item.id }
                // Adjust selection
                if self.selectedIndex >= self.items.count {
                    self.selectedIndex = max(0, self.items.count - 1)
                }
            }
            self.logger.debug("Deleted item: \(item.id)")

            // Reload dedup cache so deleted items can be re-copied
            NotificationCenter.default.post(name: .clipboardHistoryChanged, object: nil)
        }
    }

    // MARK: - Favorites (Item-Specific)

    /// Toggles favorite status for a specific item
    func toggleFavorite(for item: ClipboardItemDisplayModel) async {
        let result = await storageManager.toggleFavorite(itemId: item.id)
        if result != nil {
            // Reload items to get updated state
            await self.loadItems()
            // Try to maintain the same selection position
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                self.selectedIndex = index
            }
            self.logger.debug("Toggled favorite for item: \(item.id)")
        }
    }

    // MARK: - OCR Text

    /// Copies the OCR-extracted text for an image item to the clipboard
    func copyOCRText(for item: ClipboardItemDisplayModel) async {
        guard let ocrText = item.ocrText, !ocrText.isEmpty else {
            self.logger.warning("No OCR text available for item: \(item.id)")
            return
        }

        // Copy OCR text to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(ocrText, forType: .string)

        self.logger.info("Copied OCR text for item: \(item.id)")
    }

    #if !APP_STORE

        // MARK: - Plugin Actions

        /// Executes a plugin menu item action on a clipboard item
        func executePluginAction(
            menuItem: PluginMenuItem,
            pluginId: String,
            for item: ClipboardItemDisplayModel
        ) async {
            guard let clipboardItem = await storageManager.fetchItem(byId: item.id) else {
                self.logger.error("Failed to fetch item for plugin action: \(item.id)")
                return
            }

            let content = self.makePluginContent(from: clipboardItem)

            self.logger.debug("Executing plugin action '\(menuItem.title)' for plugin \(pluginId)")

            // Find the matching registered transformer and call its closure synchronously
            // on MainActor. We cannot use the async execution paths (PluginHost.executeAction,
            // PluginUIAPI.executeMenuItem, or menuItem.action directly) because the closures
            // are nonisolated(unsafe) and PluginClipboardContent (NSObject) is not Sendable —
            // crossing actor boundaries causes EXC_BAD_INSTRUCTION at runtime.
            let transformers = PluginTransformAPI.shared.transformers(for: pluginId)
            guard let transformer = transformers.first(where: { $0.name == menuItem.title }),
                  let transform = transformer.transform
            else {
                self.logger.warning("No transformer found for '\(menuItem.title)' in plugin \(pluginId)")
                return
            }

            do {
                let result = try await transform(content)

                if let result {
                    // Pause monitoring to avoid re-capturing the transformed content
                    self.clipboardMonitor?.pause()

                    self.writePluginResultToClipboard(result)
                    self.logger.info("Plugin action completed: \(menuItem.title) for item \(item.id)")

                    // Hide panel, restore focus, and simulate paste (same as normal paste flow)
                    self.isVisible = false
                    self.restorePreviousAppFocus?()

                    try? await Task.sleep(for: .milliseconds(200))
                    self.pasteSimulator.simulatePaste()

                    try? await Task.sleep(for: .milliseconds(300))
                    self.clipboardMonitor?.resume()
                }
            } catch {
                self.logger.error("Plugin action failed: \(menuItem.title) — \(error.localizedDescription)")
            }
        }

        /// Writes plugin transform result to the system clipboard
        private func writePluginResultToClipboard(_ result: PluginClipboardContent) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            if let text = result.text {
                pasteboard.setString(text, forType: .string)
            }
            if let html = result.html {
                pasteboard.setString(html, forType: .html)
            }
            if let rtfData = result.rtfData {
                pasteboard.setData(rtfData, forType: .rtf)
            }
            if let image = result.image {
                pasteboard.writeObjects([image])
            }
            if let url = result.url {
                pasteboard.writeObjects([url as NSURL])
            }
        }

        /// Converts a CoreData ClipboardItem to PluginClipboardContent
        private func makePluginContent(from item: ClipboardItem) -> PluginClipboardContent {
            let content = PluginClipboardContent()
            content.contentTypeIdentifier = item.contentType ?? ContentType.plainText.rawValue
            content.sourceAppBundleId = item.sourceAppBundleId
            content.timestamp = item.timestamp ?? Date()

            if let contentData = item.content {
                // Use full text content, not the truncated plainTextPreview
                content.text = contentData.textContent ?? item.plainTextPreview

                if let html = contentData.htmlContent {
                    content.html = html
                }
                if let rtfData = contentData.rtfData {
                    content.rtfData = rtfData
                }
                if let imageData = contentData.imageData {
                    content.imageData = imageData
                    content.image = NSImage(data: imageData)
                }
                if let urlString = contentData.urlString, let url = URL(string: urlString) {
                    content.url = url
                }
            } else {
                content.text = item.plainTextPreview
            }

            return content
        }
    #endif

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

        self.collections = displayModels
        self.logger.debug("Loaded \(self.collections.count) collections")
    }

    /// Applies the current collection filter and reloads items
    func applyCollectionFilter() async {
        // Clear search when changing collection
        if self.isSearchActive {
            self.clearSearch()
        }

        await self.loadItems()
    }

    /// Creates a new collection
    func createCollection(_ model: CollectionDisplayModel) async {
        _ = await self.storageManager.saveCollection(from: model)
        await self.loadCollections()
        self.showCollectionEditor = false
        self.editingCollection = nil
        self.logger.debug("Created collection: \(model.name)")
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
            await self.loadCollections()
            // Reload items if this is the selected collection
            if self.selectedCollectionId == model.id {
                await self.loadItems()
            }
        }

        self.showCollectionEditor = false
        self.editingCollection = nil
        self.logger.debug("Updated collection: \(model.name)")
    }

    /// Deletes a collection
    func deleteCollection(_ collection: CollectionDisplayModel) async {
        let success = await storageManager.deleteCollection(collection.id)
        if success {
            // Clear selection if we deleted the selected collection
            if self.selectedCollectionId == collection.id {
                self.selectedCollectionId = nil
            }
            await self.loadCollections()
            self.logger.debug("Deleted collection: \(collection.name)")
        }
    }

    /// Shows the editor for creating a new collection
    func showNewCollectionEditor() {
        self.editingCollection = nil
        self.showCollectionEditor = true
    }

    /// Shows the editor for editing an existing collection
    func showEditCollectionEditor(_ collection: CollectionDisplayModel) {
        self.editingCollection = collection
        self.showCollectionEditor = true
    }

    /// Toggles the collections sidebar visibility
    func toggleCollectionsSidebar() {
        self.showCollectionsSidebar.toggle()
        if self.showCollectionsSidebar {
            Task { await self.loadCollections() }
        }
    }

    /// Adds an item to a manual collection
    func addItemToCollection(_ item: ClipboardItemDisplayModel, collection: CollectionDisplayModel) async {
        guard !collection.isAutomatic else {
            return
        }

        // Fetch the actual ClipboardItem
        guard let clipboardItem = await storageManager.fetchItem(byId: item.id),
              let smartCollection = await storageManager.fetchCollection(byId: collection.id)
        else {
            return
        }

        let success = await storageManager.addItemToCollection(clipboardItem, collection: smartCollection)
        if success {
            await self.loadCollections() // Update item counts
            self.logger.debug("Added item \(item.id) to collection \(collection.name)")
        }
    }

    /// Removes an item from a manual collection
    func removeItemFromCollection(_ item: ClipboardItemDisplayModel, collection: CollectionDisplayModel) async {
        guard !collection.isAutomatic else {
            return
        }

        guard let clipboardItem = await storageManager.fetchItem(byId: item.id),
              let smartCollection = await storageManager.fetchCollection(byId: collection.id)
        else {
            return
        }

        let success = await storageManager.removeItemFromCollection(clipboardItem, collection: smartCollection)
        if success {
            await self.loadCollections()
            // Reload items if viewing this collection
            if self.selectedCollectionId == collection.id {
                await self.loadItems()
            }
            self.logger.debug("Removed item \(item.id) from collection \(collection.name)")
        }
    }

    // MARK: Private

    // MARK: - Dependencies

    /// Storage manager for fetching items
    private let storageManager: StorageManager

    /// Search engine for full-text and semantic search
    private let searchEngine: HybridSearchEngine

    /// Settings manager for reading search preferences
    private let settingsManager: SettingsManager

    // Paste simulator for Cmd+V simulation
    #if !APP_STORE
        private let pasteSimulator = PasteSimulator()
    #endif

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

    // MARK: - Search Setup

    /// Sets up debounced search subscription
    private func setupSearchDebounce() {
        self.searchQuerySubject
            .debounce(for: .milliseconds(self.searchDebounceMs), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                guard let self else {
                    return
                }
                Task {
                    await self.performSearch(query: query)
                }
            }
            .store(in: &self.cancellables)
    }

    /// Loads OCR text for image items and updates display models
    private func loadOCRTextForItems() async {
        // Get IDs of image items
        let imageItemIds = self.allItems
            .filter(\.contentType.isImageType)
            .map(\.id)

        guard !imageItemIds.isEmpty else {
            return
        }

        // Fetch OCR text for all image items
        let ocrTexts = await storageManager.fetchOCRTexts(for: imageItemIds)

        // Update display models with OCR text
        self.allItems = self.allItems.map { item in
            if let ocrText = ocrTexts[item.id] {
                return item.withOCRText(ocrText)
            }
            return item
        }
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
            let typeStrings = contentTypeFilter.contentTypes.map(\.rawValue)
            predicates.append(NSPredicate(format: "contentType IN %@", typeStrings))
        }

        // Favorites filter
        if self.activeFilters.favoritesOnly {
            predicates.append(NSPredicate(format: "isFavorite == YES"))
        }

        // Tag filter
        if !self.activeFilters.selectedTagIds.isEmpty {
            predicates.append(NSPredicate(
                format: "ANY tags.id IN %@",
                self.activeFilters.selectedTagIds as CVarArg
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
        if self.selectedIndex >= self.items.count {
            self.selectedIndex = self.items.isEmpty ? -1 : 0
        } else if self.selectedIndex < 0, !self.items.isEmpty {
            self.selectedIndex = 0
        }
    }

    /// Copies the item content to the system clipboard
    private func copyToClipboard(item: ClipboardItemDisplayModel) async -> Bool {
        // Fetch the full item from storage to get the actual content
        guard let clipboardItem = await storageManager.fetchItem(byId: item.id),
              let contentData = clipboardItem.content
        else {
            self.logger.error("Failed to fetch item content: \(item.id)")
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        self.writeContentToPasteboard(pasteboard, contentType: item.contentType, contentData: contentData)

        return true
    }

    /// Writes content data to the pasteboard based on the content type
    private func writeContentToPasteboard(
        _ pasteboard: NSPasteboard,
        contentType: ContentType,
        contentData: ClipboardContentData
    ) {
        switch contentType {
        case .plainText:
            self.writeTextContent(pasteboard, contentData: contentData)
        case .richText:
            self.writeRichTextContent(pasteboard, contentData: contentData)
        case .html:
            self.writeHTMLContent(pasteboard, contentData: contentData)
        case .png,
             .jpeg,
             .tiff:
            self.writeImageContent(pasteboard, contentData: contentData)
        case .url,
             .fileURL:
            self.writeURLContent(pasteboard, contentData: contentData)
        case .pdf:
            self.writePDFContent(pasteboard, contentData: contentData)
        }
    }

    private func writeTextContent(_ pasteboard: NSPasteboard, contentData: ClipboardContentData) {
        if let text = contentData.textContent {
            pasteboard.setString(text, forType: .string)
        }
    }

    private func writeRichTextContent(_ pasteboard: NSPasteboard, contentData: ClipboardContentData) {
        if let rtfData = contentData.rtfData {
            pasteboard.setData(rtfData, forType: .rtf)
        }
        if let text = contentData.textContent {
            pasteboard.setString(text, forType: .string)
        }
    }

    private func writeHTMLContent(_ pasteboard: NSPasteboard, contentData: ClipboardContentData) {
        if let htmlData = contentData.htmlData {
            pasteboard.setData(htmlData, forType: .html)
        }
        if let text = contentData.textContent {
            pasteboard.setString(text, forType: .string)
        }
    }

    private func writeImageContent(_ pasteboard: NSPasteboard, contentData: ClipboardContentData) {
        if let imageData = contentData.imageData,
           let image = NSImage(data: imageData)
        {
            pasteboard.writeObjects([image])
        }
    }

    private func writeURLContent(_ pasteboard: NSPasteboard, contentData: ClipboardContentData) {
        if let urlString = contentData.textContent,
           let url = URL(string: urlString)
        {
            pasteboard.writeObjects([url as NSURL])
        }
    }

    private func writePDFContent(_ pasteboard: NSPasteboard, contentData: ClipboardContentData) {
        if let pdfData = contentData.pdfData {
            pasteboard.setData(pdfData, forType: .pdf)
        }
    }
}
