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

    // MARK: - Properties

    @StateObject private var viewModel = DLPSettingsViewModel()

    // MARK: - Body

    var body: some View {
        dlpContent
    }

    // MARK: - DLP Content

    private var dlpContent: some View {
        Form {
            rulesSection
            violationsSection
            exportSection
            quickActionsSection
        }
        .formStyle(.grouped)
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
        .sheet(isPresented: $viewModel.showingRuleEditor) {
            DLPRuleEditorView(
                isPresented: $viewModel.showingRuleEditor,
                rule: viewModel.editingRule
            ) { savedRule in
                Task { await viewModel.saveRule(savedRule) }
            }
        }
        .sheet(isPresented: $viewModel.showingPatternTest) {
            DLPPatternTestView(isPresented: $viewModel.showingPatternTest)
        }
    }

    // MARK: - Rules Section

    private var rulesSection: some View {
        Section("DLP Rules (\(viewModel.rules.count))") {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 8)
                    Spacer()
                }
            } else if viewModel.rules.isEmpty {
                Text("No DLP rules configured")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)

                Button("Install Default Rules") {
                    Task { await viewModel.installDefaults() }
                }
            } else {
                ForEach(viewModel.rules) { rule in
                    DLPRuleRowView(rule: rule) {
                        Task { await viewModel.toggleRule(rule) }
                    } onEdit: {
                        viewModel.editingRule = rule
                        viewModel.showingRuleEditor = true
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let rule = viewModel.rules[index]
                        Task { await viewModel.deleteRule(rule) }
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Add Rule") {
                    viewModel.editingRule = nil
                    viewModel.showingRuleEditor = true
                }

                Button("Test Pattern") {
                    viewModel.showingPatternTest = true
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Violations Section

    private var violationsSection: some View {
        Section("Recent Violations (\(viewModel.recentViolations.count))") {
            if viewModel.recentViolations.isEmpty {
                Text("No violations recorded")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.recentViolations) { violation in
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
                    viewModel.exportViolationsAsCSV()
                }
                .disabled(viewModel.recentViolations.isEmpty)

                Button("Export Violations as JSON") {
                    viewModel.exportViolationsAsJSON()
                }
                .disabled(viewModel.recentViolations.isEmpty)
            }
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        Section("Quick Actions") {
            Button("Install Default Rules") {
                Task { await viewModel.installDefaults() }
            }
        }
    }

}

// MARK: - DLPRuleRowView

/// A single row in the DLP rules list.
///
/// Displays a toggle, the rule name, category badge, severity badge, and an edit button.
private struct DLPRuleRowView: View {

    // MARK: Properties

    let rule: DLPRule
    let onToggle: () -> Void
    let onEdit: () -> Void

    // MARK: Body

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 3) {
                Text(rule.name)
                    .font(.body)

                HStack(spacing: 6) {
                    categoryBadge
                    severityBadge
                    actionsBadge
                }
            }

            Spacer()

            Button("Edit") {
                onEdit()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
        .padding(.vertical, 2)
    }

    // MARK: Subviews

    private var categoryBadge: some View {
        Text(rule.patternCategory.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(.blue)
    }

    private var severityBadge: some View {
        Text(severityDisplayName(rule.severity))
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(severityColor(rule.severity).opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(severityColor(rule.severity))
    }

    private var actionsBadge: some View {
        Text(rule.actions.map(\.rawValue).joined(separator: ", "))
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
            return "None"
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .critical:
            return "Critical"
        }
    }

    private func severityColor(_ severity: SensitiveSeverity) -> Color {
        switch severity {
        case .none:
            return .secondary
        case .low:
            return .green
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }
}

// MARK: - ViolationRowView

/// A single row in the recent violations list.
///
/// Displays a severity icon, rule name, action badge, and relative timestamp.
private struct ViolationRowView: View {

    // MARK: Properties

    let violation: DLPViolation

    // MARK: Body

    var body: some View {
        HStack(spacing: 8) {
            severityIcon

            VStack(alignment: .leading, spacing: 3) {
                Text(violation.ruleName)
                    .font(.body)

                if !violation.contentPreview.isEmpty {
                    Text(violation.contentPreview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            actionBadge

            Text(formattedTimestamp(violation.timestamp))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: Subviews

    private var severityIcon: some View {
        Image(systemName: violation.wasBlocked ? "xmark.shield.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(violation.wasBlocked ? Color.red : Color.orange)
            .imageScale(.small)
    }

    private var actionBadge: some View {
        Text(violation.actionTaken.rawValue)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(actionColor(violation.actionTaken).opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(actionColor(violation.actionTaken))
    }

    // MARK: Helpers

    private func actionColor(_ action: DLPAction) -> Color {
        switch action {
        case .block:
            return .red
        case .alert:
            return .orange
        case .redact:
            return .purple
        case .logOnly:
            return .secondary
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
