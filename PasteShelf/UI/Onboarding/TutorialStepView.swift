//
//  TutorialStepView.swift
//  PasteShelf
//
//  Quick tutorial step showing key features and usage.
//

import SwiftUI

/// Tutorial step view with shortcuts overview
struct TutorialStepView: View {
    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon
            Image(systemName: "rectangle.stack")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            // Title
            Text("How It Works")
                .font(.title)
                .fontWeight(.bold)

            // Description
            Text(
                "PasteShelf runs in the background and saves everything you copy. Use the hotkey to open the clipboard panel anytime."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 380)

            Spacer()

            // Key Shortcuts
            VStack(alignment: .leading, spacing: 12) {
                Text("Key Shortcuts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    shortcutRow(keys: "⌘ ⇧ V", description: "Open clipboard panel")
                    shortcutRow(keys: "↑ ↓", description: "Navigate items")
                    shortcutRow(keys: "⏎", description: "Paste selected item")
                    shortcutRow(keys: "⌘ F", description: "Search clipboard")
                    shortcutRow(keys: "⌘ S", description: "Toggle favorite")
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.05))
            )

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Shortcut Row

    private func shortcutRow(keys: String, description: LocalizedStringKey) -> some View {
        HStack {
            Text(keys)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.accentColor)
                .frame(width: 70, alignment: .leading)

            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct TutorialStepView_Previews: PreviewProvider {
        static var previews: some View {
            TutorialStepView()
                .frame(width: 520, height: 380)
        }
    }
#endif
