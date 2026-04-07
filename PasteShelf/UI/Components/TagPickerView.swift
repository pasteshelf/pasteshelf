//
//  TagPickerView.swift
//  PasteShelf
//
//  Tag selection popover for assigning tags to clipboard items.
//  Allows selecting existing tags or creating new ones.
//

import os.log
import SwiftUI

// MARK: - TagPickerView

private let tagPickerLogger = Logger(
    subsystem: "com.pasteshelf",
    category: "tag-picker"
)

// MARK: - TagPickerView

/// Popover view for selecting and managing tags
struct TagPickerView: View {
    // MARK: Internal

    /// All available tags
    let availableTags: [TagDisplayModel]

    /// Currently selected tag IDs
    @Binding var selectedTagIds: Set<UUID>

    /// Called when a new tag should be created
    var onCreateTag: ((String, String) -> Void)?

    /// Called when selection changes
    var onSelectionChanged: (() -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Search/filter field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
                TextField("Search or create tag...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Tag list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredTags) { tag in
                        tagRow(tag)
                    }

                    // Create new tag option
                    if shouldShowCreateOption {
                        createTagRow
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 200)

            // New tag creation form
            if isCreatingTag {
                Divider()
                createTagForm
            }
        }
        .frame(width: 220)
    }

    // MARK: Private

    // MARK: - State

    @State private var searchText = ""
    @State private var isCreatingTag = false
    @State private var newTagName = ""
    @State private var newTagColor = "#007AFF"

    // MARK: - Filtered Tags

    private var filteredTags: [TagDisplayModel] {
        if searchText.isEmpty {
            return availableTags
        }
        return availableTags.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var shouldShowCreateOption: Bool {
        !searchText.isEmpty &&
            !availableTags.contains { $0.name.lowercased() == searchText.lowercased() }
    }

    // MARK: - Create Tag Row

    private var createTagRow: some View {
        Button {
            newTagName = searchText
            isCreatingTag = true
        } label: {
            HStack {
                Image(systemName: "plus.circle")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14))

                Text("Create \"\(searchText)\"")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Create Tag Form

    private var createTagForm: some View {
        VStack(spacing: 8) {
            HStack {
                Text("New Tag")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") {
                    isCreatingTag = false
                    newTagName = ""
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                // Color picker
                ColorPickerButton(selectedColor: $newTagColor)

                // Name field
                TextField("Tag name", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))

                // Create button
                Button("Add") {
                    createTag()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(newTagName.isEmpty)
            }
        }
        .padding(8)
    }

    // MARK: - Tag Row

    private func tagRow(_ tag: TagDisplayModel) -> some View {
        let isSelected = selectedTagIds.contains(tag.id)

        return Button {
            toggleTag(tag)
        } label: {
            HStack {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? tag.color : .secondary)
                    .font(.system(size: 14))

                // Color dot
                Circle()
                    .fill(tag.color)
                    .frame(width: 8, height: 8)

                // Tag name
                Text(tag.name)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? tag.color.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleTag(_ tag: TagDisplayModel) {
        if selectedTagIds.contains(tag.id) {
            selectedTagIds.remove(tag.id)
        } else {
            selectedTagIds.insert(tag.id)
        }
        onSelectionChanged?()
    }

    private func createTag() {
        guard !newTagName.isEmpty else {
            return
        }
        onCreateTag?(newTagName, newTagColor)
        isCreatingTag = false
        newTagName = ""
        searchText = ""
    }
}

// MARK: - ColorPickerButton

/// Compact color picker button for tag colors
struct ColorPickerButton: View {
    // MARK: Internal

    @Binding var selectedColor: String

    var body: some View {
        Button {
            showPicker.toggle()
        } label: {
            Circle()
                .fill(Color(hex: selectedColor) ?? .blue)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPicker) {
            colorGrid
        }
    }

    // MARK: Private

    @State private var showPicker = false

    private let presetColors = [
        "#007AFF", // Blue
        "#34C759", // Green
        "#FF3B30", // Red
        "#FF9500", // Orange
        "#FFCC00", // Yellow
        "#5856D6", // Purple
        "#AF52DE", // Violet
        "#00C7BE", // Teal
    ]

    private var colorGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(28)), count: 4), spacing: 8) {
            ForEach(presetColors, id: \.self) { colorHex in
                Button {
                    selectedColor = colorHex
                    showPicker = false
                } label: {
                    Circle()
                        .fill(Color(hex: colorHex) ?? .blue)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(
                                    selectedColor == colorHex ? Color.primary : Color.clear,
                                    lineWidth: 2
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
    }
}

// MARK: - Preview

#if DEBUG
    struct TagPickerView_Previews: PreviewProvider {
        struct PreviewWrapper: View {
            // MARK: Internal

            var body: some View {
                TagPickerView(
                    availableTags: TagDisplayModel.samples,
                    selectedTagIds: $selectedIds,
                    onCreateTag: { name, color in
                        tagPickerLogger.debug("Create tag: \(name) with color \(color)")
                    },
                    onSelectionChanged: {
                        tagPickerLogger.debug("Selection changed: \(selectedIds.count) selected")
                    }
                )
            }

            // MARK: Private

            @State private var selectedIds: Set<UUID> = [TagDisplayModel.sampleWork.id]
        }

        static var previews: some View {
            PreviewWrapper()
                .padding()
        }
    }
#endif
