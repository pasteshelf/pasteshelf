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
    // MARK: Internal

    // MARK: - Body

    var body: some View {
        auditLogContent
    }

    // MARK: Private

    @StateObject private var viewModel = AuditLogViewModel()
    @State private var pendingRetentionDays: Int?

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
            set: { if !$0 {
                viewModel.errorMessage = nil
            } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
        .alert("Change Retention Period?", isPresented: Binding(
            get: { pendingRetentionDays != nil },
            set: { if !$0 {
                pendingRetentionDays = nil
            } }
        )) {
            Button("Apply") {
                if let days = pendingRetentionDays {
                    viewModel.updateRetentionDays(days)
                }
                pendingRetentionDays = nil
            }
            Button("Cancel", role: .cancel) {
                pendingRetentionDays = nil
                // Reset picker to current value
                viewModel.retentionDays = viewModel.retentionDays
            }
        } message: {
            if let days = pendingRetentionDays {
                Text(
                    "Setting retention to \(days) day\(days == 1 ? "" : "s") will permanently delete older events during the next pruning pass. This cannot be undone."
                )
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

            if let start = viewModel.dateRangeStart, let end = viewModel.dateRangeEnd, start > end {
                Text("Start date is after end date")
                    .font(.caption)
                    .foregroundStyle(.red)
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
            if viewModel.decryptionFailureCount > 0 {
                Label(
                    "\(viewModel.decryptionFailureCount) event\(viewModel.decryptionFailureCount == 1 ? "" : "s") could not be decrypted",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

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
                Picker("Retention", selection: $viewModel.retentionDays) {
                    ForEach(AuditRetentionConfiguration.options, id: \.self) { days in
                        Text(retentionLabel(days: days)).tag(days)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
                .onChange(of: viewModel.retentionDays) { _, newValue in
                    pendingRetentionDays = newValue
                }
            }

            Text(
                "Events older than the retention window are automatically deleted during the next scheduled pruning pass."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    /// Returns a human-readable display name for the given `AuditEventCategory`.
    private func categoryDisplayName(_ category: AuditEventCategory) -> String {
        switch category {
        case .clipboard:
            "Clipboard"
        case .userAction:
            "User Action"
        case .policy:
            "Policy"
        case .authentication:
            "Authentication"
        case .compliance:
            "Compliance"
        }
    }

    /// Returns a human-readable label for a retention period in days.
    private func retentionLabel(days: Int) -> String {
        switch days {
        case 1: "1 day"
        case 30: "30 days"
        case 60: "60 days"
        case 90: "90 days"
        case 180: "180 days"
        case 365: "1 year"
        default: "\(days) days"
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
    // MARK: Internal

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

    // MARK: Private

    private var severityColor: Color {
        switch item.severity {
        case .info:
            .blue
        case .warning:
            .orange
        case .critical:
            .red
        }
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
