//
//  CollectionRuleTests.swift
//  PasteShelfTests
//
//  Unit tests for CollectionRule data structures and JSON serialization.
//

@testable import PasteShelf
import XCTest

final class CollectionRuleTests: XCTestCase {
    // MARK: - RuleCondition Tests

    func testRuleConditionCreation() {
        let condition = RuleCondition(
            field: .contentType,
            comparisonOperator: .equals,
            value: "text"
        )

        XCTAssertEqual(condition.field, .contentType)
        XCTAssertEqual(condition.comparisonOperator, .equals)
        XCTAssertEqual(condition.value, "text")
        XCTAssertNotNil(condition.id)
    }

    func testRuleConditionEquality() {
        let id = UUID()
        let condition1 = RuleCondition(
            id: id,
            field: .contentType,
            comparisonOperator: .equals,
            value: "text"
        )
        let condition2 = RuleCondition(
            id: id,
            field: .contentType,
            comparisonOperator: .equals,
            value: "text"
        )

        XCTAssertEqual(condition1, condition2)
    }

    // MARK: - CollectionRules Tests

    func testCollectionRulesCreation() {
        let rules = CollectionRules(
            conditions: [
                RuleCondition(field: .contentType, comparisonOperator: .equals, value: "images"),
            ],
            logicalOperator: .and
        )

        XCTAssertEqual(rules.conditions.count, 1)
        XCTAssertEqual(rules.logicalOperator, .and)
        XCTAssertFalse(rules.isEmpty)
    }

    func testCollectionRulesEmpty() {
        let rules = CollectionRules()

        XCTAssertTrue(rules.isEmpty)
        XCTAssertEqual(rules.conditions.count, 0)
        XCTAssertEqual(rules.logicalOperator, .and) // Default
    }

    // MARK: - JSON Serialization Tests

    func testCollectionRulesJSONSerialization() {
        let rules = CollectionRules(
            conditions: [
                RuleCondition(field: .contentType, comparisonOperator: .equals, value: "images"),
                RuleCondition(field: .dateCreated, comparisonOperator: .withinLast, value: "7d"),
            ],
            logicalOperator: .and
        )

        // Serialize to JSON
        let json = rules.toJSON()
        XCTAssertNotNil(json)

        // Deserialize from JSON
        let deserializedRules = CollectionRules.fromJSON(json)
        XCTAssertNotNil(deserializedRules)
        XCTAssertEqual(deserializedRules?.conditions.count, 2)
        XCTAssertEqual(deserializedRules?.logicalOperator, .and)
    }

    func testCollectionRulesJSONWithOrOperator() {
        let rules = CollectionRules(
            conditions: [
                RuleCondition(field: .sourceApp, comparisonOperator: .contains, value: "Safari"),
                RuleCondition(field: .sourceApp, comparisonOperator: .contains, value: "Chrome"),
            ],
            logicalOperator: .or
        )

        let json = rules.toJSON()
        XCTAssertNotNil(json)

        let deserializedRules = CollectionRules.fromJSON(json)
        XCTAssertEqual(deserializedRules?.logicalOperator, .or)
    }

    func testCollectionRulesFromInvalidJSON() {
        let result = CollectionRules.fromJSON("invalid json")
        XCTAssertNil(result)

        let nilResult = CollectionRules.fromJSON(nil)
        XCTAssertNil(nilResult)
    }

    // MARK: - RuleField Tests

    func testRuleFieldAvailableOperators() {
        // Content type should only support equals/notEquals
        XCTAssertTrue(RuleField.contentType.availableOperators.contains(.equals))
        XCTAssertTrue(RuleField.contentType.availableOperators.contains(.notEquals))
        XCTAssertFalse(RuleField.contentType.availableOperators.contains(.contains))

        // Text content should support contains/matches
        XCTAssertTrue(RuleField.textContent.availableOperators.contains(.contains))
        XCTAssertTrue(RuleField.textContent.availableOperators.contains(.matches))

        // Date should support before/after/withinLast
        XCTAssertTrue(RuleField.dateCreated.availableOperators.contains(.before))
        XCTAssertTrue(RuleField.dateCreated.availableOperators.contains(.after))
        XCTAssertTrue(RuleField.dateCreated.availableOperators.contains(.withinLast))
    }

    func testRuleFieldDefaultOperators() {
        XCTAssertEqual(RuleField.contentType.defaultOperator, .equals)
        XCTAssertEqual(RuleField.textContent.defaultOperator, .contains)
        XCTAssertEqual(RuleField.dateCreated.defaultOperator, .withinLast)
        XCTAssertEqual(RuleField.isFavorite.defaultOperator, .equals)
    }

    // MARK: - ContentTypeValue Tests

    func testContentTypeValueContentTypes() {
        // Text should map to plainText
        XCTAssertTrue(ContentTypeValue.text.contentTypes.contains(.plainText))

        // Images should map to image types
        XCTAssertTrue(ContentTypeValue.images.contentTypes.contains(.png))
        XCTAssertTrue(ContentTypeValue.images.contentTypes.contains(.jpeg))
        XCTAssertTrue(ContentTypeValue.images.contentTypes.contains(.tiff))

        // Links should map to URL
        XCTAssertTrue(ContentTypeValue.links.contentTypes.contains(.url))

        // Files should map to fileURL
        XCTAssertTrue(ContentTypeValue.files.contentTypes.contains(.fileURL))
    }

    // MARK: - DateRangeValue Tests

    func testDateRangeValueStartDate() throws {
        let lastHour = DateRangeValue.lastHour.startDate
        let now = Date()

        // Start date should be within last hour
        let hourAgo = try XCTUnwrap(Calendar.current.date(byAdding: .hour, value: -1, to: now))
        XCTAssertTrue(lastHour >= hourAgo.addingTimeInterval(-1)) // Allow 1 second tolerance

        let last7Days = DateRangeValue.last7Days.startDate
        let weekAgo = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -7, to: now))
        XCTAssertTrue(last7Days >= weekAgo.addingTimeInterval(-1))
    }

    // MARK: - LogicalOperator Tests

    func testLogicalOperatorDisplayNames() {
        XCTAssertEqual(LogicalOperator.and.displayName, "All")
        XCTAssertEqual(LogicalOperator.or.displayName, "Any")
    }

    func testLogicalOperatorConditionDescriptions() {
        XCTAssertEqual(LogicalOperator.and.conditionDescription, "Match all of the following")
        XCTAssertEqual(LogicalOperator.or.conditionDescription, "Match any of the following")
    }
}
