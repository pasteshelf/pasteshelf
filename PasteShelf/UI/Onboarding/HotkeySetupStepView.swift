//
//  HotkeySetupStepView.swift
//  PasteShelf
//
//  Hotkey configuration step in the onboarding flow.
//

import SwiftUI

/// Hotkey setup step view
struct HotkeySetupStepView: View {
    // MARK: - Properties

    @State private var hotkey: StoredHotkey = SettingsManager.shared.settings.shortcuts.globalHotkey
    @State private var isRecording = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            iconView

            // Title and description
            textContentView

            Spacer()

            // Hotkey recorder
            hotkeyRecorderSection

            // Quick options
            quickOptionsView

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Icon

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 100, height: 100)

            Image(systemName: "keyboard")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.accentColor)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Text Content

    private var textContentView: some View {
        VStack(spacing: 12) {
            Text("Set Your Hotkey")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)

            Text("Choose a keyboard shortcut to quickly open PasteShelf from anywhere.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }

    // MARK: - Hotkey Recorder Section

    private var hotkeyRecorderSection: some View {
        VStack(spacing: 16) {
            // Current hotkey display
            VStack(spacing: 8) {
                Text("Current Hotkey")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                HotkeyRecorderView(
                    hotkey: $hotkey,
                    isRecording: $isRecording
                )
                .frame(width: 180, height: 36)
                .onChange(of: hotkey) { _, newValue in
                    saveHotkey(newValue)
                }
            }

            if isRecording {
                Text("Press your desired key combination...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            } else {
                Text("Click to record a new shortcut")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.05))
        )
        .animation(.easeInOut(duration: 0.2), value: isRecording)
    }

    // MARK: - Quick Options

    private var quickOptionsView: some View {
        VStack(spacing: 12) {
            Text("Quick Presets")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                presetButton(
                    label: "⌘ ⇧ V",
                    hotkey: .default,
                    isSelected: hotkey == .default
                )

                presetButton(
                    label: "⌘ ⌥ V",
                    hotkey: .alternative,
                    isSelected: hotkey == .alternative
                )
            }
        }
    }

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
                .frame(width: 500, height: 550)
        }
    }
#endif
