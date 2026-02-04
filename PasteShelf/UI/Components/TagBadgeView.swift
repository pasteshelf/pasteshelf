//
//  TagBadgeView.swift
//  PasteShelf
//
//  Displays a tag as a colored badge.
//  Used for showing tags on clipboard items.
//

import SwiftUI

/// Displays a tag as a small colored badge
struct TagBadgeView: View {
    // MARK: - Properties

    /// The tag to display
    let tag: TagDisplayModel

    /// Whether to show the close button
    var showRemoveButton: Bool = false

    /// Called when the remove button is tapped
    var onRemove: (() -> Void)?

    /// Size variant
    var size: TagBadgeSize = .small

    // MARK: - Body

    var body: some View {
        HStack(spacing: 2) {
            // Color indicator
            Circle()
                .fill(tag.color)
                .frame(width: size.dotSize, height: size.dotSize)

            // Tag name
            Text(tag.name)
                .font(size.font)
                .lineLimit(1)

            // Remove button
            if showRemoveButton {
                Button(action: { onRemove?() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: size.iconSize, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(tag.color.opacity(0.1))
        .foregroundStyle(tag.color)
        .clipShape(Capsule())
    }
}

// MARK: - Size Variants

enum TagBadgeSize {
    case tiny
    case small
    case medium

    var font: Font {
        switch self {
        case .tiny: return .system(size: 9, weight: .medium)
        case .small: return .system(size: 10, weight: .medium)
        case .medium: return .system(size: 12, weight: .medium)
        }
    }

    var dotSize: CGFloat {
        switch self {
        case .tiny: return 4
        case .small: return 5
        case .medium: return 6
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .tiny: return 6
        case .small: return 7
        case .medium: return 9
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .tiny: return 4
        case .small: return 6
        case .medium: return 8
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .tiny: return 2
        case .small: return 3
        case .medium: return 4
        }
    }
}

// MARK: - Tag List View

/// Displays a horizontal list of tag badges
struct TagListView: View {
    let tags: [TagDisplayModel]
    var size: TagBadgeSize = .small
    var maxDisplayed: Int = 3

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tags.prefix(maxDisplayed)) { tag in
                TagBadgeView(tag: tag, size: size)
            }

            if tags.count > maxDisplayed {
                Text("+\(tags.count - maxDisplayed)")
                    .font(size.font)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct TagBadgeView_Previews: PreviewProvider {
        static var previews: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Single tags in different sizes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tiny").font(.caption).foregroundStyle(.secondary)
                    TagBadgeView(tag: .sampleWork, size: .tiny)

                    Text("Small").font(.caption).foregroundStyle(.secondary)
                    TagBadgeView(tag: .sampleWork, size: .small)

                    Text("Medium").font(.caption).foregroundStyle(.secondary)
                    TagBadgeView(tag: .sampleWork, size: .medium)
                }

                Divider()

                // With remove button
                VStack(alignment: .leading, spacing: 8) {
                    Text("With Remove Button").font(.caption).foregroundStyle(.secondary)
                    TagBadgeView(
                        tag: .sampleImportant,
                        showRemoveButton: true,
                        onRemove: {
                            print("Remove tapped")
                        },
                        size: .medium
                    )
                }

                Divider()

                // Tag list
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tag List").font(.caption).foregroundStyle(.secondary)
                    TagListView(tags: TagDisplayModel.samples)
                }

                // Tag list with overflow
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tag List (max 2)").font(.caption).foregroundStyle(.secondary)
                    TagListView(tags: TagDisplayModel.samples, maxDisplayed: 2)
                }
            }
            .padding()
        }
    }
#endif
