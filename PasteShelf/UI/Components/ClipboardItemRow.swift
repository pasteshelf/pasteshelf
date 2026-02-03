//
//  ClipboardItemRow.swift
//  PasteShelf
//
//  List row wrapper for ClipboardItemView with selection state and interactions.
//

import SwiftUI

/// List row container for a clipboard item with selection handling
struct ClipboardItemRow: View {
    // MARK: - Properties

    let item: ClipboardItemDisplayModel
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onPaste: () -> Void

    // MARK: - State

    @State private var isHovered = false

    // MARK: - Body

    var body: some View {
        ClipboardItemView(item: item)
            .background(backgroundView)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                onPaste()
            }
            .onTapGesture(count: 1) {
                onSelect()
            }
            .onHover { hovering in
                isHovered = hovering
            }
            .overlay(alignment: .trailing) {
                quickActionOverlay
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Double-click to paste")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundView: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                )
        } else if isHovered {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.05))
        } else {
            Color.clear
        }
    }

    // MARK: - Quick Actions

    @ViewBuilder
    private var quickActionOverlay: some View {
        if isSelected || isHovered {
            HStack(spacing: 8) {
                // Quick paste button
                Button(action: onPaste) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Paste (Enter)")

                // Quick number indicator for keyboard shortcut
                if index < 9 {
                    Text("\(index + 1)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                        .help("Press \(index + 1) to paste")
                }
            }
            .padding(.trailing, 12)
            .transition(.opacity)
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var label = item.displayText

        if item.isSensitive {
            label += ", sensitive content"
        }

        if item.isFavorite {
            label += ", favorite"
        }

        label += ", from \(item.sourceAppName ?? "unknown app")"
        label += ", \(item.relativeTimestamp)"

        return label
    }
}

// MARK: - Preview

#if DEBUG
    struct ClipboardItemRow_Previews: PreviewProvider {
        static var previews: some View {
            VStack(spacing: 2) {
                ClipboardItemRow(
                    item: .sampleText,
                    index: 0,
                    isSelected: true,
                    onSelect: {},
                    onPaste: {}
                )

                ClipboardItemRow(
                    item: .sampleSensitive,
                    index: 1,
                    isSelected: false,
                    onSelect: {},
                    onPaste: {}
                )

                ClipboardItemRow(
                    item: .sampleURL,
                    index: 2,
                    isSelected: false,
                    onSelect: {},
                    onPaste: {}
                )
            }
            .frame(width: 400)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
#endif
