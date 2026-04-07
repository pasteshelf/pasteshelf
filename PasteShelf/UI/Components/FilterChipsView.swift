//
//  FilterChipsView.swift
//  PasteShelf
//
//  Horizontal scrollable filter chips for content type and favorites filtering.
//  Displays active filters and allows toggling them.
//

import os.log
import SwiftUI

private let filterChipsLogger = Logger(
    subsystem: "com.pasteshelf",
    category: "filter-chips"
)

// MARK: - FilterChipsView

/// Horizontal filter chips for quick filtering
struct FilterChipsView: View {
    /// Currently selected content type filter
    @Binding var selectedContentType: ContentTypeFilter?

    /// Whether favorites filter is active
    @Binding var favoritesOnly: Bool

    /// Called when a content type filter is toggled
    var onContentTypeToggle: ((ContentTypeFilter) -> Void)?

    /// Called when favorites filter is toggled
    var onFavoritesToggle: (() -> Void)?

    /// Available tags for filtering
    var availableTags: [TagDisplayModel] = []

    /// Whether to show the tag filter row
    var showTagFilters: Bool = true

    /// Currently selected tag IDs
    @Binding var selectedTagIds: Set<UUID>

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // First row: Favorites + content type filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterChip(
                        title: "Favorites",
                        icon: "star.fill",
                        isSelected: self.favoritesOnly,
                        selectedColor: .orange
                    ) {
                        self.favoritesOnly.toggle()
                        self.onFavoritesToggle?()
                    }

                    if !ContentTypeFilter.allCases.isEmpty {
                        Divider()
                            .frame(height: 16)
                            .padding(.horizontal, 2)
                    }

                    ForEach(ContentTypeFilter.allCases) { filter in
                        FilterChip(
                            title: filter.displayName,
                            icon: filter.icon,
                            isSelected: self.selectedContentType == filter
                        ) {
                            if self.selectedContentType == filter {
                                self.selectedContentType = nil
                            } else {
                                self.selectedContentType = filter
                            }
                            self.onContentTypeToggle?(filter)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            // Second row: Tag filters (only if tags exist and setting is enabled)
            if self.showTagFilters, !self.availableTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(self.availableTags) { tag in
                            FilterChip(
                                title: tag.name,
                                icon: "tag",
                                isSelected: self.selectedTagIds.contains(tag.id),
                                selectedColor: tag.color
                            ) {
                                if self.selectedTagIds.contains(tag.id) {
                                    self.selectedTagIds.remove(tag.id)
                                } else {
                                    self.selectedTagIds.insert(tag.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - FilterChip

/// Individual filter chip button
struct FilterChip: View {
    // MARK: Internal

    /// Title text for the chip
    let title: String

    /// SF Symbol icon name
    let icon: String

    /// Whether this chip is selected
    let isSelected: Bool

    /// Color when selected (default is accent color)
    var selectedColor: Color = .accentColor

    /// Action when tapped
    let action: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: 4) {
                Image(systemName: self.icon)
                    .font(.system(size: 10, weight: .medium))
                Text(self.title)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(self.background)
            .foregroundStyle(self.foregroundColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(self.borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Private

    private var background: Color {
        self.isSelected ? self.selectedColor.opacity(0.15) : Color.clear
    }

    private var foregroundColor: Color {
        self.isSelected ? self.selectedColor : .secondary
    }

    private var borderColor: Color {
        self.isSelected ? self.selectedColor.opacity(0.3) : Color.secondary.opacity(0.3)
    }
}

// MARK: - CompactFilterChipsView

/// Compact version with icons only
struct CompactFilterChipsView: View {
    @Binding var selectedContentType: ContentTypeFilter?
    @Binding var favoritesOnly: Bool

    var onContentTypeToggle: ((ContentTypeFilter) -> Void)?
    var onFavoritesToggle: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            // Favorites
            CompactFilterChip(
                icon: "star.fill",
                isSelected: self.favoritesOnly,
                selectedColor: .orange
            ) {
                self.favoritesOnly.toggle()
                self.onFavoritesToggle?()
            }

            // Content types
            ForEach(ContentTypeFilter.allCases) { filter in
                CompactFilterChip(
                    icon: filter.icon,
                    isSelected: self.selectedContentType == filter
                ) {
                    if self.selectedContentType == filter {
                        self.selectedContentType = nil
                    } else {
                        self.selectedContentType = filter
                    }
                    self.onContentTypeToggle?(filter)
                }
            }
        }
    }
}

// MARK: - CompactFilterChip

/// Individual compact filter chip (icon only)
struct CompactFilterChip: View {
    let icon: String
    let isSelected: Bool
    var selectedColor: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            Image(systemName: self.icon)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 24, height: 24)
                .background(self.isSelected ? self.selectedColor.opacity(0.15) : Color.clear)
                .foregroundStyle(self.isSelected ? self.selectedColor : .secondary)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            self.isSelected ? self.selectedColor.opacity(0.3) : Color.secondary.opacity(0.2),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .help(self.icon)
    }
}

// MARK: - ActiveFilterSummaryView

/// Shows a summary of active filters with clear button
struct ActiveFilterSummaryView: View {
    let activeFilters: ActiveFilters
    var onClear: (() -> Void)?

    var body: some View {
        if self.activeFilters.hasActiveFilters {
            HStack(spacing: 4) {
                Text(self.activeFilters.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if self.onClear != nil {
                    Button(
                        action: { self.onClear?() },
                        label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    )
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct FilterChipsView_Previews: PreviewProvider {
        struct PreviewWrapper: View {
            // MARK: Internal

            var body: some View {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Standard Filter Chips")
                        .font(.caption).foregroundStyle(.secondary)
                    FilterChipsView(
                        selectedContentType: self.$selectedType,
                        favoritesOnly: self.$favoritesOnly,
                        selectedTagIds: self.$selectedTagIds
                    )
                    .background(Color(nsColor: .controlBackgroundColor))

                    Text("With Selection")
                        .font(.caption).foregroundStyle(.secondary)
                    FilterChipsView(
                        selectedContentType: .constant(.text),
                        favoritesOnly: .constant(true),
                        selectedTagIds: .constant([])
                    )
                    .background(Color(nsColor: .controlBackgroundColor))

                    Text("Compact Filter Chips")
                        .font(.caption).foregroundStyle(.secondary)
                    CompactFilterChipsView(
                        selectedContentType: self.$selectedType,
                        favoritesOnly: self.$favoritesOnly
                    )

                    Text("Active Filter Summary")
                        .font(.caption).foregroundStyle(.secondary)
                    ActiveFilterSummaryView(
                        activeFilters: ActiveFilters(
                            searchQuery: "hello",
                            contentTypeFilter: .text,
                            favoritesOnly: true
                        )
                    ) {
                        filterChipsLogger.debug("Clear filters")
                    }
                }
                .padding()
                .frame(width: 350)
            }

            // MARK: Private

            @State private var selectedType: ContentTypeFilter?
            @State private var favoritesOnly = false
            @State private var selectedTagIds: Set<UUID> = []
        }

        static var previews: some View {
            PreviewWrapper()
        }
    }
#endif
