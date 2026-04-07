//
//  AutomationRuleEntity+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch request for AutomationRuleEntity.
//

import CoreData
import Foundation

public extension AutomationRuleEntity {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<AutomationRuleEntity> {
        NSFetchRequest<AutomationRuleEntity>(entityName: "AutomationRuleEntity")
    }

    // MARK: - Attributes

    /// Unique identifier
    @NSManaged var id: UUID?

    /// User-defined rule name
    @NSManaged var name: String?

    /// Whether the rule is currently enabled
    @NSManaged var isEnabled: Bool

    /// Trigger type: "onCapture", "onPaste", "manual", "schedule"
    @NSManaged var triggerType: String?

    /// Optional trigger value (e.g., cron expression for schedule triggers)
    @NSManaged var triggerValue: String?

    /// JSON-serialized CollectionRules for matching conditions
    @NSManaged var conditionsJSON: String?

    /// JSON-serialized array of AutomationAction for actions to execute
    @NSManaged var actionsJSON: String?

    /// Rule priority (lower = higher priority, executes first)
    @NSManaged var priority: Int32

    /// Timestamp when the rule was created
    @NSManaged var createdAt: Date?

    /// Timestamp when the rule was last modified
    @NSManaged var modifiedAt: Date?

    /// Timestamp when the rule was last executed (nil if never)
    @NSManaged var lastExecutedAt: Date?

    /// Number of times the rule has been executed
    @NSManaged var executionCount: Int64
}

// MARK: - AutomationRuleEntity + Identifiable

extension AutomationRuleEntity: Identifiable {}

// MARK: - Convenience Initializers

extension AutomationRuleEntity {
    /// Creates a new AutomationRuleEntity with default values
    convenience init(
        context: NSManagedObjectContext,
        name: String,
        triggerType: String = "onCapture",
        isEnabled: Bool = true,
        priority: Int32 = 100
    ) {
        self.init(context: context)
        self.id = UUID()
        self.name = name
        self.triggerType = triggerType
        self.isEnabled = isEnabled
        self.priority = priority
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.executionCount = 0
    }
}

// MARK: - Fetch Requests

extension AutomationRuleEntity {
    /// Fetches all enabled rules ordered by priority
    static func enabledRulesFetchRequest() -> NSFetchRequest<AutomationRuleEntity> {
        let request = self.fetchRequest()
        request.predicate = NSPredicate(format: "isEnabled == YES")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \AutomationRuleEntity.priority, ascending: true),
            NSSortDescriptor(keyPath: \AutomationRuleEntity.createdAt, ascending: true),
        ]
        return request
    }

    /// Fetches all rules for a specific trigger type
    static func rulesForTriggerFetchRequest(triggerType: String) -> NSFetchRequest<AutomationRuleEntity> {
        let request = self.fetchRequest()
        request.predicate = NSPredicate(
            format: "isEnabled == YES AND triggerType == %@",
            triggerType
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \AutomationRuleEntity.priority, ascending: true),
            NSSortDescriptor(keyPath: \AutomationRuleEntity.createdAt, ascending: true),
        ]
        return request
    }

    /// Fetches all rules ordered by priority
    static func allRulesFetchRequest() -> NSFetchRequest<AutomationRuleEntity> {
        let request = self.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \AutomationRuleEntity.priority, ascending: true),
            NSSortDescriptor(keyPath: \AutomationRuleEntity.createdAt, ascending: true),
        ]
        return request
    }
}

// MARK: - AutomationRule Conversion

extension AutomationRuleEntity {
    /// Converts this entity to an AutomationRule model
    func toAutomationRule() -> AutomationRule? {
        guard let id,
              let name,
              let triggerTypeString = triggerType
        else {
            return nil
        }

        // Parse trigger
        let trigger: AutomationTrigger = switch triggerTypeString {
        case "onCapture":
            .onCapture
        case "onPaste":
            .onPaste
        case "manual":
            .manual
        case "schedule":
            if let value = triggerValue,
               let cronData = value.data(using: .utf8),
               let cron = try? JSONDecoder().decode(CronExpression.self, from: cronData)
            {
                .schedule(cron)
            } else {
                .manual // Fallback
            }
        default:
            .onCapture
        }

        // Parse conditions (reusing CollectionRules)
        let conditions = CollectionRules.fromJSON(self.conditionsJSON) ?? CollectionRules()

        // Parse actions
        let actions = [AutomationAction].fromJSON(self.actionsJSON) ?? []

        return AutomationRule(
            id: id,
            name: name,
            isEnabled: self.isEnabled,
            trigger: trigger,
            conditions: conditions,
            actions: actions,
            priority: self.priority,
            createdAt: self.createdAt ?? Date(),
            modifiedAt: self.modifiedAt ?? Date(),
            lastExecutedAt: self.lastExecutedAt,
            executionCount: self.executionCount
        )
    }

    /// Updates this entity from an AutomationRule model
    func update(from rule: AutomationRule) {
        self.id = rule.id
        self.name = rule.name
        self.isEnabled = rule.isEnabled
        self.triggerType = rule.trigger.rawType
        self.priority = rule.priority
        self.createdAt = rule.createdAt
        self.modifiedAt = Date()
        self.lastExecutedAt = rule.lastExecutedAt
        self.executionCount = rule.executionCount

        // Serialize trigger value if schedule
        if case let .schedule(cron) = rule.trigger {
            if let cronData = try? JSONEncoder().encode(cron),
               let cronString = String(data: cronData, encoding: .utf8)
            {
                self.triggerValue = cronString
            }
        } else {
            self.triggerValue = nil
        }

        // Serialize conditions
        self.conditionsJSON = rule.conditions.toJSON()

        // Serialize actions
        self.actionsJSON = rule.actions.toJSON()
    }
}
