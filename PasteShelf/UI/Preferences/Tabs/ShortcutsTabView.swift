//
//  ShortcutsTabView.swift
//  PasteShelf
//
//  Shortcuts settings tab for preferences window.
//

import SwiftUI

// MARK: - ShortcutsTabView

/// Shortcuts settings tab view
struct ShortcutsTabView: View {
    // MARK: Internal

    @ObservedObject var viewModel: PreferencesViewModel

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Show/Hide Panel")
                    Spacer()
                    HotkeyRecorderView(
                        hotkey: $viewModel.globalHotkey,
                        isRecording: $isRecording
                    )
                    .frame(width: 150)
                }
                .accessibilityLabel("Global hotkey")
                .accessibilityValue(viewModel.globalHotkey.displayString)
                .accessibilityHint("Click to record a new hotkey")
            } header: {
                Text("Global Hotkey")
            } footer: {
                Text("Press the key combination to set a new hotkey. The default is \u{2318}\u{21E7}V.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Toggle("Enable quick paste (\u{2318}1-9)", isOn: $viewModel.quickPasteEnabled)
                    .accessibilityLabel("Enable quick paste")
                    .accessibilityHint("When enabled, press Command plus a number to paste that item")
            } header: {
                Text("Quick Paste")
            } footer: {
                Text("When the panel is open, press \u{2318}1 through \u{2318}9 to quickly paste items.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    ShortcutRow(shortcut: "\u{2191} / \u{2193}", description: "Navigate items")
                    ShortcutRow(shortcut: "\u{21A9}", description: "Paste selected item")
                    ShortcutRow(shortcut: "\u{238B}", description: "Close panel")
                    ShortcutRow(shortcut: "\u{232B}", description: "Delete selected item")
                    ShortcutRow(shortcut: "\u{2318}S", description: "Toggle favorite")
                    ShortcutRow(shortcut: "\u{2318}F", description: "Focus search")
                    ShortcutRow(shortcut: "1-9", description: "Select item by number")
                    ShortcutRow(shortcut: "\u{2318}1-9", description: "Quick paste item by number")
                }
            } header: {
                Text("Keyboard Navigation")
            } footer: {
                Text("These shortcuts work when the clipboard panel is open.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Private

    @State private var isRecording = false
}

// MARK: - ShortcutRow

struct ShortcutRow: View {
    let shortcut: String
    let description: String

    var body: some View {
        HStack {
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
            Text(description)
                .foregroundColor(.secondary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(shortcut): \(description)")
    }
}

// MARK: - Preview

#if DEBUG
    struct ShortcutsTabView_Previews: PreviewProvider {
        static var previews: some View {
            ShortcutsTabView(viewModel: PreferencesViewModel())
                .frame(width: 500, height: 500)
        }
    }
#endif
