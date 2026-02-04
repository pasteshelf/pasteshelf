//
//  RuleEvaluatorTests.swift
//  PasteShelfTests
//
//  Unit tests for RuleEvaluator predicate building and evaluation.
//

@testable import PasteShelf
import CoreData
import XCTest

final class RuleEvaluatorTests: XCTestCase {
    var storageManager: StorageManager!
    var evaluator: RuleEvaluator!

    override func setUp() async throws {
        try await super.setUp()
        storageManager = StorageManager.forTesting()
        evaluator = RuleEvaluator.shared
    }

    override func tearDown() async throws {
        storageManager = nil
        evaluator = nil
        try await super.tearDown()
    }

    // MARK: - Predicate Building Tests

    func testBuildPredicateFromEmptyRules() {
        let rules = CollectionRules()
        let predicate = evaluator.buildPredicate(from: rules)

        // Empty rules should return always-true predicate
        XCTAssertEqual(predicate.predicateFormat, "TRUEPREDICATE")
    }

    func testBuildPredicateForContentType() {
        let rules = CollectionRules(
            conditions: [
                RuleCondition(field: .contentType, comparisonOperator: .equals, value: "images"),
            ],
            logicalOperator: .and
        )

        let predicate = evaluator.buildPredicate(from: rules)

        // Should include the content type predicate
        let format = predicate.predicateFormat
        XCTAssertTrue(format.contains("contentType"))
    }

    func testBuildPredicateForSourceApp() {
        let rules = CollectionRules(
            conditions: [
                RuleCondition(field: .sourceApp, comparisonOperator: .contains, value: "Safari"),
            ],
            logicalOperator: .and
        )

        let predicate = evaluator.buildPredicate(from: rules)

        let format = predicate.predicateFormat
        // Should check both bundleId and appName
        XCTAssertTrue(format.contains("sourceApp"))
    }

    func testBuildPredicateForTextContent() {
        let rules = CollectionRules(
            conditions: [
                RuleCondition(field: .textContent, comparisonOperator: .contains, value: "hello"),
            ],
            logicalOperator: .and
        )

        let predicate = evaluator.buildPredicate(from: rules)

        let format = predicate.predicateFormat
        XCTAssertTrue(format.contains("plainTextPreview"))
    }

    func testBuildPredicateForBoolean() {
        let rules = CollectionRules(
            conditions: [
                RuleCondition(field: .isFavorite, comparisonOperator: .equals, value: "true"),
            ],
            logicalOperator: .and
        )

        let predicate = evaluator.buildPredicate(from: rules)

        let format = predicate.predicateFormat
        XCTAssertTrue(format.contains("isFavorite"))
    }

    func testBuildPredicateWithAndOperator() {
        let rules = CollectionRules(
            conditions: [
                RuleCondition(field: .contentType, comparisonOperator: .equals, value: "images"),
                RuleCondition(field: .isFavorite, comparisonOperator: .equals, value: "true"),
            ],
            logicalOperator: .and
        )

        let predicate = evaluator.buildPredicate(from: rules)

        let format = predicate.predicateFormat
        // AND compound predicate
        XCTAssertTrue(format.contains("contentType") && format.contains("isFavorite"))
    }

    func testBuildPredicateWithOrOperator() {
        let rules = CollectionRules(
            conditions: [
                RuleCondition(field: .contentType, comparisonOperator: .equals, value: "images"),
                RuleCondition(field: .contentType, comparisonOperator: .equals, value: "pdf"),
            ],
            logicalOperator: .or
        )

        let predicate = evaluator.buildPredicate(from: rules)

        let format = predicate.predicateFormat
        // Should contain OR logic
        XCTAssertTrue(format.contains("contentType"))
    }

    // MARK: - Date Predicate Tests

    func testBuildPredicateForDateWithinLast() {
        let rules = CollectionRules(
            conditions: [
                RuleCondition(field: .dateCreated, comparisonOperator: .withinLast, value: "7d"),
            ],
            logicalOperator: .and
        )

        let predicate = evaluator.buildPredicate(from: rules)

        let format = predicate.predicateFormat
        XCTAssertTrue(format.contains("timestamp"))
    }

    func testBuildPredicateForCustomDuration() {
        let rules = CollectionRules(
            conditions: [
                RuleCondition(field: .dateCreated, comparisonOperator: .withinLast, value: "24h"),
            ],
            logicalOperator: .and
        )

        let predicate = evaluator.buildPredicate(from: rules)

        let format = predicate.predicateFormat
        XCTAssertTrue(format.contains("timestamp"))
    }

    // MARK: - In-Memory Evaluation Tests

    func testEvaluateItemAgainstEmptyRules() async {
        // Create a test item
        let content = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "Test text",
            contentHash: "test-hash"
        )
        _ = await storageManager.save(content: content, from: nil)

        let items = await storageManager.fetchRecentItems(limit: 1)
        guard let item = items.first else {
            XCTFail("Failed to create test item")
            return
        }

        let rules = CollectionRules()
        let result = evaluator.evaluate(item: item, against: rules)

        // Empty rules should always match
        XCTAssertTrue(result)
    }

    func testEvaluateContentTypeMatch() async {
        // Create a text item
        let content = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "Test text",
            contentHash: "test-hash-1"
        )
        _ = await storageManager.save(content: content, from: nil)

        let items = await storageManager.fetchRecentItems(limit: 1)
        guard let item = items.first else {
            XCTFail("Failed to create test item")
            return
        }

        // Rule for text content
        let textRules = CollectionRules(
            conditions: [
                RuleCondition(field: .contentType, comparisonOperator: .equals, value: "text"),
            ],
            logicalOperator: .and
        )

        // Rule for images (should not match)
        let imageRules = CollectionRules(
            conditions: [
                RuleCondition(field: .contentType, comparisonOperator: .equals, value: "images"),
            ],
            logicalOperator: .and
        )

        XCTAssertTrue(evaluator.evaluate(item: item, against: textRules))
        XCTAssertFalse(evaluator.evaluate(item: item, against: imageRules))
    }

    func testEvaluateBooleanMatch() async {
        // Create a favorite item
        let content = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "Favorite text",
            contentHash: "fav-hash"
        )
        _ = await storageManager.save(content: content, from: nil)

        let items = await storageManager.fetchRecentItems(limit: 1)
        guard let item = items.first else {
            XCTFail("Failed to create test item")
            return
        }

        // Mark as favorite
        _ = await storageManager.toggleFavorite(itemId: item.id!)

        // Fetch again to get updated state
        let updatedItems = await storageManager.fetchRecentItems(limit: 1)
        guard let favoriteItem = updatedItems.first else {
            XCTFail("Failed to fetch updated item")
            return
        }

        let rules = CollectionRules(
            conditions: [
                RuleCondition(field: .isFavorite, comparisonOperator: .equals, value: "true"),
            ],
            logicalOperator: .and
        )

        XCTAssertTrue(evaluator.evaluate(item: favoriteItem, against: rules))
    }

    func testEvaluateTextContentMatch() async {
        // Create item with specific text
        let content = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "Hello World from PasteShelf",
            contentHash: "hello-hash"
        )
        _ = await storageManager.save(content: content, from: nil)

        let items = await storageManager.fetchRecentItems(limit: 1)
        guard let item = items.first else {
            XCTFail("Failed to create test item")
            return
        }

        // Rule that should match
        let matchingRules = CollectionRules(
            conditions: [
                RuleCondition(field: .textContent, comparisonOperator: .contains, value: "PasteShelf"),
            ],
            logicalOperator: .and
        )

        // Rule that should not match
        let nonMatchingRules = CollectionRules(
            conditions: [
                RuleCondition(field: .textContent, comparisonOperator: .contains, value: "Clipboard"),
            ],
            logicalOperator: .and
        )

        XCTAssertTrue(evaluator.evaluate(item: item, against: matchingRules))
        XCTAssertFalse(evaluator.evaluate(item: item, against: nonMatchingRules))
    }

    func testEvaluateWithAndOperator() async {
        // Create a text item
        let content = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "Important text",
            contentHash: "and-hash"
        )
        _ = await storageManager.save(content: content, from: nil)

        let items = await storageManager.fetchRecentItems(limit: 1)
        guard let item = items.first else {
            XCTFail("Failed to create test item")
            return
        }

        // AND rule - both conditions must match
        let andRules = CollectionRules(
            conditions: [
                RuleCondition(field: .contentType, comparisonOperator: .equals, value: "text"),
                RuleCondition(field: .textContent, comparisonOperator: .contains, value: "Important"),
            ],
            logicalOperator: .and
        )

        XCTAssertTrue(evaluator.evaluate(item: item, against: andRules))

        // AND rule - one condition fails
        let failingAndRules = CollectionRules(
            conditions: [
                RuleCondition(field: .contentType, comparisonOperator: .equals, value: "text"),
                RuleCondition(field: .textContent, comparisonOperator: .contains, value: "NotFound"),
            ],
            logicalOperator: .and
        )

        XCTAssertFalse(evaluator.evaluate(item: item, against: failingAndRules))
    }

    func testEvaluateWithOrOperator() async {
        // Create a text item
        let content = ClipboardContent(
            primaryType: .plainText,
            availableTypes: [.plainText],
            plainText: "Some text",
            contentHash: "or-hash"
        )
        _ = await storageManager.save(content: content, from: nil)

        let items = await storageManager.fetchRecentItems(limit: 1)
        guard let item = items.first else {
            XCTFail("Failed to create test item")
            return
        }

        // OR rule - at least one condition must match
        let orRules = CollectionRules(
            conditions: [
                RuleCondition(field: .contentType, comparisonOperator: .equals, value: "images"), // Won't match
                RuleCondition(field: .contentType, comparisonOperator: .equals, value: "text"), // Will match
            ],
            logicalOperator: .or
        )

        XCTAssertTrue(evaluator.evaluate(item: item, against: orRules))

        // OR rule - no conditions match
        let failingOrRules = CollectionRules(
            conditions: [
                RuleCondition(field: .contentType, comparisonOperator: .equals, value: "images"),
                RuleCondition(field: .contentType, comparisonOperator: .equals, value: "links"),
            ],
            logicalOperator: .or
        )

        XCTAssertFalse(evaluator.evaluate(item: item, against: failingOrRules))
    }
}
