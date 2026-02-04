//
//  AutomationRule.swift
//  PasteShelf
//
//  Defines the automation rule structure that combines triggers, conditions, and actions.
//  Rules are evaluated when their trigger fires and conditions match.
//

import Foundation

// MARK: - Automation Rule

/// An automation rule that executes actions when conditions are met
struct AutomationRule: Codable, Equatable, Identifiable, Sendable {
    /// Unique identifier for this rule
    let id: UUID

    /// User-defined name for the rule
    var name: String

    /// Whether the rule is currently enabled
    var isEnabled: Bool

    /// The trigger that initiates rule evaluation
    var trigger: AutomationTrigger

    /// Conditions that must match for actions to execute
    /// Reuses CollectionRules from Smart Collections for consistency
    var conditions: CollectionRules

    /// Actions to execute when conditions match
    var actions: [AutomationAction]

    /// Priority for rule ordering (lower = higher priority)
    var priority: Int32

    /// Date the rule was created
    let createdAt: Date

    /// Date the rule was last modified
    var modifiedAt: Date

    /// Date the rule was last executed (nil if never)
    var lastExecutedAt: Date?

    /// Number of times the rule has been executed
    var executionCount: Int64

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        trigger: AutomationTrigger = .onCapture,
        conditions: CollectionRules = CollectionRules(),
        actions: [AutomationAction] = [],
        priority: Int32 = 100,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        lastExecutedAt: Date? = nil,
        executionCount: Int64 = 0
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.trigger = trigger
        self.conditions = conditions
        self.actions = actions
        self.priority = priority
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.lastExecutedAt = lastExecutedAt
        self.executionCount = executionCount
    }

    // MARK: - Properties

    /// Whether this rule has any conditions defined
    var hasConditions: Bool {
        !conditions.isEmpty
    }

    /// Whether this rule has any actions defined
    var hasActions: Bool {
        !actions.isEmpty
    }

    /// Whether this rule is complete and valid
    var isValid: Bool {
        !name.isEmpty && hasActions
    }

    /// Whether this rule requires Pro license
    var requiresPro: Bool {
        // All automation rules require Pro
        true
    }

    /// Whether this rule requires Enterprise license
    var requiresEnterprise: Bool {
        // Rules with webhook actions require Enterprise
        actions.contains { $0.requiresEnterprise }
    }

    // MARK: - Mutation Helpers

    /// Creates a copy with updated modification date
    func withUpdatedModificationDate() -> AutomationRule {
        var copy = self
        copy.modifiedAt = Date()
        return copy
    }

    /// Creates a copy marking successful execution
    func withExecution() -> AutomationRule {
        var copy = self
        copy.lastExecutedAt = Date()
        copy.executionCount += 1
        return copy
    }

    /// Creates a copy with a new action appended
    func appending(action: AutomationAction) -> AutomationRule {
        var copy = self
        copy.actions.append(action)
        copy.modifiedAt = Date()
        return copy
    }

    /// Creates a copy with an action removed
    func removing(action: AutomationAction) -> AutomationRule {
        var copy = self
        copy.actions.removeAll { $0.id == action.id }
        copy.modifiedAt = Date()
        return copy
    }

    /// Creates a copy with a new condition appended
    func appending(condition: RuleCondition) -> AutomationRule {
        var copy = self
        copy.conditions.conditions.append(condition)
        copy.modifiedAt = Date()
        return copy
    }

    /// Creates a copy with a condition removed
    func removing(condition: RuleCondition) -> AutomationRule {
        var copy = self
        copy.conditions.conditions.removeAll { $0.id == condition.id }
        copy.modifiedAt = Date()
        return copy
    }
}

// MARK: - Comparable by Priority

extension AutomationRule: Comparable {
    static func < (lhs: AutomationRule, rhs: AutomationRule) -> Bool {
        // Lower priority value = higher priority (executes first)
        if lhs.priority != rhs.priority {
            return lhs.priority < rhs.priority
        }
        // If same priority, sort by creation date (older first)
        return lhs.createdAt < rhs.createdAt
    }
}

// MARK: - Default Rules

extension AutomationRule {
    /// Example: Uppercase text from Terminal
    static var uppercaseTerminal: AutomationRule {
        AutomationRule(
            name: "Uppercase from Terminal",
            trigger: .onCapture,
            conditions: CollectionRules(
                conditions: [
                    RuleCondition(
                        field: .sourceApp,
                        comparisonOperator: .contains,
                        value: "Terminal"
                    )
                ]
            ),
            actions: [
                .transform(preset: .uppercase)
            ]
        )
    }

    /// Example: Clean URLs
    static var cleanURLs: AutomationRule {
        AutomationRule(
            name: "Clean URL Tracking Parameters",
            trigger: .onCapture,
            conditions: CollectionRules(
                conditions: [
                    RuleCondition(
                        field: .contentType,
                        comparisonOperator: .equals,
                        value: ContentTypeValue.links.rawValue
                    )
                ]
            ),
            actions: [
                .transform(preset: .trimWhitespace)
            ],
            priority: 50
        )
    }

    /// Example: Notify on sensitive content
    static var notifySensitive: AutomationRule {
        AutomationRule(
            name: "Alert on Sensitive Content",
            trigger: .onCapture,
            conditions: CollectionRules(
                conditions: [
                    RuleCondition(
                        field: .isSensitive,
                        comparisonOperator: .equals,
                        value: "true"
                    )
                ]
            ),
            actions: [
                .notify(
                    title: "Sensitive Content Copied",
                    message: "A sensitive item was added to your clipboard history"
                )
            ]
        )
    }
}

// MARK: - JSON Serialization

extension AutomationRule {
    /// Serializes the rule to JSON string
    func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Deserializes a rule from JSON string
    static func fromJSON(_ json: String?) -> AutomationRule? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AutomationRule.self, from: data)
    }
}

// MARK: - Display Model

/// A display-friendly representation of an AutomationRule
struct AutomationRuleDisplayModel: Identifiable, Sendable {
    let id: UUID
    let name: String
    let isEnabled: Bool
    let triggerDescription: String
    let triggerIcon: String
    let conditionCount: Int
    let actionCount: Int
    let lastExecutedDescription: String?
    let executionCount: Int64
    let requiresEnterprise: Bool

    init(from rule: AutomationRule) {
        self.id = rule.id
        self.name = rule.name
        self.isEnabled = rule.isEnabled
        self.triggerDescription = rule.trigger.displayName
        self.triggerIcon = rule.trigger.iconName
        self.conditionCount = rule.conditions.conditions.count
        self.actionCount = rule.actions.count
        self.executionCount = rule.executionCount
        self.requiresEnterprise = rule.requiresEnterprise

        if let lastExecuted = rule.lastExecutedAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            self.lastExecutedDescription = formatter.localizedString(for: lastExecuted, relativeTo: Date())
        } else {
            self.lastExecutedDescription = nil
        }
    }
}
