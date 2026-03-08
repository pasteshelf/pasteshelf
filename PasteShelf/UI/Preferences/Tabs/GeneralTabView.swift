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

        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

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
