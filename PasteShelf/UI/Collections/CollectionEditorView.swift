//
//  CollectionEditorView.swift
//  PasteShelf
//
//  Sheet view for creating and editing smart collections.
//

import SwiftUI

// MARK: - CollectionEditorView

/// View for creating or editing a smart collection
struct CollectionEditorView: View {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        collection: CollectionDisplayModel? = nil,
        onSave: @escaping (CollectionDisplayModel) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.collection = collection
        self.onSave = onSave
        self.onCancel = onCancel

        // Initialize state from collection
        if let collection {
            _name = State(initialValue: collection.name)
            _icon = State(initialValue: collection.icon)
            _colorHex = State(initialValue: collection.colorHex ?? "#007AFF")
            _isAutomatic = State(initialValue: collection.isAutomatic)
            _rules = State(initialValue: collection.rules ?? CollectionRules())
        }
    }

    // MARK: Internal

    /// The collection being edited (nil for new collection)
    let collection: CollectionDisplayModel?

    /// Called when save is requested
    let onSave: (CollectionDisplayModel) -> Void

    /// Called when cancel is requested
    let onCancel: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            self.headerView

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic info section
                    self.basicInfoSection

                    Divider()

                    // Collection type section
                    self.typeSection

                    // Rules section (only for automatic collections)
                    if self.isAutomatic {
                        Divider()
                        self.rulesSection
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            self.footerView
        }
        .frame(width: 500, height: 520)
    }

    // MARK: Private

    // MARK: - State

    @State private var name: String = ""
    @State private var icon: String = "folder"
    @State private var colorHex: String = "#007AFF"
    @State private var isAutomatic: Bool = true
    @State private var rules = CollectionRules()

    // MARK: - Data

    private var availableIcons: [String] {
        [
            "folder", "folder.fill", "tray", "tray.fill",
            "doc", "doc.text", "photo", "photo.stack",
            "link", "globe", "star", "star.fill",
            "bookmark", "bookmark.fill", "tag", "tag.fill",
            "archivebox", "archivebox.fill", "clock", "clock.fill",
            "heart", "heart.fill", "flag", "flag.fill",
            "bell", "bell.fill", "pin", "pin.fill",
            "paperclip", "scissors", "highlighter", "pencil",
        ]
    }

    private var availableColors: [String] {
        [
            "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
            "#00C7BE", "#007AFF", "#5856D6", "#AF52DE",
            "#FF2D55", "#8E8E93",
        ]
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text(self.collection == nil ? "New Collection" : "Edit Collection")
                .font(.headline)
            Spacer()
        }
        .padding()
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basic Info")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            // Name field
            HStack {
                Text("Name")
                    .frame(width: 60, alignment: .trailing)
                    .foregroundStyle(.secondary)
                TextField("Collection name", text: self.$name)
                    .textFieldStyle(.roundedBorder)
            }

            // Icon picker
            HStack(alignment: .top) {
                Text("Icon")
                    .frame(width: 60, alignment: .trailing)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                self.iconPickerGrid
            }

            // Color picker
            HStack {
                Text("Color")
                    .frame(width: 60, alignment: .trailing)
                    .foregroundStyle(.secondary)

                self.colorPickerRow
            }
        }
    }

    private var iconPickerGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 8), count: 8), spacing: 8) {
            ForEach(self.availableIcons, id: \.self) { iconName in
                Button {
                    self.icon = iconName
                } label: {
                    Image(systemName: iconName)
                        .font(.system(size: 14))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(self.icon == iconName ? Color.accentColor.opacity(0.2) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(self.icon == iconName ? Color.accentColor : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var colorPickerRow: some View {
        HStack(spacing: 8) {
            ForEach(self.availableColors, id: \.self) { hex in
                Button {
                    self.colorHex = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex) ?? .blue)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(self.colorHex == hex ? Color.primary : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    // MARK: - Type Section

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Collection Type")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Picker("Type", selection: self.$isAutomatic) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Smart Collection")
                }
                .tag(true)

                HStack {
                    Image(systemName: "hand.draw")
                    Text("Manual Collection")
                }
                .tag(false)
            }
            .pickerStyle(.radioGroup)

            Text(self.isAutomatic
                ? "Items are automatically added based on rules"
                : "Manually drag items to add them to this collection")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Rules Section

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rules")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            RuleBuilderView(rules: self.$rules)
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Spacer()

            Button("Cancel") {
                self.onCancel()
            }
            .keyboardShortcut(.cancelAction)

            Button(self.collection == nil ? "Create" : "Save") {
                self.saveCollection()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(self.name.isEmpty)
        }
        .padding()
    }

    private func saveCollection() {
        let model = CollectionDisplayModel(
            id: collection?.id ?? UUID(),
            name: self.name,
            icon: self.icon,
            colorHex: self.colorHex,
            isAutomatic: self.isAutomatic,
            itemCount: self.collection?.itemCount ?? 0,
            sortOrder: self.collection?.sortOrder ?? 0,
            rules: self.isAutomatic ? self.rules : nil
        )
        self.onSave(model)
    }
}

// MARK: - Preview

#if DEBUG
    struct CollectionEditorView_Previews: PreviewProvider {
        static var previews: some View {
            CollectionEditorView(
                collection: nil,
                onSave: { _ in },
                onCancel: {}
            )

            CollectionEditorView(
                collection: .sampleImages,
                onSave: { _ in },
                onCancel: {}
            )
        }
    }
#endif
