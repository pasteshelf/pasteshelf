//
//  DLPManager.swift
//  PasteShelf
//
//  @MainActor singleton orchestrator for the Enterprise DLP subsystem.
//  Coordinates DLPRuleEngine, DLPViolationStorageService, and audit integration.
//

import Combine
import Foundation
import os.log

// MARK: - DLP Notification Names

extension Notification.Name {

    /// Posted when a DLP violation is detected during clipboard content evaluation.
    ///
    /// The notification's `userInfo` dictionary contains:
    /// - `"violation"`: The `DLPViolation` that was detected.
    /// - `"result"`: The `DLPEvaluationResult` from the evaluation pass.
    static let dlpViolationDetected = Notification.Name("com.pasteshelf.dlpViolationDetected")
}

// MARK: - DLPManager

/// Central manager for the Enterprise Data Loss Prevention subsystem.
///
/// `DLPManager` orchestrates all DLP-related services — rule evaluation, violation storage,
/// rule persistence, and audit logging — behind a single entry point. It follows the same
/// `@MainActor` singleton pattern as `AuditManager`.
///
/// The manager exposes a `evaluate(_:)` method that the clipboard capture pipeline calls
/// before storing content. The evaluation result determines whether the content is blocked,
/// redacted, or stored as-is.
///
/// All public methods check feature availability and return safe defaults when
/// the feature is unavailable.
@MainActor
final class DLPManager: ObservableObject {

    // MARK: - Singleton

    /// The shared application-wide `DLPManager` instance.
    static let shared = DLPManager()

    // MARK: - Published State

    /// Whether the DLP subsystem has been configured and is active.
    @Published private(set) var isEnabled: Bool = false

    /// The current set of DLP rules loaded from storage.
    @Published private(set) var rules: [DLPRule] = []

    /// The most recent violations, capped at a display-friendly count.
    @Published private(set) var recentViolations: [DLPViolation] = []

    /// The most recent error encountered by the DLP subsystem, if any.
    @Published var lastError: DLPError?

    // MARK: - Dependencies

    private var ruleEngine: DLPRuleEvaluating?
    private var storageService: DLPViolationStorageService?

    private let logger = Logger.security

    /// The maximum number of recent violations to keep in memory for the UI.
    private let recentViolationsLimit = 50

    // MARK: - Initialization

    /// Private initializer for the shared singleton.
    private init() {}

    /// Designated initializer for dependency injection in tests.
    ///
    /// - Parameters:
    ///   - ruleEngine: The engine that evaluates clipboard content against rules.
    ///   - storageService: The CoreData storage backend for rules and violations.
    init(
        ruleEngine: DLPRuleEvaluating,
        storageService: DLPViolationStorageService
    ) {
        self.ruleEngine = ruleEngine
        self.storageService = storageService
    }

    // MARK: - Configuration

    /// Configures the DLP manager with production dependencies and activates the subsystem.
    ///
    /// Call this from the application lifecycle during startup.
    /// The method loads rules from storage and enables DLP evaluation.
    func configure() {
        let storage = DLPViolationStorageService()
        self.storageService = storage

        let engine = DLPRuleEngine()
        self.ruleEngine = engine

        isEnabled = true
        logger.info("DLPManager configured and enabled")

        // Load rules asynchronously
        Task {
            await loadRules()
            await loadRecentViolations()
        }
    }

    /// Disables the DLP subsystem and tears down the rule engine.
    ///
    /// Call this when the MDM profile sets `dlpEnabled` to `false` mid-session.
    func disable() {
        isEnabled = false
        ruleEngine = nil
        logger.info("DLPManager disabled")
    }

    // MARK: - Evaluation

    /// Evaluates clipboard content against the active DLP rules.
    ///
    /// This is the primary entry point called by the clipboard capture pipeline.
    /// If any rule matches, violations are recorded and the result indicates whether
    /// to block or redact the content.
    ///
    /// Returns `.clean` if DLP is disabled or the feature is unavailable.
    ///
    /// - Parameter content: The clipboard content to evaluate.
    /// - Returns: A `DLPEvaluationResult` with violations and outcome flags.
    func evaluate(_ content: ClipboardContent) async -> DLPEvaluationResult {
        guard isEnabled, let engine = ruleEngine else {
            return .clean
        }

        let activeRules = rules.filter(\.isEnabled)
        guard !activeRules.isEmpty else {
            return .clean
        }

        let result = await engine.evaluate(content, against: activeRules)

        if result.hasViolations {
            // Persist violations and log audit events
            await recordViolations(result.violations)

            // Post notification for alert UI
            for violation in result.violations where violation.actionTaken == .alert || violation.actionTaken == .block {
                NotificationCenter.default.post(
                    name: .dlpViolationDetected,
                    object: self,
                    userInfo: [
                        "violation": violation,
                        "result": result
                    ]
                )
            }
        }

        return result
    }

    // MARK: - Rule Management

    /// Loads all DLP rules from CoreData storage.
    ///
    /// Updates the published `rules` array. Errors are captured in `lastError`.
    func loadRules() async {
        guard let storage = storageService else { return }

        do {
            let entities = try await storage.loadRules()
            rules = entities.compactMap { $0.toDomainModel() }
            logger.debug("Loaded \(self.rules.count) DLP rules from storage")
        } catch {
            logger.error("Failed to load DLP rules: \(error.localizedDescription)")
            lastError = .storageFailure(error.localizedDescription)
        }
    }

    /// Adds a new DLP rule to storage and refreshes the in-memory rule set.
    ///
    /// - Parameter rule: The `DLPRule` to add.
    /// - Throws: `DLPError.storageFailure` if the save fails.
    func addRule(_ rule: DLPRule) async throws {
        guard let storage = storageService else {
            throw DLPError.featureUnavailable
        }

        try await storage.saveRule(rule)
        await loadRules()

        // Log rule creation as audit event
        await AuditManager.shared.logPolicyEvent(
            action: .policyApplied,
            policyId: rule.id.uuidString,
            detail: ["dlpAction": "ruleCreated", "ruleName": rule.name]
        )

        logger.info("Added DLP rule: \(rule.name)")
    }

    /// Updates an existing DLP rule in storage and refreshes the in-memory rule set.
    ///
    /// - Parameter rule: The `DLPRule` with updated values.
    /// - Throws: `DLPError.ruleNotFound` or `DLPError.storageFailure`.
    func updateRule(_ rule: DLPRule) async throws {
        guard let storage = storageService else {
            throw DLPError.featureUnavailable
        }

        try await storage.updateRule(rule)
        await loadRules()

        logger.info("Updated DLP rule: \(rule.name)")
    }

    /// Deletes a DLP rule from storage and refreshes the in-memory rule set.
    ///
    /// - Parameter id: The UUID of the rule to delete.
    /// - Throws: `DLPError.ruleNotFound` or `DLPError.storageFailure`.
    func deleteRule(id: UUID) async throws {
        guard let storage = storageService else {
            throw DLPError.featureUnavailable
        }

        try await storage.deleteRule(id: id)
        await loadRules()

        // Log rule deletion as audit event
        await AuditManager.shared.logPolicyEvent(
            action: .policyApplied,
            policyId: id.uuidString,
            detail: ["dlpAction": "ruleDeleted"]
        )

        logger.info("Deleted DLP rule: \(id)")
    }

    /// Installs the default DLP rules into storage if no rules exist yet.
    ///
    /// This is called during first-time setup to populate the rule store with
    /// sensible defaults derived from `DLPDefaultPatterns`.
    func installDefaultRulesIfNeeded() async {
        guard rules.isEmpty, let storage = storageService else { return }

        let defaults = DLPDefaultPatterns.allDefaultRules()
        for rule in defaults {
            do {
                try await storage.saveRule(rule)
            } catch {
                logger.error("Failed to install default DLP rule '\(rule.name)': \(error.localizedDescription)")
            }
        }

        await loadRules()
        logger.info("Installed \(defaults.count) default DLP rules")
    }

    /// Applies a server-pushed DLP policy, replacing local rules with admin-managed rules.
    ///
    /// Existing admin-managed rules are replaced. User-created rules are preserved.
    ///
    /// - Parameter policy: The `DLPPolicy` received from the admin console.
    func applyPolicy(_ policy: DLPPolicy) async {
        guard let storage = storageService else { return }

        // Save each rule from the policy
        for rule in policy.rules {
            do {
                try await storage.saveRule(rule)
            } catch {
                logger.error("Failed to apply DLP policy rule '\(rule.name)': \(error.localizedDescription)")
            }
        }

        await loadRules()

        await AuditManager.shared.logPolicyEvent(
            action: .policyApplied,
            detail: [
                "dlpAction": "policyApplied",
                "ruleCount": "\(policy.rules.count)",
                "enforced": "\(policy.enforced)"
            ]
        )

        logger.info("Applied DLP policy with \(policy.rules.count) rules")
    }

    // MARK: - Violation Access

    /// Loads the most recent violations from storage for display in the UI.
    func loadRecentViolations() async {
        guard let storage = storageService else { return }

        do {
            let entities = try await storage.fetchViolations(
                from: nil,
                to: nil,
                limit: recentViolationsLimit
            )
            recentViolations = entities.compactMap { $0.toDomainModel() }
            logger.debug("Loaded \(self.recentViolations.count) recent DLP violations")
        } catch {
            logger.error("Failed to load DLP violations: \(error.localizedDescription)")
            lastError = .storageFailure(error.localizedDescription)
        }
    }

    /// Fetches violations within a date range for reporting.
    ///
    /// - Parameters:
    ///   - from: Start date filter, or `nil` for no lower bound.
    ///   - to: End date filter, or `nil` for no upper bound.
    ///   - limit: Maximum number of violations to return.
    /// - Returns: An array of `DLPViolation` domain models.
    func fetchViolations(
        from: Date? = nil,
        to: Date? = nil,
        limit: Int = 100
    ) async throws -> [DLPViolation] {
        guard let storage = storageService else {
            throw DLPError.featureUnavailable
        }

        let entities = try await storage.fetchViolations(from: from, to: to, limit: limit)
        return entities.compactMap { $0.toDomainModel() }
    }

    /// Prunes violation records older than the specified retention period.
    ///
    /// - Parameter retentionDays: Number of days to retain violations.
    /// - Returns: The number of violations pruned.
    @discardableResult
    func pruneExpiredViolations(retentionDays: Int = 90) async throws -> Int {
        guard let storage = storageService else {
            throw DLPError.featureUnavailable
        }

        let count = try await storage.pruneExpired(retentionDays: retentionDays)
        if count > 0 {
            await loadRecentViolations()
            logger.info("Pruned \(count) expired DLP violations")
        }
        return count
    }

    // MARK: - Storage Access

    /// The `DLPViolationStoring` backend, exposed for direct access if needed.
    ///
    /// `nil` until `configure()` has been called.
    var violationStorage: DLPViolationStoring? {
        storageService
    }

    /// The `DLPRuleStoring` backend, exposed for direct access if needed.
    ///
    /// `nil` until `configure()` has been called.
    var ruleStorage: DLPRuleStoring? {
        storageService
    }

    // MARK: - Private Helpers

    /// Persists violations and logs them as audit events.
    private func recordViolations(_ violations: [DLPViolation]) async {
        guard let storage = storageService else { return }

        for violation in violations {
            // Persist to CoreData
            do {
                try await storage.save(violation)
            } catch {
                logger.error("Failed to save DLP violation: \(error.localizedDescription)")
            }

            // Log as audit event
            let severity: AuditEventSeverity = violation.wasBlocked ? .critical : .warning
            await AuditManager.shared.logPolicyEvent(
                action: .policyViolation,
                policyId: violation.ruleId.uuidString,
                detail: [
                    "ruleName": violation.ruleName,
                    "actionTaken": violation.actionTaken.rawValue,
                    "wasBlocked": "\(violation.wasBlocked)",
                    "dlpViolation": "true"
                ]
            )
        }

        // Refresh the in-memory list
        await loadRecentViolations()
    }
}
