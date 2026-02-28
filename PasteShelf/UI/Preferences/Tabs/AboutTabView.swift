//
//  AboutTabView.swift
//  PasteShelf
//
//  About tab for preferences window.
//

import SwiftUI

/// About tab view
struct AboutTabView: View {
    // MARK: - Properties

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App Icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
                .accessibilityHidden(true)

            // App Name and Version
            VStack(spacing: 4) {
                Text("PasteShelf")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Description
            Text("A privacy-first clipboard manager for macOS")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Links
            VStack(spacing: 12) {
                Link(destination: URL(string: "https://pasteshelf.app")!) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Website")
                    }
                }
                .accessibilityLabel("Visit PasteShelf website")

                Link(destination: URL(string: "https://github.com/pasteshelf/pasteshelf")!) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                        Text("Source Code")
                    }
                }
                .accessibilityLabel("View source code on GitHub")

                Link(destination: URL(string: "https://pasteshelf.app/privacy")!) {
                    HStack {
                        Image(systemName: "hand.raised")
                        Text("Privacy Policy")
                    }
                }
                .accessibilityLabel("Read privacy policy")
            }
            .buttonStyle(.link)

            Spacer()

            // Copyright
            VStack(spacing: 4) {
                Text("Open Source (AGPL-3.0)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\u{00A9} 2024 PasteShelf. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
    struct AboutTabView_Previews: PreviewProvider {
        static var previews: some View {
            AboutTabView()
                .frame(width: 500, height: 400)
        }
    }
#endif
