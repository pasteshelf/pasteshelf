//
//  AuditLogView.swift
//  PasteShelf
//
//  Audit log viewer for the Enterprise preferences tab.
//

import SwiftUI

// MARK: - AuditLogView

/// Displays the audit log interface for reviewing recorded audit events.
///
/// The view shows:
///
/// - A filter panel to narrow results by category and date range.
/// - A scrollable list of audit events with inline severity indicators.
/// - Export actions that produce CSV or JSON files via `NSSavePanel`.
/// - A retention-policy picker that delegates to `AuditManager`.
struct AuditLogView: View {

    // MARK: - Properties

    @StateObject private var viewModel = AuditLogViewModel()

    // MARK: - Body

    var body: some View {
        auditLogContent
    }

    // MARK: - Audit Log Content

    private var auditLogContent: some View {
        Form {
            filtersSection
            eventsSection
            exportSection
            retentionSection
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
    }

    // MARK: - Filters Section

    private var filtersSection: some View {
        Section("Filters") {
            // MARK: Category Picker

            Picker("Category", selection: $viewModel.selectedCategory) {
                Text("All Categories").tag(AuditEventCategory?.none)
                ForEach(AuditEventCategory.allCases, id: \.self) { category in
                    Text(categoryDisplayName(category)).tag(Optional(category))
                }
            }

            // MARK: Date Range — Start

            HStack {
                if let start = viewModel.dateRangeStart {
                    DatePicker(
                        "From",
                        selection: Binding(
                            get: { start },
                            set: { viewModel.dateRangeStart = $0 }
                        ),
                        displayedComponents: .date
                    )
                    Button("Clear") { viewModel.dateRangeStart = nil }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                } else {
                    Text("From")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Set Start Date") { viewModel.dateRangeStart = Date() }
                        .buttonStyle(.borderless)
                }
            }

            // MARK: Date Range — End

            HStack {
                if let end = viewModel.dateRangeEnd {
                    DatePicker(
                        "To",
                        selection: Binding(
                            get: { end },
                            set: { viewModel.dateRangeEnd = $0 }
                        ),
                        displayedComponents: .date
                    )
                    Button("Clear") { viewModel.dateRangeEnd = nil }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                } else {
                    Text("To")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Set End Date") { viewModel.dateRangeEnd = Date() }
                        .buttonStyle(.borderless)
                }
            }

            // MARK: Clear All Filters

            Button("Clear Filters") {
                viewModel.clearFilters()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Events Section

    private var eventsSection: some View {
        Section("Events (\(viewModel.events.count))") {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 8)
                    Spacer()
                }
            } else if viewModel.events.isEmpty {
                Text("No audit events found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.events) { item in
                    EventRowView(item: item)
                }
            }
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        Section("Export") {
            HStack(spacing: 12) {
                Button("Export as CSV") {
                    viewModel.exportAsCSV()
                }
                .disabled(viewModel.events.isEmpty)

                Button("Export as JSON") {
                    viewModel.exportAsJSON()
                }
                .disabled(viewModel.events.isEmpty)
            }
        }
    }

    // MARK: - Retention Section

    private var retentionSection: some View {
        Section("Retention Policy") {
            LabeledContent("Keep events for") {
                Picker("Retention", selection: Binding(
                    get: { AuditManager.shared.retentionConfiguration.retentionDays },
                    set: { _ in }
                )) {
                    ForEach(AuditRetentionConfiguration.options, id: \.self) { days in
                        Text(retentionLabel(days: days)).tag(days)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
            }

            Text("Events older than the retention window are automatically deleted during the next scheduled pruning pass.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    /// Returns a human-readable display name for the given `AuditEventCategory`.
    private func categoryDisplayName(_ category: AuditEventCategory) -> String {
        switch category {
        case .clipboard:
            return "Clipboard"
        case .userAction:
            return "User Action"
        case .policy:
            return "Policy"
        case .authentication:
            return "Authentication"
        case .compliance:
            return "Compliance"
        }
    }

    /// Returns a human-readable label for a retention period in days.
    private func retentionLabel(days: Int) -> String {
        switch days {
        case 1: return "1 day"
        case 30: return "30 days"
        case 60: return "60 days"
        case 90: return "90 days"
        case 180: return "180 days"
        case 365: return "1 year"
        default: return "\(days) days"
        }
    }
}

// MARK: - EventRowView

/// A single row in the audit log event list.
///
/// Displays the severity icon, action name, category badge, and relative timestamp
/// for one `AuditLogDisplayItem`. When the item has non-empty detail fields a
/// `DisclosureGroup` exposes the key/value pairs.
private struct EventRowView: View {

    // MARK: Properties

    let item: AuditLogDisplayItem

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                severityIcon

                Text(item.actionDisplayName)
                    .font(.body)

                Spacer()

                categoryBadge

                Text(item.formattedTimestamp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !item.detail.isEmpty {
                DisclosureGroup("Details") {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(item.detail.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                            HStack(alignment: .top, spacing: 6) {
                                Text(key + ":")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 80, alignment: .trailing)
                                Text(value)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: Subviews

    private var severityIcon: some View {
        Image(systemName: item.severityIconName)
            .foregroundStyle(severityColor)
            .imageScale(.small)
    }

    private var categoryBadge: some View {
        Text(item.categoryDisplayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(.secondary)
    }

    private var severityColor: Color {
        switch item.severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
}

// MARK: - Previews

#if DEBUG
    struct AuditLogView_Previews: PreviewProvider {
        static var previews: some View {
            AuditLogView()
                .frame(width: 600, height: 500)
        }
    }
#endif
