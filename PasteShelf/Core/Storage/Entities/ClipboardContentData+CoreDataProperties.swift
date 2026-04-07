//
//  ClipboardContentData+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch request for ClipboardContentData entity.
//

import CoreData
import Foundation

public extension ClipboardContentData {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<ClipboardContentData> {
        NSFetchRequest<ClipboardContentData>(entityName: "ClipboardContentData")
    }

    // MARK: - Attributes

    /// Unique identifier
    @NSManaged var id: UUID?

    /// Rich text data (RTF format)
    @NSManaged var rtfData: Data?

    /// HTML content as string
    @NSManaged var htmlContent: String?

    /// Image data (PNG, JPEG, TIFF) - uses external binary storage
    @NSManaged var imageData: Data?

    /// PDF document data - uses external binary storage
    @NSManaged var pdfData: Data?

    /// Full plain text content
    @NSManaged var plainTextData: String?

    /// Web URL as string
    @NSManaged var urlString: String?

    /// File URLs as JSON array string
    @NSManaged var fileURLsJSON: String?

    /// Available content types as JSON array string
    @NSManaged var availableTypesJSON: String?

    /// Whether the image was compressed for storage
    @NSManaged var isImageCompressed: Bool

    /// Original image width in pixels
    @NSManaged var imageWidth: Int32

    /// Original image height in pixels
    @NSManaged var imageHeight: Int32

    // MARK: - Relationships

    /// Parent clipboard item (inverse relationship)
    @NSManaged var clipboardItem: ClipboardItem?
}

// MARK: - Convenience Properties

extension ClipboardContentData {
    /// Parses fileURLsJSON into array of URLs
    var fileURLs: [URL]? {
        get {
            guard let json = fileURLsJSON,
                  let data = json.data(using: .utf8),
                  let paths = try? JSONDecoder().decode([String].self, from: data)
            else {
                return nil
            }
            return paths.compactMap { URL(string: $0) }
        }
        set {
            guard let urls = newValue else {
                self.fileURLsJSON = nil
                return
            }
            let paths = urls.map(\.absoluteString)
            if let data = try? JSONEncoder().encode(paths) {
                self.fileURLsJSON = String(data: data, encoding: .utf8)
            }
        }
    }

    /// Parses availableTypesJSON into array of strings
    var availableTypes: [String]? {
        get {
            guard let json = availableTypesJSON,
                  let data = json.data(using: .utf8)
            else {
                return nil
            }
            return try? JSONDecoder().decode([String].self, from: data)
        }
        set {
            guard let types = newValue else {
                self.availableTypesJSON = nil
                return
            }
            if let data = try? JSONEncoder().encode(types) {
                self.availableTypesJSON = String(data: data, encoding: .utf8)
            }
        }
    }

    /// Parses urlString into URL
    var url: URL? {
        get { self.urlString.flatMap { URL(string: $0) } }
        set { self.urlString = newValue?.absoluteString }
    }
}

// MARK: - ClipboardContentData + Identifiable

extension ClipboardContentData: Identifiable {}

// MARK: - Text Content Helper

extension ClipboardContentData {
    /// Returns text content from full plain text, HTML, or parent item's plainTextPreview
    var textContent: String? {
        // Try full plain text first
        if let text = plainTextData, !text.isEmpty {
            return text
        }
        // Try HTML
        if let html = htmlContent, !html.isEmpty {
            return html
        }
        // Fall back to parent's plain text preview
        return self.clipboardItem?.plainTextPreview
    }

    /// Returns HTML data as Data
    var htmlData: Data? {
        self.htmlContent?.data(using: .utf8)
    }
}
