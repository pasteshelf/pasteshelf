//
//  ClipboardItemView.swift
//  PasteShelf
//
//  Displays a single clipboard item with content preview, metadata, and actions.
//  Handles text, images, URLs, and sensitive content with appropriate masking.
//

import SwiftUI

/// View for displaying a single clipboard item
struct ClipboardItemView: View {
    // MARK: - Properties

    let item: ClipboardItemDisplayModel

    /// Optional search highlight ranges
    var searchHighlights: [MatchRange] = []

    /// Optional search query for highlighting
    var searchQuery: String?

    /// Whether sensitive content should be revealed
    @State private var isRevealed = false

    /// Whether there are search highlights to show
    private var hasSearchHighlights: Bool {
        !searchHighlights.isEmpty || searchQuery != nil
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Content type icon
            contentTypeIcon

            // Main content
            VStack(alignment: .leading, spacing: 4) {
                // Content preview
                contentPreview

                // Metadata row
                metadataRow
            }

            Spacer()

            // Actions/indicators
            indicators
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Content Type Icon

    private var contentTypeIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(iconBackgroundColor)
                .frame(width: 32, height: 32)

            Image(systemName: item.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(iconForegroundColor)
        }
    }

    private var iconBackgroundColor: Color {
        switch item.contentType {
        case .plainText, .richText, .html:
            return Color.blue.opacity(0.15)
        case .png, .jpeg, .tiff:
            return Color.green.opacity(0.15)
        case .pdf:
            return Color.red.opacity(0.15)
        case .url, .fileURL:
            return Color.purple.opacity(0.15)
        }
    }

    private var iconForegroundColor: Color {
        switch item.contentType {
        case .plainText, .richText, .html:
            return .blue
        case .png, .jpeg, .tiff:
            return .green
        case .pdf:
            return .red
        case .url, .fileURL:
            return .purple
        }
    }

    // MARK: - Content Preview

    @ViewBuilder
    private var contentPreview: some View {
        if item.isSensitive, !isRevealed {
            sensitiveContentView
        } else if item.contentType.isImageType, item.hasThumbnail {
            imagePreviewView
        } else {
            textPreviewView
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

            Button(action: { isRevealed = true }) {
                Text("Reveal")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
    }

    private var imagePreviewView: some View {
        Group {
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
        }
    }

    private var textPreviewView: some View {
        Group {
            if let query = searchQuery, !query.isEmpty {
                // Use highlighted text
                HighlightedTextView(
                    text: item.shortDisplayText(maxLength: 100),
                    query: query,
                    lineLimit: 2
                )
            } else if !searchHighlights.isEmpty {
                // Use provided highlight ranges
                HighlightedTextView(
                    text: item.shortDisplayText(maxLength: 100),
                    matchRanges: searchHighlights,
                    lineLimit: 2
                )
            } else {
                // Regular text
                Text(item.shortDisplayText(maxLength: 100))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
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
            if item.sourceAppName != nil {
                Text("\u{2022}")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
            }

            // Timestamp
            Text(item.relativeTimestamp)
                .font(.caption)
                .foregroundColor(.secondary)

            // Content type badge
            if !item.contentType.isTextType {
                Text(item.contentTypeName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
    }

    // MARK: - Indicators

    private var indicators: some View {
        VStack(spacing: 4) {
            if item.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }

            if item.isSensitive {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
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
        }
    }
#endif
