//
//  AutomationRuleStorage.swift
//  PasteShelf
//
//  CoreData storage operations for automation rules.
//  Provides CRUD operations and specialized queries.
//

import CoreData
import Foundation
import os.log

/// Storage manager for automation rules
@MainActor
final class AutomationRuleStorage {
    // MARK: Lifecycle

    // MARK: - Initialization

    private init() {}

    // MARK: Internal

    // MARK: - Singleton

    static let shared = AutomationRuleStorage()

    // MARK: - Fetch Operations

    /// Fetches all automation rules ordered by priority
    func fetchAllRules() async -> [AutomationRule] {
        let context = storageManager.viewContext
        let fetchRequest = AutomationRuleEntity.allRulesFetchRequest()

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.compactMap { $0.toAutomationRule() }
        } catch {
            logger.error("Failed to fetch automation rules: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetches all enabled rules ordered by priority
    func fetchEnabledRules() async -> [AutomationRule] {
        let context = storageManager.viewContext
        let fetchRequest = AutomationRuleEntity.enabledRulesFetchRequest()

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.compactMap { $0.toAutomationRule() }
        } catch {
            logger.error("Failed to fetch enabled rules: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetches enabled rules for a specific trigger type
    func fetchRules(for triggerType: String) async -> [AutomationRule] {
        let context = storageManager.viewContext
        let fetchRequest = AutomationRuleEntity.rulesForTriggerFetchRequest(triggerType: triggerType)

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.compactMap { $0.toAutomationRule() }
        } catch {
            logger.error("Failed to fetch rules for trigger \(triggerType): \(error.localizedDescription)")
            return []
        }
    }

    /// Fetches a single rule by ID
    func fetchRule(id: UUID) async -> AutomationRule? {
        let context = storageManager.viewContext
        let fetchRequest = AutomationRuleEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            return try context.fetch(fetchRequest).first?.toAutomationRule()
        } catch {
            logger.error("Failed to fetch rule \(id): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Create/Update Operations

    /// Creates a new automation rule
    @discardableResult
    func createRule(_ rule: AutomationRule) async -> Bool {
        let context = storageManager.newBackgroundContext()

        return await context.perform {
            let entity = AutomationRuleEntity(context: context)
            entity.update(from: rule)

            do {
                try context.save()
                self.logger.info("Created automation rule: \(rule.name)")
                return true
            } catch {
                self.logger.error("Failed to create rule: \(error.localizedDescription)")
                return false
            }
        }
    }

    /// Updates an existing automation rule
    @discardableResult
    func updateRule(_ rule: AutomationRule) async -> Bool {
        let context = storageManager.newBackgroundContext()

        return await context.perform {
            let fetchRequest = AutomationRuleEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", rule.id as CVarArg)

            do {
                if let entity = try context.fetch(fetchRequest).first {
                    entity.update(from: rule)
                    try context.save()
                    self.logger.info("Updated automation rule: \(rule.name)")
                    return true
                } else {
                    self.logger.warning("Rule not found for update: \(rule.id)")
                    return false
                }
            } catch {
                self.logger.error("Failed to update rule: \(error.localizedDescription)")
                return false
            }
        }
    }

    /// Creates or updates a rule (upsert)
    @discardableResult
    func saveRule(_ rule: AutomationRule) async -> Bool {
        if await fetchRule(id: rule.id) != nil {
            await updateRule(rule)
        } else {
            await createRule(rule)
        }
    }

    // MARK: - Delete Operations

    /// Deletes a rule by ID
    @discardableResult
    func deleteRule(id: UUID) async -> Bool {
        let context = storageManager.newBackgroundContext()

        return await context.perform {
            let fetchRequest = AutomationRuleEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            do {
                if let entity = try context.fetch(fetchRequest).first {
                    context.delete(entity)
                    try context.save()
                    self.logger.info("Deleted automation rule: \(id)")
                    return true
                } else {
                    self.logger.warning("Rule not found for deletion: \(id)")
                    return false
                }
            } catch {
                self.logger.error("Failed to delete rule: \(error.localizedDescription)")
                return false
            }
        }
    }

    /// Deletes all rules
    @discardableResult
    func deleteAllRules() async -> Bool {
        let context = storageManager.newBackgroundContext()

        return await context.perform {
            let fetchRequest = AutomationRuleEntity.fetchRequest()

            do {
                let entities = try context.fetch(fetchRequest)
                for entity in entities {
                    context.delete(entity)
                }
                try context.save()
                self.logger.info("Deleted all automation rules (\(entities.count) total)")
                return true
            } catch {
                self.logger.error("Failed to delete all rules: \(error.localizedDescription)")
                return false
            }
        }
    }

    // MARK: - Toggle Operations

    /// Toggles the enabled state of a rule
    @discardableResult
    func toggleRule(id: UUID) async -> Bool {
        let context = storageManager.newBackgroundContext()

        return await context.perform {
            let fetchRequest = AutomationRuleEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            do {
                if let entity = try context.fetch(fetchRequest).first {
                    entity.isEnabled.toggle()
                    entity.modifiedAt = Date()
                    try context.save()
                    self.logger.info("Toggled rule \(id) to enabled=\(entity.isEnabled)")
                    return true
                }
                return false
            } catch {
                self.logger.error("Failed to toggle rule: \(error.localizedDescription)")
                return false
            }
        }
    }

    // MARK: - Priority Operations

    /// Updates the priority of a rule
    @discardableResult
    func updatePriority(id: UUID, priority: Int32) async -> Bool {
        let context = storageManager.newBackgroundContext()

        return await context.perform {
            let fetchRequest = AutomationRuleEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            do {
                if let entity = try context.fetch(fetchRequest).first {
                    entity.priority = priority
                    entity.modifiedAt = Date()
                    try context.save()
                    self.logger.debug("Updated priority for rule \(id) to \(priority)")
                    return true
                }
                return false
            } catch {
                self.logger.error("Failed to update priority: \(error.localizedDescription)")
                return false
            }
        }
    }

    /// Reorders rules by updating their priorities
    @discardableResult
    func reorderRules(_ orderedIds: [UUID]) async -> Bool {
        let context = storageManager.newBackgroundContext()

        return await context.perform {
            let fetchRequest = AutomationRuleEntity.fetchRequest()

            do {
                let entities = try context.fetch(fetchRequest)
                let entityMap = Dictionary(uniqueKeysWithValues: entities.compactMap {
                    ($0.id, $0) as? (UUID, AutomationRuleEntity)
                })

                for (index, id) in orderedIds.enumerated() {
                    if let entity = entityMap[id] {
                        entity.priority = Int32(index * 10) // Space out priorities
                        entity.modifiedAt = Date()
                    }
                }

                try context.save()
                self.logger.info("Reordered \(orderedIds.count) rules")
                return true
            } catch {
                self.logger.error("Failed to reorder rules: \(error.localizedDescription)")
                return false
            }
        }
    }

    // MARK: - Execution Tracking

    /// Records that a rule was executed
    @discardableResult
    func recordExecution(id: UUID) async -> Bool {
        let context = storageManager.newBackgroundContext()

        return await context.perform {
            let fetchRequest = AutomationRuleEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            do {
                if let entity = try context.fetch(fetchRequest).first {
                    entity.lastExecutedAt = Date()
                    entity.executionCount += 1
                    try context.save()
                    return true
                }
                return false
            } catch {
                self.logger.error("Failed to record execution: \(error.localizedDescription)")
                return false
            }
        }
    }

    // MARK: - Seed Default Rules

    /// Seeds default example rules (for first launch)
    func seedDefaultRulesIfNeeded() async {
        let existingRules = await fetchAllRules()
        guard existingRules.isEmpty else {
            logger.debug("Default rules not needed, rules already exist")
            return
        }

        logger.info("Seeding default automation rules")

        // Example rules (disabled by default, user can enable if wanted)
        let examples: [AutomationRule] = [
            AutomationRule.notifySensitive,
        ]

        for rule in examples {
            await createRule(rule)
        }
    }

    // MARK: Private

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "automation.storage"
    )

    private let storageManager = StorageManager.shared
}
