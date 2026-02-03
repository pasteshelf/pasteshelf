//
//  AppExclusionListView.swift
//  PasteShelf
//
//  Displays a list of excluded applications with remove buttons.
//

import SwiftUI

/// View showing a list of excluded app bundle IDs
struct AppExclusionListView: View {
    // MARK: - Properties

    let bundleIds: [String]
    let onRemove: (String) -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(bundleIds, id: \.self) { bundleId in
                ExcludedAppRow(
                    bundleId: bundleId,
                    onRemove: { onRemove(bundleId) }
                )
            }
        }
    }
}

// MARK: - Excluded App Row

struct ExcludedAppRow: View {
    let bundleId: String
    let onRemove: () -> Void

    @State private var appName: String = ""
    @State private var appIcon: NSImage?

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

            Text(appName.isEmpty ? bundleId : appName)
                .font(.system(size: 12))
                .lineLimit(1)

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(appName.isEmpty ? bundleId : appName) from exclusion list")
        }
        .padding(.vertical, 2)
        .onAppear {
            loadAppInfo()
        }
    }

    private func loadAppInfo() {
        let workspace = NSWorkspace.shared

        // Try to find the app by bundle ID
        if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleId) {
            appIcon = workspace.icon(forFile: appURL.path)

            if let bundle = Bundle(url: appURL),
               let name = bundle.infoDictionary?["CFBundleName"] as? String
                   ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String
            {
                appName = name
            } else {
                appName = appURL.deletingPathExtension().lastPathComponent
            }
        } else {
            // App not found, show bundle ID
            appName = bundleId
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
                ],
                onRemove: { _ in }
            )
            .frame(width: 300)
            .padding()
        }
    }
#endif
