//
//  OCRManager.swift
//  PasteShelf
//
//  Wrapper around Vision framework for OCR text extraction.
//  Provides async-safe text recognition from images.
//

import AppKit
import Foundation
import NaturalLanguage
import os.log
import Vision

// MARK: - OCRResult

/// Result of OCR text recognition
struct OCRResult {
    /// Extracted text from the image
    let text: String

    /// Average confidence score (0.0 to 1.0)
    let confidence: Double

    /// Detected language code (e.g., "en", "de")
    let language: String?

    /// Individual text regions with bounding boxes
    let regions: [TextRegion]

    /// Whether extraction was successful
    var isSuccess: Bool {
        !text.isEmpty && confidence > 0
    }
}

// MARK: - TextRegion

/// Represents a recognized text region in an image
struct TextRegion {
    /// The recognized text
    let text: String

    /// Confidence score for this region
    let confidence: Double

    /// Bounding box in normalized coordinates (0.0 to 1.0)
    let boundingBox: CGRect
}

// MARK: - OCRManager

/// Manages Vision framework OCR operations for text extraction from images
final class OCRManager: @unchecked Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    private init() {
        logger.info("OCRManager initialized")
    }

    // MARK: Internal

    // MARK: - Singleton

    static let shared = OCRManager()

    /// Current OCR version (increment to invalidate cache)
    static let ocrVersion: Int16 = 1

    /// Gets the current confidence threshold
    var currentConfidenceThreshold: Float {
        lock.lock()
        defer { lock.unlock() }
        return confidenceThreshold
    }

    // MARK: - Availability

    /// Checks if OCR is available on this system
    var isAvailable: Bool {
        // Vision framework is always available on macOS 10.15+
        // Check if text recognition is specifically available
        let request = VNRecognizeTextRequest()
        return (try? request.supportedRecognitionLanguages())?.isEmpty == false
    }

    /// Returns the list of supported languages for OCR
    var supportedLanguages: [String] {
        let request = VNRecognizeTextRequest()
        return (try? request.supportedRecognitionLanguages()) ?? []
    }

    // MARK: - Configuration

    /// Sets the minimum confidence threshold for text recognition
    /// - Parameter threshold: Confidence threshold (0.0 to 1.0)
    func setConfidenceThreshold(_ threshold: Float) {
        lock.lock()
        defer { lock.unlock() }
        confidenceThreshold = max(0.0, min(1.0, threshold))
        logger.debug("Confidence threshold set to \(confidenceThreshold)")
    }

    // MARK: - Text Recognition

    /// Recognizes text in an NSImage
    /// - Parameter image: The image to process
    /// - Returns: OCR result with extracted text, or nil if recognition failed
    func recognizeText(in image: NSImage) async -> OCRResult? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            logger.error("Failed to convert NSImage to CGImage")
            return nil
        }

        return await recognizeText(in: cgImage)
    }

    /// Recognizes text in image data
    /// - Parameter imageData: Raw image data (PNG, JPEG, TIFF, etc.)
    /// - Returns: OCR result with extracted text, or nil if recognition failed
    func recognizeText(in imageData: Data) async -> OCRResult? {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            logger.error("Failed to create CGImage from data")
            return nil
        }

        return await recognizeText(in: cgImage)
    }

    /// Recognizes text in a CGImage
    /// - Parameter cgImage: The CGImage to process
    /// - Returns: OCR result with extracted text, or nil if recognition failed
    func recognizeText(in cgImage: CGImage) async -> OCRResult? {
        await withCheckedContinuation { continuation in
            performOCR(on: cgImage) { result in
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Language Detection

    /// Detects the language of text
    /// - Parameter text: The text to analyze
    /// - Returns: Language code (e.g., "en", "de") or nil
    func detectLanguage(in text: String) -> String? {
        guard !text.isEmpty else {
            return nil
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let language = recognizer.dominantLanguage else {
            return nil
        }

        return language.rawValue
    }

    // MARK: - Utility

    /// Checks if an image is suitable for OCR (not too small, etc.)
    /// - Parameter image: The image to check
    /// - Returns: True if the image can be processed
    func canProcess(_ image: NSImage) -> Bool {
        guard let rep = image.representations.first else {
            return false
        }

        // Skip very small images (icons, etc.)
        let minDimension = 20
        return rep.pixelsWide >= minDimension && rep.pixelsHigh >= minDimension
    }

    /// Checks if image data is suitable for OCR
    /// - Parameter imageData: The image data to check
    /// - Returns: True if the image can be processed
    func canProcess(_ imageData: Data) -> Bool {
        guard let image = NSImage(data: imageData) else {
            return false
        }
        return canProcess(image)
    }

    // MARK: Private

    /// Logger for OCR operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "ocr"
    )

    /// Lock for thread-safe operations
    private let lock = NSLock()

    /// Minimum confidence threshold for text recognition
    private var confidenceThreshold: Float = 0.5

    /// Recognition level for VNRecognizeTextRequest
    private let recognitionLevel: VNRequestTextRecognitionLevel = .accurate

    // MARK: - Private OCR Implementation

    private func performOCR(on cgImage: CGImage, completion: @escaping (OCRResult?) -> Void) {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self else {
                completion(nil)
                return
            }

            if let error {
                logger.error("OCR request failed: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                logger.debug("No text observations found")
                completion(OCRResult(text: "", confidence: 0, language: nil, regions: []))
                return
            }

            let result = processObservations(observations)
            completion(result)
        }

        // Configure recognition request
        configureRequest(request)

        // Perform the request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            logger.error("Failed to perform OCR: \(error.localizedDescription)")
            completion(nil)
        }
    }

    private func configureRequest(_ request: VNRecognizeTextRequest) {
        // Use accurate recognition for better quality
        request.recognitionLevel = recognitionLevel

        // Enable language correction for better accuracy
        request.usesLanguageCorrection = true

        // Set supported languages (prioritize user's language)
        let preferredLanguages = Locale.preferredLanguages.compactMap { languageCode -> String? in
            // Extract just the language code (e.g., "en" from "en-US")
            languageCode.components(separatedBy: "-").first
        }

        // Get all supported languages and prioritize user's languages
        if let supportedLanguages = try? request.supportedRecognitionLanguages() {
            var orderedLanguages = preferredLanguages.filter { supportedLanguages.contains($0) }
            for lang in supportedLanguages where !orderedLanguages.contains(lang) {
                orderedLanguages.append(lang)
            }
            request.recognitionLanguages = orderedLanguages
        }

        // Use revision 3 for best results on macOS 14+
        if #available(macOS 14.0, *) {
            request.revision = VNRecognizeTextRequestRevision3
        }
    }

    private func processObservations(_ observations: [VNRecognizedTextObservation]) -> OCRResult {
        lock.lock()
        let threshold = confidenceThreshold
        lock.unlock()

        var allText: [String] = []
        var regions: [TextRegion] = []
        var totalConfidence: Double = 0
        var detectedLanguages: [String: Int] = [:]

        for observation in observations {
            // Get the top candidate
            guard let candidate = observation.topCandidates(1).first else {
                continue
            }

            // Skip low-confidence results
            guard candidate.confidence >= threshold else {
                continue
            }

            let text = candidate.string
            allText.append(text)
            totalConfidence += Double(candidate.confidence)

            // Create text region
            let region = TextRegion(
                text: text,
                confidence: Double(candidate.confidence),
                boundingBox: observation.boundingBox
            )
            regions.append(region)

            // Track detected language
            if let language = detectLanguage(in: text) {
                detectedLanguages[language, default: 0] += 1
            }
        }

        // Calculate average confidence
        let avgConfidence = allText.isEmpty ? 0 : totalConfidence / Double(allText.count)

        // Determine primary language
        let primaryLanguage = detectedLanguages.max { $0.value < $1.value }?.key

        // Combine all text with newlines
        let combinedText = allText.joined(separator: "\n")

        logger
            .info(
                "OCR extracted \(allText.count) text blocks, avg confidence: \(String(format: "%.2f", avgConfidence))"
            )

        return OCRResult(
            text: combinedText,
            confidence: avgConfidence,
            language: primaryLanguage,
            regions: regions
        )
    }
}
