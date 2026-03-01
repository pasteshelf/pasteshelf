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

            // Auto-update: will be enabled when an update framework (e.g. Sparkle) is integrated.
            // The checkForUpdates setting exists in GeneralSettings but has no effect until then.
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
