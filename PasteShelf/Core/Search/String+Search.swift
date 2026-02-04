//
//  String+Search.swift
//  PasteShelf
//
//  String extensions for search functionality including Unicode normalization,
//  case-insensitive comparison, and match range finding.
//

import Foundation
import SwiftUI

extension String {
    // MARK: - Normalization

    /// Returns a normalized version of the string for search comparison.
    /// Applies Unicode NFD normalization, lowercases, and removes diacritics.
    var searchNormalized: String {
        // NFD decomposition followed by removing combining marks
        let decomposed = decomposedStringWithCanonicalMapping
        let pattern = "\\p{M}" // Unicode combining marks
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return lowercased()
        }
        let range = NSRange(decomposed.startIndex..., in: decomposed)
        let withoutDiacritics = regex.stringByReplacingMatches(
            in: decomposed,
            range: range,
            withTemplate: ""
        )
        return withoutDiacritics.lowercased()
    }

    /// Returns a version suitable for NSPredicate comparison.
    /// Escapes special characters that could interfere with predicate parsing.
    var predicateSafe: String {
        var result = self
        // Escape single quotes
        result = result.replacingOccurrences(of: "'", with: "''")
        // Escape percent signs (wildcards in LIKE)
        result = result.replacingOccurrences(of: "%", with: "\\%")
        // Escape asterisks (wildcards in LIKE)
        result = result.replacingOccurrences(of: "*", with: "\\*")
        return result
    }

    // MARK: - Case-Insensitive Search

    /// Checks if this string contains the query (case and diacritic insensitive).
    /// - Parameter query: The search query
    /// - Returns: True if the query is found
    func containsIgnoringCase(_ query: String) -> Bool {
        range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) != nil
    }

    /// Checks if this string starts with the query (case and diacritic insensitive).
    /// - Parameter query: The search query
    /// - Returns: True if the string starts with the query
    func startsWithIgnoringCase(_ query: String) -> Bool {
        range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive, .anchored]
        ) != nil
    }

    // MARK: - Match Finding

    /// Finds all ranges where the query matches in this string.
    /// - Parameters:
    ///   - query: The search query
    ///   - options: Comparison options (default: case and diacritic insensitive)
    /// - Returns: Array of MatchRange objects
    func findMatchRanges(
        for query: String,
        options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    ) -> [MatchRange] {
        var ranges: [MatchRange] = []
        var searchStartIndex = startIndex

        while searchStartIndex < endIndex {
            guard let range = range(
                of: query,
                options: options,
                range: searchStartIndex ..< endIndex
            ) else {
                break
            }

            let startOffset = distance(from: startIndex, to: range.lowerBound)
            let matchedText = String(self[range])

            ranges.append(MatchRange(
                start: startOffset,
                length: matchedText.count,
                matchedText: matchedText
            ))

            // Move past this match
            searchStartIndex = range.upperBound
        }

        return ranges
    }

    /// Finds match ranges for each word in a multi-word query.
    /// - Parameter query: The search query (may contain multiple words)
    /// - Returns: Array of MatchRange objects for all matched words
    func findWordMatchRanges(for query: String) -> [MatchRange] {
        let queryWords = query.split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }

        var allRanges: [MatchRange] = []

        for word in queryWords {
            let wordRanges = findMatchRanges(for: word)
            allRanges.append(contentsOf: wordRanges)
        }

        // Sort by position and remove overlapping ranges
        return mergeOverlappingRanges(allRanges.sorted { $0.start < $1.start })
    }

    // MARK: - Helper Methods

    /// Merges overlapping ranges into non-overlapping ranges.
    private func mergeOverlappingRanges(_ ranges: [MatchRange]) -> [MatchRange] {
        guard !ranges.isEmpty else { return [] }

        var merged: [MatchRange] = []
        var current = ranges[0]

        for i in 1 ..< ranges.count {
            let next = ranges[i]

            if next.start <= current.end {
                // Overlapping - extend current
                let newEnd = max(current.end, next.end)
                let newLength = newEnd - current.start
                let newText = String(dropFirst(current.start).prefix(newLength))
                current = MatchRange(
                    start: current.start,
                    length: newLength,
                    matchedText: newText
                )
            } else {
                // Not overlapping - add current and move to next
                merged.append(current)
                current = next
            }
        }

        merged.append(current)
        return merged
    }

    // MARK: - Word Extraction

    /// Extracts individual words from the string for tokenized search.
    var searchWords: [String] {
        components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    /// Returns the first N characters, adding ellipsis if truncated.
    func truncated(to length: Int, trailing: String = "...") -> String {
        if count <= length {
            return self
        }
        return String(prefix(length - trailing.count)) + trailing
    }
}

// MARK: - AttributedString Extension

extension AttributedString {
    /// Creates an AttributedString with highlighted match ranges.
    /// - Parameters:
    ///   - string: The original string
    ///   - ranges: The ranges to highlight
    ///   - highlightAttributes: Attributes to apply to highlighted text
    /// - Returns: An AttributedString with highlights applied
    static func highlighted(
        _ string: String,
        ranges: [MatchRange],
        highlightAttributes: AttributeContainer = .init().backgroundColor(.yellow.opacity(0.3))
    ) -> AttributedString {
        var result = AttributedString(string)

        for range in ranges.reversed() {
            guard let attrRange = range.attributedStringRange(in: result) else {
                continue
            }
            result[attrRange].mergeAttributes(highlightAttributes)
        }

        return result
    }
}

// MARK: - MatchRange Extension

extension MatchRange {
    /// Converts to an AttributedString range.
    func attributedStringRange(in attrString: AttributedString) -> Range<AttributedString.Index>? {
        let string = String(attrString.characters)
        guard let stringRange = range(in: string) else { return nil }

        let startOffset = string.distance(from: string.startIndex, to: stringRange.lowerBound)
        let endOffset = string.distance(from: string.startIndex, to: stringRange.upperBound)

        let attrStart = attrString.index(attrString.startIndex, offsetByCharacters: startOffset)
        let attrEnd = attrString.index(attrString.startIndex, offsetByCharacters: endOffset)

        return attrStart ..< attrEnd
    }
}
