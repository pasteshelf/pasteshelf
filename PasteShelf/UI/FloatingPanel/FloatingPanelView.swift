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
            if viewModel.showCollectionsSidebar {
                CollectionsSidebarView(
                    collections: viewModel.collections,
                    selectedCollectionId: $viewModel.selectedCollectionId,
                    onEdit: { collection in
                        viewModel.editingCollection = collection
                        viewModel.showCollectionEditor = true
                    },
                    onDelete: { collection in
                        Task { await viewModel.deleteCollection(collection) }
                    },
                    onCreate: {
                        viewModel.editingCollection = nil
                        viewModel.showCollectionEditor = true
                    }
                )
                .frame(width: 180)

                Divider()
            }

            // Main content
            VStack(spacing: 0) {
                // Header with title
                headerView

                // Search field
                searchFieldView

                // Filter chips
                filterChipsView

                Divider()

                // Content with animations
                Group {
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.items.isEmpty {
                        emptyStateView
                    } else {
                        itemListView
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
                .animation(.easeInOut(duration: 0.2), value: viewModel.items.count)
            }
        }
        .sheet(isPresented: $viewModel.showCollectionEditor) {
            CollectionEditorView(
                collection: viewModel.editingCollection,
                onSave: { model in
                    Task {
                        if viewModel.editingCollection != nil {
                            await viewModel.updateCollection(model)
                        } else {
                            await viewModel.createCollection(model)
                        }
                    }
                    viewModel.showCollectionEditor = false
                },
                onCancel: {
                    viewModel.showCollectionEditor = false
                }
            )
        }
        .frame(width: settingsManager.appearance.panelWidth.width, height: 520)
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
        .focused($isFocused)
        .onAppear {
            isFocused = true
        }
        .onKeyPress(keys: [.downArrow]) { _ in
            viewModel.selectNext()
            return .handled
        }
        .onKeyPress(keys: [.upArrow]) { _ in
            viewModel.selectPrevious()
            return .handled
        }
        .onKeyPress(keys: [.return]) { _ in
            Task {
                await viewModel.pasteSelected()
            }
            return .handled
        }
        .onKeyPress(keys: [.escape]) { _ in
            if viewModel.isSearchActive {
                viewModel.clearSearch()
                return .handled
            }
            viewModel.hide()
            return .handled
        }
        .onKeyPress(keys: [.delete]) { _ in
            guard !isSearchFocused else {
                return .ignored
            }
            Task {
                await viewModel.deleteSelected()
            }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "\u{08}\u{7F}"), phases: .down) { _ in
            guard !isSearchFocused else {
                return .ignored
            }
            Task {
                await viewModel.deleteSelected()
            }
            return .handled
        }
        .onKeyPress(characters: .decimalDigits, phases: .down) { press in
            guard !isSearchFocused else {
                return .ignored
            }
            guard settingsManager.shortcuts.quickPasteEnabled,
                  let digit = press.characters.first?.wholeNumberValue,
                  digit >= 1, digit <= 9
            else {
                return .ignored
            }
            let index = digit - 1
            guard index < viewModel.items.count else {
                return .ignored
            }
            viewModel.select(at: index)
            if press.modifiers.contains(.command) {
                Task {
                    await viewModel.pasteSelected()
                }
            }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "s"), phases: .down) { press in
            guard press.modifiers.contains(.command) else {
                return .ignored
            }
            Task {
                await viewModel.toggleFavorite()
            }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "f"), phases: .down) { press in
            guard press.modifiers.contains(.command) else {
                return .ignored
            }
            isSearchFocused = true
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
            if viewModel.isSemanticSearchActive {
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
            } else if viewModel.isSearchActive {
                Text("\(viewModel.items.count) results")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("\(viewModel.items.count) items")
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
            text: $viewModel.searchQuery,
            placeholder: "Search clipboard...",
            onSubmit: {
                // Optional: do something on enter
            },
            onClear: {
                viewModel.clearSearch()
            },
            autoFocus: false
        )
        .focused($isSearchFocused)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    // MARK: - Filter Chips

    private var filterChipsView: some View {
        FilterChipsView(
            selectedContentType: Binding(
                get: { viewModel.activeFilters.contentTypeFilter },
                set: { newValue in
                    Task {
                        if let filter = newValue {
                            await viewModel.toggleContentTypeFilter(filter)
                        } else if let current = viewModel.activeFilters.contentTypeFilter {
                            await viewModel.toggleContentTypeFilter(current)
                        }
                    }
                }
            ),
            favoritesOnly: Binding(
                get: { viewModel.activeFilters.favoritesOnly },
                set: { _ in
                    Task {
                        await viewModel.toggleFavoritesFilter()
                    }
                }
            ),
            availableTags: viewModel.availableTags,
            showTagFilters: settingsManager.appearance.showTagFilters,
            selectedTagIds: Binding(
                get: { viewModel.activeFilters.selectedTagIds },
                set: { newValue in
                    let old = viewModel.activeFilters.selectedTagIds
                    let toggled = newValue.symmetricDifference(old)
                    if let tagId = toggled.first {
                        Task {
                            await viewModel.toggleTagFilter(tagId)
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
            if viewModel.isSearchActive {
                EmptyStateView.noSearchResults {
                    viewModel.clearSearch()
                }
            } else if viewModel.activeFilters.hasActiveFilters {
                EmptyStateView.noFilteredResults {
                    Task {
                        await viewModel.clearAllFilters()
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
                if viewModel.shouldShowGroupedView {
                    // Grouped by date
                    groupedItemsContent
                } else {
                    // Flat list (search results or no grouping)
                    flatItemsContent
                }
            }
            .onChange(of: viewModel.selectedIndex) { _, newIndex in
                guard newIndex >= 0, newIndex < viewModel.items.count else {
                    return
                }
                let item = viewModel.items[newIndex]
                let itemId = item.id
                withAnimation {
                    proxy.scrollTo(itemId, anchor: .center)
                }

                // Announce to VoiceOver
                AccessibilityAnnouncement.announceSelection(
                    at: newIndex,
                    of: viewModel.items.count,
                    item: item.displayText
                )
            }
        }
    }

    // MARK: - Grouped Items Content

    private var groupedItemsContent: some View {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(viewModel.groupedItems) { section in
                Section {
                    ForEach(section.items) { item in
                        itemRow(for: item)
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
            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                itemRow(for: item, index: index)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Item Row

    private func itemRow(
        for item: ClipboardItemDisplayModel,
        index: Int? = nil
    ) -> some View {
        let actualIndex = index ?? viewModel.items.firstIndex { $0.id == item.id } ?? 0
        let matchRanges = viewModel.matchRanges(for: item.id)

        return buildItemRow(
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
                isSelected: viewModel.selectedIndex == actualIndex,
                searchHighlights: matchRanges,
                searchQuery: viewModel.isSearchActive ? viewModel.searchQuery : nil,
                onSelect: { viewModel.select(at: actualIndex) },
                onPaste: { Task { await viewModel.paste(item: item) } },
                onCopyOCRText: item.hasOCRText ? {
                    Task { await viewModel.copyOCRText(for: item) }
                } : nil,
                onDelete: { Task { await viewModel.delete(item: item) } },
                onToggleFavorite: {
                    Task { await viewModel.toggleFavorite(for: item) }
                },
                onPluginAction: { menuItem, pluginId in
                    Task {
                        await viewModel.executePluginAction(
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
                isSelected: viewModel.selectedIndex == actualIndex,
                searchHighlights: matchRanges,
                searchQuery: viewModel.isSearchActive ? viewModel.searchQuery : nil,
                onSelect: { viewModel.select(at: actualIndex) },
                onPaste: { Task { await viewModel.paste(item: item) } },
                onCopyOCRText: item.hasOCRText ? {
                    Task { await viewModel.copyOCRText(for: item) }
                } : nil,
                onDelete: { Task { await viewModel.delete(item: item) } },
                onToggleFavorite: {
                    Task { await viewModel.toggleFavorite(for: item) }
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
