//
//  CollectionsSidebarView.swift
//  PasteShelf
//
//  Sidebar view displaying smart collections list.
//

import AppKit
import SwiftUI

// MARK: - CollectionsSidebarView

/// Sidebar view showing all collections
struct CollectionsSidebarView: View {
    // MARK: Internal

    /// Collections to display
    let collections: [CollectionDisplayModel]

    /// Currently selected collection ID (nil = All Items)
    @Binding var selectedCollectionId: UUID?

    /// Called when edit is requested for a collection
    var onEdit: ((CollectionDisplayModel) -> Void)?

    /// Called when delete is requested for a collection
    var onDelete: ((CollectionDisplayModel) -> Void)?

    /// Called when a new collection should be created
    var onCreate: (() -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            self.headerView

            Divider()
                .padding(.horizontal, 12)

            // Collections list
            ScrollView {
                LazyVStack(spacing: 2) {
                    // All Items row
                    self.allItemsRow

                    // Divider between All Items and collections
                    if !self.collections.isEmpty {
                        Divider()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }

                    // Collection rows
                    ForEach(self.collections) { collection in
                        self.collectionRow(collection)
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()

            // Footer with new collection button
            self.footerView
        }
        .frame(minWidth: 180, maxWidth: 220)
    }

    // MARK: Private

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Collections")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - All Items Row

    private var allItemsRow: some View {
        HStack(spacing: 10) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.secondary.opacity(0.1))

                Image(systemName: "tray.full")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 26, height: 26)

            Text("All Items")
                .font(.system(size: 13, weight: self.selectedCollectionId == nil ? .semibold : .regular))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(self.allItemsBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            self.selectedCollectionId = nil
        }
    }

    @ViewBuilder private var allItemsBackground: some View {
        if self.selectedCollectionId == nil {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
        } else {
            Color.clear
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 12)

            Button(
                action: { self.onCreate?() },
                label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("New Collection")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                }
            )
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Collection Row

    private func collectionRow(_ collection: CollectionDisplayModel) -> some View {
        CollectionRowView(
            collection: collection,
            isSelected: self.selectedCollectionId == collection.id
        ) {
            self.selectedCollectionId = collection.id
        }
        .contextMenu {
            self.collectionContextMenu(collection)
        }
    }

    @ViewBuilder
    private func collectionContextMenu(_ collection: CollectionDisplayModel) -> some View {
        // Edit
        Button {
            self.onEdit?(collection)
        } label: {
            Label("Edit Collection...", systemImage: "pencil")
        }

        Divider()

        // Delete
        Button(role: .destructive) {
            self.onDelete?(collection)
        } label: {
            Label("Delete Collection", systemImage: "trash")
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct CollectionsSidebarView_Previews: PreviewProvider {
        struct PreviewWrapper: View {
            // MARK: Internal

            var body: some View {
                CollectionsSidebarView(
                    collections: CollectionDisplayModel.samples,
                    selectedCollectionId: self.$selectedId,
                    onEdit: { _ in },
                    onDelete: { _ in },
                    onCreate: {}
                )
            }

            // MARK: Private

            @State private var selectedId: UUID?
        }

        static var previews: some View {
            PreviewWrapper()
                .frame(height: 400)
                .background(Color(NSColor.windowBackgroundColor))
        }
    }
#endif
