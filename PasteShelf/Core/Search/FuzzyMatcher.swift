//
//  FuzzyMatcher.swift
//  PasteShelf
//
//  Fuzzy string matching using Levenshtein distance algorithm.
//  Provides approximate matching with configurable similarity thresholds.
//

import Foundation

// MARK: - FuzzyMatcher

/// Provides fuzzy string matching capabilities using Levenshtein distance
struct FuzzyMatcher {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        threshold: Double = 0.6,
        maxQueryLength: Int = 50,
        normalizeStrings: Bool = true
    ) {
        self.threshold = max(0.0, min(1.0, threshold))
        self.maxQueryLength = maxQueryLength
        self.normalizeStrings = normalizeStrings
    }

    // MARK: Internal

    /// Default matcher with standard threshold
    static let `default` = FuzzyMatcher()

    /// Strict matcher requiring high similarity
    static let strict = FuzzyMatcher(threshold: 0.8)

    /// Lenient matcher allowing looser matches
    static let lenient = FuzzyMatcher(threshold: 0.4)

    // MARK: - Configuration

    /// Minimum similarity threshold (0.0 to 1.0)
    /// Higher values require closer matches
    let threshold: Double

    /// Maximum query length for fuzzy matching (performance optimization)
    let maxQueryLength: Int

    /// Whether to normalize strings before comparison
    let normalizeStrings: Bool

    // MARK: - Matching

    /// Checks if two strings are fuzzy matches
    /// - Parameters:
    ///   - source: The source string to check
    ///   - query: The query to match against
    /// - Returns: True if the strings are similar enough
    func matches(_ source: String, query: String) -> Bool {
        self.similarity(source, query) >= self.threshold
    }

    /// Calculates similarity between two strings
    /// - Parameters:
    ///   - source: The source string
    ///   - query: The query string
    /// - Returns: Similarity score from 0.0 (no match) to 1.0 (exact match)
    func similarity(_ source: String, _ query: String) -> Double {
        let s1 = self.normalizeStrings ? source.searchNormalized : source.lowercased()
        let s2 = self.normalizeStrings ? query.searchNormalized : query.lowercased()

        // Exact match
        if s1 == s2 {
            return 1.0
        }

        // Empty strings
        if s1.isEmpty || s2.isEmpty {
            return 0.0
        }

        // If query is too long, skip fuzzy matching
        if s2.count > self.maxQueryLength {
            return 0.0
        }

        // Calculate Levenshtein distance
        let distance = self.levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)

        // Convert distance to similarity (0.0 to 1.0)
        return 1.0 - (Double(distance) / Double(maxLength))
    }

    /// Finds the best fuzzy match for a query within a string
    /// - Parameters:
    ///   - source: The source string to search in
    ///   - query: The query to find
    /// - Returns: FuzzyMatch result if found, nil otherwise
    func findBestMatch(in source: String, for query: String) -> FuzzyMatch? {
        let s1 = self.normalizeStrings ? source.searchNormalized : source.lowercased()
        let s2 = self.normalizeStrings ? query.searchNormalized : query.lowercased()

        // Skip if query is too long
        if s2.count > self.maxQueryLength {
            return nil
        }

        // Try to find the best matching substring
        var bestMatch: FuzzyMatch?
        var bestSimilarity = 0.0

        // Extract words from source
        let words = s1.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        for (wordIndex, word) in words.enumerated() {
            let sim = self.similarity(word, s2)
            if sim >= self.threshold, sim > bestSimilarity {
                bestSimilarity = sim

                // Find the position of this word in the original string
                if let range = findWordRange(word, at: wordIndex, in: source) {
                    bestMatch = FuzzyMatch(
                        matchedText: String(source[range]),
                        range: range,
                        similarity: sim,
                        originalQuery: query
                    )
                }
            }
        }

        // Also check if query matches a substring of the whole text
        if bestMatch == nil {
            let overallSimilarity = self.similarity(source, query)
            if overallSimilarity >= self.threshold {
                let startIndex = source.startIndex
                let endIndex = source.index(startIndex, offsetBy: min(query.count, source.count))
                bestMatch = FuzzyMatch(
                    matchedText: String(source[startIndex ..< endIndex]),
                    range: startIndex ..< endIndex,
                    similarity: overallSimilarity,
                    originalQuery: query
                )
            }
        }

        return bestMatch
    }

    /// Finds all fuzzy matches for a query within a string
    /// - Parameters:
    ///   - source: The source string to search in
    ///   - query: The query to find
    ///   - maxMatches: Maximum number of matches to return
    /// - Returns: Array of FuzzyMatch results
    func findAllMatches(
        in source: String,
        for query: String,
        maxMatches: Int = 10
    ) -> [FuzzyMatch] {
        let s2 = self.normalizeStrings ? query.searchNormalized : query.lowercased()

        // Skip if query is too long
        if s2.count > self.maxQueryLength {
            return []
        }

        var matches: [FuzzyMatch] = []

        // Check each word in the source
        let words = source.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        for (wordIndex, word) in words.enumerated() {
            let wordNormalized = self.normalizeStrings ? word.searchNormalized : word.lowercased()
            let sim = self.similarity(wordNormalized, s2)

            if sim >= self.threshold {
                if let range = findWordRange(word, at: wordIndex, in: source) {
                    matches.append(FuzzyMatch(
                        matchedText: String(source[range]),
                        range: range,
                        similarity: sim,
                        originalQuery: query
                    ))

                    if matches.count >= maxMatches {
                        break
                    }
                }
            }
        }

        // Sort by similarity (highest first)
        return matches.sorted { $0.similarity > $1.similarity }
    }

    // MARK: - Levenshtein Distance

    /// Calculates the Levenshtein (edit) distance between two strings
    /// Uses dynamic programming with O(min(len1,len2)) space optimization
    func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let len1 = s1.count
        let len2 = s2.count

        // Quick returns for edge cases
        if len1 == 0 {
            return len2
        }
        if len2 == 0 {
            return len1
        }

        // Ensure s1 is the shorter string for space optimization
        if len1 > len2 {
            return self.levenshteinDistance(s2, s1)
        }

        let s1Array = Array(s1)
        let s2Array = Array(s2)

        // Use two rows instead of full matrix (space optimization)
        var previousRow = Array(0 ... len1)
        var currentRow = [Int](repeating: 0, count: len1 + 1)

        for j in 1 ... len2 {
            currentRow[0] = j

            for i in 1 ... len1 {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1

                currentRow[i] = min(
                    previousRow[i] + 1, // Deletion
                    currentRow[i - 1] + 1, // Insertion
                    previousRow[i - 1] + cost // Substitution
                )
            }

            swap(&previousRow, &currentRow)
        }

        return previousRow[len1]
    }

    /// Converts a FuzzyMatch to a MatchRange
    func toMatchRange(_ match: FuzzyMatch, in source: String) -> MatchRange {
        let start = source.distance(from: source.startIndex, to: match.range.lowerBound)
        let length = source.distance(from: match.range.lowerBound, to: match.range.upperBound)
        return MatchRange(start: start, length: length, matchedText: match.matchedText)
    }

    // MARK: Private

    // MARK: - Helper Methods

    /// Finds the range of a word at a specific position in the original string
    private func findWordRange(
        _ word: String,
        at wordIndex: Int,
        in source: String
    ) -> Range<String.Index>? {
        var currentIndex = source.startIndex
        var currentWordIndex = 0

        while currentIndex < source.endIndex {
            // Skip whitespace
            while currentIndex < source.endIndex,
                  source[currentIndex].isWhitespace
            {
                currentIndex = source.index(after: currentIndex)
            }

            if currentIndex >= source.endIndex {
                break
            }

            // Find word end
            let wordStart = currentIndex
            while currentIndex < source.endIndex,
                  !source[currentIndex].isWhitespace
            {
                currentIndex = source.index(after: currentIndex)
            }
            let wordEnd = currentIndex

            // Check if this is our target word
            if currentWordIndex == wordIndex {
                let foundWord = String(source[wordStart ..< wordEnd])
                // Verify it matches (accounting for normalization)
                let normalizedFound = self.normalizeStrings ? foundWord.searchNormalized : foundWord.lowercased()
                let normalizedTarget = self.normalizeStrings ? word.searchNormalized : word.lowercased()

                if normalizedFound == normalizedTarget || foundWord == word {
                    return wordStart ..< wordEnd
                }
            }

            currentWordIndex += 1
        }

        // Fallback: search for the word directly
        return source.range(of: word, options: [.caseInsensitive, .diacriticInsensitive])
    }
}

// MARK: - FuzzyMatch

/// Represents a fuzzy match result
struct FuzzyMatch {
    /// The text that was matched
    let matchedText: String

    /// Range of the match in the source string
    let range: Range<String.Index>

    /// Similarity score (0.0 to 1.0)
    let similarity: Double

    /// The original query that was searched for
    let originalQuery: String

    /// Whether this is a high-quality match (similarity >= 0.8)
    var isHighQuality: Bool {
        self.similarity >= 0.8
    }
}

// MARK: - Array Extension

extension [FuzzyMatch] {
    /// Converts fuzzy matches to match ranges
    func toMatchRanges(in source: String) -> [MatchRange] {
        let matcher = FuzzyMatcher.default
        return map { matcher.toMatchRange($0, in: source) }
    }
}
