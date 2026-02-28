//
//  DLPProtocols.swift
//  PasteShelf
//
//  Protocol definitions for the DLP subsystem, following the AuditProtocols pattern.
//

import Foundation

// MARK: - DLPRuleEvaluating

/// Evaluates clipboard content against a set of DLP rules and returns a consolidated result.
///
/// Implementations compile each rule's regex pattern, scan the content for matches,
/// and aggregate all violations into a `DLPEvaluationResult`. The result's `shouldBlock`
/// and `shouldRedact` flags drive downstream decisions in the clipboard capture pipeline.
///
/// Evaluation is performed asynchronously to avoid blocking the main thread during
/// potentially expensive regex operations on large content payloads.
protocol DLPRuleEvaluating: Sendable {

    /// Evaluates the given clipboard content against the provided rules.
    ///
    /// Only rules with `isEnabled == true` are evaluated. Rules with invalid patterns
    /// are skipped silently; callers should validate patterns via `DLPError.invalidPattern`
    /// before adding rules to the active policy.
    ///
    /// - Parameters:
    ///   - content: The in-memory clipboard content captured from the system pasteboard.
    ///   - rules: The ordered list of active `DLPRule` values to evaluate.
    /// - Returns: A `DLPEvaluationResult` aggregating all violations and outcome flags.
    func evaluate(_ content: ClipboardContent, against rules: [DLPRule]) async -> DLPEvaluationResult
}

// MARK: - DLPViolationStoring

/// Provides CoreData-backed persistence for DLP violation records.
///
/// Implementations store violations as `DLPViolationEntity` managed objects,
/// support filtered queries for the violation log viewer, and enforce the configured
/// retention window by pruning expired records.
protocol DLPViolationStoring: Sendable {

    /// Persists a single DLP violation record to local CoreData storage.
    ///
    /// - Parameter violation: The `DLPViolation` to persist.
    /// - Throws: `DLPError.storageFailure` if the CoreData save fails.
    func save(_ violation: DLPViolation) async throws

    /// Fetches stored violation records, optionally filtered by date range.
    ///
    /// Results are returned sorted by timestamp descending (most recent first).
    ///
    /// - Parameters:
    ///   - from: If non-nil, only violations at or after this date are returned.
    ///   - to: If non-nil, only violations at or before this date are returned.
    ///   - limit: The maximum number of records to return.
    /// - Returns: An array of `DLPViolationEntity` managed objects matching the filters.
    /// - Throws: `DLPError.storageFailure` if the CoreData fetch fails.
    func fetchViolations(from: Date?, to: Date?, limit: Int) async throws -> [DLPViolationEntity]

    /// Deletes violation records whose timestamp predates the retention cutoff.
    ///
    /// - Parameter retentionDays: The number of days to retain records. Records older
    ///   than this are permanently deleted.
    /// - Returns: The number of records that were pruned.
    /// - Throws: `DLPError.storageFailure` if the CoreData delete operation fails.
    func pruneExpired(retentionDays: Int) async throws -> Int
}

// MARK: - DLPRuleStoring

/// Provides CoreData-backed persistence for DLP rule definitions.
///
/// Implementations store rules as `DLPRuleEntity` managed objects and support
/// full CRUD operations. Rules loaded from storage are used by `DLPRuleEvaluating`
/// implementations at clipboard capture time.
protocol DLPRuleStoring: Sendable {

    /// Fetches all stored DLP rules.
    ///
    /// Results are returned sorted by creation date ascending.
    ///
    /// - Returns: An array of `DLPRuleEntity` managed objects.
    /// - Throws: `DLPError.storageFailure` if the CoreData fetch fails.
    func loadRules() async throws -> [DLPRuleEntity]

    /// Persists a new DLP rule to local CoreData storage.
    ///
    /// - Parameter rule: The `DLPRule` to persist.
    /// - Throws: `DLPError.storageFailure` if the CoreData save fails.
    func saveRule(_ rule: DLPRule) async throws

    /// Permanently deletes the DLP rule with the given identifier.
    ///
    /// - Parameter id: The UUID of the rule to delete.
    /// - Throws: `DLPError.ruleNotFound` if no rule exists with the given ID,
    ///   or `DLPError.storageFailure` if the CoreData delete fails.
    func deleteRule(id: UUID) async throws

    /// Updates an existing DLP rule in local CoreData storage.
    ///
    /// The rule is matched by its `id`. The `updatedAt` timestamp should be
    /// refreshed by the caller before invoking this method.
    ///
    /// - Parameter rule: The `DLPRule` with updated field values.
    /// - Throws: `DLPError.ruleNotFound` if no matching rule is found,
    ///   or `DLPError.storageFailure` if the CoreData save fails.
    func updateRule(_ rule: DLPRule) async throws
}
