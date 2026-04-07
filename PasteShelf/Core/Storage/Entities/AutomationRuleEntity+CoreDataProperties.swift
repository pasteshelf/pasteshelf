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
        id = UUID()
        self.name = name
        self.triggerType = triggerType
        self.isEnabled = isEnabled
        self.priority = priority
        createdAt = Date()
        modifiedAt = Date()
        executionCount = 0
    }
}

// MARK: - Fetch Requests

extension AutomationRuleEntity {
    /// Fetches all enabled rules ordered by priority
    static func enabledRulesFetchRequest() -> NSFetchRequest<AutomationRuleEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isEnabled == YES")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \AutomationRuleEntity.priority, ascending: true),
            NSSortDescriptor(keyPath: \AutomationRuleEntity.createdAt, ascending: true),
        ]
        return request
    }

    /// Fetches all rules for a specific trigger type
    static func rulesForTriggerFetchRequest(triggerType: String) -> NSFetchRequest<AutomationRuleEntity> {
        let request = fetchRequest()
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
        let request = fetchRequest()
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
        let conditions = CollectionRules.fromJSON(conditionsJSON) ?? CollectionRules()

        // Parse actions
        let actions = [AutomationAction].fromJSON(actionsJSON) ?? []

        return AutomationRule(
            id: id,
            name: name,
            isEnabled: isEnabled,
            trigger: trigger,
            conditions: conditions,
            actions: actions,
            priority: priority,
            createdAt: createdAt ?? Date(),
            modifiedAt: modifiedAt ?? Date(),
            lastExecutedAt: lastExecutedAt,
            executionCount: executionCount
        )
    }

    /// Updates this entity from an AutomationRule model
    func update(from rule: AutomationRule) {
        id = rule.id
        name = rule.name
        isEnabled = rule.isEnabled
        triggerType = rule.trigger.rawType
        priority = rule.priority
        createdAt = rule.createdAt
        modifiedAt = Date()
        lastExecutedAt = rule.lastExecutedAt
        executionCount = rule.executionCount

        // Serialize trigger value if schedule
        if case let .schedule(cron) = rule.trigger {
            if let cronData = try? JSONEncoder().encode(cron),
               let cronString = String(data: cronData, encoding: .utf8)
            {
                triggerValue = cronString
            }
        } else {
            triggerValue = nil
        }

        // Serialize conditions
        conditionsJSON = rule.conditions.toJSON()

        // Serialize actions
        actionsJSON = rule.actions.toJSON()
    }
}
