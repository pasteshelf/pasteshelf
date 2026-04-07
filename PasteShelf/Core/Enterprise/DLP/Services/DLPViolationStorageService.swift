//
//  DLPViolationStorageService.swift
//  PasteShelf
//
//  CoreData-backed persistence for DLP violations and rules.
//

import CoreData
import Foundation
import os.log

// MARK: - DLPViolationStorageService

/// Persists, queries, and prunes `DLPViolationEntity` and `DLPRuleEntity` CoreData entities on
/// behalf of the DLP subsystem.
///
/// `DLPViolationStorageService` conforms to both `DLPViolationStoring` and `DLPRuleStoring`
/// and delegates all managed-object context work to `PersistenceController`. Reads use the
/// shared `viewContext`; writes use a fresh background context to avoid blocking the main thread.
final class DLPViolationStorageService: DLPViolationStoring, DLPRuleStoring, @unchecked Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates a `DLPViolationStorageService` with the given persistence controller.
    ///
    /// - Parameter persistenceController: The `PersistenceController` that owns the CoreData stack.
    ///   Defaults to the application singleton.
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    // MARK: Internal

    // MARK: - DLPViolationStoring

    /// Persists a single DLP violation record to CoreData.
    ///
    /// Uses a background context to avoid blocking the main thread.
    ///
    /// - Parameter violation: The `DLPViolation` to persist.
    /// - Throws: `DLPError.storageFailure` if the CoreData save fails.
    func save(_ violation: DLPViolation) async throws {
        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            _ = DLPViolationEntity(context: context, violation: violation)

            do {
                try context.save()
                self.logger.debug("Saved DLP violation \(violation.id) (rule: \(violation.ruleName))")
            } catch {
                self.logger
                    .error("CoreData save failed for DLP violation \(violation.id): \(error.localizedDescription)")
                throw DLPError.storageFailure(error.localizedDescription)
            }
        }
    }

    /// Fetches stored violation records, optionally filtered by date range.
    ///
    /// Uses the shared `viewContext` and `DLPViolationEntity.violationsFetchRequest(from:to:)` to
    /// return results sorted by timestamp descending.
    ///
    /// - Parameters:
    ///   - from: If non-nil, only violations at or after this date are returned.
    ///   - to: If non-nil, only violations at or before this date are returned.
    ///   - limit: The maximum number of records to return.
    /// - Returns: An array of `DLPViolationEntity` managed objects matching the filters.
    /// - Throws: `DLPError.storageFailure` if the CoreData fetch fails.
    func fetchViolations(from: Date?, to: Date?, limit: Int) async throws -> [DLPViolationEntity] {
        let viewContext = persistenceController.container.viewContext
        return try await viewContext.perform {
            let request = DLPViolationEntity.violationsFetchRequest(from: from, to: to)
            request.fetchLimit = limit
            do {
                let results = try viewContext.fetch(request)
                self.logger.debug("Fetched \(results.count) DLP violations (limit: \(limit))")
                return results
            } catch {
                self.logger.error("CoreData fetch failed for DLP violations: \(error.localizedDescription)")
                throw DLPError.storageFailure(error.localizedDescription)
            }
        }
    }

    /// Deletes violation records whose timestamp predates the retention cutoff.
    ///
    /// Computes a cutoff date of `now - retentionDays` days and deletes all matching
    /// `DLPViolationEntity` records using a background context.
    ///
    /// - Parameter retentionDays: The number of days to retain records.
    /// - Returns: The number of records that were pruned.
    /// - Throws: `DLPError.storageFailure` if the CoreData fetch or delete fails.
    func pruneExpired(retentionDays: Int) async throws -> Int {
        guard let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -retentionDays,
            to: Date()
        ) else {
            logger.error("Failed to compute retention cutoff date for \(retentionDays) days")
            throw DLPError.storageFailure("Failed to compute retention cutoff date")
        }

        let context = persistenceController.newBackgroundContext()
        return try await context.perform {
            let request = DLPViolationEntity.retentionCleanupFetchRequest(olderThan: cutoff)
            let violations: [DLPViolationEntity]
            do {
                violations = try context.fetch(request)
            } catch {
                self.logger.error("CoreData fetch for pruneExpired failed: \(error.localizedDescription)")
                throw DLPError.storageFailure(error.localizedDescription)
            }

            guard !violations.isEmpty else {
                self.logger.debug("No DLP violations to prune (cutoff: \(cutoff))")
                return 0
            }

            for violation in violations {
                context.delete(violation)
            }

            do {
                try context.save()
                self.logger.info("Pruned \(violations.count) expired DLP violations (cutoff: \(cutoff))")
                return violations.count
            } catch {
                self.logger.error("CoreData save failed in pruneExpired: \(error.localizedDescription)")
                throw DLPError.storageFailure(error.localizedDescription)
            }
        }
    }

    // MARK: - DLPRuleStoring

    /// Fetches all stored DLP rules, sorted by creation date ascending.
    ///
    /// Uses the shared `viewContext` and `DLPRuleEntity.allRulesFetchRequest()`.
    ///
    /// - Returns: An array of `DLPRuleEntity` managed objects.
    /// - Throws: `DLPError.storageFailure` if the CoreData fetch fails.
    func loadRules() async throws -> [DLPRuleEntity] {
        let viewContext = persistenceController.container.viewContext
        return try await viewContext.perform {
            let request = DLPRuleEntity.allRulesFetchRequest()
            do {
                let results = try viewContext.fetch(request)
                self.logger.debug("Loaded \(results.count) DLP rules")
                return results
            } catch {
                self.logger.error("CoreData fetch failed for DLP rules: \(error.localizedDescription)")
                throw DLPError.storageFailure(error.localizedDescription)
            }
        }
    }

    /// Persists a new DLP rule to local CoreData storage.
    ///
    /// Uses a background context to avoid blocking the main thread.
    ///
    /// - Parameter rule: The `DLPRule` to persist.
    /// - Throws: `DLPError.storageFailure` if the CoreData save fails.
    func saveRule(_ rule: DLPRule) async throws {
        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            _ = DLPRuleEntity(context: context, rule: rule)

            do {
                try context.save()
                self.logger.debug("Saved DLP rule \(rule.id) (name: \(rule.name))")
            } catch {
                self.logger.error("CoreData save failed for DLP rule \(rule.id): \(error.localizedDescription)")
                throw DLPError.storageFailure(error.localizedDescription)
            }
        }
    }

    /// Permanently deletes the DLP rule with the given identifier.
    ///
    /// Uses a background context. Throws `DLPError.ruleNotFound` if no rule exists for the ID.
    ///
    /// - Parameter id: The UUID of the rule to delete.
    /// - Throws: `DLPError.ruleNotFound` if no rule exists with the given ID,
    ///   or `DLPError.storageFailure` if the CoreData delete fails.
    func deleteRule(id: UUID) async throws {
        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            let request = DLPRuleEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            let entities: [DLPRuleEntity]
            do {
                entities = try context.fetch(request)
            } catch {
                self.logger.error("CoreData fetch for deleteRule failed: \(error.localizedDescription)")
                throw DLPError.storageFailure(error.localizedDescription)
            }

            guard !entities.isEmpty else {
                self.logger.error("DLP rule not found for deletion: \(id)")
                throw DLPError.ruleNotFound(id)
            }

            for entity in entities {
                context.delete(entity)
            }

            do {
                try context.save()
                self.logger.info("Deleted DLP rule \(id)")
            } catch {
                self.logger.error("CoreData save failed in deleteRule for \(id): \(error.localizedDescription)")
                throw DLPError.storageFailure(error.localizedDescription)
            }
        }
    }

    /// Updates an existing DLP rule in local CoreData storage.
    ///
    /// The rule is matched by its `id`. All mutable fields are overwritten with the
    /// values from the provided `DLPRule`. Throws `DLPError.ruleNotFound` if no rule
    /// exists for the given ID.
    ///
    /// - Parameter rule: The `DLPRule` with updated field values.
    /// - Throws: `DLPError.ruleNotFound` if no matching rule is found,
    ///   or `DLPError.storageFailure` if the CoreData save fails.
    func updateRule(_ rule: DLPRule) async throws {
        let context = persistenceController.newBackgroundContext()
        try await context.perform {
            let request = DLPRuleEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", rule.id as CVarArg)

            let entities: [DLPRuleEntity]
            do {
                entities = try context.fetch(request)
            } catch {
                self.logger.error("CoreData fetch for updateRule failed: \(error.localizedDescription)")
                throw DLPError.storageFailure(error.localizedDescription)
            }

            guard let entity = entities.first else {
                self.logger.error("DLP rule not found for update: \(rule.id)")
                throw DLPError.ruleNotFound(rule.id)
            }

            entity.name = rule.name
            entity.isEnabled = rule.isEnabled
            entity.patternCategory = rule.patternCategory.rawValue
            entity.pattern = rule.pattern
            entity.severity = rule.severity.rawValue.description
            entity.updatedAt = rule.updatedAt
            entity.actionsJSON = try? JSONEncoder().encode(rule.actions.map(\.rawValue))

            do {
                try context.save()
                self.logger.debug("Updated DLP rule \(rule.id) (name: \(rule.name))")
            } catch {
                self.logger.error("CoreData save failed in updateRule for \(rule.id): \(error.localizedDescription)")
                throw DLPError.storageFailure(error.localizedDescription)
            }
        }
    }

    // MARK: Private

    // MARK: - Dependencies

    private let persistenceController: PersistenceController
    private let logger = Logger.security
}
