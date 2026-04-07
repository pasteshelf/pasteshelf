//
//  WelcomeStepView.swift
//  PasteShelf
//
//  Welcome screen for the onboarding flow with app overview.
//

import SwiftUI

// MARK: - WelcomeStepView

/// Welcome step view with app icon and feature highlights
struct WelcomeStepView: View {
    // MARK: Internal

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // App icon
            Image(systemName: "clipboard.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            // Welcome text
            Text("Welcome to PasteShelf")
                .font(.title)
                .fontWeight(.bold)

            Text("Your privacy-first clipboard manager")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Spacer()

            // Feature highlights
            VStack(spacing: 12) {
                self.featureRow(
                    icon: "clock.arrow.circlepath",
                    title: "Clipboard History",
                    description: "Access everything you've copied"
                )

                self.featureRow(
                    icon: "magnifyingglass",
                    title: "Instant Search",
                    description: "Find any item in seconds"
                )

                self.featureRow(
                    icon: "lock.shield",
                    title: "Privacy First",
                    description: "All data stays on your Mac"
                )

                self.featureRow(
                    icon: "keyboard",
                    title: "Keyboard Shortcuts",
                    description: "Quick access with a single keystroke"
                )
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: Private

    // MARK: - Feature Row

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct WelcomeStepView_Previews: PreviewProvider {
        static var previews: some View {
            WelcomeStepView()
                .frame(width: 520, height: 380)
        }
    }
#endif
