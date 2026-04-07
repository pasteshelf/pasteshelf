//
//  FloatingPanelView.swift
//  PasteShelf
//
//  SwiftUI root view for the floating clipboard history panel.
//  Displays list of clipboard items with keyboard navigation support.
//

// swiftformat:disable organizeDeclarations

import SwiftUI

// MARK: - FloatingPanelView

/// Main view for the floating clipboard history panel
struct FloatingPanelView: View { // swiftlint:disable:this type_body_length
    // MARK: Internal

    @ObservedObject var viewModel: FloatingPanelViewModel

    /// Observe settings for reactive updates
    @EnvironmentObject var settingsManager: SettingsManager

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Collections sidebar (togglable)
            if self.viewModel.showCollectionsSidebar {
                CollectionsSidebarView(
                    collections: self.viewModel.collections,
                    selectedCollectionId: self.$viewModel.selectedCollectionId,
                    onEdit: { collection in
                        self.viewModel.editingCollection = collection
                        self.viewModel.showCollectionEditor = true
                    },
                    onDelete: { collection in
                        Task { await self.viewModel.deleteCollection(collection) }
                    },
                    onCreate: {
                        self.viewModel.editingCollection = nil
                        self.viewModel.showCollectionEditor = true
                    }
                )
                .frame(width: 180)

                Divider()
            }

            // Main content
            VStack(spacing: 0) {
                // Header with title
                self.headerView

                // Search field
                self.searchFieldView

                // Filter chips
                self.filterChipsView

                Divider()

                // Content with animations
                Group {
                    if self.viewModel.isLoading {
                        self.loadingView
                    } else if self.viewModel.items.isEmpty {
                        self.emptyStateView
                    } else {
                        self.itemListView
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: self.viewModel.isLoading)
                .animation(.easeInOut(duration: 0.2), value: self.viewModel.items.count)
            }
        }
        .sheet(isPresented: self.$viewModel.showCollectionEditor) {
            CollectionEditorView(
                collection: self.viewModel.editingCollection,
                onSave: { model in
                    Task {
                        if self.viewModel.editingCollection != nil {
                            await self.viewModel.updateCollection(model)
                        } else {
                            await self.viewModel.createCollection(model)
                        }
                    }
                    self.viewModel.showCollectionEditor = false
                },
                onCancel: {
                    self.viewModel.showCollectionEditor = false
                }
            )
        }
        .frame(width: self.settingsManager.appearance.panelWidth.width, height: 520)
        .background(
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .focusable()
        .focusEffectDisabled()
        .focused(self.$isFocused)
        .onAppear {
            self.isFocused = true
        }
        .onKeyPress(keys: [.downArrow]) { _ in
            self.viewModel.selectNext()
            return .handled
        }
        .onKeyPress(keys: [.upArrow]) { _ in
            self.viewModel.selectPrevious()
            return .handled
        }
        .onKeyPress(keys: [.return]) { _ in
            Task {
                await self.viewModel.pasteSelected()
            }
            return .handled
        }
        .onKeyPress(keys: [.escape]) { _ in
            if self.viewModel.isSearchActive {
                self.viewModel.clearSearch()
                return .handled
            }
            self.viewModel.hide()
            return .handled
        }
        .onKeyPress(keys: [.delete]) { _ in
            guard !self.isSearchFocused else {
                return .ignored
            }
            Task {
                await self.viewModel.deleteSelected()
            }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "\u{08}\u{7F}"), phases: .down) { _ in
            guard !self.isSearchFocused else {
                return .ignored
            }
            Task {
                await self.viewModel.deleteSelected()
            }
            return .handled
        }
        .onKeyPress(characters: .decimalDigits, phases: .down) { press in
            guard !self.isSearchFocused else {
                return .ignored
            }
            guard self.settingsManager.shortcuts.quickPasteEnabled,
                  let digit = press.characters.first?.wholeNumberValue,
                  digit >= 1, digit <= 9
            else {
                return .ignored
            }
            let index = digit - 1
            guard index < self.viewModel.items.count else {
                return .ignored
            }
            self.viewModel.select(at: index)
            if press.modifiers.contains(.command) {
                Task {
                    await self.viewModel.pasteSelected()
                }
            }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "s"), phases: .down) { press in
            guard press.modifiers.contains(.command) else {
                return .ignored
            }
            Task {
                await self.viewModel.toggleFavorite()
            }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "f"), phases: .down) { press in
            guard press.modifiers.contains(.command) else {
                return .ignored
            }
            self.isSearchFocused = true
            return .handled
        }
    }

    // MARK: Private

    /// Focus state for keyboard handling
    @FocusState private var isFocused: Bool

    /// Focus state for search field
    @FocusState private var isSearchFocused: Bool

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Clipboard History")
                .font(.headline)
                .foregroundColor(.primary)

            // Semantic search indicator
            if self.viewModel.isSemanticSearchActive {
                HStack(spacing: 3) {
                    Image(systemName: "brain")
                        .font(.caption2)
                    Text("AI")
                        .font(.caption2.bold())
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.15))
                .foregroundStyle(.purple)
                .clipShape(Capsule())
                .help("Results powered by semantic search")
            }

            Spacer()

            // Show search state or item count
            if case let .searching(query) = viewModel.searchState {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Searching \"\(query)\"...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if self.viewModel.isSearchActive {
                Text("\(self.viewModel.items.count) results")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("\(self.viewModel.items.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Search Field

    private var searchFieldView: some View {
        SearchFieldView(
            text: self.$viewModel.searchQuery,
            placeholder: "Search clipboard...",
            onSubmit: {
                // Optional: do something on enter
            },
            onClear: {
                self.viewModel.clearSearch()
            },
            autoFocus: false
        )
        .focused(self.$isSearchFocused)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    // MARK: - Filter Chips

    private var filterChipsView: some View {
        FilterChipsView(
            selectedContentType: Binding(
                get: { self.viewModel.activeFilters.contentTypeFilter },
                set: { newValue in
                    Task {
                        if let filter = newValue {
                            await self.viewModel.toggleContentTypeFilter(filter)
                        } else if let current = viewModel.activeFilters.contentTypeFilter {
                            await self.viewModel.toggleContentTypeFilter(current)
                        }
                    }
                }
            ),
            favoritesOnly: Binding(
                get: { self.viewModel.activeFilters.favoritesOnly },
                set: { _ in
                    Task {
                        await self.viewModel.toggleFavoritesFilter()
                    }
                }
            ),
            availableTags: self.viewModel.availableTags,
            showTagFilters: self.settingsManager.appearance.showTagFilters,
            selectedTagIds: Binding(
                get: { self.viewModel.activeFilters.selectedTagIds },
                set: { newValue in
                    let old = self.viewModel.activeFilters.selectedTagIds
                    let toggled = newValue.symmetricDifference(old)
                    if let tagId = toggled.first {
                        Task {
                            await self.viewModel.toggleTagFilter(tagId)
                        }
                    }
                }
            )
        )
    }

    // MARK: - Loading View

    private var loadingView: some View {
        SkeletonLoadingView(rowCount: 6)
            .transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        Group {
            if self.viewModel.isSearchActive {
                EmptyStateView.noSearchResults {
                    self.viewModel.clearSearch()
                }
            } else if self.viewModel.activeFilters.hasActiveFilters {
                EmptyStateView.noFilteredResults {
                    Task {
                        await self.viewModel.clearAllFilters()
                    }
                }
            } else {
                EmptyStateView.noClipboardItems()
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)).animation(.easeInOut(duration: 0.2)))
    }

    // MARK: - Item List

    private var itemListView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                if self.viewModel.shouldShowGroupedView {
                    // Grouped by date
                    self.groupedItemsContent
                } else {
                    // Flat list (search results or no grouping)
                    self.flatItemsContent
                }
            }
            .onChange(of: self.viewModel.selectedIndex) { _, newIndex in
                guard newIndex >= 0, newIndex < self.viewModel.items.count else {
                    return
                }
                let item = self.viewModel.items[newIndex]
                let itemId = item.id
                withAnimation {
                    proxy.scrollTo(itemId, anchor: .center)
                }

                // Announce to VoiceOver
                AccessibilityAnnouncement.announceSelection(
                    at: newIndex,
                    of: self.viewModel.items.count,
                    item: item.displayText
                )
            }
        }
    }

    // MARK: - Grouped Items Content

    private var groupedItemsContent: some View {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(self.viewModel.groupedItems) { section in
                Section {
                    ForEach(section.items) { item in
                        self.itemRow(for: item)
                    }
                } header: {
                    DateGroupHeaderView(
                        group: section.group,
                        itemCount: section.count
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Flat Items Content

    private var flatItemsContent: some View {
        LazyVStack(spacing: 2) {
            ForEach(Array(self.viewModel.items.enumerated()), id: \.element.id) { index, item in
                self.itemRow(for: item, index: index)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Item Row

    private func itemRow(
        for item: ClipboardItemDisplayModel,
        index: Int? = nil
    ) -> some View {
        let actualIndex = index ?? self.viewModel.items.firstIndex { $0.id == item.id } ?? 0
        let matchRanges = self.viewModel.matchRanges(for: item.id)

        return self.buildItemRow(
            item: item,
            actualIndex: actualIndex,
            matchRanges: matchRanges
        )
        .id(item.id)
    }

    private func buildItemRow(
        item: ClipboardItemDisplayModel,
        actualIndex: Int,
        matchRanges: [MatchRange]
    ) -> ClipboardItemRow {
        #if !APP_STORE
            return ClipboardItemRow(
                item: item,
                index: actualIndex,
                isSelected: self.viewModel.selectedIndex == actualIndex,
                searchHighlights: matchRanges,
                searchQuery: self.viewModel.isSearchActive ? self.viewModel.searchQuery : nil,
                onSelect: { self.viewModel.select(at: actualIndex) },
                onPaste: { Task { await self.viewModel.paste(item: item) } },
                onCopyOCRText: item.hasOCRText ? {
                    Task { await self.viewModel.copyOCRText(for: item) }
                } : nil,
                onDelete: { Task { await self.viewModel.delete(item: item) } },
                onToggleFavorite: {
                    Task { await self.viewModel.toggleFavorite(for: item) }
                },
                onPluginAction: { menuItem, pluginId in
                    Task {
                        await self.viewModel.executePluginAction(
                            menuItem: menuItem,
                            pluginId: pluginId,
                            for: item
                        )
                    }
                }
            )
        #else
            return ClipboardItemRow(
                item: item,
                index: actualIndex,
                isSelected: self.viewModel.selectedIndex == actualIndex,
                searchHighlights: matchRanges,
                searchQuery: self.viewModel.isSearchActive ? self.viewModel.searchQuery : nil,
                onSelect: { self.viewModel.select(at: actualIndex) },
                onPaste: { Task { await self.viewModel.paste(item: item) } },
                onCopyOCRText: item.hasOCRText ? {
                    Task { await self.viewModel.copyOCRText(for: item) }
                } : nil,
                onDelete: { Task { await self.viewModel.delete(item: item) } },
                onToggleFavorite: {
                    Task { await self.viewModel.toggleFavorite(for: item) }
                }
            )
        #endif
    }
}

// MARK: - Preview

#if DEBUG
    struct FloatingPanelView_Previews: PreviewProvider {
        static var previews: some View {
            let viewModel = FloatingPanelViewModel()

            // Manually set items for preview
            FloatingPanelView(viewModel: viewModel)
                .environmentObject(SettingsManager.shared)
                .onAppear {
                    // Simulate some items in preview
                }
        }
    }
#endif
