//
//  SourceAppIconView.swift
//  PasteShelf
//
//  Displays the icon of the source application for a clipboard item.
//

import AppKit
import SwiftUI

/// View for displaying source application icon from bundle ID
struct SourceAppIconView: View {
    // MARK: - Properties

    let bundleId: String?
    let size: CGFloat

    // MARK: - State

    @State private var appIcon: NSImage?

    // MARK: - Initialization

    init(bundleId: String?, size: CGFloat = 16) {
        self.bundleId = bundleId
        self.size = size
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.8))
                    .foregroundColor(.secondary)
                    .frame(width: size, height: size)
            }
        }
        .task {
            appIcon = await loadAppIcon()
        }
    }

    // MARK: - Icon Loading

    private func loadAppIcon() async -> NSImage? {
        guard let bundleId = bundleId else { return nil }

        return await MainActor.run {
            // Get app URL from bundle identifier
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
                return nil
            }

            // Get icon for the app
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: size * 2, height: size * 2) // Retina support
            return icon
        }
    }
}

// MARK: - Cached Icon Provider

/// Provides cached app icons for better performance
final class AppIconCache {
    static let shared = AppIconCache()

    private var cache: [String: NSImage] = [:]
    private let queue = DispatchQueue(label: "com.pasteshelf.icon-cache")

    private init() {}

    /// Gets or loads an app icon for a bundle identifier
    func icon(for bundleId: String, size: CGFloat = 32) -> NSImage? {
        // Check cache first
        if let cached = queue.sync(execute: { cache[bundleId] }) {
            return cached
        }

        // Load icon
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: size, height: size)

        // Cache for future use
        queue.sync {
            cache[bundleId] = icon
        }

        return icon
    }

    /// Clears the icon cache
    func clearCache() {
        queue.sync {
            cache.removeAll()
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct SourceAppIconView_Previews: PreviewProvider {
        static var previews: some View {
            HStack(spacing: 16) {
                VStack {
                    SourceAppIconView(bundleId: "com.apple.Safari", size: 32)
                    Text("Safari")
                        .font(.caption)
                }

                VStack {
                    SourceAppIconView(bundleId: "com.apple.finder", size: 32)
                    Text("Finder")
                        .font(.caption)
                }

                VStack {
                    SourceAppIconView(bundleId: "com.apple.Terminal", size: 32)
                    Text("Terminal")
                        .font(.caption)
                }

                VStack {
                    SourceAppIconView(bundleId: nil, size: 32)
                    Text("Unknown")
                        .font(.caption)
                }
            }
            .padding()
        }
    }
#endif
