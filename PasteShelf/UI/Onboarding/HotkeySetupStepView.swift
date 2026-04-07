//
//  HotkeySetupStepView.swift
//  PasteShelf
//
//  Hotkey configuration step in the onboarding flow.
//

import SwiftUI

// MARK: - HotkeySetupStepView

/// Hotkey setup step view
struct HotkeySetupStepView: View {
    // MARK: Internal

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon
            Image(systemName: "keyboard")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            // Title
            Text("Set Your Hotkey")
                .font(.title)
                .fontWeight(.bold)

            // Description
            Text("Choose a keyboard shortcut to quickly open PasteShelf from anywhere.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Spacer()

            // Hotkey recorder
            VStack(spacing: 16) {
                Text("Current Hotkey")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                HotkeyRecorderView(
                    hotkey: $hotkey,
                    isRecording: $isRecording
                )
                .frame(width: 180, height: 36)
                .onChange(of: hotkey) { _, newValue in
                    saveHotkey(newValue)
                }

                Text(isRecording ? "Press your desired key combination..." : "Click to record a new shortcut")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.05))
            )
            .animation(.easeInOut(duration: 0.2), value: isRecording)

            // Quick presets
            VStack(spacing: 8) {
                Text("Quick Presets")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    presetButton(label: "⌘ ⇧ V", hotkey: .default, isSelected: hotkey == .default)
                    presetButton(label: "⌘ ⌥ V", hotkey: .alternative, isSelected: hotkey == .alternative)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: Private

    @State private var hotkey: StoredHotkey = SettingsManager.shared.settings.shortcuts.globalHotkey
    @State private var isRecording = false

    // MARK: - Preset Button

    private func presetButton(
        label: String,
        hotkey presetHotkey: StoredHotkey,
        isSelected: Bool
    ) -> some View {
        Button {
            hotkey = presetHotkey
            saveHotkey(presetHotkey)
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper Methods

    private func saveHotkey(_ newHotkey: StoredHotkey) {
        var settings = SettingsManager.shared.settings
        settings.shortcuts.globalHotkey = newHotkey
        SettingsManager.shared.save(settings)
    }
}

// MARK: - Preview

#if DEBUG
    struct HotkeySetupStepView_Previews: PreviewProvider {
        static var previews: some View {
            HotkeySetupStepView()
                .frame(width: 520, height: 380)
        }
    }
#endif
