//
//  WelcomeStepView.swift
//  PasteShelf
//
//  Welcome screen for the onboarding flow with app overview.
//

import SwiftUI

/// Welcome step view with app logo and feature highlights
struct WelcomeStepView: View {
    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon
            appIconView

            // Welcome text
            welcomeTextView

            Spacer()

            // Feature highlights
            featuresView

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - App Icon

    private var appIconView: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.accentColor.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 30,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)

            // Icon
            Image(systemName: "clipboard.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .accessibilityHidden(true)
    }

    // MARK: - Welcome Text

    private var welcomeTextView: some View {
        VStack(spacing: 12) {
            Text("Welcome to PasteShelf")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)

            Text("Your privacy-first clipboard manager")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Features

    private var featuresView: some View {
        VStack(spacing: 16) {
            featureRow(
                icon: "clock.arrow.circlepath",
                title: "Clipboard History",
                description: "Access everything you've copied"
            )

            featureRow(
                icon: "magnifyingglass",
                title: "Instant Search",
                description: "Find any item in seconds"
            )

            featureRow(
                icon: "lock.shield",
                title: "Privacy First",
                description: "All data stays on your Mac"
            )

            featureRow(
                icon: "keyboard",
                title: "Keyboard Shortcuts",
                description: "Quick access with a single keystroke"
            )
        }
        .padding(.horizontal, 16)
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
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
                .frame(width: 500, height: 500)
        }
    }
#endif
