//
//  SearchSettings.swift
//  PasteShelf
//
//  Search-related settings including semantic search and OCR.
//

import Foundation

/// Search-related settings
struct SearchSettings: Codable, Equatable {
    // MARK: - General Search

    /// Whether fuzzy matching is enabled
    var fuzzyMatchEnabled: Bool

    // MARK: - Semantic Search

    /// Whether semantic search is enabled
    var semanticSearchEnabled: Bool

    /// Similarity threshold for semantic search (0.3...0.8)
    var semanticThreshold: Double

    // MARK: - OCR Search

    /// Whether OCR search is enabled
    var ocrSearchEnabled: Bool

    /// Confidence threshold for OCR (0.3...0.9)
    var ocrConfidenceThreshold: Double

    // MARK: - Initialization

    init(
        fuzzyMatchEnabled: Bool = true,
        semanticSearchEnabled: Bool = false,
        semanticThreshold: Double = 0.5,
        ocrSearchEnabled: Bool = false,
        ocrConfidenceThreshold: Double = 0.5
    ) {
        self.fuzzyMatchEnabled = fuzzyMatchEnabled
        self.semanticSearchEnabled = semanticSearchEnabled
        self.semanticThreshold = semanticThreshold
        self.ocrSearchEnabled = ocrSearchEnabled
        self.ocrConfidenceThreshold = ocrConfidenceThreshold
    }

    // MARK: - Default Configuration

    /// Default search settings
    static let `default` = SearchSettings()
}
