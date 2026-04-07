//
//  AppearanceTabView.swift
//  PasteShelf
//
//  Appearance settings tab for preferences window.
//

import SwiftUI

// MARK: - AppearanceTabView

/// Appearance settings tab view
struct AppearanceTabView: View {
    @ObservedObject var viewModel: PreferencesViewModel

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $viewModel.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Theme")
                .accessibilityHint("Choose between system, light, or dark theme")
                .managedSetting(.theme)
            } header: {
                Text("Theme")
            } footer: {
                Text("System follows your macOS appearance setting.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Picker("Panel width", selection: $viewModel.panelWidth) {
                    ForEach(PanelWidth.allCases) { width in
                        Text(width.displayName).tag(width)
                    }
                }
                .accessibilityLabel("Panel width")
                .accessibilityHint("Width of the clipboard history panel")

                Toggle("Compact mode", isOn: $viewModel.compactMode)
                    .accessibilityLabel("Compact mode")
                    .accessibilityHint("When enabled, items are displayed more compactly")

                Toggle("Show tag filters", isOn: $viewModel.showTagFilters)
                    .accessibilityLabel("Show tag filters")
                    .accessibilityHint("When enabled, tag filter chips are shown below the content type filters")
            } header: {
                Text("Panel")
            }

            Section {
                HStack {
                    Text("Preview lines")
                    Spacer()
                    Stepper(
                        "\(viewModel.previewLines)",
                        value: $viewModel.previewLines,
                        in: 1 ... 5
                    )
                    .accessibilityLabel("Preview lines")
                    .accessibilityValue("\(viewModel.previewLines) lines")
                    .accessibilityHint("Number of lines to show in text previews")
                }

                Toggle("Show image thumbnails", isOn: $viewModel.showThumbnails)
                    .accessibilityLabel("Show image thumbnails")
                    .accessibilityHint("When enabled, image previews are shown for copied images")
            } header: {
                Text("Content Preview")
            } footer: {
                Text("Preview lines affects how much text is shown for each clipboard item.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
    struct AppearanceTabView_Previews: PreviewProvider {
        static var previews: some View {
            AppearanceTabView(viewModel: PreferencesViewModel())
                .frame(width: 500, height: 400)
        }
    }
#endif
