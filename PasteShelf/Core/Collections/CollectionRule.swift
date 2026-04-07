//
//  CollectionRule.swift
//  PasteShelf
//
//  Data structures for Smart Collection rule definitions.
//  These structures are Codable for JSON serialization in the SmartCollection entity.
//

import Foundation

// MARK: - CollectionRules

/// Container for collection filtering rules
struct CollectionRules: Codable, Equatable {
    // MARK: Lifecycle

    /// Creates default empty rules
    init(
        conditions: [RuleCondition] = [],
        logicalOperator: LogicalOperator = .and
    ) {
        self.conditions = conditions
        self.logicalOperator = logicalOperator
    }

    // MARK: Internal

    /// Individual conditions to evaluate
    var conditions: [RuleCondition]

    /// Logical operator to combine conditions (AND/OR)
    var logicalOperator: LogicalOperator

    /// Whether the rules have any conditions
    var isEmpty: Bool {
        self.conditions.isEmpty
    }
}

// MARK: - RuleCondition

/// A single rule condition for filtering clipboard items
struct RuleCondition: Codable, Equatable, Identifiable {
    // MARK: Lifecycle

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

    // MARK: Internal

    /// Unique identifier for this condition
    let id: UUID

    /// The field to evaluate
    var field: RuleField

    /// The comparison operator
    var comparisonOperator: RuleOperator

    /// The value to compare against
    var value: String
}

// MARK: - RuleField

/// Fields that can be used in rule conditions
enum RuleField: String, Codable, CaseIterable {
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

    // MARK: Internal

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .contentType: "Content Type"
        case .sourceApp: "Source App"
        case .textContent: "Text Content"
        case .dateCreated: "Date Created"
        case .isFavorite: "Is Favorite"
        case .isSensitive: "Is Sensitive"
        }
    }

    /// SF Symbol icon for the field
    var icon: String {
        switch self {
        case .contentType: "doc"
        case .sourceApp: "app.badge"
        case .textContent: "text.alignleft"
        case .dateCreated: "calendar"
        case .isFavorite: "star"
        case .isSensitive: "lock.shield"
        }
    }

    /// Available operators for this field
    var availableOperators: [RuleOperator] {
        switch self {
        case .contentType:
            [.equals, .notEquals]
        case .sourceApp:
            [.equals, .notEquals, .contains, .notContains]
        case .textContent:
            [.contains, .notContains, .matches]
        case .dateCreated:
            [.before, .after, .withinLast]
        case .isFavorite,
             .isSensitive:
            [.equals]
        }
    }

    /// Default operator for this field
    var defaultOperator: RuleOperator {
        switch self {
        case .contentType: .equals
        case .sourceApp: .equals
        case .textContent: .contains
        case .dateCreated: .withinLast
        case .isFavorite,
             .isSensitive: .equals
        }
    }
}

// MARK: - RuleOperator

/// Comparison operators for rule conditions
enum RuleOperator: String, Codable, CaseIterable {
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

    // MARK: Internal

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .equals: "is"
        case .notEquals: "is not"
        case .contains: "contains"
        case .notContains: "does not contain"
        case .matches: "matches pattern"
        case .before: "is before"
        case .after: "is after"
        case .withinLast: "is within last"
        }
    }
}

// MARK: - LogicalOperator

/// Logical operators to combine multiple conditions
enum LogicalOperator: String, Codable, CaseIterable {
    /// All conditions must match
    case and

    /// Any condition can match
    case or

    // MARK: Internal

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .and: "All"
        case .or: "Any"
        }
    }

    /// Description for UI
    var conditionDescription: String {
        switch self {
        case .and: "Match all of the following"
        case .or: "Match any of the following"
        }
    }
}

// MARK: - ContentTypeValue

/// Predefined content type values for rule conditions
enum ContentTypeValue: String, CaseIterable {
    case text
    case images
    case files
    case links
    case richText
    case html
    case pdf

    // MARK: Internal

    var displayName: String {
        switch self {
        case .text: "Text"
        case .images: "Images"
        case .files: "Files"
        case .links: "Links"
        case .richText: "Rich Text"
        case .html: "HTML"
        case .pdf: "PDF"
        }
    }

    /// The ContentType values this represents
    var contentTypes: Set<ContentType> {
        switch self {
        case .text:
            [.plainText]
        case .images:
            [.png, .jpeg, .tiff]
        case .files:
            [.fileURL]
        case .links:
            [.url]
        case .richText:
            [.richText]
        case .html:
            [.html]
        case .pdf:
            [.pdf]
        }
    }

    /// All content type raw values for this category
    var contentTypeRawValues: [String] {
        self.contentTypes.map(\.rawValue)
    }
}

// MARK: - DateRangeValue

/// Predefined date range values for rule conditions
enum DateRangeValue: String, CaseIterable {
    case lastHour = "1h"
    case last24Hours = "24h"
    case last7Days = "7d"
    case last30Days = "30d"
    case last90Days = "90d"

    // MARK: Internal

    var displayName: String {
        switch self {
        case .lastHour: "Last Hour"
        case .last24Hours: "Last 24 Hours"
        case .last7Days: "Last 7 Days"
        case .last30Days: "Last 30 Days"
        case .last90Days: "Last 90 Days"
        }
    }

    /// Calculates the start date for this range
    var startDate: Date {
        switch self {
        case .lastHour:
            Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
        case .last24Hours:
            Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        case .last7Days:
            Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .last30Days:
            Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        case .last90Days:
            Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        }
    }
}

// MARK: - JSON Serialization

extension CollectionRules {
    /// Serializes rules to JSON string
    func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(self) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Deserializes rules from JSON string
    static func fromJSON(_ json: String?) -> CollectionRules? {
        guard let json, let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(CollectionRules.self, from: data)
    }
}
