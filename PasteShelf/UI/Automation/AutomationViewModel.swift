//
//  AutomationViewModel.swift
//  PasteShelf
//
//  ViewModel for automation rules management.
//  Handles CRUD operations for automation rules.
//

import Combine
import Foundation
import os.log
import SwiftUI

// MARK: - AutomationViewModel

/// ViewModel for managing automation rules
@MainActor
final class AutomationViewModel: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(storage: AutomationRuleStorage = .shared, engine: AutomationEngine = .shared) {
        self.storage = storage
        self.engine = engine
        Task {
            await loadRules()
        }
    }

    // MARK: Internal

    // MARK: - Published Properties

    /// All automation rules
    @Published private(set) var rules: [AutomationRule] = []

    /// Currently selected rule for editing
    @Published var selectedRule: AutomationRule?

    /// Whether a rule is being edited
    @Published var isEditing = false

    /// Whether a new rule is being created
    @Published var isCreating = false

    /// Loading state
    @Published private(set) var isLoading = false

    /// Error message
    @Published var errorMessage: String?

    /// Search query for filtering rules
    @Published var searchQuery = ""

    /// Filtered rules based on search query
    var filteredRules: [AutomationRule] {
        if searchQuery.isEmpty {
            return rules
        }
        return rules.filter { rule in
            rule.name.localizedCaseInsensitiveContains(searchQuery) ||
                rule.trigger.displayName.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    /// Count of enabled rules
    var enabledRulesCount: Int {
        rules.filter(\.isEnabled).count
    }

    /// Count of disabled rules
    var disabledRulesCount: Int {
        rules.filter { !$0.isEnabled }.count
    }

    // MARK: - Public Methods

    /// Load all automation rules
    func loadRules() async {
        isLoading = true
        defer { isLoading = false }

        do {
            rules = try await storage.fetchAllRules()
            logger.info("Loaded \(rules.count) automation rules")
        } catch {
            errorMessage = "Failed to load rules: \(error.localizedDescription)"
            logger.error("Failed to load rules: \(error.localizedDescription)")
        }
    }

    /// Create a new rule
    func createRule(_ rule: AutomationRule) async {
        do {
            try await storage.createRule(rule)
            engine.invalidateRuleCache()
            await loadRules()
            logger.info("Created rule: \(rule.name)")
        } catch {
            errorMessage = "Failed to create rule: \(error.localizedDescription)"
            logger.error("Failed to create rule: \(error.localizedDescription)")
        }
    }

    /// Update an existing rule
    func updateRule(_ rule: AutomationRule) async {
        do {
            try await storage.updateRule(rule)
            engine.invalidateRuleCache()
            await loadRules()
            logger.info("Updated rule: \(rule.name)")
        } catch {
            errorMessage = "Failed to update rule: \(error.localizedDescription)"
            logger.error("Failed to update rule: \(error.localizedDescription)")
        }
    }

    /// Delete a rule
    func deleteRule(_ rule: AutomationRule) async {
        do {
            try await storage.deleteRule(id: rule.id)
            engine.invalidateRuleCache()
            await loadRules()
            logger.info("Deleted rule: \(rule.name)")
        } catch {
            errorMessage = "Failed to delete rule: \(error.localizedDescription)"
            logger.error("Failed to delete rule: \(error.localizedDescription)")
        }
    }

    /// Delete multiple rules
    func deleteRules(_ rules: [AutomationRule]) async {
        for rule in rules {
            await deleteRule(rule)
        }
    }

    /// Toggle rule enabled state
    func toggleRule(_ rule: AutomationRule) async {
        do {
            try await storage.toggleRule(id: rule.id)
            engine.invalidateRuleCache()
            await loadRules()
            logger.info("Toggled rule: \(rule.name) -> \(!rule.isEnabled)")
        } catch {
            errorMessage = "Failed to toggle rule: \(error.localizedDescription)"
            logger.error("Failed to toggle rule: \(error.localizedDescription)")
        }
    }

    /// Move a rule to a new position (reorder)
    func moveRule(from source: IndexSet, to destination: Int) async {
        var reorderedRules = rules
        reorderedRules.move(fromOffsets: source, toOffset: destination)

        // Update priorities based on new order
        for (index, rule) in reorderedRules.enumerated() {
            do {
                try await storage.updatePriority(id: rule.id, priority: Int32(index * 10))
            } catch {
                logger.error("Failed to update rule priority: \(error.localizedDescription)")
            }
        }

        await loadRules()
    }

    /// Duplicate a rule
    func duplicateRule(_ rule: AutomationRule) async {
        let duplicatedRule = AutomationRule(
            id: UUID(),
            name: "\(rule.name) (Copy)",
            isEnabled: false,
            trigger: rule.trigger,
            conditions: rule.conditions,
            actions: rule.actions,
            priority: Int32(rules.count * 10)
        )

        await createRule(duplicatedRule)
    }

    /// Start editing a rule
    func startEditing(_ rule: AutomationRule) {
        selectedRule = rule
        isEditing = true
        isCreating = false
    }

    /// Start creating a new rule
    func startCreating() {
        selectedRule = AutomationRule.empty()
        isEditing = true
        isCreating = true
    }

    /// Cancel editing
    func cancelEditing() {
        selectedRule = nil
        isEditing = false
        isCreating = false
    }

    /// Save the current rule being edited
    func saveCurrentRule() async {
        guard let rule = selectedRule else {
            return
        }

        if isCreating {
            await createRule(rule)
        } else {
            await updateRule(rule)
        }

        cancelEditing()
    }

    /// Clear error message
    func clearError() {
        errorMessage = nil
    }

    // MARK: Private

    // MARK: - Private Properties

    private let storage: AutomationRuleStorage
    private let engine: AutomationEngine
    private var cancellables = Set<AnyCancellable>()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "automation-vm"
    )
}

// MARK: - AutomationRule Extension

extension AutomationRule {
    /// Create an empty rule for new rule creation
    static func empty() -> AutomationRule {
        AutomationRule(
            id: UUID(),
            name: "New Rule",
            isEnabled: true,
            trigger: .onCapture,
            conditions: CollectionRules(),
            actions: [],
            priority: 100
        )
    }
}
