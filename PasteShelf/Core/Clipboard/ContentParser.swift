//
//  ContentParser.swift
//  PasteShelf
//
//  Parses NSPasteboard content into ClipboardContent,
//  extracting all available representations with priority handling.
//

import AppKit
import Foundation
import os.log
import UniformTypeIdentifiers

/// Parses clipboard content from NSPasteboard
final class ContentParser: ContentParsing, Sendable {
    // MARK: - Properties

    /// Image processor for handling image content
    private let imageProcessor: ImageProcessing

    /// Deduplicator for computing content hash
    private let deduplicator: Deduplicating

    // MARK: - Initialization

    init(
        imageProcessor: ImageProcessing = ImageProcessor(),
        deduplicator: Deduplicating = Deduplicator()
    ) {
        self.imageProcessor = imageProcessor
        self.deduplicator = deduplicator
    }

    // MARK: - ContentParsing

    func parse(_ pasteboard: NSPasteboard) -> ClipboardContent? {
        // Get available types sorted by priority
        let availableTypes = getAvailableTypes(from: pasteboard)

        guard !availableTypes.isEmpty else {
            Logger.clipboard.debug("No supported content types in pasteboard")
            return nil
        }

        // Primary type is the highest priority available
        guard let primaryType = availableTypes.first else {
            return nil
        }

        var content = ClipboardContent(primaryType: primaryType)
        content.availableTypes = availableTypes

        // Extract all representations
        extractTextContent(from: pasteboard, into: &content)
        extractImageContent(from: pasteboard, into: &content)
        extractDocumentContent(from: pasteboard, into: &content)
        extractURLContent(from: pasteboard, into: &content)

        // Refine primary type based on extracted content
        refineContentType(&content)

        // Ensure we have at least some content
        guard !content.isEmpty else {
            Logger.clipboard.debug("Parsed content is empty")
            return nil
        }

        // Compute content hash
        content.contentHash = deduplicator.computeHash(for: content)

        Logger.clipboard.debug(
            "Parsed content: type=\(primaryType.displayName), types=\(availableTypes.count)"
        )

        return content
    }

    func parse(_ pasteboard: NSPasteboard, forType type: ContentType) -> ClipboardContent? {
        var content = ClipboardContent(primaryType: type)
        content.availableTypes = [type]

        switch type {
        case .plainText:
            content.plainText = pasteboard.string(forType: .string)

        case .richText:
            content.rtfData = pasteboard.data(forType: .rtf)
            // Also extract plain text for preview
            extractPlainTextFromRTF(pasteboard, into: &content)

        case .html:
            content.html = pasteboard.string(forType: .html)
            // Also extract plain text for preview
            content.plainText = pasteboard.string(forType: .string)

        case .png, .jpeg, .tiff:
            extractImageContent(from: pasteboard, into: &content)

        case .pdf:
            content.pdfData = pasteboard.data(forType: .pdf)

        case .fileURL:
            extractFileURLs(from: pasteboard, into: &content)

        case .url:
            extractWebURL(from: pasteboard, into: &content)
        }

        guard !content.isEmpty else {
            return nil
        }

        content.contentHash = deduplicator.computeHash(for: content)
        return content
    }

    // MARK: - Type Detection

    /// Gets supported content types from pasteboard, sorted by priority
    private func getAvailableTypes(from pasteboard: NSPasteboard) -> [ContentType] {
        guard let pasteboardTypes = pasteboard.types else {
            return []
        }

        var contentTypes: [ContentType] = []

        for pasteboardType in pasteboardTypes {
            // Try to convert pasteboard type to our ContentType
            if let contentType = ContentType(rawValue: pasteboardType.rawValue) {
                if !contentTypes.contains(contentType) {
                    contentTypes.append(contentType)
                }
                continue
            }

            // Handle additional mappings
            if let mappedType = mapPasteboardType(pasteboardType) {
                if !contentTypes.contains(mappedType) {
                    contentTypes.append(mappedType)
                }
            }
        }

        // Sort by priority (lower = higher priority)
        return contentTypes.sorted { $0.priority < $1.priority }
    }

    /// Maps additional pasteboard types to our ContentType enum
    private func mapPasteboardType(_ type: NSPasteboard.PasteboardType) -> ContentType? {
        switch type {
        case .string:
            return .plainText
        case .rtf:
            return .richText
        case .html:
            return .html
        case .png:
            return .png
        case .tiff:
            return .tiff
        case .pdf:
            return .pdf
        case .fileURL:
            return .fileURL
        case .URL:
            return .url
        default:
            // Check UTType conformance
            if let utType = UTType(type.rawValue) {
                if utType.conforms(to: .jpeg) {
                    return .jpeg
                }
                if utType.conforms(to: .plainText) {
                    return .plainText
                }
                if utType.conforms(to: .image) {
                    return .png // Default image type
                }
            }
            return nil
        }
    }

    // MARK: - Content Extraction

    private func extractTextContent(from pasteboard: NSPasteboard, into content: inout ClipboardContent) {
        // Plain text
        if content.availableTypes.contains(.plainText) {
            content.plainText = pasteboard.string(forType: .string)
        }

        // Rich text (RTF)
        if content.availableTypes.contains(.richText) {
            content.rtfData = pasteboard.data(forType: .rtf)
            // Extract plain text from RTF if not already set
            if content.plainText == nil {
                extractPlainTextFromRTF(pasteboard, into: &content)
            }
        }

        // HTML
        if content.availableTypes.contains(.html) {
            content.html = pasteboard.string(forType: .html)
            // Extract plain text from HTML if not already set
            if content.plainText == nil {
                content.plainText = pasteboard.string(forType: .string)
            }
        }
    }

    private func extractImageContent(from pasteboard: NSPasteboard, into content: inout ClipboardContent) {
        let imageTypes: [ContentType] = [.png, .jpeg, .tiff]
        guard content.availableTypes.contains(where: { imageTypes.contains($0) }) else {
            return
        }

        // Try to create NSImage from pasteboard
        guard let image = NSImage(pasteboard: pasteboard) else {
            Logger.clipboard.debug("Failed to create NSImage from pasteboard")
            return
        }

        // Process the image
        let processed = imageProcessor.process(image)
        content.imageData = processed.data
        content.thumbnailData = processed.thumbnail
        content.imageWidth = processed.width
        content.imageHeight = processed.height
        content.isImageCompressed = processed.isCompressed
    }

    private func extractDocumentContent(from pasteboard: NSPasteboard, into content: inout ClipboardContent) {
        // PDF
        if content.availableTypes.contains(.pdf) {
            content.pdfData = pasteboard.data(forType: .pdf)
        }
    }

    private func extractURLContent(from pasteboard: NSPasteboard, into content: inout ClipboardContent) {
        // File URLs
        if content.availableTypes.contains(.fileURL) {
            extractFileURLs(from: pasteboard, into: &content)
        }

        // Web URLs
        extractWebURL(from: pasteboard, into: &content)
    }

    private func extractFileURLs(from pasteboard: NSPasteboard, into content: inout ClipboardContent) {
        let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]

        content.fileURLs = urls?.filter { $0.isFileURL }
    }

    private func extractWebURL(from pasteboard: NSPasteboard, into content: inout ClipboardContent) {
        // Try URL type first
        if let urlString = pasteboard.string(forType: .URL),
           let url = URL(string: urlString) {
            content.url = url
            return
        }

        // Fall back to reading URL objects
        let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: false]
        ) as? [URL]

        content.url = urls?.first { !$0.isFileURL }

        // Also check plain text for URLs
        if content.url == nil,
           let text = pasteboard.string(forType: .string),
           let url = URL(string: text),
           url.scheme != nil {
            content.url = url
        }
    }

    /// Re-evaluates primaryType based on actually extracted content.
    /// Handles cases where pasteboard type priority doesn't match actual content
    /// (e.g., HTML wrapper around an image, or a URL provided only as plain text).
    private func refineContentType(_ content: inout ClipboardContent) {
        // If we extracted image data but primary type is text, prefer image type
        if content.imageData != nil && content.primaryType.isTextType {
            if let imageType = content.availableTypes.first(where: { $0.isImageType }) {
                content.primaryType = imageType
            }
        }

        // If primary is plain text and content is a valid URL, upgrade to URL type
        if content.primaryType == .plainText,
           content.url != nil || isURL(content.plainText) {
            if content.url == nil, let text = content.plainText,
               let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                content.url = url
            }
            content.primaryType = .url
            if !content.availableTypes.contains(.url) {
                content.availableTypes.append(.url)
            }
        }
    }

    /// Checks if a string looks like a URL
    private func isURL(_ text: String?) -> Bool {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              !text.contains(" "),
              !text.contains("\n"),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              ["http", "https", "ftp", "ftps", "ssh"].contains(scheme)
        else { return false }
        return true
    }

    private func extractPlainTextFromRTF(_ pasteboard: NSPasteboard, into content: inout ClipboardContent) {
        guard let rtfData = pasteboard.data(forType: .rtf) else { return }

        do {
            let attributedString = try NSAttributedString(
                data: rtfData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
            content.plainText = attributedString.string
        } catch {
            Logger.clipboard.debug("Failed to extract plain text from RTF: \(error.localizedDescription)")
        }
    }
}

// MARK: - Pasteboard Extensions

extension NSPasteboard {
    /// Estimates the total size of pasteboard content
    var estimatedSize: Int {
        var totalSize = 0
        for type in types ?? [] {
            if let data = data(forType: type) {
                totalSize += data.count
            }
        }
        return totalSize
    }
}
