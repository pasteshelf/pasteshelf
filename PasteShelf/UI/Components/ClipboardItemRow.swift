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
    var searchHighlights: [MatchRange] = []
    var searchQuery: String?
    let onSelect: () -> Void
    let onPaste: () -> Void
    var onCopyOCRText: (() -> Void)?
    var onDelete: (() -> Void)?
    var onToggleFavorite: (() -> Void)?
    #if !APP_STORE
    var onPluginAction: ((PluginMenuItem, String) -> Void)?
    #endif

    // MARK: - State

    /// Observe settings for reactive updates
    @EnvironmentObject var settingsManager: SettingsManager

    @State private var isHovered = false
    @State private var availableTags: [TagDisplayModel] = []
    @State private var assignedTagIds: Set<UUID> = []

    // MARK: - Body

    var body: some View {
        ClipboardItemView(
            item: item,
            searchHighlights: searchHighlights,
            searchQuery: searchQuery
        )
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
            .overlay(alignment: .topTrailing) {
                quickActionOverlay
                    .padding(.top, settingsManager.appearance.compactMode ? 25 : 30)
            }
            .contextMenu {
                contextMenuContent
            }
            .task {
                let tags = await StorageManager.shared.fetchTags()
                availableTags = TagDisplayModel.from(tags)
                assignedTagIds = await StorageManager.shared.fetchTagIds(forItemId: item.id)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Double-click to paste")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        // Paste
        Button {
            onPaste()
        } label: {
            Label("Paste", systemImage: "doc.on.clipboard")
        }

        // Copy OCR text (only for images with OCR)
        if item.hasOCRText, let onCopyOCR = onCopyOCRText {
            Button {
                onCopyOCR()
            } label: {
                Label("Copy Extracted Text", systemImage: "text.viewfinder")
            }
        }

        Divider()

        // Toggle favorite
        if let onFavorite = onToggleFavorite {
            Button {
                onFavorite()
            } label: {
                if item.isFavorite {
                    Label("Remove from Favorites", systemImage: "star.slash")
                } else {
                    Label("Add to Favorites", systemImage: "star")
                }
            }
        }

        // Tags submenu
        if !availableTags.isEmpty {
            Divider()

            Menu {
                ForEach(availableTags) { tag in
                    Button {
                        Task {
                            _ = await StorageManager.shared.toggleTag(tagId: tag.id, onItemId: item.id)
                            assignedTagIds = await StorageManager.shared.fetchTagIds(forItemId: item.id)
                        }
                    } label: {
                        HStack {
                            Text(tag.name)
                            if assignedTagIds.contains(tag.id) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Tags", systemImage: "tag")
            }
        }

        #if !APP_STORE
        // Plugin actions — grouped under a single "Plugins" submenu
        let pluginMenuItems = PluginManager.shared.allMenuItems
            .sorted(by: { ($0.pluginId) < ($1.pluginId) })
            .filter { pluginId, _ in
                let types = PluginManager.shared.plugins[pluginId]?.bundle.manifest.supportedContentTypes ?? []
                return types.isEmpty || types.contains(item.contentType.rawValue)
            }
        if !pluginMenuItems.isEmpty {
            Divider()

            Menu {
                ForEach(pluginMenuItems, id: \.pluginId) { pluginId, items in
                    let pluginName = PluginManager.shared.plugins[pluginId]?.bundle.manifest.localizedName ?? pluginId

                    Section(pluginName) {
                        ForEach(items, id: \.actionId) { menuItem in
                            Button {
                                onPluginAction?(menuItem, pluginId)
                            } label: {
                                if let icon = menuItem.iconName {
                                    Label(menuItem.title, systemImage: icon)
                                } else {
                                    Text(menuItem.title)
                                }
                            }
                            .disabled(!menuItem.isEnabled)
                        }
                    }
                }
            } label: {
                Label("Plugins", systemImage: "puzzlepiece.extension")
            }
        }
        #endif

        // Delete
        if let onDeleteAction = onDelete {
            Divider()

            Button(role: .destructive) {
                onDeleteAction()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
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

                // Quick number indicator for keyboard shortcut (if enabled)
                if settingsManager.shortcuts.quickPasteEnabled, index < 9 {
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
            label += ", " + String(localized: "sensitive content")
        }

        if item.isFavorite {
            label += ", " + String(localized: "favorite")
        }

        let app = item.sourceAppName ?? String(localized: "unknown app")
        label += ", " + String(localized: "from \(app)")
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
            .environmentObject(SettingsManager.shared)
        }
    }
#endif
