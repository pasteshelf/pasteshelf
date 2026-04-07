//
//  OCRGenerator.swift
//  PasteShelf
//
//  Background OCR text extraction for image search.
//  Handles batch processing of images and caching of extracted text.
//

import Combine
import Foundation
import os.log

/// Manages background OCR text extraction from images for search
@MainActor
final class OCRGenerator: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    private init(
        storageManager: StorageManager = .shared,
        ocrManager: OCRManager = .shared
    ) {
        self.storageManager = storageManager
        self.ocrManager = ocrManager
    }

    // MARK: Internal

    // MARK: - Singleton

    static let shared = OCRGenerator()

    // MARK: - Published Properties

    /// Whether processing is currently in progress
    @Published private(set) var isProcessing: Bool = false

    /// Number of items processed in the current/last batch
    @Published private(set) var processedCount: Int = 0

    /// Total items to process in the current batch
    @Published private(set) var totalToProcess: Int = 0

    /// Progress percentage (0.0 to 1.0)
    var progress: Double {
        guard self.totalToProcess > 0 else {
            return 0.0
        }
        return Double(self.processedCount) / Double(self.totalToProcess)
    }

    /// Whether OCR search is available
    var isAvailable: Bool {
        self.ocrManager.isAvailable
    }

    /// Creates an OCRGenerator for testing
    static func forTesting(storageManager: StorageManager) -> OCRGenerator {
        OCRGenerator()
    }

    // MARK: - Single Item Processing

    /// Extracts OCR text for a single clipboard item
    /// - Parameter itemId: The clipboard item ID
    /// - Returns: True if OCR was extracted successfully
    @discardableResult
    func generateOCR(for itemId: UUID) async -> Bool { // swiftlint:disable:this function_body_length
        // Check if OCR manager is available
        guard self.ocrManager.isAvailable else {
            self.logger.warning("OCR manager not available")
            return false
        }

        // Fetch the item
        guard let item = await storageManager.fetchItem(byId: itemId) else {
            return false
        }

        // Check if it's an image type
        guard let contentTypeStr = item.contentType,
              let contentType = ContentType(rawValue: contentTypeStr),
              contentType.isImageType
        else {
            return false
        }

        // Check if OCR already exists
        if await self.storageManager.fetchOCRText(for: itemId) != nil {
            self.logger.debug("OCR already exists for item: \(itemId)")
            return true
        }

        // Get image data
        guard let imageData = item.content?.imageData else {
            self.logger.debug("No image data for item: \(itemId)")
            return false
        }

        // Check if image is processable
        guard self.ocrManager.canProcess(imageData) else {
            self.logger.debug("Image too small for OCR: \(itemId)")
            return false
        }

        // Check for duplicate image (reuse existing OCR)
        if let existingText = await storageManager.findOCRByImageHash(imageData) {
            let imageHash = StorageManager.hashImageData(imageData)
            let saved = await storageManager.saveOCRText(
                for: itemId,
                text: existingText,
                confidence: 1.0, // Reused, assume good confidence
                language: nil,
                imageHash: imageHash
            )
            self.logger.debug("Reused existing OCR for item: \(itemId)")
            return saved
        }

        // Perform OCR
        guard let result = await ocrManager.recognizeText(in: imageData),
              result.isSuccess
        else {
            self.logger.debug("OCR failed for item: \(itemId)")
            return false
        }

        // Save OCR result
        let imageHash = StorageManager.hashImageData(imageData)
        let saved = await storageManager.saveOCRText(
            for: itemId,
            text: result.text,
            confidence: result.confidence,
            language: result.language,
            imageHash: imageHash
        )

        if saved {
            self.logger.debug("Generated OCR for item: \(itemId), confidence: \(result.confidence)")
        }

        return saved
    }

    // MARK: - Batch Processing

    /// Processes all image items that don't have OCR text
    /// - Returns: Number of items processed
    @discardableResult
    func processAllMissingOCR() async -> Int { // swiftlint:disable:this function_body_length
        // Check if already processing
        guard !self.isProcessing else {
            self.logger.debug("Processing already in progress")
            return 0
        }

        // Check if OCR manager is available
        guard self.ocrManager.isAvailable else {
            self.logger.warning("OCR manager not available")
            return 0
        }

        // Cancel any existing task
        self.processingTask?.cancel()

        self.isProcessing = true
        self.processedCount = 0
        self.totalToProcess = 0

        let task = Task<Int, Never>(priority: .background) { [weak self] in
            guard let self else {
                return 0
            }

            var totalProcessed = 0

            // Fetch image items without OCR in batches
            var offset = 0

            while !Task.isCancelled {
                // Fetch a batch of recent image items
                let contentTypePredicate = NSPredicate(
                    format: "contentType IN %@",
                    imageContentTypes.map(\.rawValue)
                )
                let items = await storageManager.fetchRecentItems(
                    limit: self.batchSize,
                    offset: offset,
                    predicate: contentTypePredicate
                )

                if items.isEmpty {
                    break
                }

                // Get items without OCR
                let itemIds = items.compactMap(\.id)
                let missingIds = await storageManager.findItemsWithoutOCR(from: itemIds)

                if missingIds.isEmpty {
                    offset += self.batchSize
                    continue
                }

                // Update progress
                await MainActor.run {
                    self.totalToProcess += missingIds.count
                }

                // Process items without OCR
                for itemId in missingIds {
                    if Task.isCancelled {
                        break
                    }

                    let success = await processItem(itemId: itemId)
                    if success {
                        totalProcessed += 1
                        await MainActor.run {
                            self.processedCount += 1
                        }
                    }

                    // Check session limit
                    if totalProcessed >= self.maxItemsPerSession {
                        self.logger.info("Reached session limit: \(totalProcessed) items processed")
                        break
                    }
                }

                if totalProcessed >= self.maxItemsPerSession {
                    break
                }

                offset += self.batchSize

                // Delay between batches to avoid overwhelming the system
                try? await Task.sleep(for: .milliseconds(self.batchDelayMs))
            }

            await MainActor.run {
                self.isProcessing = false
            }

            self.logger.info("OCR processing completed: \(totalProcessed) items processed")
            return totalProcessed
        }

        self.processingTask = task
        return await task.value
    }

    // MARK: - Control

    /// Cancels the current processing operation
    func cancelProcessing() {
        self.processingTask?.cancel()
        self.processingTask = nil
        self.isProcessing = false
    }

    /// Clears all OCR cache and resets progress
    func clearAllOCR() async {
        self.cancelProcessing()
        let deleted = await storageManager.deleteAllOCR()
        self.logger.info("Cleared \(deleted) OCR entries")
        self.processedCount = 0
        self.totalToProcess = 0
    }

    /// Deletes outdated OCR entries (different version)
    func clearOutdatedOCR() async {
        let deleted = await storageManager.deleteOutdatedOCR()
        if deleted > 0 {
            self.logger.info("Cleared \(deleted) outdated OCR entries")
        }
    }

    // MARK: - Statistics

    /// Returns the number of processed items
    func processedItemCount() async -> Int {
        await self.storageManager.ocrCount()
    }

    // MARK: Private

    // MARK: - Configuration

    /// Number of items to process in each batch (smaller than embeddings since OCR is heavier)
    private let batchSize: Int = 20

    /// Delay between batches in milliseconds
    private let batchDelayMs: Int = 200

    /// Maximum items to process in a single session
    private let maxItemsPerSession: Int = 200

    /// Storage manager for item and OCR cache access
    private let storageManager: StorageManager

    /// OCR manager for text extraction
    private let ocrManager: OCRManager

    /// Logger for OCR operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "ocr-gen"
    )

    /// Current processing task
    private var processingTask: Task<Int, Never>?

    /// Image content types to process
    private let imageContentTypes: Set<ContentType> = [.png, .jpeg, .tiff]

    /// Processes a single item for OCR
    private func processItem(itemId: UUID) async -> Bool {
        // Fetch the item
        guard let item = await storageManager.fetchItem(byId: itemId) else {
            return false
        }

        // Get image data
        guard let imageData = item.content?.imageData else {
            return false
        }

        // Check if image is processable
        guard self.ocrManager.canProcess(imageData) else {
            return false
        }

        // Check for duplicate image (reuse existing OCR)
        if let existingText = await storageManager.findOCRByImageHash(imageData) {
            let imageHash = StorageManager.hashImageData(imageData)
            return await self.storageManager.saveOCRText(
                for: itemId,
                text: existingText,
                confidence: 1.0,
                language: nil,
                imageHash: imageHash
            )
        }

        // Perform OCR
        guard let result = await ocrManager.recognizeText(in: imageData),
              result.isSuccess
        else {
            return false
        }

        // Save OCR result
        let imageHash = StorageManager.hashImageData(imageData)
        return await self.storageManager.saveOCRText(
            for: itemId,
            text: result.text,
            confidence: result.confidence,
            language: result.language,
            imageHash: imageHash
        )
    }
}
