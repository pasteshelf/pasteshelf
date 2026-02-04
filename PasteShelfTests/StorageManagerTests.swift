//
//  StorageManagerTests.swift
//  PasteShelfTests
//
//  Unit tests for StorageManager core functionality.
//

@testable import PasteShelf
import CoreData
import XCTest

final class StorageManagerTests: XCTestCase {
    var storageManager: StorageManager!

    override func setUp() async throws {
        try await super.setUp()
        storageManager = await MainActor.run { StorageManager.forTesting() }
    }

    override func tearDown() async throws {
        storageManager = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    @MainActor
    func testStorageManagerCreation() {
        XCTAssertNotNil(storageManager)
        XCTAssertNotNil(storageManager.viewContext)
    }

    @MainActor
    func testBackgroundContextCreation() {
        let context = storageManager.newBackgroundContext()
        XCTAssertNotNil(context)
        XCTAssertNotEqual(context, storageManager.viewContext)
    }

    // MARK: - Statistics Tests

    func testTotalItemCountEmpty() async {
        let count = await storageManager.totalItemCount()
        XCTAssertEqual(count, 0)
    }

    func testItemCountByContentType() async {
        // Create test items
        let textContent = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "Test text",
            contentHash: "hash1"
        )

        let imageContent = ClipboardContent(
            primaryType: .png,
            availableTypes: [.png],
            imageData: Data([0x89, 0x50, 0x4E, 0x47]),
            contentHash: "hash2"
        )

        _ = await storageManager.save(content: textContent, from: nil)
        _ = await storageManager.save(content: imageContent, from: nil)

        let textCount = await storageManager.itemCount(byContentType: .plainText)
        let imageCount = await storageManager.itemCount(byContentType: .png)

        XCTAssertEqual(textCount, 1)
        XCTAssertEqual(imageCount, 1)
    }
}
