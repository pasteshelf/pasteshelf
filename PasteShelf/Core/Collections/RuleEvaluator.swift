//
//  RuleEvaluator.swift
//  PasteShelf
//
//  Evaluates collection rules and builds NSPredicate for CoreData queries.
//  Follows the predicate building pattern from FullTextSearchEngine.
//

import CoreData
import Foundation
import os.log

/// Evaluates Smart Collection rules and builds CoreData predicates
final class RuleEvaluator: @unchecked Sendable { // swiftlint:disable:this type_body_length
    // MARK: - Properties

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "collections"
    )

    // MARK: - Singleton

    static let shared = RuleEvaluator()

    private init() {}

    // MARK: - Predicate Building

    /// Builds an NSPredicate from collection rules
    /// - Parameter rules: The collection rules to evaluate
    /// - Returns: An NSPredicate that matches items according to the rules
    func buildPredicate(from rules: CollectionRules) -> NSPredicate {
        guard !rules.isEmpty else {
            logger.debug("Empty rules, returning always-true predicate")
            return NSPredicate(value: true)
        }

        let conditionPredicates = rules.conditions.compactMap { condition in
            buildConditionPredicate(condition)
        }

        guard !conditionPredicates.isEmpty else {
            logger.debug("No valid condition predicates, returning always-true predicate")
            return NSPredicate(value: true)
        }

        // Combine predicates based on logical operator
        let combinedPredicate: NSPredicate
        switch rules.logicalOperator {
        case .and:
            combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: conditionPredicates)
        case .or:
            combinedPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: conditionPredicates)
        }

        let count = conditionPredicates.count
        let op = rules.logicalOperator.rawValue
        logger.debug("Built predicate with \(count) conditions using \(op)")
        return combinedPredicate
    }

    /// Builds a predicate for a single condition
    /// - Parameter condition: The rule condition to evaluate
    /// - Returns: An NSPredicate for this condition, or nil if invalid
    private func buildConditionPredicate(_ condition: RuleCondition) -> NSPredicate? {
        switch condition.field {
        case .contentType:
            return buildContentTypePredicate(condition)
        case .sourceApp:
            return buildSourceAppPredicate(condition)
        case .textContent:
            return buildTextContentPredicate(condition)
        case .dateCreated:
            return buildDatePredicate(condition)
        case .isFavorite:
            return buildBooleanPredicate(condition, keyPath: "isFavorite")
        case .isSensitive:
            return buildBooleanPredicate(condition, keyPath: "isSensitive")
        }
    }

    // MARK: - Content Type Predicate

    private func buildContentTypePredicate(_ condition: RuleCondition) -> NSPredicate? {
        // Try to parse as ContentTypeValue first
        let contentTypeRawValues: [String]
        if let contentTypeValue = ContentTypeValue(rawValue: condition.value) {
            contentTypeRawValues = contentTypeValue.contentTypeRawValues
        } else if let contentType = ContentType(rawValue: condition.value) {
            // Direct ContentType raw value
            contentTypeRawValues = [contentType.rawValue]
        } else {
            // Unknown value - try using it directly
            contentTypeRawValues = [condition.value]
        }

        switch condition.comparisonOperator {
        case .equals:
            return NSPredicate(format: "contentType IN %@", contentTypeRawValues)
        case .notEquals:
            return NSPredicate(format: "NOT (contentType IN %@)", contentTypeRawValues)
        default:
            logger.warning("Unsupported operator \(condition.comparisonOperator.rawValue) for contentType")
            return nil
        }
    }

    // MARK: - Source App Predicate

    private func buildSourceAppPredicate(_ condition: RuleCondition) -> NSPredicate? {
        let safeValue = condition.value.predicateSafe

        switch condition.comparisonOperator {
        case .equals:
            // Match bundle ID or app name
            return NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "sourceAppBundleId ==[cd] %@", safeValue),
                NSPredicate(format: "sourceAppName ==[cd] %@", safeValue),
            ])
        case .notEquals:
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "sourceAppBundleId !=[cd] %@", safeValue),
                NSPredicate(format: "sourceAppName !=[cd] %@", safeValue),
            ])
        case .contains:
            return NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "sourceAppBundleId CONTAINS[cd] %@", safeValue),
                NSPredicate(format: "sourceAppName CONTAINS[cd] %@", safeValue),
            ])
        case .notContains:
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "NOT (sourceAppBundleId CONTAINS[cd] %@)", safeValue),
                NSPredicate(format: "NOT (sourceAppName CONTAINS[cd] %@)", safeValue),
            ])
        default:
            logger.warning("Unsupported operator \(condition.comparisonOperator.rawValue) for sourceApp")
            return nil
        }
    }

    // MARK: - Text Content Predicate

    private func buildTextContentPredicate(_ condition: RuleCondition) -> NSPredicate? {
        let safeValue = condition.value.predicateSafe

        switch condition.comparisonOperator {
        case .contains:
            return NSPredicate(format: "plainTextPreview CONTAINS[cd] %@", safeValue)
        case .notContains:
            return NSPredicate(format: "NOT (plainTextPreview CONTAINS[cd] %@)", safeValue)
        case .matches:
            // MATCHES uses regex
            return NSPredicate(format: "plainTextPreview MATCHES %@", condition.value)
        case .equals:
            return NSPredicate(format: "plainTextPreview ==[cd] %@", safeValue)
        case .notEquals:
            return NSPredicate(format: "plainTextPreview !=[cd] %@", safeValue)
        default:
            logger.warning("Unsupported operator \(condition.comparisonOperator.rawValue) for textContent")
            return nil
        }
    }

    // MARK: - Date Predicate

    private func buildDatePredicate(_ condition: RuleCondition) -> NSPredicate? {
        switch condition.comparisonOperator {
        case .withinLast:
            // Try to parse as DateRangeValue first
            if let rangeValue = DateRangeValue(rawValue: condition.value) {
                let startDate = rangeValue.startDate
                return NSPredicate(format: "timestamp >= %@", startDate as NSDate)
            }
            // Try parsing as a custom duration (e.g., "7d", "24h")
            if let startDate = parseCustomDuration(condition.value) {
                return NSPredicate(format: "timestamp >= %@", startDate as NSDate)
            }
            logger.warning("Could not parse date range value: \(condition.value)")
            return nil

        case .before:
            if let date = parseDate(condition.value) {
                return NSPredicate(format: "timestamp < %@", date as NSDate)
            }
            logger.warning("Could not parse date: \(condition.value)")
            return nil

        case .after:
            if let date = parseDate(condition.value) {
                return NSPredicate(format: "timestamp > %@", date as NSDate)
            }
            logger.warning("Could not parse date: \(condition.value)")
            return nil

        default:
            logger.warning("Unsupported operator \(condition.comparisonOperator.rawValue) for dateCreated")
            return nil
        }
    }

    /// Parses a custom duration string like "7d", "24h", "30d"
    private func parseCustomDuration(_ value: String) -> Date? {
        let pattern = #"^(\d+)([hdwm])$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let numberRange = Range(match.range(at: 1), in: value),
              let unitRange = Range(match.range(at: 2), in: value),
              let number = Int(value[numberRange])
        else {
            return nil
        }

        let unit = String(value[unitRange]).lowercased()
        let calendar = Calendar.current

        switch unit {
        case "h": // hours
            return calendar.date(byAdding: .hour, value: -number, to: Date())
        case "d": // days
            return calendar.date(byAdding: .day, value: -number, to: Date())
        case "w": // weeks
            return calendar.date(byAdding: .weekOfYear, value: -number, to: Date())
        case "m": // months
            return calendar.date(byAdding: .month, value: -number, to: Date())
        default:
            return nil
        }
    }

    /// Parses an ISO date string or common date formats
    private func parseDate(_ value: String) -> Date? {
        let formatters = [
            ISO8601DateFormatter(),
        ]

        for formatter in formatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        // Try DateFormatter for common formats
        let dateFormatter = DateFormatter()
        let formats = ["yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss", "MM/dd/yyyy"]
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    // MARK: - Boolean Predicate

    private func buildBooleanPredicate(_ condition: RuleCondition, keyPath: String) -> NSPredicate? {
        let boolValue: Bool
        switch condition.value.lowercased() {
        case "true", "yes", "1":
            boolValue = true
        case "false", "no", "0":
            boolValue = false
        default:
            logger.warning("Could not parse boolean value: \(condition.value)")
            return nil
        }

        switch condition.comparisonOperator {
        case .equals:
            return NSPredicate(format: "%K == %@", keyPath, NSNumber(value: boolValue))
        case .notEquals:
            return NSPredicate(format: "%K != %@", keyPath, NSNumber(value: boolValue))
        default:
            logger.warning("Unsupported operator \(condition.comparisonOperator.rawValue) for boolean field")
            return nil
        }
    }

    // MARK: - In-Memory Evaluation

    /// Evaluates whether a ClipboardItem matches the rules
    /// This is useful for filtering items that are already fetched
    /// - Parameters:
    ///   - item: The clipboard item to evaluate
    ///   - rules: The rules to apply
    /// - Returns: True if the item matches the rules
    func evaluate(item: ClipboardItem, against rules: CollectionRules) -> Bool {
        guard !rules.isEmpty else { return true }

        let results = rules.conditions.map { condition in
            evaluateCondition(condition, for: item)
        }

        switch rules.logicalOperator {
        case .and:
            return results.allSatisfy { $0 }
        case .or:
            return results.contains { $0 }
        }
    }

    /// Evaluates a single condition against an item
    private func evaluateCondition(_ condition: RuleCondition, for item: ClipboardItem) -> Bool {
        switch condition.field {
        case .contentType:
            return evaluateContentType(condition, item: item)
        case .sourceApp:
            return evaluateSourceApp(condition, item: item)
        case .textContent:
            return evaluateTextContent(condition, item: item)
        case .dateCreated:
            return evaluateDate(condition, item: item)
        case .isFavorite:
            return evaluateBoolean(condition, value: item.isFavorite)
        case .isSensitive:
            return evaluateBoolean(condition, value: item.isSensitive)
        }
    }

    private func evaluateContentType(_ condition: RuleCondition, item: ClipboardItem) -> Bool {
        guard let itemContentType = item.contentType else { return false }

        let targetTypes: Set<String>
        if let contentTypeValue = ContentTypeValue(rawValue: condition.value) {
            targetTypes = Set(contentTypeValue.contentTypeRawValues)
        } else {
            targetTypes = [condition.value]
        }

        switch condition.comparisonOperator {
        case .equals:
            return targetTypes.contains(itemContentType)
        case .notEquals:
            return !targetTypes.contains(itemContentType)
        default:
            return false
        }
    }

    private func evaluateSourceApp(_ condition: RuleCondition, item: ClipboardItem) -> Bool {
        let bundleId = item.sourceAppBundleId ?? ""
        let appName = item.sourceAppName ?? ""
        let value = condition.value.lowercased()

        switch condition.comparisonOperator {
        case .equals:
            return bundleId.lowercased() == value || appName.lowercased() == value
        case .notEquals:
            return bundleId.lowercased() != value && appName.lowercased() != value
        case .contains:
            return bundleId.lowercased().contains(value) || appName.lowercased().contains(value)
        case .notContains:
            return !bundleId.lowercased().contains(value) && !appName.lowercased().contains(value)
        default:
            return false
        }
    }

    private func evaluateTextContent(_ condition: RuleCondition, item: ClipboardItem) -> Bool {
        guard let text = item.plainTextPreview else { return false }
        let value = condition.value

        switch condition.comparisonOperator {
        case .contains:
            return text.containsIgnoringCase(value)
        case .notContains:
            return !text.containsIgnoringCase(value)
        case .equals:
            return text.lowercased() == value.lowercased()
        case .notEquals:
            return text.lowercased() != value.lowercased()
        case .matches:
            guard let regex = try? NSRegularExpression(pattern: value) else { return false }
            let range = NSRange(text.startIndex..., in: text)
            return regex.firstMatch(in: text, range: range) != nil
        default:
            return false
        }
    }

    private func evaluateDate(_ condition: RuleCondition, item: ClipboardItem) -> Bool {
        guard let timestamp = item.timestamp else { return false }

        switch condition.comparisonOperator {
        case .withinLast:
            let startDate: Date?
            if let rangeValue = DateRangeValue(rawValue: condition.value) {
                startDate = rangeValue.startDate
            } else {
                startDate = parseCustomDuration(condition.value)
            }
            guard let start = startDate else { return false }
            return timestamp >= start

        case .before:
            guard let date = parseDate(condition.value) else { return false }
            return timestamp < date

        case .after:
            guard let date = parseDate(condition.value) else { return false }
            return timestamp > date

        default:
            return false
        }
    }

    private func evaluateBoolean(_ condition: RuleCondition, value: Bool) -> Bool {
        let targetValue: Bool
        switch condition.value.lowercased() {
        case "true", "yes", "1":
            targetValue = true
        case "false", "no", "0":
            targetValue = false
        default:
            return false
        }

        switch condition.comparisonOperator {
        case .equals:
            return value == targetValue
        case .notEquals:
            return value != targetValue
        default:
            return false
        }
    }
}
