//
//  AutomationRuleEntity+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch request for AutomationRuleEntity.
//

import CoreData
import Foundation

extension AutomationRuleEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AutomationRuleEntity> {
        NSFetchRequest<AutomationRuleEntity>(entityName: "AutomationRuleEntity")
    }

    // MARK: - Attributes

    /// Unique identifier
    @NSManaged public var id: UUID?

    /// User-defined rule name
    @NSManaged public var name: String?

    /// Whether the rule is currently enabled
    @NSManaged public var isEnabled: Bool

    /// Trigger type: "onCapture", "onPaste", "manual", "schedule"
    @NSManaged public var triggerType: String?

    /// Optional trigger value (e.g., cron expression for schedule triggers)
    @NSManaged public var triggerValue: String?

    /// JSON-serialized CollectionRules for matching conditions
    @NSManaged public var conditionsJSON: String?

    /// JSON-serialized array of AutomationAction for actions to execute
    @NSManaged public var actionsJSON: String?

    /// Rule priority (lower = higher priority, executes first)
    @NSManaged public var priority: Int32

    /// Timestamp when the rule was created
    @NSManaged public var createdAt: Date?

    /// Timestamp when the rule was last modified
    @NSManaged public var modifiedAt: Date?

    /// Timestamp when the rule was last executed (nil if never)
    @NSManaged public var lastExecutedAt: Date?

    /// Number of times the rule has been executed
    @NSManaged public var executionCount: Int64
}

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
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isEnabled == YES")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \AutomationRuleEntity.priority, ascending: true),
            NSSortDescriptor(keyPath: \AutomationRuleEntity.createdAt, ascending: true)
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
            NSSortDescriptor(keyPath: \AutomationRuleEntity.createdAt, ascending: true)
        ]
        return request
    }

    /// Fetches all rules ordered by priority
    static func allRulesFetchRequest() -> NSFetchRequest<AutomationRuleEntity> {
        let request = fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \AutomationRuleEntity.priority, ascending: true),
            NSSortDescriptor(keyPath: \AutomationRuleEntity.createdAt, ascending: true)
        ]
        return request
    }
}

// MARK: - AutomationRule Conversion

extension AutomationRuleEntity {
    /// Converts this entity to an AutomationRule model
    func toAutomationRule() -> AutomationRule? {
        guard let id = id,
              let name = name,
              let triggerTypeString = triggerType
        else {
            return nil
        }

        // Parse trigger
        let trigger: AutomationTrigger
        switch triggerTypeString {
        case "onCapture":
            trigger = .onCapture
        case "onPaste":
            trigger = .onPaste
        case "manual":
            trigger = .manual
        case "schedule":
            if let value = triggerValue,
               let cronData = value.data(using: .utf8),
               let cron = try? JSONDecoder().decode(CronExpression.self, from: cronData)
            {
                trigger = .schedule(cron)
            } else {
                trigger = .manual // Fallback
            }
        default:
            trigger = .onCapture
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
        if case .schedule(let cron) = rule.trigger {
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
