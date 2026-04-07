//
//  ClipboardItemView.swift
//  PasteShelf
//
//  Displays a single clipboard item with content preview, metadata, and actions.
//  Handles text, images, URLs, and sensitive content with appropriate masking.
//

import AppKit
import SwiftUI

// MARK: - ClipboardItemView

/// View for displaying a single clipboard item
struct ClipboardItemView: View {
    // MARK: Internal

    let item: ClipboardItemDisplayModel

    /// Optional search highlight ranges
    var searchHighlights: [MatchRange] = []

    /// Optional search query for highlighting
    var searchQuery: String?

    /// Observe settings for reactive updates
    @EnvironmentObject var settingsManager: SettingsManager

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Content type icon
            self.contentTypeIcon

            // Main content
            VStack(alignment: .leading, spacing: 4) {
                // Content preview
                self.contentPreview

                // Metadata row
                self.metadataRow
            }

            Spacer()

            // Actions/indicators
            self.indicators
        }
        .padding(.horizontal, self.settingsManager.appearance.compactMode ? 8 : 12)
        .padding(.vertical, self.settingsManager.appearance.compactMode ? 4 : 8)
    }

    // MARK: Private

    /// Whether sensitive content should be revealed
    @State private var isRevealed = false

    /// Whether OCR text is expanded
    @State private var isOCRExpanded = false

    /// Whether there are search highlights to show
    private var hasSearchHighlights: Bool {
        !self.searchHighlights.isEmpty || self.searchQuery != nil
    }

    private var iconBackgroundColor: Color {
        switch self.item.contentType {
        case .plainText,
             .richText,
             .html:
            Color.blue.opacity(0.15)
        case .png,
             .jpeg,
             .tiff:
            Color.green.opacity(0.15)
        case .pdf:
            Color.red.opacity(0.15)
        case .url,
             .fileURL:
            Color.purple.opacity(0.15)
        }
    }

    private var iconForegroundColor: Color {
        switch self.item.contentType {
        case .plainText,
             .richText,
             .html:
            .blue
        case .png,
             .jpeg,
             .tiff:
            .green
        case .pdf:
            .red
        case .url,
             .fileURL:
            .purple
        }
    }

    // MARK: - Content Type Icon

    private var contentTypeIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(self.iconBackgroundColor)
                .frame(width: 32, height: 32)

            Image(systemName: self.item.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(self.iconForegroundColor)
        }
    }

    // MARK: - Content Preview

    @ViewBuilder private var contentPreview: some View {
        if self.item.isSensitive, !self.isRevealed {
            self.sensitiveContentView
        } else if self.item.contentType.isImageType, self.item.hasThumbnail,
                  self.settingsManager.appearance.showThumbnails
        {
            self.imagePreviewView
        } else {
            self.textPreviewView
        }
    }

    private var sensitiveContentView: some View {
        HStack(spacing: 6) {
            Image(systemName: "eye.slash.fill")
                .font(.caption)
                .foregroundColor(.orange)

            Text("Sensitive content")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .italic()

            Button(
                action: { self.isRevealed = true },
                label: {
                    Text("Reveal")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            )
            .buttonStyle(.plain)
        }
    }

    private var imagePreviewView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let thumbnail = item.thumbnailImage {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 60)
                    .cornerRadius(4)
            } else {
                Text("[Image]")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // OCR text preview
            if self.item.hasOCRText {
                self.ocrTextPreview
            }
        }
    }

    @ViewBuilder private var ocrTextPreview: some View {
        if let ocrText = item.ocrText, !ocrText.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                // OCR header with toggle
                Button(
                    action: { self.isOCRExpanded.toggle() },
                    label: {
                        HStack(spacing: 4) {
                            Image(systemName: "text.viewfinder")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Text("Extracted Text")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Image(systemName: self.isOCRExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Spacer()
                        }
                    }
                )
                .buttonStyle(.plain)

                // OCR text content
                if self.isOCRExpanded {
                    Text(ocrText)
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.8))
                        .lineLimit(5)
                        .multilineTextAlignment(.leading)
                        .padding(6)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(4)
                } else if let preview = item.ocrTextPreview {
                    Text(preview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var textPreviewView: some View {
        Group {
            if let query = searchQuery, !query.isEmpty {
                // Use highlighted text
                HighlightedTextView(
                    text: self.item.shortDisplayText(maxLength: 100),
                    query: query,
                    lineLimit: self.settingsManager.appearance.previewLines
                )
            } else if !self.searchHighlights.isEmpty {
                // Use provided highlight ranges
                HighlightedTextView(
                    text: self.item.shortDisplayText(maxLength: 100),
                    matchRanges: self.searchHighlights,
                    lineLimit: self.settingsManager.appearance.previewLines
                )
            } else {
                // Regular text
                Text(self.item.shortDisplayText(maxLength: 100))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(self.settingsManager.appearance.previewLines)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack(spacing: 8) {
            // Source app
            if let appName = item.sourceAppName {
                HStack(spacing: 4) {
                    if let icon = item.sourceAppIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 12, height: 12)
                    }
                    Text(appName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Separator
            if self.item.sourceAppName != nil {
                Text("\u{2022}")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
            }

            // Timestamp
            Text(self.item.relativeTimestamp)
                .font(.caption)
                .foregroundColor(.secondary)

            // Content type badge
            Text(self.item.contentTypeName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
    }

    // MARK: - Indicators

    private var indicators: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if self.item.isSensitive {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                if self.item.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }

            if self.item.hasOCRText {
                Image(systemName: "text.viewfinder")
                    .font(.caption)
                    .foregroundColor(.teal)
                    .help("Contains extracted text from image")
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct ClipboardItemView_Previews: PreviewProvider {
        static var previews: some View {
            VStack(spacing: 0) {
                ClipboardItemView(item: .sampleText)
                    .background(Color(NSColor.windowBackgroundColor))

                Divider()

                ClipboardItemView(item: .sampleSensitive)
                    .background(Color(NSColor.windowBackgroundColor))

                Divider()

                ClipboardItemView(item: .sampleURL)
                    .background(Color(NSColor.windowBackgroundColor))
            }
            .frame(width: 400)
            .environmentObject(SettingsManager.shared)
        }
    }
#endif
