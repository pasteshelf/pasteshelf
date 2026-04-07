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
                        isSelected: favoritesOnly,
                        selectedColor: .orange
                    ) {
                        favoritesOnly.toggle()
                        onFavoritesToggle?()
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
                            isSelected: selectedContentType == filter
                        ) {
                            if selectedContentType == filter {
                                selectedContentType = nil
                            } else {
                                selectedContentType = filter
                            }
                            onContentTypeToggle?(filter)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            // Second row: Tag filters (only if tags exist and setting is enabled)
            if showTagFilters, !availableTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(availableTags) { tag in
                            FilterChip(
                                title: tag.name,
                                icon: "tag",
                                isSelected: selectedTagIds.contains(tag.id),
                                selectedColor: tag.color
                            ) {
                                if selectedTagIds.contains(tag.id) {
                                    selectedTagIds.remove(tag.id)
                                } else {
                                    selectedTagIds.insert(tag.id)
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
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Private

    private var background: Color {
        isSelected ? selectedColor.opacity(0.15) : Color.clear
    }

    private var foregroundColor: Color {
        isSelected ? selectedColor : .secondary
    }

    private var borderColor: Color {
        isSelected ? selectedColor.opacity(0.3) : Color.secondary.opacity(0.3)
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
                isSelected: favoritesOnly,
                selectedColor: .orange
            ) {
                favoritesOnly.toggle()
                onFavoritesToggle?()
            }

            // Content types
            ForEach(ContentTypeFilter.allCases) { filter in
                CompactFilterChip(
                    icon: filter.icon,
                    isSelected: selectedContentType == filter
                ) {
                    if selectedContentType == filter {
                        selectedContentType = nil
                    } else {
                        selectedContentType = filter
                    }
                    onContentTypeToggle?(filter)
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
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 24, height: 24)
                .background(isSelected ? selectedColor.opacity(0.15) : Color.clear)
                .foregroundStyle(isSelected ? selectedColor : .secondary)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            isSelected ? selectedColor.opacity(0.3) : Color.secondary.opacity(0.2),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .help(icon)
    }
}

// MARK: - ActiveFilterSummaryView

/// Shows a summary of active filters with clear button
struct ActiveFilterSummaryView: View {
    let activeFilters: ActiveFilters
    var onClear: (() -> Void)?

    var body: some View {
        if activeFilters.hasActiveFilters {
            HStack(spacing: 4) {
                Text(activeFilters.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if onClear != nil {
                    Button(
                        action: { onClear?() },
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
                        selectedContentType: $selectedType,
                        favoritesOnly: $favoritesOnly,
                        selectedTagIds: $selectedTagIds
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
                        selectedContentType: $selectedType,
                        favoritesOnly: $favoritesOnly
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
