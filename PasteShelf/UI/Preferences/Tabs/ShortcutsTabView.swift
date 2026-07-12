//
//  ShortcutsTabView.swift
//  PasteShelf
//
//  Shortcuts settings tab for preferences window.
//

import SwiftUI

/// Shortcuts settings tab view
struct ShortcutsTabView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: PreferencesViewModel
    @State private var isRecording = false

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
                // App Store build copies to the clipboard (user pastes with ⌘V),
                // so its UI must not claim it pastes (Guideline 2.4.5 wording).
                #if APP_STORE
                Toggle("Enable quick copy (\u{2318}1-9)", isOn: $viewModel.quickPasteEnabled)
                    .accessibilityLabel("Enable quick copy")
                    .accessibilityHint("When enabled, press Command plus a number to copy that item")
                #else
                Toggle("Enable quick paste (\u{2318}1-9)", isOn: $viewModel.quickPasteEnabled)
                    .accessibilityLabel("Enable quick paste")
                    .accessibilityHint("When enabled, press Command plus a number to paste that item")
                #endif
            } header: {
                #if APP_STORE
                Text("Quick Copy")
                #else
                Text("Quick Paste")
                #endif
            } footer: {
                #if APP_STORE
                Text("When the panel is open, press \u{2318}1 through \u{2318}9 to quickly copy items.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                #else
                Text("When the panel is open, press \u{2318}1 through \u{2318}9 to quickly paste items.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                #endif
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // ShortcutRow renders plain Strings, so localize here
                    ShortcutRow(shortcut: "\u{2191} / \u{2193}", description: String(localized: "Navigate items"))
                    #if APP_STORE
                    ShortcutRow(shortcut: "\u{21A9}", description: String(localized: "Copy selected item"))
                    #else
                    ShortcutRow(shortcut: "\u{21A9}", description: String(localized: "Paste selected item"))
                    #endif
                    ShortcutRow(shortcut: "\u{238B}", description: String(localized: "Close panel"))
                    ShortcutRow(shortcut: "\u{232B}", description: String(localized: "Delete selected item"))
                    ShortcutRow(shortcut: "\u{2318}S", description: String(localized: "Toggle favorite"))
                    ShortcutRow(shortcut: "\u{2318}F", description: String(localized: "Focus search"))
                    ShortcutRow(shortcut: "1-9", description: String(localized: "Select item by number"))
                    #if APP_STORE
                    ShortcutRow(shortcut: "\u{2318}1-9", description: String(localized: "Quick copy item by number"))
                    #else
                    ShortcutRow(shortcut: "\u{2318}1-9", description: String(localized: "Quick paste item by number"))
                    #endif
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
}

// MARK: - Shortcut Row

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
