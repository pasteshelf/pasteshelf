//
//  EmbeddingManager.swift
//  PasteShelf
//
//  Wrapper around NLEmbedding for generating sentence embeddings.
//  Provides cached embedding instances and async-safe embedding generation.
//

import Foundation
import NaturalLanguage
import os.log

/// Manages NLEmbedding instances and generates embeddings for text content
final class EmbeddingManager: @unchecked Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    private init() {
        // Pre-load embedding instance on init
        _ = self.getEmbedding()
    }

    // MARK: Internal

    // MARK: - Singleton

    static let shared = EmbeddingManager()

    /// Current embedding version (increment to invalidate cache)
    static let embeddingVersion: Int16 = 1

    /// Returns the embedding dimension (vector size)
    var embeddingDimension: Int {
        self.getEmbedding()?.dimension ?? 0
    }

    /// Checks if embeddings are available on this system
    var isAvailable: Bool {
        self.getEmbedding() != nil
    }

    // MARK: - Serialization

    /// Converts an embedding vector to binary data for storage
    /// - Parameter vector: The embedding vector
    /// - Returns: Binary data representation
    static func serializeEmbedding(_ vector: [Double]) -> Data {
        var mutableVector = vector
        return Data(bytes: &mutableVector, count: vector.count * MemoryLayout<Double>.size)
    }

    /// Converts binary data back to an embedding vector
    /// - Parameter data: The binary data
    /// - Returns: The embedding vector
    static func deserializeEmbedding(_ data: Data) -> [Double] {
        let count = data.count / MemoryLayout<Double>.size
        var vector = [Double](repeating: 0, count: count)
        _ = vector.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        return vector
    }

    // MARK: - Embedding Generation

    /// Generates a vector embedding for the given text
    /// - Parameter text: The text to embed
    /// - Returns: An array of Double values representing the embedding vector, or nil if embedding failed
    func generateEmbedding(for text: String) -> [Double]? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip text that's too short for meaningful embeddings
        guard trimmedText.count >= self.minimumTextLength else {
            self.logger.debug("Text too short for embedding: \(trimmedText.count) chars")
            return nil
        }

        guard let embedding = getEmbedding() else {
            self.logger.error("Failed to get NLEmbedding instance")
            return nil
        }

        // Get the embedding vector
        guard let vector = embedding.vector(for: trimmedText) else {
            self.logger.debug("No embedding vector for text")
            return nil
        }

        return vector
    }

    /// Generates embeddings for multiple texts in batch
    /// - Parameter texts: Array of texts to embed
    /// - Returns: Dictionary mapping text to its embedding vector (nil values omitted)
    func generateEmbeddings(for texts: [String]) -> [String: [Double]] {
        var results: [String: [Double]] = [:]

        for text in texts {
            if let embedding = generateEmbedding(for: text) {
                results[text] = embedding
            }
        }

        return results
    }

    /// Checks if text is suitable for embedding
    /// - Parameter text: The text to check
    /// - Returns: True if the text can be embedded
    func canEmbed(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.count >= self.minimumTextLength
    }

    // MARK: Private

    /// Logger for embedding operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "embedding"
    )

    /// Cached NLEmbedding instance for sentence embeddings
    private var cachedEmbedding: NLEmbedding?

    /// Lock for thread-safe embedding access
    private let lock = NSLock()

    /// Minimum text length for meaningful embeddings
    private let minimumTextLength = 3

    // MARK: - Embedding Instance Management

    /// Gets or creates the NLEmbedding instance
    private func getEmbedding() -> NLEmbedding? {
        self.lock.lock()
        defer { lock.unlock() }

        if let existing = cachedEmbedding {
            return existing
        }

        // Request sentence embedding for English
        // NLEmbedding.sentenceEmbedding supports semantic similarity
        if let embedding = NLEmbedding.sentenceEmbedding(for: .english) {
            self.cachedEmbedding = embedding
            self.logger.info("Loaded NLEmbedding for English (dimension: \(embedding.dimension))")
            return embedding
        }

        // Fallback: Try word embedding if sentence embedding unavailable
        if let wordEmbedding = NLEmbedding.wordEmbedding(for: .english) {
            self.logger.warning("Sentence embedding unavailable, falling back to word embedding")
            self.cachedEmbedding = wordEmbedding
            return wordEmbedding
        }

        self.logger.error("No NLEmbedding available for English")
        return nil
    }
}
