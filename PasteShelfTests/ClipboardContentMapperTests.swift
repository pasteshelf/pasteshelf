//
//  ClipboardContentMapperTests.swift
//  PasteShelfTests
//
//  Unit tests for ClipboardContentMapper.
//

@testable import PasteShelf
import CoreData
import XCTest

final class ClipboardContentMapperTests: XCTestCase {
    var context: NSManagedObjectContext!

    override func setUp() async throws {
        try await super.setUp()
        let persistence = PersistenceController(inMemory: true)
        context = persistence.container.viewContext
    }

    override func tearDown() async throws {
        context = nil
        try await super.tearDown()
    }

    // MARK: - Map to Entities Tests

    func testMapTextContentToEntity() {
        let content = ClipboardContent(
            id: UUID(),
            timestamp: Date(),
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "Hello, World!",
            contentHash: "abc123"
        )

        let (item, contentData) = ClipboardContentMapper.mapToEntities(content, sourceApp: nil, context: context)

        XCTAssertEqual(item.id, content.id)
        XCTAssertEqual(item.contentType, ContentType.plainText.rawValue)
        XCTAssertEqual(item.contentHash, "abc123")
        XCTAssertEqual(item.plainTextPreview, "Hello, World!")
        XCTAssertFalse(item.isSensitive)
        XCTAssertFalse(item.isFavorite)
        XCTAssertEqual(item.accessCount, 0)

        XCTAssertNotNil(contentData.id)
        XCTAssertNil(contentData.imageData)
    }

    func testMapContentWithSourceApp() {
        let content = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "From Safari",
            contentHash: "safari123"
        )
        let sourceApp = SourceApp(bundleId: "com.apple.Safari", name: "Safari")

        let (item, _) = ClipboardContentMapper.mapToEntities(content, sourceApp: sourceApp, context: context)

        XCTAssertEqual(item.sourceAppBundleId, "com.apple.Safari")
        XCTAssertEqual(item.sourceAppName, "Safari")
    }

    func testMapImageContentToEntity() {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let thumbnailData = Data([0x00, 0x01, 0x02])

        let content = ClipboardContent(
            primaryType: .png,
            availableTypes: [.png],
            imageData: imageData,
            thumbnailData: thumbnailData,
            imageWidth: 1920,
            imageHeight: 1080,
            isImageCompressed: true,
            contentHash: "img123"
        )

        let (item, contentData) = ClipboardContentMapper.mapToEntities(content, sourceApp: nil, context: context)

        XCTAssertEqual(item.contentType, ContentType.png.rawValue)
        XCTAssertNotNil(item.preview)
        XCTAssertEqual(item.preview?.thumbnailData, thumbnailData)

        XCTAssertEqual(contentData.imageData, imageData)
        XCTAssertTrue(contentData.isImageCompressed)
        XCTAssertEqual(contentData.imageWidth, 1920)
        XCTAssertEqual(contentData.imageHeight, 1080)
    }

    func testMapURLContentToEntity() {
        let content = ClipboardContent(
            primaryType: .url,
            availableTypes: [.url],
            url: URL(string: "https://example.com"),
            contentHash: "url123"
        )

        let (_, contentData) = ClipboardContentMapper.mapToEntities(content, sourceApp: nil, context: context)

        XCTAssertEqual(contentData.urlString, "https://example.com")
        XCTAssertEqual(contentData.url?.absoluteString, "https://example.com")
    }

    func testMapFileURLsToEntity() {
        let content = ClipboardContent(
            primaryType: .fileURL,
            availableTypes: [.fileURL],
            fileURLs: [
                URL(fileURLWithPath: "/Users/test/file1.txt"),
                URL(fileURLWithPath: "/Users/test/file2.txt")
            ],
            contentHash: "files123"
        )

        let (_, contentData) = ClipboardContentMapper.mapToEntities(content, sourceApp: nil, context: context)

        XCTAssertNotNil(contentData.fileURLsJSON)
        XCTAssertEqual(contentData.fileURLs?.count, 2)
    }

    func testMapAvailableTypes() {
        let content = ClipboardContent(
            primaryType: .richText,
            availableTypes: [.richText, .plainText, .html],
            contentHash: "multi123"
        )

        let (_, contentData) = ClipboardContentMapper.mapToEntities(content, sourceApp: nil, context: context)

        let types = contentData.availableTypes
        XCTAssertEqual(types?.count, 3)
        XCTAssertTrue(types?.contains(ContentType.richText.rawValue) ?? false)
        XCTAssertTrue(types?.contains(ContentType.plainText.rawValue) ?? false)
        XCTAssertTrue(types?.contains(ContentType.html.rawValue) ?? false)
    }

    // MARK: - Map from Entities Tests

    func testMapFromEntity() {
        // Create entity
        let item = ClipboardItem(context: context)
        item.id = UUID()
        item.timestamp = Date()
        item.contentType = ContentType.plainText.rawValue
        item.contentHash = "hash123"
        item.plainTextPreview = "Test content"
        item.isSensitive = true
        item.isFavorite = false

        let contentData = ClipboardContentData(context: context)
        contentData.id = UUID()
        item.content = contentData

        let content = ClipboardContentMapper.mapFromEntity(item)

        XCTAssertNotNil(content)
        XCTAssertEqual(content?.id, item.id)
        XCTAssertEqual(content?.primaryType, .plainText)
        XCTAssertEqual(content?.contentHash, "hash123")
        XCTAssertEqual(content?.previewText, "Test content")
        XCTAssertTrue(content?.isSensitive ?? false)
    }

    func testMapFromEntityWithSourceApp() {
        let item = ClipboardItem(context: context)
        item.id = UUID()
        item.timestamp = Date()
        item.contentType = ContentType.plainText.rawValue
        item.contentHash = "hash456"
        item.sourceAppBundleId = "com.test.app"
        item.sourceAppName = "Test App"

        let contentData = ClipboardContentData(context: context)
        contentData.id = UUID()
        item.content = contentData

        let content = ClipboardContentMapper.mapFromEntity(item)

        XCTAssertNotNil(content?.sourceApp)
        XCTAssertEqual(content?.sourceApp?.bundleId, "com.test.app")
        XCTAssertEqual(content?.sourceApp?.name, "Test App")
    }

    func testMapFromEntityReturnsNilForInvalidData() {
        let item = ClipboardItem(context: context)
        // Missing required fields

        let content = ClipboardContentMapper.mapFromEntity(item)
        XCTAssertNil(content)
    }

    // MARK: - Update Entity Tests

    func testUpdateEntity() {
        // Create initial entity
        let item = ClipboardItem(context: context)
        item.id = UUID()
        item.timestamp = Date()
        item.contentType = ContentType.plainText.rawValue
        item.contentHash = "old_hash"
        item.plainTextPreview = "Old content"

        let contentData = ClipboardContentData(context: context)
        contentData.id = UUID()
        item.content = contentData

        // Create updated content
        let updatedContent = ClipboardContent(
            primaryType: .html,
            availableTypes: [.html, .plainText],
            plainText: "New content",
            html: "<p>New HTML</p>",
            contentHash: "new_hash"
        )

        ClipboardContentMapper.updateEntity(item, with: updatedContent, context: context)

        XCTAssertEqual(item.contentType, ContentType.html.rawValue)
        XCTAssertEqual(item.contentHash, "new_hash")
        XCTAssertEqual(item.content?.htmlContent, "<p>New HTML</p>")
    }
}
