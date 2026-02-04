//
//  CollectionRowView.swift
//  PasteShelf
//
//  Displays a single collection row in the sidebar.
//

import SwiftUI

/// Displays a collection as a row in the sidebar
struct CollectionRowView: View {
    // MARK: - Properties

    /// The collection to display
    let collection: CollectionDisplayModel

    /// Whether this row is selected
    let isSelected: Bool

    /// Called when the row is tapped
    let onSelect: () -> Void

    // MARK: - State

    @State private var isHovered = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            iconView

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .primary)
                    .lineLimit(1)

                // Subtitle showing item count
                if collection.itemCount > 0 {
                    Text("\(collection.itemCount) items")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Automatic indicator
            if collection.isAutomatic {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .help("Smart Collection - items are added automatically")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundView)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Icon View

    @ViewBuilder
    private var iconView: some View {
        ZStack {
            if collection.hasCustomColor {
                RoundedRectangle(cornerRadius: 5)
                    .fill(collection.color.opacity(0.15))
            }

            Image(systemName: collection.icon)
                .font(.system(size: 14))
                .foregroundStyle(collection.hasCustomColor ? collection.color : .secondary)
        }
        .frame(width: 26, height: 26)
    }

    // MARK: - Background View

    @ViewBuilder
    private var backgroundView: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
        } else if isHovered {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.05))
        } else {
            Color.clear
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var label = collection.name
        label += ", \(collection.itemCount) items"
        if collection.isAutomatic {
            label += ", smart collection"
        }
        return label
    }
}

// MARK: - Preview

#if DEBUG
    struct CollectionRowView_Previews: PreviewProvider {
        static var previews: some View {
            VStack(spacing: 2) {
                CollectionRowView(
                    collection: .sampleImages,
                    isSelected: true,
                    onSelect: {}
                )

                CollectionRowView(
                    collection: .sampleFromSafari,
                    isSelected: false,
                    onSelect: {}
                )

                CollectionRowView(
                    collection: .sampleRecentLinks,
                    isSelected: false,
                    onSelect: {}
                )

                CollectionRowView(
                    collection: .sampleFavorites,
                    isSelected: false,
                    onSelect: {}
                )
            }
            .frame(width: 200)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
#endif
