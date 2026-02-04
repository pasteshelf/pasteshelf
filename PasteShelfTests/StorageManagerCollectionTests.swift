//
//  StorageManagerCollectionTests.swift
//  PasteShelfTests
//
//  Unit tests for StorageManager collection operations.
//

@testable import PasteShelf
import CoreData
import XCTest

final class StorageManagerCollectionTests: XCTestCase {
    var storageManager: StorageManager!

    override func setUp() async throws {
        try await super.setUp()
        storageManager = StorageManager.forTesting()
    }

    override func tearDown() async throws {
        storageManager = nil
        try await super.tearDown()
    }

    // MARK: - Collection CRUD Tests

    func testSaveCollection() async {
        let model = CollectionDisplayModel(
            id: UUID(),
            name: "Test Collection",
            icon: "folder",
            colorHex: "#007AFF",
            isAutomatic: true,
            itemCount: 0,
            sortOrder: 0,
            rules: CollectionRules(
                conditions: [
                    RuleCondition(field: .contentType, comparisonOperator: .equals, value: "text"),
                ],
                logicalOperator: .and
            )
        )

        let savedCollection = await storageManager.saveCollection(model)

        XCTAssertNotNil(savedCollection)
        XCTAssertEqual(savedCollection?.name, "Test Collection")
        XCTAssertEqual(savedCollection?.icon, "folder")
        XCTAssertEqual(savedCollection?.colorHex, "#007AFF")
        XCTAssertTrue(savedCollection?.isAutomatic ?? false)
    }

    func testFetchCollections() async {
        // Create multiple collections
        let model1 = CollectionDisplayModel(
            id: UUID(),
            name: "Collection A",
            icon: "folder",
            colorHex: "#FF3B30",
            isAutomatic: true,
            itemCount: 0,
            sortOrder: 0,
            rules: nil
        )
        let model2 = CollectionDisplayModel(
            id: UUID(),
            name: "Collection B",
            icon: "star",
            colorHex: "#34C759",
            isAutomatic: false,
            itemCount: 0,
            sortOrder: 1,
            rules: nil
        )

        _ = await storageManager.saveCollection(model1)
        _ = await storageManager.saveCollection(model2)

        let collections = await storageManager.fetchCollections()

        XCTAssertEqual(collections.count, 2)
        // Should be sorted by sortOrder
        XCTAssertEqual(collections.first?.name, "Collection A")
        XCTAssertEqual(collections.last?.name, "Collection B")
    }

    func testFetchCollectionById() async {
        let id = UUID()
        let model = CollectionDisplayModel(
            id: id,
            name: "Specific Collection",
            icon: "bookmark",
            colorHex: "#5856D6",
            isAutomatic: true,
            itemCount: 0,
            sortOrder: 0,
            rules: nil
        )

        _ = await storageManager.saveCollection(model)

        let fetchedCollection = await storageManager.fetchCollection(byId: id)

        XCTAssertNotNil(fetchedCollection)
        XCTAssertEqual(fetchedCollection?.name, "Specific Collection")
    }

    func testFetchCollectionByIdNotFound() async {
        let randomId = UUID()
        let fetchedCollection = await storageManager.fetchCollection(byId: randomId)

        XCTAssertNil(fetchedCollection)
    }

    func testUpdateCollection() async {
        let id = UUID()
        let model = CollectionDisplayModel(
            id: id,
            name: "Original Name",
            icon: "folder",
            colorHex: "#007AFF",
            isAutomatic: true,
            itemCount: 0,
            sortOrder: 0,
            rules: nil
        )

        _ = await storageManager.saveCollection(model)

        // Update the collection
        let updatedModel = CollectionDisplayModel(
            id: id,
            name: "Updated Name",
            icon: "star.fill",
            colorHex: "#FF9500",
            isAutomatic: false,
            itemCount: 0,
            sortOrder: 1,
            rules: nil
        )

        let success = await storageManager.updateCollection(updatedModel)
        XCTAssertTrue(success)

        // Verify update
        let fetchedCollection = await storageManager.fetchCollection(byId: id)
        XCTAssertEqual(fetchedCollection?.name, "Updated Name")
        XCTAssertEqual(fetchedCollection?.icon, "star.fill")
        XCTAssertEqual(fetchedCollection?.colorHex, "#FF9500")
        XCTAssertFalse(fetchedCollection?.isAutomatic ?? true)
    }

    func testDeleteCollection() async {
        let id = UUID()
        let model = CollectionDisplayModel(
            id: id,
            name: "To Delete",
            icon: "trash",
            colorHex: "#FF3B30",
            isAutomatic: true,
            itemCount: 0,
            sortOrder: 0,
            rules: nil
        )

        _ = await storageManager.saveCollection(model)

        // Verify it exists
        let beforeDelete = await storageManager.fetchCollection(byId: id)
        XCTAssertNotNil(beforeDelete)

        // Delete
        let success = await storageManager.deleteCollection(id)
        XCTAssertTrue(success)

        // Verify deletion
        let afterDelete = await storageManager.fetchCollection(byId: id)
        XCTAssertNil(afterDelete)
    }

    // MARK: - Manual Collection Item Management Tests

    func testAddItemToManualCollection() async {
        // Create a manual collection
        let collectionId = UUID()
        let collectionModel = CollectionDisplayModel(
            id: collectionId,
            name: "Manual Collection",
            icon: "folder",
            colorHex: "#007AFF",
            isAutomatic: false,
            itemCount: 0,
            sortOrder: 0,
            rules: nil
        )
        guard let collection = await storageManager.saveCollection(collectionModel) else {
            XCTFail("Failed to create collection")
            return
        }

        // Create a clipboard item
        let content = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "Test item",
            contentHash: "manual-test-hash"
        )
        _ = await storageManager.save(content: content, from: nil)

        let items = await storageManager.fetchRecentItems(limit: 1)
        guard let item = items.first else {
            XCTFail("Failed to create clipboard item")
            return
        }

        // Add item to collection
        let success = await storageManager.addItemToCollection(item, collection: collection)
        XCTAssertTrue(success)

        // Verify item is in collection
        let isInCollection = await storageManager.isItemInCollection(item, collection: collection)
        XCTAssertTrue(isInCollection)
    }

    func testRemoveItemFromManualCollection() async {
        // Create a manual collection
        let collectionId = UUID()
        let collectionModel = CollectionDisplayModel(
            id: collectionId,
            name: "Manual Collection 2",
            icon: "folder",
            colorHex: "#007AFF",
            isAutomatic: false,
            itemCount: 0,
            sortOrder: 0,
            rules: nil
        )
        guard let collection = await storageManager.saveCollection(collectionModel) else {
            XCTFail("Failed to create collection")
            return
        }

        // Create and add a clipboard item
        let content = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "Item to remove",
            contentHash: "remove-test-hash"
        )
        _ = await storageManager.save(content: content, from: nil)

        let items = await storageManager.fetchRecentItems(limit: 1)
        guard let item = items.first else {
            XCTFail("Failed to create clipboard item")
            return
        }

        _ = await storageManager.addItemToCollection(item, collection: collection)

        // Verify item is in collection
        var isInCollection = await storageManager.isItemInCollection(item, collection: collection)
        XCTAssertTrue(isInCollection)

        // Remove item
        let success = await storageManager.removeItemFromCollection(item, collection: collection)
        XCTAssertTrue(success)

        // Verify removal
        isInCollection = await storageManager.isItemInCollection(item, collection: collection)
        XCTAssertFalse(isInCollection)
    }

    func testItemCountForCollection() async {
        // Create a manual collection
        let collectionId = UUID()
        let collectionModel = CollectionDisplayModel(
            id: collectionId,
            name: "Count Test Collection",
            icon: "folder",
            colorHex: "#007AFF",
            isAutomatic: false,
            itemCount: 0,
            sortOrder: 0,
            rules: nil
        )
        guard let collection = await storageManager.saveCollection(collectionModel) else {
            XCTFail("Failed to create collection")
            return
        }

        // Create multiple items and add them
        for i in 0..<3 {
            let content = ClipboardContent(
                primaryType: .plainText,
                availableTypes: [.plainText],
                plainText: "Item \(i)",
                contentHash: "count-hash-\(i)"
            )
            _ = await storageManager.save(content: content, from: nil)
        }

        let items = await storageManager.fetchRecentItems(limit: 3)
        for item in items {
            _ = await storageManager.addItemToCollection(item, collection: collection)
        }

        // Verify count
        let count = await storageManager.itemCountForCollection(collection)
        XCTAssertEqual(count, 3)
    }

    // MARK: - Rules JSON Serialization Tests

    func testCollectionRulesSerializationRoundTrip() async {
        let rules = CollectionRules(
            conditions: [
                RuleCondition(field: .contentType, comparisonOperator: .equals, value: "images"),
                RuleCondition(field: .dateCreated, comparisonOperator: .withinLast, value: "7d"),
            ],
            logicalOperator: .and
        )

        let id = UUID()
        let model = CollectionDisplayModel(
            id: id,
            name: "Rules Test",
            icon: "sparkles",
            colorHex: "#AF52DE",
            isAutomatic: true,
            itemCount: 0,
            sortOrder: 0,
            rules: rules
        )

        _ = await storageManager.saveCollection(model)

        let fetchedCollection = await storageManager.fetchCollection(byId: id)
        XCTAssertNotNil(fetchedCollection)

        // Parse rules from fetched collection
        if let rulesJSON = fetchedCollection?.rulesJSON,
           let parsedRules = CollectionRules.fromJSON(rulesJSON)
        {
            XCTAssertEqual(parsedRules.conditions.count, 2)
            XCTAssertEqual(parsedRules.logicalOperator, .and)
            XCTAssertEqual(parsedRules.conditions[0].field, .contentType)
            XCTAssertEqual(parsedRules.conditions[1].field, .dateCreated)
        } else {
            XCTFail("Failed to parse rules JSON")
        }
    }

    // MARK: - Automatic Collection Fetch Tests

    func testFetchItemsForAutomaticCollection() async {
        // Create an automatic collection for text items
        let rules = CollectionRules(
            conditions: [
                RuleCondition(field: .contentType, comparisonOperator: .equals, value: "text"),
            ],
            logicalOperator: .and
        )

        let collectionId = UUID()
        let collectionModel = CollectionDisplayModel(
            id: collectionId,
            name: "Text Items",
            icon: "doc.text",
            colorHex: "#007AFF",
            isAutomatic: true,
            itemCount: 0,
            sortOrder: 0,
            rules: rules
        )
        guard let collection = await storageManager.saveCollection(collectionModel) else {
            XCTFail("Failed to create collection")
            return
        }

        // Create text items
        for i in 0..<3 {
            let content = ClipboardContent(
                primaryType: .plainText,
                availableTypes: [.plainText],
                plainText: "Text item \(i)",
                contentHash: "auto-text-hash-\(i)"
            )
            _ = await storageManager.save(content: content, from: nil)
        }

        // Fetch items for automatic collection
        let items = await storageManager.fetchItemsForCollection(collection, limit: 10)

        // Should find the text items
        XCTAssertGreaterThanOrEqual(items.count, 3)
    }
}
