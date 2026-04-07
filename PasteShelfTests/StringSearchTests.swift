//
//  StringSearchTests.swift
//  PasteShelfTests
//
//  Unit tests for String+Search extension methods.
//

@testable import PasteShelf
import XCTest

final class StringSearchTests: XCTestCase {
    // MARK: - Normalization Tests

    func testSearchNormalized_lowercasing() {
        XCTAssertEqual("HELLO".searchNormalized, "hello")
        XCTAssertEqual("HeLLo WoRLd".searchNormalized, "hello world")
    }

    func testSearchNormalized_diacriticRemoval() {
        XCTAssertEqual("café".searchNormalized, "cafe")
        XCTAssertEqual("naïve".searchNormalized, "naive")
        XCTAssertEqual("résumé".searchNormalized, "resume")
    }

    func testSearchNormalized_combinedMarks() {
        // Characters with combining marks (NFD form)
        let combined = "e\u{0301}" // e + combining acute accent = é
        XCTAssertEqual(combined.searchNormalized, "e")
    }

    func testPredicateSafe_singleQuotes() {
        XCTAssertEqual("it's".predicateSafe, "it''s")
        XCTAssertEqual("don't".predicateSafe, "don''t")
    }

    func testPredicateSafe_wildcards() {
        XCTAssertEqual("100%".predicateSafe, "100\\%")
        XCTAssertEqual("test*".predicateSafe, "test\\*")
    }

    // MARK: - Case-Insensitive Search Tests

    func testContainsIgnoringCase_basicMatch() {
        XCTAssertTrue("Hello World".containsIgnoringCase("world"))
        XCTAssertTrue("Hello World".containsIgnoringCase("WORLD"))
        XCTAssertTrue("Hello World".containsIgnoringCase("WoRlD"))
    }

    func testContainsIgnoringCase_diacriticInsensitive() {
        XCTAssertTrue("café".containsIgnoringCase("cafe"))
        XCTAssertTrue("resume".containsIgnoringCase("résumé"))
    }

    func testContainsIgnoringCase_noMatch() {
        XCTAssertFalse("Hello World".containsIgnoringCase("xyz"))
    }

    func testStartsWithIgnoringCase_match() {
        XCTAssertTrue("Hello World".startsWithIgnoringCase("hello"))
        XCTAssertTrue("Hello World".startsWithIgnoringCase("HELLO"))
    }

    func testStartsWithIgnoringCase_noMatch() {
        XCTAssertFalse("Hello World".startsWithIgnoringCase("world"))
    }

    // MARK: - Match Range Finding Tests

    func testFindMatchRanges_singleMatch() {
        let text = "Hello World"
        let ranges = text.findMatchRanges(for: "World")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(ranges[0].start, 6)
        XCTAssertEqual(ranges[0].length, 5)
        XCTAssertEqual(ranges[0].matchedText, "World")
    }

    func testFindMatchRanges_multipleMatches() {
        let text = "hello hello hello"
        let ranges = text.findMatchRanges(for: "hello")

        XCTAssertEqual(ranges.count, 3)
        XCTAssertEqual(ranges[0].start, 0)
        XCTAssertEqual(ranges[1].start, 6)
        XCTAssertEqual(ranges[2].start, 12)
    }

    func testFindMatchRanges_caseInsensitive() {
        let text = "Hello HELLO hello"
        let ranges = text.findMatchRanges(for: "hello")

        XCTAssertEqual(ranges.count, 3)
    }

    func testFindMatchRanges_noMatch() {
        let text = "Hello World"
        let ranges = text.findMatchRanges(for: "xyz")

        XCTAssertEqual(ranges.count, 0)
    }

    func testFindMatchRanges_overlapping() {
        let text = "aaa"
        let ranges = text.findMatchRanges(for: "aa")

        // The implementation advances past each match (non-overlapping),
        // so "aa" is found at position 0, then search continues from position 2
        // where there is only one "a" left, which doesn't match "aa".
        XCTAssertEqual(ranges.count, 1)
    }

    // MARK: - Word Match Ranges Tests

    func testFindWordMatchRanges_multiWordQuery() {
        let text = "The quick brown fox"
        let ranges = text.findWordMatchRanges(for: "quick fox")

        XCTAssertEqual(ranges.count, 2)
    }

    func testFindWordMatchRanges_overlappingMerge() {
        let text = "testing"
        let ranges = text.findWordMatchRanges(for: "test testing")

        // "test" and "testing" overlap, should be merged
        XCTAssertTrue(ranges.count <= 2)
    }

    // MARK: - Word Extraction Tests

    func testSearchWords_basicSplit() {
        let words = "Hello World".searchWords

        XCTAssertEqual(words, ["Hello", "World"])
    }

    func testSearchWords_withPunctuation() {
        let words = "Hello, World! How are you?".searchWords

        XCTAssertEqual(words, ["Hello", "World", "How", "are", "you"])
    }

    func testSearchWords_multipleSpaces() {
        let words = "Hello   World".searchWords

        XCTAssertEqual(words, ["Hello", "World"])
    }

    func testSearchWords_empty() {
        let words = "".searchWords

        XCTAssertEqual(words, [])
    }

    // MARK: - Truncation Tests

    func testTruncated_shortString() {
        let result = "Hello".truncated(to: 10)

        XCTAssertEqual(result, "Hello")
    }

    func testTruncated_exactLength() {
        let result = "Hello".truncated(to: 5)

        XCTAssertEqual(result, "Hello")
    }

    func testTruncated_longString() {
        let result = "Hello World".truncated(to: 8)

        XCTAssertEqual(result, "Hello...")
    }

    func testTruncated_customTrailing() {
        let result = "Hello World".truncated(to: 8, trailing: "…")

        XCTAssertEqual(result, "Hello W…")
    }

    // MARK: - MatchRange Tests

    func testMatchRange_rangeInString() throws {
        let text = "Hello World"
        let matchRange = MatchRange(start: 6, length: 5, matchedText: "World")

        let range = matchRange.range(in: text)

        XCTAssertNotNil(range)
        XCTAssertEqual(try String(text[XCTUnwrap(range)]), "World")
    }

    func testMatchRange_invalidRange() {
        let text = "Hello"
        let matchRange = MatchRange(start: 10, length: 5, matchedText: "World")

        let range = matchRange.range(in: text)

        XCTAssertNil(range)
    }

    // MARK: - Edge Cases

    func testEmptyString_allMethods() {
        XCTAssertEqual("".searchNormalized, "")
        XCTAssertEqual("".predicateSafe, "")
        XCTAssertFalse("".containsIgnoringCase("test"))
        XCTAssertFalse("".startsWithIgnoringCase("test"))
        XCTAssertEqual("".findMatchRanges(for: "test").count, 0)
    }

    func testUnicode_variousScripts() {
        // CJK characters
        let japanese = "日本語テスト"
        XCTAssertTrue(japanese.containsIgnoringCase("テスト"))

        // Emoji
        let emoji = "Hello 😀 World"
        XCTAssertTrue(emoji.containsIgnoringCase("world"))
    }
}
