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
            await self.loadRules()
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
        if self.searchQuery.isEmpty {
            return self.rules
        }
        return self.rules.filter { rule in
            rule.name.localizedCaseInsensitiveContains(self.searchQuery) ||
                rule.trigger.displayName.localizedCaseInsensitiveContains(self.searchQuery)
        }
    }

    /// Count of enabled rules
    var enabledRulesCount: Int {
        self.rules.filter(\.isEnabled).count
    }

    /// Count of disabled rules
    var disabledRulesCount: Int {
        self.rules.filter { !$0.isEnabled }.count
    }

    // MARK: - Public Methods

    /// Load all automation rules
    func loadRules() async {
        self.isLoading = true
        defer { isLoading = false }

        do {
            self.rules = try await self.storage.fetchAllRules()
            self.logger.info("Loaded \(self.rules.count) automation rules")
        } catch {
            self.errorMessage = "Failed to load rules: \(error.localizedDescription)"
            self.logger.error("Failed to load rules: \(error.localizedDescription)")
        }
    }

    /// Create a new rule
    func createRule(_ rule: AutomationRule) async {
        do {
            try await self.storage.createRule(rule)
            self.engine.invalidateRuleCache()
            await self.loadRules()
            self.logger.info("Created rule: \(rule.name)")
        } catch {
            self.errorMessage = "Failed to create rule: \(error.localizedDescription)"
            self.logger.error("Failed to create rule: \(error.localizedDescription)")
        }
    }

    /// Update an existing rule
    func updateRule(_ rule: AutomationRule) async {
        do {
            try await self.storage.updateRule(rule)
            self.engine.invalidateRuleCache()
            await self.loadRules()
            self.logger.info("Updated rule: \(rule.name)")
        } catch {
            self.errorMessage = "Failed to update rule: \(error.localizedDescription)"
            self.logger.error("Failed to update rule: \(error.localizedDescription)")
        }
    }

    /// Delete a rule
    func deleteRule(_ rule: AutomationRule) async {
        do {
            try await self.storage.deleteRule(id: rule.id)
            self.engine.invalidateRuleCache()
            await self.loadRules()
            self.logger.info("Deleted rule: \(rule.name)")
        } catch {
            self.errorMessage = "Failed to delete rule: \(error.localizedDescription)"
            self.logger.error("Failed to delete rule: \(error.localizedDescription)")
        }
    }

    /// Delete multiple rules
    func deleteRules(_ rules: [AutomationRule]) async {
        for rule in rules {
            await self.deleteRule(rule)
        }
    }

    /// Toggle rule enabled state
    func toggleRule(_ rule: AutomationRule) async {
        do {
            try await self.storage.toggleRule(id: rule.id)
            self.engine.invalidateRuleCache()
            await self.loadRules()
            self.logger.info("Toggled rule: \(rule.name) -> \(!rule.isEnabled)")
        } catch {
            self.errorMessage = "Failed to toggle rule: \(error.localizedDescription)"
            self.logger.error("Failed to toggle rule: \(error.localizedDescription)")
        }
    }

    /// Move a rule to a new position (reorder)
    func moveRule(from source: IndexSet, to destination: Int) async {
        var reorderedRules = self.rules
        reorderedRules.move(fromOffsets: source, toOffset: destination)

        // Update priorities based on new order
        for (index, rule) in reorderedRules.enumerated() {
            do {
                try await self.storage.updatePriority(id: rule.id, priority: Int32(index * 10))
            } catch {
                self.logger.error("Failed to update rule priority: \(error.localizedDescription)")
            }
        }

        await self.loadRules()
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
            priority: Int32(self.rules.count * 10)
        )

        await self.createRule(duplicatedRule)
    }

    /// Start editing a rule
    func startEditing(_ rule: AutomationRule) {
        self.selectedRule = rule
        self.isEditing = true
        self.isCreating = false
    }

    /// Start creating a new rule
    func startCreating() {
        self.selectedRule = AutomationRule.empty()
        self.isEditing = true
        self.isCreating = true
    }

    /// Cancel editing
    func cancelEditing() {
        self.selectedRule = nil
        self.isEditing = false
        self.isCreating = false
    }

    /// Save the current rule being edited
    func saveCurrentRule() async {
        guard let rule = selectedRule else {
            return
        }

        if self.isCreating {
            await self.createRule(rule)
        } else {
            await self.updateRule(rule)
        }

        self.cancelEditing()
    }

    /// Clear error message
    func clearError() {
        self.errorMessage = nil
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
