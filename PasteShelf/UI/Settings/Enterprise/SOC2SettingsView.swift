//
//  SOC2SettingsView.swift
//  PasteShelf
//
//  SOC 2 compliance settings: report generation, evidence export, audit trail.
//

import SwiftUI

// MARK: - SOC2SettingsView

/// Settings view for SOC 2 compliance tools.
struct SOC2SettingsView: View {

    @ObservedObject var viewModel: ComplianceSettingsViewModel

    @State private var trailStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var trailEndDate = Date()
    @State private var isExportingTrail = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Security Controls Report
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button {
                                viewModel.generateSOC2Report()
                            } label: {
                                if viewModel.isGenerating {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Label("Generate Report", systemImage: "doc.text.magnifyingglass")
                                }
                            }
                            .disabled(viewModel.isGenerating)

                            Spacer()

                            if let report = viewModel.soc2Report {
                                Text("Score: \(report.overallScore)/100")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(report.overallScore >= 80 ? .green : .orange)
                            }
                        }

                        if let report = viewModel.soc2Report {
                            Divider()
                            Text(report.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(report.categories) { category in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.name)
                                        .font(.caption.bold())
                                    ForEach(category.controls) { control in
                                        HStack {
                                            statusIcon(control.status)
                                            Text(control.name)
                                                .font(.caption)
                                            Spacer()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Security Controls Report", systemImage: "shield.checkered")
                }

                // Audit Trail Export
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            DatePicker("From:", selection: $trailStartDate, displayedComponents: .date)
                                .frame(maxWidth: 200)
                            DatePicker("To:", selection: $trailEndDate, displayedComponents: .date)
                                .frame(maxWidth: 200)
                        }

                        Button {
                            Task { await exportAuditTrail() }
                        } label: {
                            if isExportingTrail {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Export Verified Audit Trail", systemImage: "link.badge.plus")
                            }
                        }
                        .disabled(isExportingTrail)

                        Text("Exports a cryptographically chained audit trail with SHA-256 integrity verification.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Audit Trail", systemImage: "doc.text.fill")
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func statusIcon(_ status: ComplianceFindingStatus) -> some View {
        switch status {
        case .pass:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .fail:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
        }
    }

    private func exportAuditTrail() async {
        isExportingTrail = true
        defer { isExportingTrail = false }

        if let url = await viewModel.exportAuditTrail(dateRange: trailStartDate...trailEndDate) {
            NSWorkspace.shared.open(url)
        }
    }
}
