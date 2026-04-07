//
//  OCRCache+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch request for OCRCache entity.
//

import CoreData
import Foundation

public extension OCRCache {
    @nonobjc class func fetchRequest() -> NSFetchRequest<OCRCache> {
        NSFetchRequest<OCRCache>(entityName: "OCRCache")
    }

    // MARK: - Attributes

    /// Unique identifier for this cache entry
    @NSManaged var id: UUID?

    /// ID of the associated clipboard item
    @NSManaged var clipboardItemId: UUID?

    /// Extracted text from the image
    @NSManaged var extractedText: String?

    /// Version of the OCR model (for cache invalidation)
    @NSManaged var ocrVersion: Int16

    /// SHA256 hash of the image data (for deduplication)
    @NSManaged var imageHash: String?

    /// Average confidence score of text recognition (0.0 to 1.0)
    @NSManaged var confidence: Double

    /// Detected language of the text
    @NSManaged var language: String?

    /// When this OCR result was created
    @NSManaged var createdAt: Date?
}

// MARK: - Convenience Methods

extension OCRCache {
    /// Returns whether this cache entry has valid text
    var hasText: Bool {
        guard let text = extractedText else {
            return false
        }
        return !text.isEmpty
    }

    /// Returns the text preview (first 100 characters)
    var textPreview: String? {
        guard let text = extractedText, !text.isEmpty else {
            return nil
        }
        if text.count <= 100 {
            return text
        }
        return String(text.prefix(100)) + "..."
    }
}

// MARK: - OCRCache + Identifiable

extension OCRCache: Identifiable {}
