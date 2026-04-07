//
//  DeduplicatorTests.swift
//  PasteShelfTests
//
//  Tests for content deduplication functionality.
//

import Foundation
@testable import PasteShelf
import Testing

// MARK: - DeduplicatorTests

struct DeduplicatorTests {
    let deduplicator = Deduplicator()

    // MARK: - Hash Consistency Tests

    @Test("Same text produces same hash")
    func sameTextProducesSameHash() {
        let text = "Hello, World!"
        let hash1 = deduplicator.computeHash(forText: text)
        let hash2 = deduplicator.computeHash(forText: text)

        #expect(hash1 == hash2)
    }

    @Test("Different text produces different hash")
    func differentTextProducesDifferentHash() {
        let hash1 = deduplicator.computeHash(forText: "Hello")
        let hash2 = deduplicator.computeHash(forText: "World")

        #expect(hash1 != hash2)
    }

    @Test("Hash is 64 characters (SHA256 hex)")
    func hashIsCorrectLength() {
        let hash = deduplicator.computeHash(forText: "Test")

        #expect(hash.count == 64)
    }

    @Test("Hash contains only hex characters")
    func hashContainsOnlyHexCharacters() {
        let hash = deduplicator.computeHash(forText: "Test")
        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdef")

        #expect(hash.unicodeScalars.allSatisfy { hexCharacters.contains($0) })
    }

    // MARK: - Normalization Tests

    @Test("Trailing whitespace is normalized")
    func trailingWhitespaceIsNormalized() {
        let hash1 = deduplicator.computeHash(forText: "Hello")
        let hash2 = deduplicator.computeHash(forText: "Hello   ")

        #expect(hash1 == hash2)
    }

    @Test("Leading whitespace is normalized")
    func leadingWhitespaceIsNormalized() {
        let hash1 = deduplicator.computeHash(forText: "Hello")
        let hash2 = deduplicator.computeHash(forText: "   Hello")

        #expect(hash1 == hash2)
    }

    @Test("Line endings are normalized")
    func lineEndingsAreNormalized() {
        let hash1 = deduplicator.computeHash(forText: "Hello\nWorld")
        let hash2 = deduplicator.computeHash(forText: "Hello\r\nWorld")

        #expect(hash1 == hash2)
    }

    // MARK: - Content Type Hash Tests

    @Test("Plain text content hash matches text hash")
    func plainTextContentHashMatchesTextHash() {
        let text = "Hello, World!"
        var content = ClipboardContent(primaryType: .plainText)
        content.plainText = text

        let contentHash = deduplicator.computeHash(for: content)
        let textHash = deduplicator.computeHash(forText: text)

        #expect(contentHash == textHash)
    }

    @Test("URL content hashes normalized URL")
    func urlContentHashesNormalizedUrl() {
        var content1 = ClipboardContent(primaryType: .url)
        content1.url = URL(string: "https://example.com/path/")

        var content2 = ClipboardContent(primaryType: .url)
        content2.url = URL(string: "HTTPS://EXAMPLE.COM/path")

        let hash1 = deduplicator.computeHash(for: content1)
        let hash2 = deduplicator.computeHash(for: content2)

        #expect(hash1 == hash2)
    }

    // MARK: - Duplicate Detection Tests

    @Test("Detects duplicate content")
    func detectsDuplicateContent() {
        var content = ClipboardContent(primaryType: .plainText)
        content.plainText = "Test content"

        let hash = deduplicator.computeHash(for: content)
        let recentHashes = [hash, "other-hash-1", "other-hash-2"]

        #expect(deduplicator.isDuplicate(content, comparing: recentHashes))
    }

    @Test("Does not flag unique content as duplicate")
    func doesNotFlagUniqueContent() {
        var content = ClipboardContent(primaryType: .plainText)
        content.plainText = "Unique content"

        let recentHashes = ["hash-1", "hash-2", "hash-3"]

        #expect(!deduplicator.isDuplicate(content, comparing: recentHashes))
    }

    @Test("Empty recent hashes means no duplicates")
    func emptyRecentHashesMeansNoDuplicates() {
        var content = ClipboardContent(primaryType: .plainText)
        content.plainText = "Any content"

        #expect(!deduplicator.isDuplicate(content, comparing: []))
    }
}

// MARK: - DeduplicationOptions

/// Options for customizing deduplication behavior
struct DeduplicationOptions {
    /// Default options - semantic comparison only
    static let `default` = DeduplicationOptions()

    /// Strict options - all differences matter
    static let strict = DeduplicationOptions(
        whitespaceSignificant: true,
        caseSensitive: true,
        formattingSignificant: true
    )

    /// Whether to consider whitespace differences as unique content
    var whitespaceSignificant: Bool = false

    /// Whether to consider case differences as unique content
    var caseSensitive: Bool = true

    /// Whether to consider RTF formatting as part of uniqueness
    var formattingSignificant: Bool = false
}

// MARK: - ConfigurableDeduplicator

/// Deduplicator with configurable comparison options (used only in tests)
final class ConfigurableDeduplicator: Deduplicating, Sendable {
    // MARK: Lifecycle

    init(options: DeduplicationOptions = .default) {
        self.options = options
    }

    // MARK: Internal

    func computeHash(for content: ClipboardContent) -> String {
        guard content.primaryType.isTextType else {
            return baseDeduplicator.computeHash(for: content)
        }
        guard var text = content.plainText else {
            return baseDeduplicator.computeHash(for: content)
        }
        if !options.whitespaceSignificant {
            text = text.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
        if !options.caseSensitive {
            text = text.lowercased()
        }
        return computeHash(forText: text)
    }

    func computeHash(forText text: String) -> String {
        var processedText = text
        if !options.whitespaceSignificant {
            processedText = processedText.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
        if !options.caseSensitive {
            processedText = processedText.lowercased()
        }
        return baseDeduplicator.computeHash(forText: processedText)
    }

    func isDuplicate(_ content: ClipboardContent, comparing recentHashes: [String]) -> Bool {
        let hash = computeHash(for: content)
        return recentHashes.contains(hash)
    }

    // MARK: Private

    private let options: DeduplicationOptions
    private let baseDeduplicator = Deduplicator()
}

// MARK: - ConfigurableDeduplicatorTests

struct ConfigurableDeduplicatorTests {
    @Test("Case insensitive option works")
    func caseInsensitiveOptionWorks() {
        let options = DeduplicationOptions(
            whitespaceSignificant: false,
            caseSensitive: false,
            formattingSignificant: false
        )
        let deduplicator = ConfigurableDeduplicator(options: options)

        let hash1 = deduplicator.computeHash(forText: "HELLO")
        let hash2 = deduplicator.computeHash(forText: "hello")

        #expect(hash1 == hash2)
    }

    @Test("Whitespace collapse option works")
    func whitespaceCollapseOptionWorks() {
        let options = DeduplicationOptions(
            whitespaceSignificant: false,
            caseSensitive: true,
            formattingSignificant: false
        )
        let deduplicator = ConfigurableDeduplicator(options: options)

        let hash1 = deduplicator.computeHash(forText: "Hello World")
        let hash2 = deduplicator.computeHash(forText: "Hello    World")

        #expect(hash1 == hash2)
    }

    @Test("Default options use semantic comparison")
    func defaultOptionsUseSemanticComparison() {
        let deduplicator = ConfigurableDeduplicator(options: .default)

        let hash1 = deduplicator.computeHash(forText: "  Hello  World  ")
        let hash2 = deduplicator.computeHash(forText: "Hello World")

        #expect(hash1 == hash2)
    }

    @Test("Strict options preserve all differences")
    func strictOptionsPreserveAllDifferences() {
        let deduplicator = ConfigurableDeduplicator(options: .strict)

        let hash1 = deduplicator.computeHash(forText: "HELLO")
        let hash2 = deduplicator.computeHash(forText: "hello")

        #expect(hash1 != hash2)
    }
}
