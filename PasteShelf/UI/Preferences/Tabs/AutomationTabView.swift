//
//  AutomationTabView.swift
//  PasteShelf
//
//  Preferences tab for managing automation rules.
//  Provides a list view of rules with add, edit, delete actions.
//

import SwiftUI

// MARK: - AutomationTabView

/// Automation preferences tab view
struct AutomationTabView: View {
    // MARK: Internal

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            self.headerView

            // Rules list
            self.rulesListView
        }
        .padding()
        .sheet(isPresented: self.$showingRuleEditor) {
            RuleEditorView(
                viewModel: self.viewModel,
                isPresented: self.$showingRuleEditor
            )
        }
        .alert("Delete Rule", isPresented: self.$showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let rule = ruleToDelete {
                    Task {
                        await self.viewModel.deleteRule(rule)
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this rule? This action cannot be undone.")
        }
        .alert("Error", isPresented: .init(
            get: { self.viewModel.errorMessage != nil },
            set: { if !$0 {
                self.viewModel.clearError()
            }
            }
        )) {
            Button("OK") { self.viewModel.clearError() }
        } message: {
            Text(self.viewModel.errorMessage ?? "")
        }
    }

    // MARK: Private

    @StateObject private var viewModel = AutomationViewModel()
    @State private var showingRuleEditor = false
    @State private var showingDeleteConfirmation = false
    @State private var ruleToDelete: AutomationRule?

    // MARK: - Subviews

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Automation Rules")
                .font(.headline)

            Text("Create rules to automatically process clipboard items when they are captured or pasted.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Text("\(self.viewModel.enabledRulesCount) active")
                    .foregroundColor(.green)

                if self.viewModel.disabledRulesCount > 0 {
                    Text("\(self.viewModel.disabledRulesCount) disabled")
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    self.viewModel.startCreating()
                    self.showingRuleEditor = true
                } label: {
                    Label("Add Rule", systemImage: "plus")
                }
            }
            .padding(.top, 4)
        }
    }

    private var rulesListView: some View {
        VStack(spacing: 8) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search rules...", text: self.$viewModel.searchQuery)
                    .textFieldStyle(.plain)

                if !self.viewModel.searchQuery.isEmpty {
                    Button {
                        self.viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            // Rules list
            if self.viewModel.filteredRules.isEmpty {
                self.emptyStateView
            } else {
                List {
                    ForEach(self.viewModel.filteredRules) { rule in
                        RuleRowView(
                            rule: rule,
                            onToggle: {
                                Task {
                                    await self.viewModel.toggleRule(rule)
                                }
                            },
                            onEdit: {
                                self.viewModel.startEditing(rule)
                                self.showingRuleEditor = true
                            },
                            onDuplicate: {
                                Task {
                                    await self.viewModel.duplicateRule(rule)
                                }
                            },
                            onDelete: {
                                self.ruleToDelete = rule
                                self.showingDeleteConfirmation = true
                            }
                        )
                    }
                    .onMove { source, destination in
                        Task {
                            await self.viewModel.moveRule(from: source, to: destination)
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 36))
                .foregroundColor(.secondary)

            if self.viewModel.searchQuery.isEmpty {
                Text("No Rules Yet")
                    .font(.headline)

                Text("Create your first automation rule to get started.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button("Create Rule") {
                    self.viewModel.startCreating()
                    self.showingRuleEditor = true
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("No Matching Rules")
                    .font(.headline)

                Text("No rules match your search.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - RuleRowView

struct RuleRowView: View {
    let rule: AutomationRule
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Enable/disable toggle
            Toggle("", isOn: .init(
                get: { self.rule.isEnabled },
                set: { _ in self.onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            // Rule info
            VStack(alignment: .leading, spacing: 2) {
                Text(self.rule.name)
                    .font(.body)
                    .foregroundColor(self.rule.isEnabled ? .primary : .secondary)

                HStack(spacing: 8) {
                    // Trigger badge
                    Label(self.rule.trigger.displayName, systemImage: self.rule.trigger.iconName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Actions count
                    Text("\(self.rule.actions.count) action\(self.rule.actions.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Execution count
                    if self.rule.executionCount > 0 {
                        Text("Run \(self.rule.executionCount)x")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Context menu button
            Menu {
                Button {
                    self.onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button {
                    self.onDuplicate()
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }

                Divider()

                Button(role: .destructive) {
                    self.onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            self.onEdit()
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct AutomationTabView_Previews: PreviewProvider {
        static var previews: some View {
            AutomationTabView()
                .frame(width: 500, height: 400)
        }
    }
#endif
