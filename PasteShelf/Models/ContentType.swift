//
//  ContentType.swift
//  PasteShelf
//
//  Represents the different content types supported by the clipboard engine.
//  Maps to macOS UTI (Uniform Type Identifier) system.
//

import Foundation
import UniformTypeIdentifiers

/// Represents supported clipboard content types with UTI mappings
public enum ContentType: String, CaseIterable, Codable, Sendable {
    case plainText = "public.utf8-plain-text"
    case richText = "public.rtf"
    case html = "public.html"
    case png = "public.png"
    case jpeg = "public.jpeg"
    case tiff = "public.tiff"
    case pdf = "com.adobe.pdf"
    case fileURL = "public.file-url"
    case url = "public.url"

    // MARK: Internal

    // MARK: - UTType Conversion

    /// Returns the corresponding UTType for this content type
    var utType: UTType? {
        switch self {
        case .plainText: .plainText
        case .richText: .rtf
        case .html: .html
        case .png: .png
        case .jpeg: .jpeg
        case .tiff: .tiff
        case .pdf: .pdf
        case .fileURL: .fileURL
        case .url: .url
        }
    }

    // MARK: - Priority

    /// Priority for type selection when multiple types are available.
    /// Lower values indicate higher priority (richer content preferred).
    var priority: Int {
        switch self {
        case .richText: 1
        case .html: 2
        case .fileURL: 3
        case .url: 4
        case .png: 5
        case .jpeg: 6
        case .tiff: 7
        case .pdf: 8
        case .plainText: 9
        }
    }

    // MARK: - Display Properties

    /// SF Symbol icon name for display
    var icon: String {
        switch self {
        case .plainText: "doc.text"
        case .richText: "doc.richtext"
        case .html: "chevron.left.forwardslash.chevron.right"
        case .png,
             .jpeg,
             .tiff: "photo"
        case .pdf: "doc.fill"
        case .fileURL: "folder"
        case .url: "link"
        }
    }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .plainText: "Plain Text"
        case .richText: "Rich Text"
        case .html: "HTML"
        case .png: "PNG Image"
        case .jpeg: "JPEG Image"
        case .tiff: "TIFF Image"
        case .pdf: "PDF Document"
        case .fileURL: "File"
        case .url: "URL"
        }
    }

    // MARK: - Type Categories

    /// Whether this content type represents text content
    var isTextType: Bool {
        switch self {
        case .plainText,
             .richText,
             .html: true
        default: false
        }
    }

    /// Whether this content type represents image content
    var isImageType: Bool {
        switch self {
        case .png,
             .jpeg,
             .tiff: true
        default: false
        }
    }

    /// Whether this content type represents a URL or file reference
    var isReferenceType: Bool {
        switch self {
        case .url,
             .fileURL: true
        default: false
        }
    }

    /// Creates a ContentType from a UTType
    /// - Parameter utType: The UTType to convert
    /// - Returns: The corresponding ContentType, or nil if not supported
    static func from(utType: UTType) -> ContentType? {
        switch utType {
        case .plainText: .plainText
        case .rtf: .richText
        case .html: .html
        case .png: .png
        case .jpeg: .jpeg
        case .tiff: .tiff
        case .pdf: .pdf
        case .fileURL: .fileURL
        case .url: .url
        default: nil
        }
    }

    /// Creates a ContentType from a raw UTI string
    /// - Parameter uti: The UTI string
    /// - Returns: The corresponding ContentType, or nil if not supported
    static func from(uti: String) -> ContentType? {
        ContentType(rawValue: uti)
    }
}
