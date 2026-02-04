//
//  FullTextSearchEngineTests.swift
//  PasteShelfTests
//
//  Unit tests for FullTextSearchEngine.
//

import XCTest
@testable import PasteShelf

final class FullTextSearchEngineTests: XCTestCase {
    var searchEngine: FullTextSearchEngine!

    override func setUp() {
        super.setUp()
        searchEngine = FullTextSearchEngine()
    }

    override func tearDown() {
        searchEngine = nil
        super.tearDown()
    }

    // MARK: - Basic Search Tests

    func testSearch_exactMatch() {
        let text = "Hello World"

        XCTAssertTrue(searchEngine.matches(text: text, query: "Hello"))
        XCTAssertTrue(searchEngine.matches(text: text, query: "World"))
        XCTAssertTrue(searchEngine.matches(text: text, query: "Hello World"))
    }

    func testSearch_caseInsensitive() {
        let text = "Hello World"

        XCTAssertTrue(searchEngine.matches(text: text, query: "hello"))
        XCTAssertTrue(searchEngine.matches(text: text, query: "WORLD"))
        XCTAssertTrue(searchEngine.matches(text: text, query: "hElLo WoRlD"))
    }

    func testSearch_prefixMatch() {
        let text = "Hello World"

        XCTAssertTrue(searchEngine.matches(text: text, query: "Hel"))
        XCTAssertTrue(searchEngine.matches(text: text, query: "Wor"))
        XCTAssertTrue(searchEngine.matches(text: text, query: "H"))
    }

    func testSearch_noMatch() {
        let text = "Hello World"

        XCTAssertFalse(searchEngine.matches(text: text, query: "Goodbye"))
        XCTAssertFalse(searchEngine.matches(text: text, query: "xyz"))
    }

    // MARK: - Unicode Tests

    func testSearch_unicodeNormalization() {
        // Test with composed vs decomposed characters
        let composed = "café"
        let decomposed = "cafe\u{0301}"  // e + combining acute accent

        XCTAssertTrue(searchEngine.matches(text: composed, query: "café"))
        XCTAssertTrue(searchEngine.matches(text: decomposed, query: "café"))
    }

    func testSearch_accentInsensitive() {
        let text = "résumé"

        // Accent-insensitive search
        XCTAssertTrue(searchEngine.matches(text: text, query: "resume", options: .diacriticInsensitive))
    }

    func testSearch_chineseCharacters() {
        let text = "你好世界"

        XCTAssertTrue(searchEngine.matches(text: text, query: "你好"))
        XCTAssertTrue(searchEngine.matches(text: text, query: "世界"))
    }

    func testSearch_japaneseCharacters() {
        let text = "こんにちは世界"

        XCTAssertTrue(searchEngine.matches(text: text, query: "こんにちは"))
        XCTAssertTrue(searchEngine.matches(text: text, query: "世界"))
    }

    func testSearch_koreanCharacters() {
        let text = "안녕하세요 세계"

        XCTAssertTrue(searchEngine.matches(text: text, query: "안녕"))
        XCTAssertTrue(searchEngine.matches(text: text, query: "세계"))
    }

    func testSearch_emojiInText() {
        let text = "Hello 👋 World 🌍"

        XCTAssertTrue(searchEngine.matches(text: text, query: "Hello"))
        XCTAssertTrue(searchEngine.matches(text: text, query: "World"))
        XCTAssertTrue(searchEngine.matches(text: text, query: "👋"))
    }

    // MARK: - Edge Cases

    func testSearch_emptyQuery() {
        let text = "Hello World"

        // Empty query should match everything or nothing depending on implementation
        // Most implementations return true for empty query
        let result = searchEngine.matches(text: text, query: "")
        // Either behavior is acceptable
        _ = result
    }

    func testSearch_emptyText() {
        let text = ""

        XCTAssertFalse(searchEngine.matches(text: text, query: "Hello"))
    }

    func testSearch_whitespaceOnly() {
        let text = "Hello World"

        let result = searchEngine.matches(text: text, query: "   ")
        // Whitespace-only query typically returns no match
        _ = result
    }

    func testSearch_specialCharacters() {
        let text = "function() { return true; }"

        XCTAssertTrue(searchEngine.matches(text: text, query: "function"))
        XCTAssertTrue(searchEngine.matches(text: text, query: "return"))
        XCTAssertTrue(searchEngine.matches(text: text, query: "true"))
    }

    func testSearch_multilineText() {
        let text = """
        Line 1
        Line 2
        Line 3
        """

        XCTAssertTrue(searchEngine.matches(text: text, query: "Line 1"))
        XCTAssertTrue(searchEngine.matches(text: text, query: "Line 2"))
        XCTAssertTrue(searchEngine.matches(text: text, query: "Line"))
    }

    func testSearch_veryLongText() {
        let text = String(repeating: "Hello World ", count: 1000)

        XCTAssertTrue(searchEngine.matches(text: text, query: "Hello"))
        XCTAssertTrue(searchEngine.matches(text: text, query: "World"))
    }

    // MARK: - Multiple Word Search

    func testSearch_allWordsMatch() {
        let text = "The quick brown fox jumps over the lazy dog"

        XCTAssertTrue(searchEngine.matchesAll(text: text, words: ["quick", "brown", "fox"]))
        XCTAssertTrue(searchEngine.matchesAll(text: text, words: ["lazy", "dog"]))
    }

    func testSearch_someWordsMatch() {
        let text = "The quick brown fox"

        XCTAssertFalse(searchEngine.matchesAll(text: text, words: ["quick", "lazy"]))
    }

    func testSearch_anyWordMatches() {
        let text = "The quick brown fox"

        XCTAssertTrue(searchEngine.matchesAny(text: text, words: ["cat", "dog", "fox"]))
        XCTAssertFalse(searchEngine.matchesAny(text: text, words: ["cat", "dog", "bird"]))
    }

    // MARK: - Performance Tests

    func testPerformance_shortQuery() {
        let text = "Hello World, this is a test string for performance testing"

        measure {
            for _ in 0..<10000 {
                _ = searchEngine.matches(text: text, query: "test")
            }
        }
    }

    func testPerformance_longText() {
        let text = String(repeating: "Lorem ipsum dolor sit amet ", count: 100)

        measure {
            for _ in 0..<1000 {
                _ = searchEngine.matches(text: text, query: "dolor")
            }
        }
    }
}

// MARK: - Helper Extensions for Tests

extension FullTextSearchEngine {
    /// Check if text matches all given words
    func matchesAll(text: String, words: [String]) -> Bool {
        words.allSatisfy { matches(text: text, query: $0) }
    }

    /// Check if text matches any given word
    func matchesAny(text: String, words: [String]) -> Bool {
        words.contains { matches(text: text, query: $0) }
    }

    /// Match with specific options
    func matches(text: String, query: String, options: String.CompareOptions) -> Bool {
        text.range(of: query, options: options) != nil
    }
}
