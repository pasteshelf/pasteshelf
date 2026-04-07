//
//  StorageManagerCollectionTests.swift
//  PasteShelfTests
//
//  Unit tests for StorageManager collection operations.
//

import CoreData
@testable import PasteShelf
import XCTest

// swiftlint:disable:next type_body_length
final class StorageManagerCollectionTests: XCTestCase {
    var storageManager: StorageManager!

    override func setUp() async throws {
        try await super.setUp()
        storageManager = await MainActor.run { StorageManager.forTesting() }
    }

    override func tearDown() async throws {
        storageManager = nil
        try await super.tearDown()
    }

    // MARK: - Collection CRUD Tests

    func testSaveCollection() async {
        let id = UUID()
        let model = CollectionDisplayModel(
            id: id,
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

        let savedCollection = await storageManager.saveCollection(from: model)
        XCTAssertNotNil(savedCollection)

        // Re-fetch from the view context to verify properties,
        // since the returned object belongs to a background context.
        let fetched = await storageManager.fetchCollection(byId: id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "Test Collection")
        XCTAssertEqual(fetched?.icon, "folder")
        XCTAssertEqual(fetched?.colorHex, "#007AFF")
        XCTAssertTrue(fetched?.isAutomatic ?? false)
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

        _ = await storageManager.saveCollection(from: model1)
        _ = await storageManager.saveCollection(from: model2)

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

        _ = await storageManager.saveCollection(from: model)

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

        _ = await storageManager.saveCollection(from: model)

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

        let success = await storageManager.updateCollection(
            updatedModel.id,
            name: updatedModel.name,
            icon: updatedModel.icon,
            colorHex: updatedModel.colorHex,
            rules: updatedModel.rules
        )
        XCTAssertTrue(success)

        // Verify update
        let fetchedCollection = await storageManager.fetchCollection(byId: id)
        XCTAssertEqual(fetchedCollection?.name, "Updated Name")
        XCTAssertEqual(fetchedCollection?.icon, "star.fill")
        XCTAssertEqual(fetchedCollection?.colorHex, "#FF9500")
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

        _ = await storageManager.saveCollection(from: model)

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
        _ = await storageManager.saveCollection(from: collectionModel)

        // Re-fetch collection from view context so property access works correctly
        guard let collection = await storageManager.fetchCollection(byId: collectionId) else {
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

        // Re-fetch collection to verify with fresh context state
        guard let refreshedCollection = await storageManager.fetchCollection(byId: collectionId) else {
            XCTFail("Failed to re-fetch collection")
            return
        }

        // Verify item is in collection
        let isInCollection = await storageManager.isItemInCollection(item, collection: refreshedCollection)
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
        _ = await storageManager.saveCollection(from: collectionModel)

        // Re-fetch from view context
        guard let collection = await storageManager.fetchCollection(byId: collectionId) else {
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

        // Re-fetch collection for fresh state
        guard let refreshedCollection = await storageManager.fetchCollection(byId: collectionId) else {
            XCTFail("Failed to re-fetch collection")
            return
        }

        // Verify item is in collection
        var isInCollection = await storageManager.isItemInCollection(item, collection: refreshedCollection)
        XCTAssertTrue(isInCollection)

        // Remove item
        let success = await storageManager.removeItemFromCollection(item, collection: refreshedCollection)
        XCTAssertTrue(success)

        // Re-fetch again after removal
        guard let finalCollection = await storageManager.fetchCollection(byId: collectionId) else {
            XCTFail("Failed to re-fetch collection after removal")
            return
        }

        // Verify removal
        isInCollection = await storageManager.isItemInCollection(item, collection: finalCollection)
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
        _ = await storageManager.saveCollection(from: collectionModel)

        // Re-fetch from view context
        guard let collection = await storageManager.fetchCollection(byId: collectionId) else {
            XCTFail("Failed to create collection")
            return
        }

        // Create multiple items and add them
        for i in 0 ..< 3 {
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

        // Re-fetch collection for fresh state
        guard let refreshedCollection = await storageManager.fetchCollection(byId: collectionId) else {
            XCTFail("Failed to re-fetch collection")
            return
        }

        // Verify count
        let count = await storageManager.itemCountForCollection(refreshedCollection)
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

        _ = await storageManager.saveCollection(from: model)

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
        _ = await storageManager.saveCollection(from: collectionModel)

        // Re-fetch from view context
        guard let collection = await storageManager.fetchCollection(byId: collectionId) else {
            XCTFail("Failed to create collection")
            return
        }

        // Create text items
        for i in 0 ..< 3 {
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
