//
//  FuzzyMatcherTests.swift
//  PasteShelfTests
//
//  Unit tests for FuzzyMatcher Levenshtein distance and fuzzy matching.
//

import XCTest
@testable import PasteShelf

final class FuzzyMatcherTests: XCTestCase {
    // MARK: - Levenshtein Distance Tests

    func testLevenshteinDistance_identicalStrings() {
        let matcher = FuzzyMatcher()

        XCTAssertEqual(matcher.levenshteinDistance("hello", "hello"), 0)
        XCTAssertEqual(matcher.levenshteinDistance("", ""), 0)
        XCTAssertEqual(matcher.levenshteinDistance("test", "test"), 0)
    }

    func testLevenshteinDistance_emptyStrings() {
        let matcher = FuzzyMatcher()

        XCTAssertEqual(matcher.levenshteinDistance("", "hello"), 5)
        XCTAssertEqual(matcher.levenshteinDistance("hello", ""), 5)
    }

    func testLevenshteinDistance_singleCharacterDifference() {
        let matcher = FuzzyMatcher()

        // Substitution
        XCTAssertEqual(matcher.levenshteinDistance("cat", "bat"), 1)

        // Insertion
        XCTAssertEqual(matcher.levenshteinDistance("cat", "cats"), 1)

        // Deletion
        XCTAssertEqual(matcher.levenshteinDistance("cats", "cat"), 1)
    }

    func testLevenshteinDistance_multipleEdits() {
        let matcher = FuzzyMatcher()

        XCTAssertEqual(matcher.levenshteinDistance("kitten", "sitting"), 3)
        XCTAssertEqual(matcher.levenshteinDistance("saturday", "sunday"), 3)
    }

    func testLevenshteinDistance_completelyDifferent() {
        let matcher = FuzzyMatcher()

        XCTAssertEqual(matcher.levenshteinDistance("abc", "xyz"), 3)
    }

    // MARK: - Similarity Tests

    func testSimilarity_exactMatch() {
        let matcher = FuzzyMatcher()

        XCTAssertEqual(matcher.similarity("hello", "hello"), 1.0)
        XCTAssertEqual(matcher.similarity("TEST", "TEST"), 1.0)
    }

    func testSimilarity_caseInsensitive() {
        let matcher = FuzzyMatcher(normalizeStrings: true)

        XCTAssertEqual(matcher.similarity("Hello", "hello"), 1.0)
        XCTAssertEqual(matcher.similarity("TEST", "test"), 1.0)
    }

    func testSimilarity_partialMatch() {
        let matcher = FuzzyMatcher()

        let similarity = matcher.similarity("hello", "hallo")
        // 1 edit out of 5 characters = 0.8 similarity
        XCTAssertEqual(similarity, 0.8, accuracy: 0.01)
    }

    func testSimilarity_emptyStrings() {
        let matcher = FuzzyMatcher()

        XCTAssertEqual(matcher.similarity("", "hello"), 0.0)
        XCTAssertEqual(matcher.similarity("hello", ""), 0.0)
        XCTAssertEqual(matcher.similarity("", ""), 1.0)
    }

    // MARK: - Matching Tests

    func testMatches_aboveThreshold() {
        let matcher = FuzzyMatcher(threshold: 0.6)

        // "hallo" vs "hello" = 0.8 similarity
        XCTAssertTrue(matcher.matches("hello", query: "hallo"))
    }

    func testMatches_belowThreshold() {
        let matcher = FuzzyMatcher(threshold: 0.6)

        // "xyz" vs "hello" = very low similarity
        XCTAssertFalse(matcher.matches("hello", query: "xyz"))
    }

    func testMatches_strictThreshold() {
        let matcher = FuzzyMatcher.strict // threshold 0.8

        // Exactly 0.8 should pass
        XCTAssertTrue(matcher.matches("hello", query: "hallo"))

        // 0.6 should fail strict threshold
        XCTAssertFalse(matcher.matches("hello", query: "hxllo"))
    }

    func testMatches_lenientThreshold() {
        let matcher = FuzzyMatcher.lenient // threshold 0.4

        // More permissive matches
        XCTAssertTrue(matcher.matches("hello", query: "hxllo"))
    }

    // MARK: - FindBestMatch Tests

    func testFindBestMatch_exactWord() {
        let matcher = FuzzyMatcher()
        let source = "Hello world this is a test"

        let match = matcher.findBestMatch(in: source, for: "world")

        XCTAssertNotNil(match)
        XCTAssertEqual(match?.matchedText, "world")
        XCTAssertEqual(match?.similarity, 1.0)
    }

    func testFindBestMatch_fuzzyWord() {
        let matcher = FuzzyMatcher(threshold: 0.6)
        let source = "Hello world this is a test"

        let match = matcher.findBestMatch(in: source, for: "wrold")

        XCTAssertNotNil(match)
        XCTAssertEqual(match?.matchedText.lowercased(), "world")
    }

    func testFindBestMatch_noMatch() {
        let matcher = FuzzyMatcher(threshold: 0.8)
        let source = "Hello world"

        let match = matcher.findBestMatch(in: source, for: "xyz123")

        XCTAssertNil(match)
    }

    // MARK: - FindAllMatches Tests

    func testFindAllMatches_multipleWords() {
        let matcher = FuzzyMatcher(threshold: 0.6)
        let source = "test testing tested"

        let matches = matcher.findAllMatches(in: source, for: "test")

        // Should find "test" and potentially "testing" and "tested" depending on threshold
        XCTAssertTrue(matches.count >= 1)
        XCTAssertTrue(matches.contains(where: { $0.matchedText == "test" }))
    }

    func testFindAllMatches_maxLimit() {
        let matcher = FuzzyMatcher(threshold: 0.5)
        let source = "a a a a a a a a a a a a"

        let matches = matcher.findAllMatches(in: source, for: "a", maxMatches: 3)

        XCTAssertEqual(matches.count, 3)
    }

    // MARK: - Unicode and Diacritics Tests

    func testSimilarity_withDiacritics() {
        let matcher = FuzzyMatcher(normalizeStrings: true)

        // "café" normalized should be similar to "cafe"
        let similarity = matcher.similarity("cafe", "café")
        XCTAssertGreaterThan(similarity, 0.8)
    }

    func testMatches_unicodeCharacters() {
        let matcher = FuzzyMatcher(threshold: 0.6)

        // Test with emoji
        XCTAssertTrue(matcher.matches("hello", query: "hello"))

        // Test with CJK characters
        let similarity = matcher.similarity("日本語", "日本語")
        XCTAssertEqual(similarity, 1.0)
    }

    // MARK: - Edge Cases

    func testMatches_queryTooLong() {
        let matcher = FuzzyMatcher(maxQueryLength: 5)

        // Query longer than maxQueryLength should return 0 similarity
        let similarity = matcher.similarity("hello", "verylongquery")
        XCTAssertEqual(similarity, 0.0)
    }

    func testMatches_singleCharacter() {
        let matcher = FuzzyMatcher(threshold: 0.5)

        XCTAssertTrue(matcher.matches("a", query: "a"))
        XCTAssertFalse(matcher.matches("a", query: "b"))
    }

    // MARK: - Performance Tests

    func testPerformance_levenshteinDistance() {
        let matcher = FuzzyMatcher()
        let longString1 = String(repeating: "a", count: 100)
        let longString2 = String(repeating: "b", count: 100)

        measure {
            _ = matcher.levenshteinDistance(longString1, longString2)
        }
    }

    func testPerformance_findAllMatches() {
        let matcher = FuzzyMatcher()
        let source = String(repeating: "hello world ", count: 100)

        measure {
            _ = matcher.findAllMatches(in: source, for: "world", maxMatches: 10)
        }
    }
}
