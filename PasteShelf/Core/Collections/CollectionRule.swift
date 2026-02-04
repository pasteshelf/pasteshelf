//
//  CollectionRule.swift
//  PasteShelf
//
//  Data structures for Smart Collection rule definitions.
//  These structures are Codable for JSON serialization in the SmartCollection entity.
//

import Foundation

// MARK: - Collection Rules

/// Container for collection filtering rules
struct CollectionRules: Codable, Equatable, Sendable {
    /// Individual conditions to evaluate
    var conditions: [RuleCondition]

    /// Logical operator to combine conditions (AND/OR)
    var logicalOperator: LogicalOperator

    /// Creates default empty rules
    init(
        conditions: [RuleCondition] = [],
        logicalOperator: LogicalOperator = .and
    ) {
        self.conditions = conditions
        self.logicalOperator = logicalOperator
    }

    /// Whether the rules have any conditions
    var isEmpty: Bool {
        conditions.isEmpty
    }
}

// MARK: - Rule Condition

/// A single rule condition for filtering clipboard items
struct RuleCondition: Codable, Equatable, Identifiable, Sendable {
    /// Unique identifier for this condition
    let id: UUID

    /// The field to evaluate
    var field: RuleField

    /// The comparison operator
    var comparisonOperator: RuleOperator

    /// The value to compare against
    var value: String

    init(
        id: UUID = UUID(),
        field: RuleField,
        comparisonOperator: RuleOperator,
        value: String
    ) {
        self.id = id
        self.field = field
        self.comparisonOperator = comparisonOperator
        self.value = value
    }
}

// MARK: - Rule Field

/// Fields that can be used in rule conditions
enum RuleField: String, Codable, CaseIterable, Sendable {
    /// Content type (text, image, file, etc.)
    case contentType

    /// Source application bundle ID or name
    case sourceApp

    /// Text content (plainTextPreview)
    case textContent

    /// Date the item was created
    case dateCreated

    /// Whether the item is a favorite
    case isFavorite

    /// Whether the item contains sensitive data
    case isSensitive

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .contentType: return "Content Type"
        case .sourceApp: return "Source App"
        case .textContent: return "Text Content"
        case .dateCreated: return "Date Created"
        case .isFavorite: return "Is Favorite"
        case .isSensitive: return "Is Sensitive"
        }
    }

    /// SF Symbol icon for the field
    var icon: String {
        switch self {
        case .contentType: return "doc"
        case .sourceApp: return "app.badge"
        case .textContent: return "text.alignleft"
        case .dateCreated: return "calendar"
        case .isFavorite: return "star"
        case .isSensitive: return "lock.shield"
        }
    }

    /// Available operators for this field
    var availableOperators: [RuleOperator] {
        switch self {
        case .contentType:
            return [.equals, .notEquals]
        case .sourceApp:
            return [.equals, .notEquals, .contains, .notContains]
        case .textContent:
            return [.contains, .notContains, .matches]
        case .dateCreated:
            return [.before, .after, .withinLast]
        case .isFavorite, .isSensitive:
            return [.equals]
        }
    }

    /// Default operator for this field
    var defaultOperator: RuleOperator {
        switch self {
        case .contentType: return .equals
        case .sourceApp: return .equals
        case .textContent: return .contains
        case .dateCreated: return .withinLast
        case .isFavorite, .isSensitive: return .equals
        }
    }
}

// MARK: - Rule Operator

/// Comparison operators for rule conditions
enum RuleOperator: String, Codable, CaseIterable, Sendable {
    /// Exact match (for strings: case-insensitive)
    case equals

    /// Not equal
    case notEquals

    /// Contains substring (case-insensitive)
    case contains

    /// Does not contain substring
    case notContains

    /// Regular expression match
    case matches

    /// Date is before value
    case before

    /// Date is after value
    case after

    /// Date is within last N days/hours
    case withinLast

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .equals: return "is"
        case .notEquals: return "is not"
        case .contains: return "contains"
        case .notContains: return "does not contain"
        case .matches: return "matches pattern"
        case .before: return "is before"
        case .after: return "is after"
        case .withinLast: return "is within last"
        }
    }
}

// MARK: - Logical Operator

/// Logical operators to combine multiple conditions
enum LogicalOperator: String, Codable, CaseIterable, Sendable {
    /// All conditions must match
    case and

    /// Any condition can match
    case or

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .and: return "All"
        case .or: return "Any"
        }
    }

    /// Description for UI
    var conditionDescription: String {
        switch self {
        case .and: return "Match all of the following"
        case .or: return "Match any of the following"
        }
    }
}

// MARK: - Content Type Values

/// Predefined content type values for rule conditions
enum ContentTypeValue: String, CaseIterable, Sendable {
    case text
    case images
    case files
    case links
    case richText
    case html
    case pdf

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .images: return "Images"
        case .files: return "Files"
        case .links: return "Links"
        case .richText: return "Rich Text"
        case .html: return "HTML"
        case .pdf: return "PDF"
        }
    }

    /// The ContentType values this represents
    var contentTypes: Set<ContentType> {
        switch self {
        case .text:
            return [.plainText]
        case .images:
            return [.png, .jpeg, .tiff]
        case .files:
            return [.fileURL]
        case .links:
            return [.url]
        case .richText:
            return [.richText]
        case .html:
            return [.html]
        case .pdf:
            return [.pdf]
        }
    }

    /// All content type raw values for this category
    var contentTypeRawValues: [String] {
        contentTypes.map { $0.rawValue }
    }
}

// MARK: - Date Range Values

/// Predefined date range values for rule conditions
enum DateRangeValue: String, CaseIterable, Sendable {
    case lastHour = "1h"
    case last24Hours = "24h"
    case last7Days = "7d"
    case last30Days = "30d"
    case last90Days = "90d"

    var displayName: String {
        switch self {
        case .lastHour: return "Last Hour"
        case .last24Hours: return "Last 24 Hours"
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .last90Days: return "Last 90 Days"
        }
    }

    /// Calculates the start date for this range
    var startDate: Date {
        switch self {
        case .lastHour:
            return Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
        case .last24Hours:
            return Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        case .last7Days:
            return Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .last30Days:
            return Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        case .last90Days:
            return Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        }
    }
}

// MARK: - JSON Serialization

extension CollectionRules {
    /// Serializes rules to JSON string
    func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Deserializes rules from JSON string
    static func fromJSON(_ json: String?) -> CollectionRules? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CollectionRules.self, from: data)
    }
}
