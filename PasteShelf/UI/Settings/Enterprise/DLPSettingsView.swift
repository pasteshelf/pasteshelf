//
//  DLPSettingsView.swift
//  PasteShelf
//
//  DLP policy settings viewer for the Enterprise preferences tab.
//

import SwiftUI

// MARK: - DLPSettingsView

/// Displays the DLP (Data Loss Prevention) settings interface.
///
/// The view shows:
///
/// - A list of configured DLP rules with enable/disable toggles.
/// - A recent violations log with action and severity indicators.
/// - Export actions that produce CSV or JSON files via `NSSavePanel`.
/// - Quick actions to install default rules and open the pattern tester.
struct DLPSettingsView: View {
    // MARK: Internal

    // MARK: - Body

    var body: some View {
        self.dlpContent
    }

    // MARK: Private

    @StateObject private var viewModel = DLPSettingsViewModel()

    // MARK: - DLP Content

    private var dlpContent: some View {
        Form {
            self.rulesSection
            self.violationsSection
            self.exportSection
            self.quickActionsSection
        }
        .formStyle(.grouped)
        .alert("Error", isPresented: Binding(
            get: { self.viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    self.viewModel.errorMessage = nil
                }
            }
        )) {
            Button("OK") { self.viewModel.errorMessage = nil }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
        .sheet(isPresented: self.$viewModel.showingRuleEditor) {
            DLPRuleEditorView(
                isPresented: self.$viewModel.showingRuleEditor,
                rule: self.viewModel.editingRule
            ) { savedRule in
                Task { await self.viewModel.saveRule(savedRule) }
            }
        }
        .sheet(isPresented: self.$viewModel.showingPatternTest) {
            DLPPatternTestView(isPresented: self.$viewModel.showingPatternTest)
        }
    }

    // MARK: - Rules Section

    private var rulesSection: some View {
        Section("DLP Rules (\(self.viewModel.rules.count))") {
            if self.viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 8)
                    Spacer()
                }
            } else if self.viewModel.rules.isEmpty {
                Text("No DLP rules configured")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)

                Button("Install Default Rules") {
                    Task { await self.viewModel.installDefaults() }
                }
            } else {
                ForEach(self.viewModel.rules) { rule in
                    DLPRuleRowView(rule: rule) {
                        Task { await self.viewModel.toggleRule(rule) }
                    } onEdit: {
                        self.viewModel.editingRule = rule
                        self.viewModel.showingRuleEditor = true
                    }
                }
                .onDelete { indexSet in
                    let rulesToDelete = indexSet.map { self.viewModel.rules[$0] }
                    Task {
                        for rule in rulesToDelete {
                            await self.viewModel.deleteRule(rule)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Add Rule") {
                    self.viewModel.editingRule = nil
                    self.viewModel.showingRuleEditor = true
                }

                Button("Test Pattern") {
                    self.viewModel.showingPatternTest = true
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Violations Section

    private var violationsSection: some View {
        Section("Recent Violations (\(self.viewModel.recentViolations.count))") {
            if self.viewModel.recentViolations.isEmpty {
                Text("No violations recorded")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(self.viewModel.recentViolations) { violation in
                    ViolationRowView(violation: violation)
                }
            }
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        Section("Export") {
            HStack(spacing: 12) {
                Button("Export Violations as CSV") {
                    self.viewModel.exportViolationsAsCSV()
                }
                .disabled(self.viewModel.recentViolations.isEmpty)

                Button("Export Violations as JSON") {
                    self.viewModel.exportViolationsAsJSON()
                }
                .disabled(self.viewModel.recentViolations.isEmpty)
            }
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        Section("Quick Actions") {
            Button("Install Default Rules") {
                Task { await self.viewModel.installDefaults() }
            }
        }
    }
}

// MARK: - DLPRuleRowView

/// A single row in the DLP rules list.
///
/// Displays a toggle, the rule name, category badge, severity badge, and an edit button.
private struct DLPRuleRowView: View {
    // MARK: Internal

    let rule: DLPRule
    let onToggle: () -> Void
    let onEdit: () -> Void

    // MARK: Body

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { self.rule.isEnabled },
                set: { _ in self.onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 3) {
                Text(self.rule.name)
                    .font(.body)

                HStack(spacing: 6) {
                    self.categoryBadge
                    self.severityBadge
                    self.actionsBadge
                }
            }

            Spacer()

            Button("Edit") {
                self.onEdit()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
        .padding(.vertical, 2)
    }

    // MARK: Private

    // MARK: Subviews

    private var categoryBadge: some View {
        Text(self.rule.patternCategory.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(.blue)
    }

    private var severityBadge: some View {
        Text(self.severityDisplayName(self.rule.severity))
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(self.severityColor(self.rule.severity).opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(self.severityColor(self.rule.severity))
    }

    private var actionsBadge: some View {
        Text(self.rule.actions.map(\.rawValue).joined(separator: ", "))
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(.secondary)
    }

    // MARK: Helpers

    private func severityDisplayName(_ severity: SensitiveSeverity) -> String {
        switch severity {
        case .none:
            "None"
        case .low:
            "Low"
        case .medium:
            "Medium"
        case .high:
            "High"
        case .critical:
            "Critical"
        }
    }

    private func severityColor(_ severity: SensitiveSeverity) -> Color {
        switch severity {
        case .none:
            .secondary
        case .low:
            .green
        case .medium:
            .yellow
        case .high:
            .orange
        case .critical:
            .red
        }
    }
}

// MARK: - ViolationRowView

/// A single row in the recent violations list.
///
/// Displays a severity icon, rule name, action badge, and relative timestamp.
private struct ViolationRowView: View {
    // MARK: Internal

    let violation: DLPViolation

    // MARK: Body

    var body: some View {
        HStack(spacing: 8) {
            self.severityIcon

            VStack(alignment: .leading, spacing: 3) {
                Text(self.violation.ruleName)
                    .font(.body)

                if !self.violation.contentPreview.isEmpty {
                    Text(self.violation.contentPreview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            self.actionBadge

            Text(self.formattedTimestamp(self.violation.timestamp))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: Private

    // MARK: Subviews

    private var severityIcon: some View {
        Image(systemName: self.violation.wasBlocked ? "xmark.shield.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(self.violation.wasBlocked ? Color.red : Color.orange)
            .imageScale(.small)
    }

    private var actionBadge: some View {
        Text(self.violation.actionTaken.rawValue)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                self.actionColor(self.violation.actionTaken).opacity(0.15),
                in: RoundedRectangle(cornerRadius: 4)
            )
            .foregroundStyle(self.actionColor(self.violation.actionTaken))
    }

    // MARK: Helpers

    private func actionColor(_ action: DLPAction) -> Color {
        switch action {
        case .block:
            .red
        case .alert:
            .orange
        case .redact:
            .purple
        case .logOnly:
            .secondary
        }
    }

    private func formattedTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Previews

#if DEBUG
    struct DLPSettingsView_Previews: PreviewProvider {
        static var previews: some View {
            DLPSettingsView()
                .frame(width: 600, height: 500)
        }
    }
#endif
