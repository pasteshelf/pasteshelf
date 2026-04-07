//
//  StorageManager+OCR.swift
//  PasteShelf
//
//  OCR cache CRUD operations for text extraction from images.
//

import CoreData
import CryptoKit
import Foundation
import os.log

// MARK: - OCRCacheEntry

/// Represents an OCR cache entry with extracted text and metadata
struct OCRCacheEntry {
    let text: String
    let confidence: Double
    let language: String?
}

// MARK: - OCRResult

/// Represents an OCR result with its associated clipboard item
struct OCRResult {
    let itemId: UUID
    let text: String
    let confidence: Double
}

extension StorageManager {
    // MARK: - Create Operations

    /// Saves OCR text for a clipboard item
    /// - Parameters:
    ///   - itemId: The clipboard item ID
    ///   - text: The extracted text
    ///   - confidence: The OCR confidence score (0.0 to 1.0)
    ///   - language: The detected language code
    ///   - imageHash: SHA256 hash of the image data
    /// - Returns: True if save succeeded
    func saveOCRText(
        for itemId: UUID,
        text: String,
        confidence: Double,
        language: String?,
        imageHash: String? = nil
    ) async -> Bool {
        do {
            try await performBackgroundTask { context in
                // Check for existing OCR cache
                let request = OCRCache.fetchRequest()
                request.predicate = NSPredicate(format: "clipboardItemId == %@", itemId as CVarArg)
                request.fetchLimit = 1

                // Delete existing if present
                if let existing = try context.fetch(request).first {
                    context.delete(existing)
                }

                // Create new OCR cache entry
                let cache = OCRCache(context: context)
                cache.id = UUID()
                cache.clipboardItemId = itemId
                cache.extractedText = text
                cache.ocrVersion = OCRManager.ocrVersion
                cache.confidence = confidence
                cache.language = language
                cache.imageHash = imageHash
                cache.createdAt = Date()
            }
            return true
        } catch {
            return false
        }
    }

    /// Saves multiple OCR results in batch
    /// - Parameter ocrResults: Array of OCRSaveItem structs
    /// - Returns: Number of OCR results saved
    func saveOCRResults(_ ocrResults: [OCRSaveItem]) async -> Int {
        let result = await performBackgroundTaskSafe { context -> Int in
            var savedCount = 0

            for item in ocrResults {
                let itemId = item.itemId
                let text = item.text
                let confidence = item.confidence
                let language = item.language
                // Check for existing
                let request = OCRCache.fetchRequest()
                request.predicate = NSPredicate(format: "clipboardItemId == %@", itemId as CVarArg)
                request.fetchLimit = 1

                if let existing = try? context.fetch(request).first {
                    context.delete(existing)
                }

                let cache = OCRCache(context: context)
                cache.id = UUID()
                cache.clipboardItemId = itemId
                cache.extractedText = text
                cache.ocrVersion = OCRManager.ocrVersion
                cache.confidence = confidence
                cache.language = language
                cache.createdAt = Date()

                savedCount += 1
            }

            return savedCount
        }
        return result ?? 0
    }

    // MARK: - Read Operations

    /// Fetches the OCR text for a clipboard item
    /// - Parameter itemId: The clipboard item ID
    /// - Returns: The extracted text, or nil if not found
    func fetchOCRText(for itemId: UUID) async -> String? {
        let context = newBackgroundContext()

        return await context.perform {
            let request = OCRCache.fetchRequest()
            request.predicate = NSPredicate(
                format: "clipboardItemId == %@ AND ocrVersion == %d",
                itemId as CVarArg,
                OCRManager.ocrVersion
            )
            request.fetchLimit = 1

            guard let cache = try? context.fetch(request).first else {
                return nil
            }
            return cache.extractedText
        }
    }

    /// Fetches the full OCR cache entry for a clipboard item
    /// - Parameter itemId: The clipboard item ID
    /// - Returns: OCR cache data or nil if not found
    func fetchOCRCache(for itemId: UUID) async -> OCRCacheEntry? {
        let context = newBackgroundContext()

        return await context.perform {
            let request = OCRCache.fetchRequest()
            request.predicate = NSPredicate(
                format: "clipboardItemId == %@ AND ocrVersion == %d",
                itemId as CVarArg,
                OCRManager.ocrVersion
            )
            request.fetchLimit = 1

            guard let cache = try? context.fetch(request).first,
                  let text = cache.extractedText
            else {
                return nil
            }
            return OCRCacheEntry(text: text, confidence: cache.confidence, language: cache.language)
        }
    }

    /// Fetches OCR text for multiple clipboard items
    /// - Parameter itemIds: Array of clipboard item IDs
    /// - Returns: Dictionary mapping item ID to extracted text
    func fetchOCRTexts(for itemIds: [UUID]) async -> [UUID: String] {
        guard !itemIds.isEmpty else {
            return [:]
        }

        let context = newBackgroundContext()

        return await context.perform {
            let request = OCRCache.fetchRequest()
            request.predicate = NSPredicate(
                format: "clipboardItemId IN %@ AND ocrVersion == %d",
                itemIds,
                OCRManager.ocrVersion
            )

            guard let caches = try? context.fetch(request) else {
                return [:]
            }

            var results: [UUID: String] = [:]
            for cache in caches {
                if let itemId = cache.clipboardItemId, let text = cache.extractedText {
                    results[itemId] = text
                }
            }
            return results
        }
    }

    /// Fetches all OCR results with their clipboard item IDs
    /// - Parameter limit: Maximum number of results to fetch
    /// - Returns: Array of (itemId, text, confidence) tuples
    func fetchAllOCRResults(limit: Int = 1000) async -> [OCRResult] {
        let context = newBackgroundContext()

        return await context.perform {
            let request = OCRCache.fetchRequest()
            request.predicate = NSPredicate(format: "ocrVersion == %d", OCRManager.ocrVersion)
            request.fetchLimit = limit
            request.sortDescriptors = [NSSortDescriptor(keyPath: \OCRCache.createdAt, ascending: false)]

            guard let caches = try? context.fetch(request) else {
                return []
            }

            return caches.compactMap { cache in
                guard let itemId = cache.clipboardItemId, let text = cache.extractedText else {
                    return nil
                }
                return OCRResult(itemId: itemId, text: text, confidence: cache.confidence)
            }
        }
    }

    /// Finds an existing OCR result by image hash (for deduplication)
    /// - Parameter imageData: The image data to find OCR for
    /// - Returns: The extracted text if found
    func findOCRByImageHash(_ imageData: Data) async -> String? {
        let hash = Self.hashImageData(imageData)
        let context = newBackgroundContext()

        return await context.perform {
            let request = OCRCache.fetchRequest()
            request.predicate = NSPredicate(
                format: "imageHash == %@ AND ocrVersion == %d",
                hash,
                OCRManager.ocrVersion
            )
            request.fetchLimit = 1

            guard let cache = try? context.fetch(request).first else {
                return nil
            }
            return cache.extractedText
        }
    }

    /// Returns IDs of clipboard items that don't have OCR text
    /// - Parameter itemIds: Array of item IDs to check
    /// - Returns: Array of item IDs without OCR
    func findItemsWithoutOCR(from itemIds: [UUID]) async -> [UUID] {
        guard !itemIds.isEmpty else {
            return []
        }

        let context = newBackgroundContext()

        return await context.perform {
            let request = OCRCache.fetchRequest()
            request.predicate = NSPredicate(
                format: "clipboardItemId IN %@ AND ocrVersion == %d",
                itemIds,
                OCRManager.ocrVersion
            )
            request.propertiesToFetch = ["clipboardItemId"]

            guard let caches = try? context.fetch(request) else {
                return itemIds
            }

            let ocrItemIds = Set(caches.compactMap(\.clipboardItemId))
            return itemIds.filter { !ocrItemIds.contains($0) }
        }
    }

    // MARK: - Delete Operations

    /// Deletes the OCR cache for a clipboard item
    /// - Parameter itemId: The clipboard item ID
    /// - Returns: True if deletion succeeded
    func deleteOCRText(for itemId: UUID) async -> Bool {
        do {
            try await performBackgroundTask { context in
                let request = OCRCache.fetchRequest()
                request.predicate = NSPredicate(format: "clipboardItemId == %@", itemId as CVarArg)

                let caches = try context.fetch(request)
                for cache in caches {
                    context.delete(cache)
                }
            }
            return true
        } catch {
            return false
        }
    }

    /// Deletes OCR caches for multiple clipboard items
    /// - Parameter itemIds: Array of clipboard item IDs
    /// - Returns: Number of OCR entries deleted
    func deleteOCRTexts(for itemIds: [UUID]) async -> Int {
        guard !itemIds.isEmpty else {
            return 0
        }

        let result = await performBackgroundTaskSafe { context -> Int in
            let request = OCRCache.fetchRequest()
            request.predicate = NSPredicate(format: "clipboardItemId IN %@", itemIds)

            guard let caches = try? context.fetch(request) else {
                return 0
            }

            let count = caches.count
            for cache in caches {
                context.delete(cache)
            }
            return count
        }
        return result ?? 0
    }

    /// Deletes all OCR entries with outdated versions
    /// - Returns: Number of OCR entries deleted
    func deleteOutdatedOCR() async -> Int {
        let result = await performBackgroundTaskSafe { context -> Int in
            let request = OCRCache.fetchRequest()
            request.predicate = NSPredicate(format: "ocrVersion != %d", OCRManager.ocrVersion)

            guard let caches = try? context.fetch(request) else {
                return 0
            }

            let count = caches.count
            for cache in caches {
                context.delete(cache)
            }
            return count
        }
        return result ?? 0
    }

    /// Deletes all OCR entries
    /// - Returns: Number of OCR entries deleted
    func deleteAllOCR() async -> Int {
        let result = await performBackgroundTaskSafe { context -> Int in
            let request = OCRCache.fetchRequest()

            guard let caches = try? context.fetch(request) else {
                return 0
            }

            let count = caches.count
            for cache in caches {
                context.delete(cache)
            }
            return count
        }
        return result ?? 0
    }

    // MARK: - Statistics

    /// Returns the total number of cached OCR entries
    func ocrCount() async -> Int {
        let context = newBackgroundContext()

        return await context.perform {
            let request = OCRCache.fetchRequest()
            request.predicate = NSPredicate(format: "ocrVersion == %d", OCRManager.ocrVersion)
            return (try? context.count(for: request)) ?? 0
        }
    }

    // MARK: - Helpers

    /// Creates a SHA256 hash of the image data for deduplication
    static func hashImageData(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - OCRSaveItem

/// Data structure for batch saving OCR results
struct OCRSaveItem: Sendable {
    // MARK: Lifecycle

    init(itemId: UUID, text: String, confidence: Double, language: String? = nil) {
        self.itemId = itemId
        self.text = text
        self.confidence = confidence
        self.language = language
    }

    // MARK: Internal

    let itemId: UUID
    let text: String
    let confidence: Double
    let language: String?
}
