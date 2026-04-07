//
//  CollectionRowView.swift
//  PasteShelf
//
//  Displays a single collection row in the sidebar.
//

import SwiftUI

// MARK: - CollectionRowView

/// Displays a collection as a row in the sidebar
struct CollectionRowView: View {
    // MARK: Internal

    /// The collection to display
    let collection: CollectionDisplayModel

    /// Whether this row is selected
    let isSelected: Bool

    /// Called when the row is tapped
    let onSelect: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            self.iconView

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(self.collection.name)
                    .font(.system(size: 13, weight: self.isSelected ? .semibold : .regular))
                    .foregroundStyle(self.isSelected ? .primary : .primary)
                    .lineLimit(1)

                // Subtitle showing item count
                if self.collection.itemCount > 0 {
                    Text("\(self.collection.itemCount) items")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Automatic indicator
            if self.collection.isAutomatic {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .help("Smart Collection - items are added automatically")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(self.backgroundView)
        .contentShape(Rectangle())
        .onTapGesture {
            self.onSelect()
        }
        .onHover { hovering in
            self.isHovered = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityAddTraits(self.isSelected ? .isSelected : [])
    }

    // MARK: Private

    // MARK: - State

    @State private var isHovered = false

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var label = self.collection.name
        label += ", \(self.collection.itemCount) items"
        if self.collection.isAutomatic {
            label += ", smart collection"
        }
        return label
    }

    // MARK: - Icon View

    private var iconView: some View {
        ZStack {
            if self.collection.hasCustomColor {
                RoundedRectangle(cornerRadius: 5)
                    .fill(self.collection.color.opacity(0.15))
            }

            Image(systemName: self.collection.icon)
                .font(.system(size: 14))
                .foregroundStyle(self.collection.hasCustomColor ? self.collection.color : .secondary)
        }
        .frame(width: 26, height: 26)
    }

    // MARK: - Background View

    @ViewBuilder private var backgroundView: some View {
        if self.isSelected {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
        } else if self.isHovered {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.05))
        } else {
            Color.clear
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct CollectionRowView_Previews: PreviewProvider {
        static var previews: some View {
            VStack(spacing: 2) {
                CollectionRowView(
                    collection: .sampleImages,
                    isSelected: true
                ) {}

                CollectionRowView(
                    collection: .sampleFromSafari,
                    isSelected: false
                ) {}

                CollectionRowView(
                    collection: .sampleRecentLinks,
                    isSelected: false
                ) {}

                CollectionRowView(
                    collection: .sampleFavorites,
                    isSelected: false
                ) {}
            }
            .frame(width: 200)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
#endif
