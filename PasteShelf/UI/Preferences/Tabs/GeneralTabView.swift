//
//  GeneralTabView.swift
//  PasteShelf
//
//  General settings tab for preferences window.
//

import SwiftUI

// MARK: - GeneralTabView

/// General settings tab view
struct GeneralTabView: View {
    // MARK: Internal

    @ObservedObject var viewModel: PreferencesViewModel

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: self.$viewModel.launchAtLogin)
                    .accessibilityLabel("Launch PasteShelf at login")
                    .accessibilityHint("When enabled, PasteShelf will start automatically when you log in")

                Toggle("Show in Dock", isOn: self.$viewModel.showInDock)
                    .accessibilityLabel("Show in Dock")
                    .accessibilityHint("When enabled, PasteShelf will appear in the Dock")
            } header: {
                Text("Startup")
            }

            Section {
                Picker("History limit", selection: self.$viewModel.historyLimit) {
                    ForEach(HistoryLimit.allCases) { limit in
                        Text(limit.displayName).tag(limit)
                    }
                }
                .accessibilityLabel("History limit")
                .accessibilityHint("Maximum number of clipboard items to keep")
                .managedSetting(.maxHistoryItems)
            } header: {
                Text("History")
            } footer: {
                Text(
                    "Items beyond this limit will be automatically removed (oldest first)."
                        + " Favorites are always preserved."
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Section {
                Toggle(isOn: self.$viewModel.captureTextContent) {
                    Label("Text", systemImage: "doc.text")
                }
                .disabled(self.isSoleCaptureType(\.captureTextContent))

                Toggle(isOn: self.$viewModel.captureImageContent) {
                    Label("Images", systemImage: "photo")
                }
                .disabled(self.isSoleCaptureType(\.captureImageContent))

                Toggle(isOn: self.$viewModel.captureFileContent) {
                    Label("Files & Documents", systemImage: "folder")
                }
                .disabled(self.isSoleCaptureType(\.captureFileContent))

                Toggle(isOn: self.$viewModel.captureLinkContent) {
                    Label("Links", systemImage: "link")
                }
                .disabled(self.isSoleCaptureType(\.captureLinkContent))
            } header: {
                Text("Capture")
            } footer: {
                Text("Unchecked types will be ignored when copied to clipboard.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                ForEach(self.tags) { tag in
                    HStack {
                        Circle()
                            .fill(tag.color)
                            .frame(width: 10, height: 10)

                        Text(tag.name)
                            .font(.system(size: 13))

                        Spacer()

                        Button {
                            Task { await self.deleteTag(tag) }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if self.showTagInput {
                    HStack(spacing: 8) {
                        ColorPickerButton(selectedColor: self.$newTagColor)

                        TextField("Tag name", text: self.$newTagName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                            .onSubmit { self.createTag() }

                        Button("Add") {
                            self.createTag()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(self.newTagName.isEmpty)

                        Button("Cancel") {
                            self.showTagInput = false
                            self.newTagName = ""
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    }
                } else {
                    Button {
                        self.showTagInput = true
                    } label: {
                        Label("Create Tag", systemImage: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } header: {
                Text("Tags")
            } footer: {
                Text("Tags can be assigned to clipboard items for organization.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await self.loadTags() }
        .onDisappear {
            self.showTagInput = false
            self.newTagName = ""
        }
    }

    // MARK: Private

    // MARK: - Tag Management State

    @State private var tags: [TagDisplayModel] = []
    @State private var newTagName = ""
    @State private var newTagColor = "#007AFF"
    @State private var showTagInput = false

    // MARK: - Capture Type Helper

    /// Returns true if this is the only enabled capture type (prevents disabling all)
    private func isSoleCaptureType(_ keyPath: KeyPath<PreferencesViewModel, Bool>) -> Bool {
        let enabledCount = [
            viewModel.captureTextContent,
            self.viewModel.captureImageContent,
            self.viewModel.captureFileContent,
            self.viewModel.captureLinkContent,
        ].filter { $0 }.count
        return enabledCount == 1 && self.viewModel[keyPath: keyPath]
    }

    // MARK: - Tag Actions

    private func loadTags() async {
        let fetched = await StorageManager.shared.fetchTags()
        self.tags = TagDisplayModel.from(fetched)
    }

    private func createTag() {
        guard !self.newTagName.isEmpty else {
            return
        }
        let name = self.newTagName
        let color = self.newTagColor
        self.newTagName = ""
        Task {
            _ = await StorageManager.shared.saveTag(name: name, color: color)
            await self.loadTags()
        }
    }

    private func deleteTag(_ tag: TagDisplayModel) async {
        let fetched = await StorageManager.shared.fetchTags()
        if let coreDataTag = fetched.first(where: { $0.id == tag.id }) {
            _ = await StorageManager.shared.delete(tag: coreDataTag)
            await self.loadTags()
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct GeneralTabView_Previews: PreviewProvider {
        static var previews: some View {
            GeneralTabView(viewModel: PreferencesViewModel())
                .frame(width: 500, height: 400)
        }
    }
#endif
