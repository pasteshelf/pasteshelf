//
//  ClipboardContent.swift
//  PasteShelf
//
//  In-memory representation of clipboard content before persistence.
//  Holds all available representations of the clipboard data.
//

import AppKit
import Foundation

/// Represents clipboard content with all available data representations
struct ClipboardContent: Sendable {
    // MARK: - Properties

    /// Unique identifier for this content
    let id: UUID

    /// The timestamp when the content was captured
    let timestamp: Date

    /// The primary (highest priority) content type
    var primaryType: ContentType

    /// All available content types for this clipboard item
    var availableTypes: [ContentType]

    // MARK: - Text Representations

    /// Plain text content (UTF-8)
    var plainText: String?

    /// Rich text data (RTF format)
    var rtfData: Data?

    /// HTML content as string
    var html: String?

    // MARK: - Image Representations

    /// Image data in original format
    var imageData: Data?

    /// Generated thumbnail data (PNG, 256px max dimension)
    var thumbnailData: Data?

    /// Original image dimensions
    var imageWidth: Int?
    var imageHeight: Int?

    /// Whether the image was compressed for storage
    var isImageCompressed: Bool = false

    // MARK: - Document Representations

    /// PDF document data
    var pdfData: Data?

    // MARK: - Reference Representations

    /// Web URL
    var url: URL?

    /// File URLs (for file/folder references)
    var fileURLs: [URL]?

    // MARK: - Metadata

    /// Content hash for deduplication (SHA256)
    var contentHash: String?

    /// Whether this content was detected as sensitive
    var isSensitive: Bool = false

    /// Detected sensitive data types (if any)
    var sensitiveTypes: [String] = []

    /// The application that was the source of this content
    var sourceApp: SourceApp?

    // MARK: - Initialization

    /// Creates a new ClipboardContent with a primary type
    /// - Parameter primaryType: The primary content type
    init(primaryType: ContentType = .plainText) {
        self.id = UUID()
        self.timestamp = Date()
        self.primaryType = primaryType
        self.availableTypes = [primaryType]
    }

    /// Creates a ClipboardContent with full configuration
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        primaryType: ContentType,
        availableTypes: [ContentType],
        plainText: String? = nil,
        rtfData: Data? = nil,
        html: String? = nil,
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        isImageCompressed: Bool = false,
        pdfData: Data? = nil,
        url: URL? = nil,
        fileURLs: [URL]? = nil,
        contentHash: String? = nil,
        isSensitive: Bool = false,
        sensitiveTypes: [String] = [],
        sourceApp: SourceApp? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.primaryType = primaryType
        self.availableTypes = availableTypes
        self.plainText = plainText
        self.rtfData = rtfData
        self.html = html
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.isImageCompressed = isImageCompressed
        self.pdfData = pdfData
        self.url = url
        self.fileURLs = fileURLs
        self.contentHash = contentHash
        self.isSensitive = isSensitive
        self.sensitiveTypes = sensitiveTypes
        self.sourceApp = sourceApp
    }

    // MARK: - Computed Properties

    /// Returns a preview string suitable for display (first 500 characters)
    var previewText: String? {
        guard let text = plainText else { return nil }
        if text.count <= 500 {
            return text
        }
        return String(text.prefix(500)) + "..."
    }

    /// Returns the character count of plain text content
    var characterCount: Int? {
        plainText?.count
    }

    /// Returns the word count of plain text content
    var wordCount: Int? {
        guard let text = plainText else { return nil }
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }

    /// Returns the total size of all data in bytes
    var totalSizeBytes: Int {
        var size = 0
        size += plainText?.utf8.count ?? 0
        size += rtfData?.count ?? 0
        size += html?.utf8.count ?? 0
        size += imageData?.count ?? 0
        size += thumbnailData?.count ?? 0
        size += pdfData?.count ?? 0
        return size
    }

    /// Returns the image dimensions as a formatted string
    var imageDimensionsString: String? {
        guard let width = imageWidth, let height = imageHeight else {
            return nil
        }
        return "\(width) × \(height)"
    }

    /// Returns the file count for file URL content
    var fileCount: Int? {
        fileURLs?.count
    }

    /// Returns the first file URL's filename
    var primaryFileName: String? {
        fileURLs?.first?.lastPathComponent
    }

    // MARK: - Type Checks

    /// Whether this content has text data
    var hasText: Bool {
        plainText != nil || rtfData != nil || html != nil
    }

    /// Whether this content has image data
    var hasImage: Bool {
        imageData != nil
    }

    /// Whether this content has file references
    var hasFiles: Bool {
        fileURLs != nil && !(fileURLs?.isEmpty ?? true)
    }

    /// Whether this content has a URL
    var hasURL: Bool {
        url != nil
    }

    /// Whether this content is empty
    var isEmpty: Bool {
        !hasText && !hasImage && !hasFiles && !hasURL && pdfData == nil
    }
}

// MARK: - Equatable

extension ClipboardContent: Equatable {
    static func == (lhs: ClipboardContent, rhs: ClipboardContent) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension ClipboardContent: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
