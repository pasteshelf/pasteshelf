//
//  FloatingPanelView.swift
//  PasteShelf
//
//  SwiftUI root view for the floating clipboard history panel.
//  Displays list of clipboard items with keyboard navigation support.
//

import SwiftUI

/// Main view for the floating clipboard history panel
struct FloatingPanelView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: FloatingPanelViewModel

    /// Observe settings for reactive updates
    @EnvironmentObject var settingsManager: SettingsManager

    /// Focus state for keyboard handling
    @FocusState private var isFocused: Bool

    /// Focus state for search field
    @FocusState private var isSearchFocused: Bool

    // MARK: - Body

    var body: some View {
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
        .frame(width: settingsManager.appearance.panelWidth.width, height: 520)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .focusable()
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
            Task {
                await viewModel.deleteSelected()
            }
            return .handled
        }
        .onKeyPress(characters: .decimalDigits, phases: .down) { press in
            guard settingsManager.shortcuts.quickPasteEnabled,
                  press.modifiers.contains(.command),
                  let digit = press.characters.first?.wholeNumberValue,
                  digit >= 1, digit <= 9 else {
                return .ignored
            }
            let index = digit - 1
            guard index < viewModel.items.count else { return .ignored }
            viewModel.select(at: index)
            Task {
                await viewModel.pasteSelected()
            }
            return .handled
        }
        // Note: Cmd+S and Cmd+F shortcuts are handled via keyboardShortcut on buttons in the menu bar
    }

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

    /// Whether the tag picker popover is shown
    @State private var showTagPicker = false

    /// Available tags loaded from storage
    @State private var availableTags: [TagDisplayModel] = []

    private var filterChipsView: some View {
        HStack(spacing: 0) {
            FilterChipsView(
                selectedContentType: Binding(
                    get: { viewModel.activeFilters.contentTypeFilter },
                    set: { newValue in
                        Task {
                            if let filter = newValue {
                                await viewModel.toggleContentTypeFilter(filter)
                            } else if viewModel.activeFilters.contentTypeFilter != nil {
                                await viewModel.toggleContentTypeFilter(viewModel.activeFilters.contentTypeFilter!)
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
                )
            )

            // Tag filter button
            Button {
                Task {
                    availableTags = await viewModel.loadAvailableTags()
                }
                showTagPicker.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .font(.system(size: 10, weight: .medium))
                    if !viewModel.activeFilters.selectedTagIds.isEmpty {
                        Text("\(viewModel.activeFilters.selectedTagIds.count)")
                            .font(.system(size: 10, weight: .bold))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    viewModel.activeFilters.selectedTagIds.isEmpty
                        ? Color.clear
                        : Color.accentColor.opacity(0.15)
                )
                .foregroundColor(
                    viewModel.activeFilters.selectedTagIds.isEmpty
                        ? .secondary
                        : .accentColor
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            viewModel.activeFilters.selectedTagIds.isEmpty
                                ? Color.secondary.opacity(0.3)
                                : Color.accentColor.opacity(0.3),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
            .popover(isPresented: $showTagPicker) {
                TagPickerView(
                    availableTags: availableTags,
                    selectedTagIds: Binding(
                        get: { viewModel.activeFilters.selectedTagIds },
                        set: { newValue in
                            viewModel.activeFilters.selectedTagIds = newValue
                        }
                    ),
                    onCreateTag: { name, color in
                        Task {
                            availableTags = await viewModel.createTag(name: name, color: color)
                        }
                    },
                    onSelectionChanged: {
                        Task {
                            await viewModel.loadItems()
                        }
                    }
                )
            }
        }
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
            ScrollView {
                if viewModel.shouldShowGroupedView {
                    // Grouped by date
                    groupedItemsContent
                } else {
                    // Flat list (search results or no grouping)
                    flatItemsContent
                }
            }
            .onChange(of: viewModel.selectedIndex) { _, newIndex in
                guard newIndex >= 0, newIndex < viewModel.items.count else { return }
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

    private func itemRow(for item: ClipboardItemDisplayModel, index: Int? = nil) -> some View {
        let actualIndex = index ?? viewModel.items.firstIndex(where: { $0.id == item.id }) ?? 0
        let matchRanges = viewModel.matchRanges(for: item.id)

        return ClipboardItemRow(
            item: item,
            index: actualIndex,
            isSelected: viewModel.selectedIndex == actualIndex,
            searchHighlights: matchRanges,
            searchQuery: viewModel.isSearchActive ? viewModel.searchQuery : nil,
            onSelect: {
                viewModel.select(at: actualIndex)
            },
            onPaste: {
                Task {
                    await viewModel.paste(item: item)
                }
            },
            onCopyOCRText: item.hasOCRText ? {
                Task {
                    await viewModel.copyOCRText(for: item)
                }
            } : nil,
            onDelete: {
                Task {
                    await viewModel.delete(item: item)
                }
            },
            onToggleFavorite: {
                Task {
                    await viewModel.toggleFavorite(for: item)
                }
            }
        )
        .id(item.id)
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
