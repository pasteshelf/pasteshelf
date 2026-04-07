//
//  AppExclusionListView.swift
//  PasteShelf
//
//  Displays a list of excluded applications with remove buttons.
//

import AppKit
import SwiftUI

// MARK: - AppExclusionListView

/// View showing a list of excluded app bundle IDs
struct AppExclusionListView: View {
    let bundleIds: [String]
    let onRemove: (String) -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(self.bundleIds, id: \.self) { bundleId in
                ExcludedAppRow(
                    bundleId: bundleId
                ) { self.onRemove(bundleId) }
            }
        }
    }
}

// MARK: - ExcludedAppRow

struct ExcludedAppRow: View {
    // MARK: Internal

    let bundleId: String
    let onRemove: () -> Void

    var body: some View {
        HStack {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app")
                    .frame(width: 20, height: 20)
                    .foregroundColor(.secondary)
            }

            Text(self.appName.isEmpty ? self.bundleId : self.appName)
                .font(.system(size: 12))
                .lineLimit(1)

            Spacer()

            Button(action: self.onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(self.appName.isEmpty ? self.bundleId : self.appName) from exclusion list")
        }
        .padding(.vertical, 2)
        .onAppear {
            self.loadAppInfo()
        }
    }

    // MARK: Private

    @State private var appName: String = ""
    @State private var appIcon: NSImage?

    private func loadAppInfo() {
        let workspace = NSWorkspace.shared

        // Try to find the app by bundle ID
        if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleId) {
            self.appIcon = workspace.icon(forFile: appURL.path)

            if let bundle = Bundle(url: appURL),
               let name = bundle.infoDictionary?["CFBundleName"] as? String
               ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String
            {
                self.appName = name
            } else {
                self.appName = appURL.deletingPathExtension().lastPathComponent
            }
        } else {
            // App not found, show bundle ID
            self.appName = self.bundleId
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct AppExclusionListView_Previews: PreviewProvider {
        static var previews: some View {
            AppExclusionListView(
                bundleIds: [
                    "com.apple.Safari",
                    "com.google.Chrome",
                    "com.agilebits.onepassword7",
                ]
            ) { _ in }
                .frame(width: 300)
                .padding()
        }
    }
#endif
