//
//  ClipboardItemDisplayModel.swift
//  PasteShelf
//
//  UI-friendly display model created from CoreData ClipboardItem entity.
//  Used for presenting clipboard items in SwiftUI views.
//

import AppKit
import Foundation

/// UI-friendly model for displaying clipboard items
struct ClipboardItemDisplayModel: Identifiable, Hashable {
    // MARK: - Properties

    /// Unique identifier
    let id: UUID

    /// Primary content type
    let contentType: ContentType

    /// Plain text preview (first 500 chars)
    let plainTextPreview: String?

    /// Timestamp when captured
    let timestamp: Date

    /// Source application bundle ID
    let sourceAppBundleId: String?

    /// Source application display name
    let sourceAppName: String?

    /// Whether this item contains sensitive data
    let isSensitive: Bool

    /// Whether this item is marked as favorite
    let isFavorite: Bool

    /// SHA256 content hash for identification
    let contentHash: String?

    /// Thumbnail image data (for images)
    let thumbnailData: Data?

    /// Thumbnail dimensions
    let thumbnailSize: CGSize?

    /// OCR-extracted text from image
    var ocrText: String?

    // MARK: - Computed Properties

    /// Whether this item has OCR text available
    var hasOCRText: Bool {
        ocrText != nil && !(ocrText?.isEmpty ?? true)
    }

    /// Short OCR text preview (truncated)
    var ocrTextPreview: String? {
        guard let text = ocrText, !text.isEmpty else { return nil }
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        if cleaned.count <= 80 {
            return cleaned
        }
        return String(cleaned.prefix(77)) + "..."
    }

    /// SF Symbol icon for the content type
    var icon: String {
        contentType.icon
    }

    /// Human-readable content type name
    var contentTypeName: String {
        contentType.displayName
    }

    /// Whether this item has a thumbnail preview
    var hasThumbnail: Bool {
        thumbnailData != nil
    }

    /// NSImage from thumbnail data
    var thumbnailImage: NSImage? {
        guard let data = thumbnailData else { return nil }
        return NSImage(data: data)
    }

    /// Source app icon from bundle ID
    var sourceAppIcon: NSImage? {
        guard let bundleId = sourceAppBundleId,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
        else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    /// Relative timestamp string (e.g., "2 minutes ago")
    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    /// Full timestamp string for tooltip
    var fullTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    /// Display text for the item (truncated preview or type description)
    var displayText: String {
        if let preview = plainTextPreview, !preview.isEmpty {
            return preview
        }
        return "[\(contentTypeName)]"
    }

    /// Short display text (single line, truncated)
    func shortDisplayText(maxLength: Int = 50) -> String {
        let text = displayText
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespaces)

        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength - 3)) + "..."
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ClipboardItemDisplayModel, rhs: ClipboardItemDisplayModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Factory

extension ClipboardItemDisplayModel {
    /// Creates a display model from a CoreData ClipboardItem
    /// - Parameter item: The CoreData entity
    /// - Returns: A display model, or nil if the item has invalid data
    static func from(_ item: ClipboardItem) -> ClipboardItemDisplayModel? {
        guard let id = item.id,
              let contentTypeRaw = item.contentType,
              let contentType = ContentType(rawValue: contentTypeRaw),
              let timestamp = item.timestamp
        else {
            return nil
        }

        var thumbnailSize: CGSize?
        if let preview = item.preview {
            thumbnailSize = CGSize(
                width: CGFloat(preview.width),
                height: CGFloat(preview.height)
            )
        }

        return ClipboardItemDisplayModel(
            id: id,
            contentType: contentType,
            plainTextPreview: item.plainTextPreview,
            timestamp: timestamp,
            sourceAppBundleId: item.sourceAppBundleId,
            sourceAppName: item.sourceAppName,
            isSensitive: item.isSensitive,
            isFavorite: item.isFavorite,
            contentHash: item.contentHash,
            thumbnailData: item.preview?.thumbnailData,
            thumbnailSize: thumbnailSize,
            ocrText: nil
        )
    }

    /// Returns a copy of this model with OCR text set
    func withOCRText(_ text: String?) -> ClipboardItemDisplayModel {
        var copy = self
        copy.ocrText = text
        return copy
    }

    /// Creates display models from an array of CoreData items
    /// - Parameter items: Array of CoreData entities
    /// - Returns: Array of display models (invalid items are filtered out)
    static func from(_ items: [ClipboardItem]) -> [ClipboardItemDisplayModel] {
        items.compactMap { from($0) }
    }
}

// MARK: - Preview Support

#if DEBUG
    extension ClipboardItemDisplayModel {
        /// Sample text item for previews
        static let sampleText = ClipboardItemDisplayModel(
            id: UUID(),
            contentType: .plainText,
            plainTextPreview: "Hello, this is a sample clipboard item with some text content.",
            timestamp: Date().addingTimeInterval(-120),
            sourceAppBundleId: "com.apple.Safari",
            sourceAppName: "Safari",
            isSensitive: false,
            isFavorite: false,
            contentHash: "abc123",
            thumbnailData: nil,
            thumbnailSize: nil,
            ocrText: nil
        )

        /// Sample sensitive item for previews
        static let sampleSensitive = ClipboardItemDisplayModel(
            id: UUID(),
            contentType: .plainText,
            plainTextPreview: "sk-1234567890abcdef",
            timestamp: Date().addingTimeInterval(-300),
            sourceAppBundleId: "com.apple.Terminal",
            sourceAppName: "Terminal",
            isSensitive: true,
            isFavorite: false,
            contentHash: "def456",
            thumbnailData: nil,
            thumbnailSize: nil,
            ocrText: nil
        )

        /// Sample URL item for previews
        static let sampleURL = ClipboardItemDisplayModel(
            id: UUID(),
            contentType: .url,
            plainTextPreview: "https://www.apple.com",
            timestamp: Date().addingTimeInterval(-600),
            sourceAppBundleId: "com.apple.Safari",
            sourceAppName: "Safari",
            isSensitive: false,
            isFavorite: true,
            contentHash: "ghi789",
            thumbnailData: nil,
            thumbnailSize: nil,
            ocrText: nil
        )

        /// Sample items array for previews
        static let samples: [ClipboardItemDisplayModel] = [
            sampleText,
            sampleSensitive,
            sampleURL,
        ]
    }
#endif
