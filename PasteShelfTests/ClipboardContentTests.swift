//
//  ClipboardContentTests.swift
//  PasteShelfTests
//
//  Tests for ClipboardContent model functionality.
//

import Foundation
@testable import PasteShelf
import Testing

struct ClipboardContentTests {
    // MARK: - Initialization Tests

    @Test("Default initialization sets correct values")
    func defaultInitializationSetsCorrectValues() {
        let content = ClipboardContent(primaryType: .plainText)

        #expect(content.primaryType == .plainText)
        #expect(content.availableTypes == [.plainText])
        #expect(content.id != UUID()) // ID is generated
        #expect(content.timestamp <= Date())
    }

    @Test("Full initialization sets all values")
    func fullInitializationSetsAllValues() {
        let id = UUID()
        let timestamp = Date()
        let content = ClipboardContent(
            id: id,
            timestamp: timestamp,
            primaryType: .html,
            availableTypes: [.html, .plainText],
            plainText: "Hello",
            html: "<p>Hello</p>",
            isSensitive: true
        )

        #expect(content.id == id)
        #expect(content.timestamp == timestamp)
        #expect(content.primaryType == .html)
        #expect(content.availableTypes.count == 2)
        #expect(content.plainText == "Hello")
        #expect(content.html == "<p>Hello</p>")
        #expect(content.isSensitive)
    }

    // MARK: - Preview Text Tests

    @Test("Preview text is truncated for long content")
    func previewTextIsTruncatedForLongContent() {
        var content = ClipboardContent(primaryType: .plainText)
        content.plainText = String(repeating: "a", count: 1000)

        guard let preview = content.previewText else {
            Issue.record("Preview should not be nil")
            return
        }

        #expect(preview.count == 503) // 500 chars + "..."
        #expect(preview.hasSuffix("..."))
    }

    @Test("Preview text is not truncated for short content")
    func previewTextIsNotTruncatedForShortContent() {
        var content = ClipboardContent(primaryType: .plainText)
        content.plainText = "Short text"

        #expect(content.previewText == "Short text")
    }

    @Test("Preview text is nil for nil plain text")
    func previewTextIsNilForNilPlainText() {
        let content = ClipboardContent(primaryType: .png)

        #expect(content.previewText == nil)
    }

    // MARK: - Character/Word Count Tests

    @Test("Character count is correct")
    func characterCountIsCorrect() {
        var content = ClipboardContent(primaryType: .plainText)
        content.plainText = "Hello, World!"

        #expect(content.characterCount == 13)
    }

    @Test("Word count is correct")
    func wordCountIsCorrect() {
        var content = ClipboardContent(primaryType: .plainText)
        content.plainText = "Hello World"

        #expect(content.wordCount == 2)
    }

    @Test("Word count handles multiple spaces")
    func wordCountHandlesMultipleSpaces() {
        var content = ClipboardContent(primaryType: .plainText)
        content.plainText = "Hello   World"

        #expect(content.wordCount == 2)
    }

    @Test("Word count is nil for nil plain text")
    func wordCountIsNilForNilPlainText() {
        let content = ClipboardContent(primaryType: .png)

        #expect(content.wordCount == nil)
    }

    // MARK: - Size Calculation Tests

    @Test("Total size includes all data")
    func totalSizeIncludesAllData() {
        var content = ClipboardContent(primaryType: .plainText)
        content.plainText = "Hello" // 5 bytes
        content.html = "<p>Hi</p>" // 9 bytes

        #expect(content.totalSizeBytes == 14)
    }

    @Test("Total size is zero for empty content")
    func totalSizeIsZeroForEmptyContent() {
        let content = ClipboardContent(primaryType: .plainText)

        #expect(content.totalSizeBytes == 0)
    }

    // MARK: - Image Dimension Tests

    @Test("Image dimensions string is formatted correctly")
    func imageDimensionsStringIsFormattedCorrectly() {
        var content = ClipboardContent(primaryType: .png)
        content.imageWidth = 800
        content.imageHeight = 600

        #expect(content.imageDimensionsString == "800 × 600")
    }

    @Test("Image dimensions string is nil without dimensions")
    func imageDimensionsStringIsNilWithoutDimensions() {
        let content = ClipboardContent(primaryType: .png)

        #expect(content.imageDimensionsString == nil)
    }

    // MARK: - Type Check Tests

    @Test("Has text is true for text content")
    func hasTextIsTrueForTextContent() {
        var content = ClipboardContent(primaryType: .plainText)
        content.plainText = "Hello"

        #expect(content.hasText)
    }

    @Test("Has image is true for image content")
    func hasImageIsTrueForImageContent() {
        var content = ClipboardContent(primaryType: .png)
        content.imageData = Data([0x00])

        #expect(content.hasImage)
    }

    @Test("Has files is true for file URLs")
    func hasFilesIsTrueForFileUrls() {
        var content = ClipboardContent(primaryType: .fileURL)
        content.fileURLs = [URL(fileURLWithPath: "/tmp/test.txt")]

        #expect(content.hasFiles)
    }

    @Test("Has URL is true for URL content")
    func hasUrlIsTrueForUrlContent() {
        var content = ClipboardContent(primaryType: .url)
        content.url = URL(string: "https://example.com")

        #expect(content.hasURL)
    }

    @Test("Is empty for empty content")
    func isEmptyForEmptyContent() {
        let content = ClipboardContent(primaryType: .plainText)

        #expect(content.isEmpty)
    }

    @Test("Is not empty for content with data")
    func isNotEmptyForContentWithData() {
        var content = ClipboardContent(primaryType: .plainText)
        content.plainText = "Hello"

        #expect(!content.isEmpty)
    }

    // MARK: - File Count Tests

    @Test("File count is correct")
    func fileCountIsCorrect() {
        var content = ClipboardContent(primaryType: .fileURL)
        content.fileURLs = [
            URL(fileURLWithPath: "/tmp/file1.txt"),
            URL(fileURLWithPath: "/tmp/file2.txt"),
            URL(fileURLWithPath: "/tmp/file3.txt"),
        ]

        #expect(content.fileCount == 3)
    }

    @Test("Primary file name is first file")
    func primaryFileNameIsFirstFile() {
        var content = ClipboardContent(primaryType: .fileURL)
        content.fileURLs = [
            URL(fileURLWithPath: "/tmp/first.txt"),
            URL(fileURLWithPath: "/tmp/second.txt"),
        ]

        #expect(content.primaryFileName == "first.txt")
    }

    // MARK: - Equatable Tests

    @Test("Same ID means equal")
    func sameIdMeansEqual() {
        let id = UUID()
        let content1 = ClipboardContent(
            id: id,
            timestamp: Date(),
            primaryType: .plainText,
            availableTypes: [.plainText]
        )
        let content2 = ClipboardContent(
            id: id,
            timestamp: Date(),
            primaryType: .html,
            availableTypes: [.html]
        )

        #expect(content1 == content2)
    }

    @Test("Different ID means not equal")
    func differentIdMeansNotEqual() {
        let content1 = ClipboardContent(primaryType: .plainText)
        let content2 = ClipboardContent(primaryType: .plainText)

        #expect(content1 != content2)
    }
}
