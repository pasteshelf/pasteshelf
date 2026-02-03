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
enum ContentType: String, CaseIterable, Codable, Sendable {
    case plainText = "public.utf8-plain-text"
    case richText = "public.rtf"
    case html = "public.html"
    case png = "public.png"
    case jpeg = "public.jpeg"
    case tiff = "public.tiff"
    case pdf = "com.adobe.pdf"
    case fileURL = "public.file-url"
    case url = "public.url"

    // MARK: - UTType Conversion

    /// Returns the corresponding UTType for this content type
    var utType: UTType? {
        switch self {
        case .plainText: return .plainText
        case .richText: return .rtf
        case .html: return .html
        case .png: return .png
        case .jpeg: return .jpeg
        case .tiff: return .tiff
        case .pdf: return .pdf
        case .fileURL: return .fileURL
        case .url: return .url
        }
    }

    /// Creates a ContentType from a UTType
    /// - Parameter utType: The UTType to convert
    /// - Returns: The corresponding ContentType, or nil if not supported
    static func from(utType: UTType) -> ContentType? {
        switch utType {
        case .plainText: return .plainText
        case .rtf: return .richText
        case .html: return .html
        case .png: return .png
        case .jpeg: return .jpeg
        case .tiff: return .tiff
        case .pdf: return .pdf
        case .fileURL: return .fileURL
        case .url: return .url
        default: return nil
        }
    }

    /// Creates a ContentType from a raw UTI string
    /// - Parameter uti: The UTI string
    /// - Returns: The corresponding ContentType, or nil if not supported
    static func from(uti: String) -> ContentType? {
        ContentType(rawValue: uti)
    }

    // MARK: - Priority

    /// Priority for type selection when multiple types are available.
    /// Lower values indicate higher priority (richer content preferred).
    var priority: Int {
        switch self {
        case .richText: return 1
        case .html: return 2
        case .plainText: return 3
        case .png: return 4
        case .jpeg: return 5
        case .tiff: return 6
        case .pdf: return 7
        case .url: return 8
        case .fileURL: return 9
        }
    }

    // MARK: - Display Properties

    /// SF Symbol icon name for display
    var icon: String {
        switch self {
        case .plainText: return "doc.text"
        case .richText: return "doc.richtext"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .png, .jpeg, .tiff: return "photo"
        case .pdf: return "doc.fill"
        case .fileURL: return "folder"
        case .url: return "link"
        }
    }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .plainText: return "Plain Text"
        case .richText: return "Rich Text"
        case .html: return "HTML"
        case .png: return "PNG Image"
        case .jpeg: return "JPEG Image"
        case .tiff: return "TIFF Image"
        case .pdf: return "PDF Document"
        case .fileURL: return "File"
        case .url: return "URL"
        }
    }

    // MARK: - Type Categories

    /// Whether this content type represents text content
    var isTextType: Bool {
        switch self {
        case .plainText, .richText, .html: return true
        default: return false
        }
    }

    /// Whether this content type represents image content
    var isImageType: Bool {
        switch self {
        case .png, .jpeg, .tiff: return true
        default: return false
        }
    }

    /// Whether this content type represents a URL or file reference
    var isReferenceType: Bool {
        switch self {
        case .url, .fileURL: return true
        default: return false
        }
    }
}
