//
//  AutomationEngine.swift
//  PasteShelf
//
//  Core engine for evaluating and executing automation rules.
//  Integrates with ClipboardMonitor to process captured content.
//

import CoreData
import Foundation
import os.log

// MARK: - AutomationResult

/// Result of automation rule evaluation and execution
struct AutomationResult: Sendable {
    /// The original content (before any transformations)
    let originalContent: ClipboardContent

    /// The transformed content (after all rule actions applied)
    var transformedContent: ClipboardContent

    /// Rules that were evaluated
    let evaluatedRules: [AutomationRule]

    /// Rules that matched and were executed
    let matchedRules: [AutomationRule]

    /// Actions that were executed
    let executedActions: [AutomationAction]

    /// Whether the item should be deleted (not stored)
    var shouldDelete: Bool

    /// Any errors that occurred during execution
    var errors: [AutomationError]
}

// MARK: - AutomationError

/// Errors that can occur during automation execution
enum AutomationError: Error, Sendable {
    case ruleEvaluationFailed(ruleName: String, reason: String)
    case actionExecutionFailed(actionType: String, reason: String)
    case webhookFailed(url: String, statusCode: Int?)
    case scriptExecutionFailed(path: String, reason: String)
    case invalidConfiguration(reason: String)
}

// MARK: - AutomationEngine

/// Main automation engine that evaluates and executes rules
@MainActor
final class AutomationEngine {
    // MARK: Lifecycle

    // MARK: - Initialization

    private init() {
        logger.info("AutomationEngine initialized")
    }

    // MARK: Internal

    // MARK: - Singleton

    static let shared = AutomationEngine()

    // MARK: - Rule Evaluation

    /// Evaluates all enabled rules for the given content and trigger
    /// - Parameters:
    ///   - content: The clipboard content to evaluate
    ///   - trigger: The trigger that initiated this evaluation
    ///   - sourceApp: The source application (optional)
    /// - Returns: AutomationResult with transformed content and execution details
    func evaluateRules(
        for content: ClipboardContent,
        trigger: AutomationTrigger,
        sourceApp: SourceApp? = nil
    ) async -> AutomationResult {
        logger.debug("Evaluating rules for trigger: \(trigger.displayName)")

        // Fetch enabled rules for this trigger
        let rules = await fetchEnabledRules(for: trigger)
        logger.debug("Found \(rules.count) rules for trigger \(trigger.rawType)")

        var transformedContent = content
        var matchedRules: [AutomationRule] = []
        var executedActions: [AutomationAction] = []
        var shouldDelete = false
        var errors: [AutomationError] = []

        // Evaluate each rule in priority order
        for rule in rules {
            do {
                let matches = evaluateConditions(rule: rule, content: transformedContent, sourceApp: sourceApp)

                if matches {
                    logger.info("Rule '\(rule.name)' matched")
                    matchedRules.append(rule)

                    // Execute all actions for this rule
                    for action in rule.actions {
                        do {
                            let result = try await actionExecutor.execute(
                                action: action,
                                content: transformedContent,
                                rule: rule
                            )

                            transformedContent = result.content
                            executedActions.append(action)

                            if result.shouldDelete {
                                shouldDelete = true
                            }

                            // Record successful execution
                            await recordRuleExecution(rule)

                        } catch let error as AutomationError {
                            logger.error("Action failed: \(error.localizedDescription)")
                            errors.append(error)
                        } catch {
                            logger.error("Unexpected action error: \(error.localizedDescription)")
                            errors.append(.actionExecutionFailed(
                                actionType: action.actionType.rawValue,
                                reason: error.localizedDescription
                            ))
                        }
                    }
                }
            } catch {
                logger.error("Rule evaluation failed for '\(rule.name)': \(error.localizedDescription)")
                errors.append(.ruleEvaluationFailed(
                    ruleName: rule.name,
                    reason: error.localizedDescription
                ))
            }
        }

        logger.debug("""
        Automation complete: \(matchedRules.count) rules matched, \
        \(executedActions.count) actions executed, \
        \(errors.count) errors
        """)

        return AutomationResult(
            originalContent: content,
            transformedContent: transformedContent,
            evaluatedRules: rules,
            matchedRules: matchedRules,
            executedActions: executedActions,
            shouldDelete: shouldDelete,
            errors: errors
        )
    }

    /// Evaluates a single rule manually (for testing or manual triggers)
    /// - Parameters:
    ///   - rule: The rule to evaluate
    ///   - content: The content to evaluate against
    /// - Returns: True if the rule's conditions match
    func evaluateRule(_ rule: AutomationRule, against content: ClipboardContent) -> Bool {
        // Create a temporary ClipboardItem-like structure for RuleEvaluator
        // Since we're working with ClipboardContent directly, we need to adapt
        evaluateConditions(rule: rule, content: content, sourceApp: content.sourceApp)
    }

    /// Invalidates the rule cache (call when rules are modified)
    func invalidateRuleCache() {
        cachedRules = []
        lastRuleRefresh = .distantPast
        logger.debug("Rule cache invalidated")
    }

    // MARK: Private

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "automation"
    )

    private let storageManager = StorageManager.shared

    /// Cache of enabled rules (refreshed on rule changes)
    private var cachedRules: [AutomationRule] = []
    private var lastRuleRefresh: Date = .distantPast
    private let ruleCacheTTL: TimeInterval = 60 // 1 minute

    /// Action executor for running actions
    private lazy var actionExecutor = ActionExecutor()

    // MARK: - Condition Evaluation

    /// Evaluates whether a rule's conditions match the content
    private func evaluateConditions(
        rule: AutomationRule,
        content: ClipboardContent,
        sourceApp: SourceApp?
    ) -> Bool {
        // If no conditions, rule always matches
        guard !rule.conditions.isEmpty else {
            return true
        }

        // Evaluate each condition
        let results = rule.conditions.conditions.map { condition in
            evaluateSingleCondition(condition, content: content, sourceApp: sourceApp)
        }

        // Apply logical operator
        switch rule.conditions.logicalOperator {
        case .and:
            return results.allSatisfy { $0 }
        case .or:
            return results.contains { $0 }
        }
    }

    /// Evaluates a single condition against content
    private func evaluateSingleCondition(
        _ condition: RuleCondition,
        content: ClipboardContent,
        sourceApp: SourceApp?
    ) -> Bool {
        switch condition.field {
        case .contentType:
            evaluateContentTypeCondition(condition, content: content)
        case .sourceApp:
            evaluateSourceAppCondition(condition, sourceApp: sourceApp)
        case .textContent:
            evaluateTextContentCondition(condition, content: content)
        case .dateCreated:
            evaluateDateCondition(condition, content: content)
        case .isFavorite:
            // ClipboardContent doesn't have isFavorite, assume false for new content
            evaluateBooleanCondition(condition, value: false)
        case .isSensitive:
            evaluateBooleanCondition(condition, value: content.isSensitive)
        }
    }

    private func evaluateContentTypeCondition(
        _ condition: RuleCondition,
        content: ClipboardContent
    ) -> Bool {
        let contentTypeRaw = content.primaryType.rawValue

        let targetTypes: Set<String> = if let contentTypeValue = ContentTypeValue(rawValue: condition.value) {
            Set(contentTypeValue.contentTypeRawValues)
        } else {
            [condition.value]
        }

        switch condition.comparisonOperator {
        case .equals:
            return targetTypes.contains(contentTypeRaw)
        case .notEquals:
            return !targetTypes.contains(contentTypeRaw)
        default:
            return false
        }
    }

    private func evaluateSourceAppCondition(
        _ condition: RuleCondition,
        sourceApp: SourceApp?
    ) -> Bool {
        let bundleId = sourceApp?.bundleId.lowercased() ?? ""
        let appName = sourceApp?.name.lowercased() ?? ""
        let value = condition.value.lowercased()

        switch condition.comparisonOperator {
        case .equals:
            return bundleId == value || appName == value
        case .notEquals:
            return bundleId != value && appName != value
        case .contains:
            return bundleId.contains(value) || appName.contains(value)
        case .notContains:
            return !bundleId.contains(value) && !appName.contains(value)
        default:
            return false
        }
    }

    private func evaluateTextContentCondition(
        _ condition: RuleCondition,
        content: ClipboardContent
    ) -> Bool {
        guard let text = content.plainText else {
            return false
        }
        let value = condition.value

        switch condition.comparisonOperator {
        case .contains:
            return text.localizedCaseInsensitiveContains(value)
        case .notContains:
            return !text.localizedCaseInsensitiveContains(value)
        case .equals:
            return text.lowercased() == value.lowercased()
        case .notEquals:
            return text.lowercased() != value.lowercased()
        case .matches:
            guard let regex = try? NSRegularExpression(pattern: value) else {
                return false
            }
            let range = NSRange(text.startIndex..., in: text)
            return regex.firstMatch(in: text, range: range) != nil
        default:
            return false
        }
    }

    private func evaluateDateCondition(
        _ condition: RuleCondition,
        content: ClipboardContent
    ) -> Bool {
        let timestamp = content.timestamp

        switch condition.comparisonOperator {
        case .withinLast:
            if let rangeValue = DateRangeValue(rawValue: condition.value) {
                return timestamp >= rangeValue.startDate
            }
            // Try parsing custom duration (e.g., "7d", "24h")
            if let startDate = parseCustomDuration(condition.value) {
                return timestamp >= startDate
            }
            return false

        case .before:
            if let date = parseDate(condition.value) {
                return timestamp < date
            }
            return false

        case .after:
            if let date = parseDate(condition.value) {
                return timestamp > date
            }
            return false

        default:
            return false
        }
    }

    private func evaluateBooleanCondition(_ condition: RuleCondition, value: Bool) -> Bool {
        let targetValue: Bool
        switch condition.value.lowercased() {
        case "true",
             "yes",
             "1":
            targetValue = true
        case "false",
             "no",
             "0":
            targetValue = false
        default:
            return false
        }

        switch condition.comparisonOperator {
        case .equals:
            return value == targetValue
        case .notEquals:
            return value != targetValue
        default:
            return false
        }
    }

    // MARK: - Rule Fetching

    /// Fetches enabled rules for the given trigger type
    private func fetchEnabledRules(for trigger: AutomationTrigger) async -> [AutomationRule] {
        // Check cache first
        if Date().timeIntervalSince(lastRuleRefresh) < ruleCacheTTL, !cachedRules.isEmpty {
            return cachedRules.filter { $0.trigger == trigger }
        }

        // Fetch from storage
        let rules = await fetchRulesFromStorage()
        cachedRules = rules
        lastRuleRefresh = Date()

        return rules.filter { $0.trigger == trigger && $0.isEnabled }
    }

    /// Fetches all automation rules from CoreData
    private func fetchRulesFromStorage() async -> [AutomationRule] {
        let context = storageManager.viewContext
        let fetchRequest = AutomationRuleEntity.enabledRulesFetchRequest()

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.compactMap { $0.toAutomationRule() }
        } catch {
            logger.error("Failed to fetch automation rules: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Execution Recording

    /// Records that a rule was executed
    private func recordRuleExecution(_ rule: AutomationRule) async {
        let context = storageManager.newBackgroundContext()

        await context.perform {
            let fetchRequest = AutomationRuleEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", rule.id as CVarArg)

            do {
                if let entity = try context.fetch(fetchRequest).first {
                    entity.lastExecutedAt = Date()
                    entity.executionCount += 1
                    try context.save()
                }
            } catch {
                self.logger.error("Failed to record rule execution: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Date Parsing Helpers

    private func parseCustomDuration(_ value: String) -> Date? {
        let pattern = #"^(\d+)([hdwm])$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let numberRange = Range(match.range(at: 1), in: value),
              let unitRange = Range(match.range(at: 2), in: value),
              let number = Int(value[numberRange])
        else {
            return nil
        }

        let unit = String(value[unitRange]).lowercased()
        let calendar = Calendar.current

        switch unit {
        case "h":
            return calendar.date(byAdding: .hour, value: -number, to: Date())
        case "d":
            return calendar.date(byAdding: .day, value: -number, to: Date())
        case "w":
            return calendar.date(byAdding: .weekOfYear, value: -number, to: Date())
        case "m":
            return calendar.date(byAdding: .month, value: -number, to: Date())
        default:
            return nil
        }
    }

    private func parseDate(_ value: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: value) {
            return date
        }

        let dateFormatter = DateFormatter()
        let formats = ["yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss", "MM/dd/yyyy"]
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: value) {
                return date
            }
        }

        return nil
    }
}

// MARK: - ActionExecutionResult

/// Result of executing a single automation action
struct ActionExecutionResult {
    /// The content after the action was applied
    var content: ClipboardContent

    /// Whether the item should be deleted
    var shouldDelete: Bool = false
}
