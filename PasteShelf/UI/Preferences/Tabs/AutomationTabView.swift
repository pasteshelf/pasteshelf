//
//  AutomationTabView.swift
//  PasteShelf
//
//  Preferences tab for managing automation rules.
//  Provides a list view of rules with add, edit, delete actions.
//

import SwiftUI

/// Automation preferences tab view
struct AutomationTabView: View {
    // MARK: - Properties

    @StateObject private var viewModel = AutomationViewModel()
    @State private var showingRuleEditor = false
    @State private var showingDeleteConfirmation = false
    @State private var ruleToDelete: AutomationRule?

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            headerView

            // Feature gate check
            if !viewModel.isFeatureAvailable {
                featureUnavailableView
            } else {
                // Rules list
                rulesListView
            }
        }
        .padding()
        .sheet(isPresented: $showingRuleEditor) {
            RuleEditorView(
                viewModel: viewModel,
                isPresented: $showingRuleEditor
            )
        }
        .alert("Delete Rule", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let rule = ruleToDelete {
                    Task {
                        await viewModel.deleteRule(rule)
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this rule? This action cannot be undone.")
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Automation Rules")
                .font(.headline)

            Text("Create rules to automatically process clipboard items when they are captured or pasted.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Text("\(viewModel.enabledRulesCount) active")
                    .foregroundColor(.green)

                if viewModel.disabledRulesCount > 0 {
                    Text("\(viewModel.disabledRulesCount) disabled")
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    viewModel.startCreating()
                    showingRuleEditor = true
                } label: {
                    Label("Add Rule", systemImage: "plus")
                }
                .disabled(!viewModel.isFeatureAvailable)
            }
            .padding(.top, 4)
        }
    }

    private var featureUnavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Automation Requires Pro")
                .font(.headline)

            Text("Upgrade to PasteShelf Pro to create automation rules that automatically process your clipboard items.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Upgrade to Pro") {
                // Open license tab or purchase flow
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenLicenseTab"),
                    object: nil
                )
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var rulesListView: some View {
        VStack(spacing: 8) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search rules...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
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
            if viewModel.filteredRules.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(viewModel.filteredRules) { rule in
                        RuleRowView(
                            rule: rule,
                            onToggle: {
                                Task {
                                    await viewModel.toggleRule(rule)
                                }
                            },
                            onEdit: {
                                viewModel.startEditing(rule)
                                showingRuleEditor = true
                            },
                            onDuplicate: {
                                Task {
                                    await viewModel.duplicateRule(rule)
                                }
                            },
                            onDelete: {
                                ruleToDelete = rule
                                showingDeleteConfirmation = true
                            }
                        )
                    }
                    .onMove { source, destination in
                        Task {
                            await viewModel.moveRule(from: source, to: destination)
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

            if viewModel.searchQuery.isEmpty {
                Text("No Rules Yet")
                    .font(.headline)

                Text("Create your first automation rule to get started.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button("Create Rule") {
                    viewModel.startCreating()
                    showingRuleEditor = true
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

// MARK: - Rule Row View

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
                get: { rule.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            // Rule info
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(.body)
                    .foregroundColor(rule.isEnabled ? .primary : .secondary)

                HStack(spacing: 8) {
                    // Trigger badge
                    Label(rule.trigger.displayName, systemImage: rule.trigger.iconName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Actions count
                    Text("\(rule.actions.count) action\(rule.actions.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Execution count
                    if rule.executionCount > 0 {
                        Text("Run \(rule.executionCount)x")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Context menu button
            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button {
                    onDuplicate()
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }

                Divider()

                Button(role: .destructive) {
                    onDelete()
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
            onEdit()
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
