//
//  StorageManagerFetchTests.swift
//  PasteShelfTests
//
//  Unit tests for StorageManager fetch operations.
//

@testable import PasteShelf
import CoreData
import XCTest

final class StorageManagerFetchTests: XCTestCase {
    var storageManager: StorageManager!

    override func setUp() async throws {
        try await super.setUp()
        storageManager = await MainActor.run { StorageManager.forTesting() }
    }

    override func tearDown() async throws {
        storageManager = nil
        try await super.tearDown()
    }

    // MARK: - Setup Helpers

    private func createTestItems(count: Int) async {
        for i in 1...count {
            let content = ClipboardContent(
                primaryType: .plainText,
                availableTypes: [.plainText],
                plainText: "Item \(i)",
                contentHash: "hash_\(i)"
            )
            _ = await storageManager.save(content: content, from: nil)
        }
    }

    // MARK: - Fetch Recent Items Tests

    func testFetchRecentItemsEmpty() async {
        let items = await storageManager.fetchRecentItems()
        XCTAssertTrue(items.isEmpty)
    }

    func testFetchRecentItems() async {
        await createTestItems(count: 5)

        let items = await storageManager.fetchRecentItems()
        XCTAssertEqual(items.count, 5)
    }

    func testFetchRecentItemsWithLimit() async {
        await createTestItems(count: 10)

        let items = await storageManager.fetchRecentItems(limit: 3)
        XCTAssertEqual(items.count, 3)
    }

    func testFetchRecentItemsWithOffset() async {
        await createTestItems(count: 10)

        let items = await storageManager.fetchRecentItems(limit: 5, offset: 5)
        XCTAssertEqual(items.count, 5)
    }

    // MARK: - Fetch by Content Type Tests

    func testFetchItemsByContentType() async {
        let textContent = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "Text",
            contentHash: "text_hash"
        )
        let urlContent = ClipboardContent(
            primaryType: .url,
            availableTypes: [.url],
            url: URL(string: "https://example.com"),
            contentHash: "url_hash"
        )

        _ = await storageManager.save(content: textContent, from: nil)
        _ = await storageManager.save(content: urlContent, from: nil)

        let textItems = await storageManager.fetchItems(byContentType: .plainText)
        let urlItems = await storageManager.fetchItems(byContentType: .url)

        XCTAssertEqual(textItems.count, 1)
        XCTAssertEqual(urlItems.count, 1)
    }

    // MARK: - Fetch Favorites Tests

    func testFetchFavoritesEmpty() async {
        await createTestItems(count: 3)

        let favorites = await storageManager.fetchFavorites()
        XCTAssertTrue(favorites.isEmpty)
    }

    func testFetchFavorites() async {
        let content = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "Favorite item",
            contentHash: "fav_hash"
        )
        _ = await storageManager.save(content: content, from: nil)

        // Fetch the item and mark as favorite
        let items = await storageManager.fetchRecentItems(limit: 1)
        if let item = items.first {
            _ = await storageManager.setFavorite(item: item, isFavorite: true)
        }

        let favorites = await storageManager.fetchFavorites()
        XCTAssertEqual(favorites.count, 1)
    }

    // MARK: - Fetch by ID Tests

    func testFetchItemById() async {
        let content = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "Find me",
            contentHash: "find_hash"
        )
        _ = await storageManager.save(content: content, from: nil)

        // First fetch to get the ID
        let items = await storageManager.fetchRecentItems(limit: 1)
        guard let item = items.first, let itemId = item.id else {
            XCTFail("Failed to create test item")
            return
        }

        let foundItem = await storageManager.fetchItem(byId: itemId)
        XCTAssertNotNil(foundItem)
        XCTAssertEqual(foundItem?.id, itemId)
    }

    func testFetchItemByIdNotFound() async {
        let item = await storageManager.fetchItem(byId: UUID())
        XCTAssertNil(item)
    }

    // MARK: - Fetch by Hash Tests

    func testFetchItemByHash() async {
        let content = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "Unique content",
            contentHash: "unique_hash_123"
        )
        _ = await storageManager.save(content: content, from: nil)

        let item = await storageManager.fetchItem(byHash: "unique_hash_123")
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.contentHash, "unique_hash_123")
    }

    func testItemExistsWithHash() async {
        let content = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "Existing content",
            contentHash: "existing_hash"
        )
        _ = await storageManager.save(content: content, from: nil)

        let exists = await storageManager.itemExists(withHash: "existing_hash")
        let notExists = await storageManager.itemExists(withHash: "nonexistent_hash")

        XCTAssertTrue(exists)
        XCTAssertFalse(notExists)
    }

    // MARK: - Tag Fetch Tests

    func testFetchTags() async {
        _ = await storageManager.saveTag(name: "Tag A", color: "#FF0000")
        _ = await storageManager.saveTag(name: "Tag B", color: "#00FF00")

        let tags = await storageManager.fetchTags()
        XCTAssertEqual(tags.count, 2)
    }

    func testFetchTagByName() async {
        _ = await storageManager.saveTag(name: "Urgent", color: "#FF0000")

        let tag = await storageManager.fetchTag(byName: "Urgent")
        XCTAssertNotNil(tag)
        XCTAssertEqual(tag?.name, "Urgent")
    }

    // MARK: - Folder Fetch Tests

    func testFetchFolders() async {
        _ = await storageManager.saveFolder(name: "Folder A")
        _ = await storageManager.saveFolder(name: "Folder B")

        let folders = await storageManager.fetchFolders()
        XCTAssertEqual(folders.count, 2)
    }

    func testFetchFolderById() async {
        let folder = await storageManager.saveFolder(name: "Test Folder")
        guard let folderId = folder?.id else {
            XCTFail("Failed to create folder")
            return
        }

        let found = await storageManager.fetchFolder(byId: folderId)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Test Folder")
    }

    // MARK: - Application Fetch Tests

    func testFetchExcludedApplications() async {
        _ = await storageManager.saveApplication(bundleId: "com.app1", name: "App 1", isExcluded: true)
        _ = await storageManager.saveApplication(bundleId: "com.app2", name: "App 2", isExcluded: false)
        _ = await storageManager.saveApplication(bundleId: "com.app3", name: "App 3", isExcluded: true)

        let excluded = await storageManager.fetchExcludedApplications()
        XCTAssertEqual(excluded.count, 2)
    }

    func testIsApplicationExcluded() async {
        _ = await storageManager.saveApplication(bundleId: "com.excluded", name: "Excluded", isExcluded: true)
        _ = await storageManager.saveApplication(bundleId: "com.included", name: "Included", isExcluded: false)

        let isExcluded = await storageManager.isApplicationExcluded(bundleId: "com.excluded")
        let isIncluded = await storageManager.isApplicationExcluded(bundleId: "com.included")
        let unknown = await storageManager.isApplicationExcluded(bundleId: "com.unknown")

        XCTAssertTrue(isExcluded)
        XCTAssertFalse(isIncluded)
        XCTAssertFalse(unknown)
    }
}
