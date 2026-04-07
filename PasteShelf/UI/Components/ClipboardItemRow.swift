//
//  ClipboardItemRow.swift
//  PasteShelf
//
//  List row wrapper for ClipboardItemView with selection state and interactions.
//

import SwiftUI

// MARK: - ClipboardItemRow

/// List row container for a clipboard item with selection handling
struct ClipboardItemRow: View {
    // MARK: Internal

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

    // MARK: - State

    /// Observe settings for reactive updates
    @EnvironmentObject var settingsManager: SettingsManager

    #if !APP_STORE
        var onPluginAction: ((PluginMenuItem, String) -> Void)?
    #endif

    // MARK: - Body

    var body: some View {
        ClipboardItemView(
            item: self.item,
            searchHighlights: self.searchHighlights,
            searchQuery: self.searchQuery
        )
        .background(self.backgroundView)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            self.onPaste()
        }
        .onTapGesture(count: 1) {
            self.onSelect()
        }
        .onHover { hovering in
            self.isHovered = hovering
        }
        .overlay(alignment: .topTrailing) {
            self.quickActionOverlay
                .padding(.top, self.settingsManager.appearance.compactMode ? 25 : 30)
        }
        .contextMenu {
            self.contextMenuContent
        }
        .task {
            let tags = await StorageManager.shared.fetchTags()
            self.availableTags = TagDisplayModel.from(tags)
            self.assignedTagIds = await StorageManager.shared.fetchTagIds(forItemId: self.item.id)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityHint("Double-click to paste")
        .accessibilityAddTraits(self.isSelected ? .isSelected : [])
    }

    // MARK: Private

    @State private var isHovered = false
    @State private var availableTags: [TagDisplayModel] = []
    @State private var assignedTagIds: Set<UUID> = []

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var label = self.item.displayText

        if self.item.isSensitive {
            label += ", sensitive content"
        }

        if self.item.isFavorite {
            label += ", favorite"
        }

        label += ", from \(self.item.sourceAppName ?? "unknown app")"
        label += ", \(self.item.relativeTimestamp)"

        return label
    }

    // MARK: - Context Menu

    @ViewBuilder private var contextMenuContent: some View {
        // Paste
        Button {
            self.onPaste()
        } label: {
            Label("Paste", systemImage: "doc.on.clipboard")
        }

        // Copy OCR text (only for images with OCR)
        if self.item.hasOCRText, let onCopyOCR = onCopyOCRText {
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
                if self.item.isFavorite {
                    Label("Remove from Favorites", systemImage: "star.slash")
                } else {
                    Label("Add to Favorites", systemImage: "star")
                }
            }
        }

        // Tags submenu
        if !self.availableTags.isEmpty {
            Divider()

            Menu {
                ForEach(self.availableTags) { tag in
                    Button {
                        Task {
                            _ = await StorageManager.shared.toggleTag(tagId: tag.id, onItemId: self.item.id)
                            self.assignedTagIds = await StorageManager.shared.fetchTagIds(forItemId: self.item.id)
                        }
                    } label: {
                        HStack {
                            Text(tag.name)
                            if self.assignedTagIds.contains(tag.id) {
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
                .sorted { ($0.pluginId) < ($1.pluginId) }
                .filter { pluginId, _ in
                    let types = PluginManager.shared.plugins[pluginId]?.bundle.manifest.supportedContentTypes ?? []
                    return types.isEmpty || types.contains(self.item.contentType.rawValue)
                }
            if !pluginMenuItems.isEmpty {
                Divider()

                Menu {
                    ForEach(pluginMenuItems, id: \.pluginId) { pluginId, items in
                        let pluginName = PluginManager.shared.plugins[pluginId]?.bundle.manifest.name ?? pluginId

                        Section(pluginName) {
                            ForEach(items, id: \.actionId) { menuItem in
                                Button {
                                    self.onPluginAction?(menuItem, pluginId)
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

    @ViewBuilder private var backgroundView: some View {
        if self.isSelected {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                )
        } else if self.isHovered {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.05))
        } else {
            Color.clear
        }
    }

    // MARK: - Quick Actions

    @ViewBuilder private var quickActionOverlay: some View {
        if self.isSelected || self.isHovered {
            HStack(spacing: 8) {
                // Quick paste button
                Button(action: self.onPaste) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Paste (Enter)")

                // Quick number indicator for keyboard shortcut (if enabled)
                if self.settingsManager.shortcuts.quickPasteEnabled, self.index < 9 {
                    Text("\(self.index + 1)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                        .help("Press \(self.index + 1) to paste")
                }
            }
            .padding(.trailing, 12)
            .transition(.opacity)
        }
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
