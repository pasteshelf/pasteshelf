//
//  GeneralTabView.swift
//  PasteShelf
//
//  General settings tab for preferences window.
//

import SwiftUI

/// General settings tab view
struct GeneralTabView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: PreferencesViewModel

    // MARK: - Tag Management State

    @State private var tags: [TagDisplayModel] = []
    @State private var newTagName = ""
    @State private var newTagColor = "#007AFF"
    @State private var showTagInput = false

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $viewModel.launchAtLogin)
                    .accessibilityLabel("Launch PasteShelf at login")
                    .accessibilityHint("When enabled, PasteShelf will start automatically when you log in")

                Toggle("Show in Dock", isOn: $viewModel.showInDock)
                    .accessibilityLabel("Show in Dock")
                    .accessibilityHint("When enabled, PasteShelf will appear in the Dock")
            } header: {
                Text("Startup")
            }

            Section {
                Picker("History limit", selection: $viewModel.historyLimit) {
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
                Text("Items beyond this limit will be automatically removed (oldest first). Favorites are always preserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                Toggle(isOn: $viewModel.captureTextContent) {
                    Label("Text", systemImage: "doc.text")
                }
                .disabled(isSoleCaptureType(\.captureTextContent))

                Toggle(isOn: $viewModel.captureImageContent) {
                    Label("Images", systemImage: "photo")
                }
                .disabled(isSoleCaptureType(\.captureImageContent))

                Toggle(isOn: $viewModel.captureFileContent) {
                    Label("Files & Documents", systemImage: "folder")
                }
                .disabled(isSoleCaptureType(\.captureFileContent))

                Toggle(isOn: $viewModel.captureLinkContent) {
                    Label("Links", systemImage: "link")
                }
                .disabled(isSoleCaptureType(\.captureLinkContent))
            } header: {
                Text("Capture")
            } footer: {
                Text("Unchecked types will be ignored when copied to clipboard.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                ForEach(tags) { tag in
                    HStack {
                        Circle()
                            .fill(tag.color)
                            .frame(width: 10, height: 10)

                        Text(tag.name)
                            .font(.system(size: 13))

                        Spacer()

                        Button {
                            Task { await deleteTag(tag) }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if showTagInput {
                    HStack(spacing: 8) {
                        ColorPickerButton(selectedColor: $newTagColor)

                        TextField("Tag name", text: $newTagName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                            .onSubmit { createTag() }

                        Button("Add") {
                            createTag()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newTagName.isEmpty)

                        Button("Cancel") {
                            showTagInput = false
                            newTagName = ""
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    }
                } else {
                    Button {
                        showTagInput = true
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
        .task { await loadTags() }
        .onDisappear {
            showTagInput = false
            newTagName = ""
        }
    }

    // MARK: - Capture Type Helper

    /// Returns true if this is the only enabled capture type (prevents disabling all)
    private func isSoleCaptureType(_ keyPath: KeyPath<PreferencesViewModel, Bool>) -> Bool {
        let enabledCount = [
            viewModel.captureTextContent,
            viewModel.captureImageContent,
            viewModel.captureFileContent,
            viewModel.captureLinkContent
        ].filter { $0 }.count
        return enabledCount == 1 && viewModel[keyPath: keyPath]
    }

    // MARK: - Tag Actions

    private func loadTags() async {
        let fetched = await StorageManager.shared.fetchTags()
        tags = TagDisplayModel.from(fetched)
    }

    private func createTag() {
        guard !newTagName.isEmpty else { return }
        let name = newTagName
        let color = newTagColor
        newTagName = ""
        Task {
            _ = await StorageManager.shared.saveTag(name: name, color: color)
            await loadTags()
        }
    }

    private func deleteTag(_ tag: TagDisplayModel) async {
        let fetched = await StorageManager.shared.fetchTags()
        if let coreDataTag = fetched.first(where: { $0.id == tag.id }) {
            _ = await StorageManager.shared.delete(tag: coreDataTag)
            await loadTags()
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
