//
//  HIPAASettingsView.swift
//  PasteShelf
//
//  HIPAA compliance settings: mode toggle, access controls, retention, encryption.
//

import SwiftUI

// MARK: - HIPAASettingsView

/// Settings view for HIPAA compliance configuration.
struct HIPAASettingsView: View {

    @ObservedObject var viewModel: ComplianceSettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // HIPAA Mode
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable HIPAA Compliance Mode", isOn: $viewModel.hipaaConfig.isEnabled)
                            .onChange(of: viewModel.hipaaConfig.isEnabled) { _, _ in
                                viewModel.saveHIPAAConfig()
                            }

                        if viewModel.hipaaConfig.isEnabled {
                            Divider()

                            Picker("Session Timeout", selection: $viewModel.hipaaConfig.sessionTimeoutMinutes) {
                                Text("5 minutes").tag(5)
                                Text("10 minutes").tag(10)
                                Text("15 minutes").tag(15)
                                Text("30 minutes").tag(30)
                            }
                            .onChange(of: viewModel.hipaaConfig.sessionTimeoutMinutes) { _, _ in
                                viewModel.saveHIPAAConfig()
                            }

                            Toggle("Require Biometric Authentication", isOn: $viewModel.hipaaConfig.requireBiometric)
                                .onChange(of: viewModel.hipaaConfig.requireBiometric) { _, _ in
                                    viewModel.saveHIPAAConfig()
                                }

                            Toggle("Require SSO Authentication", isOn: $viewModel.hipaaConfig.requireSSO)
                                .onChange(of: viewModel.hipaaConfig.requireSSO) { _, _ in
                                    viewModel.saveHIPAAConfig()
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("HIPAA Compliance Mode", systemImage: "cross.case.fill")
                }

                // Data Retention
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Retention Compliance:")
                            if viewModel.isHIPAARetentionCompliant {
                                Label("Compliant", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Label("Non-Compliant", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        Text("HIPAA requires a minimum 6-year (2190 day) retention period with immutability.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Data Retention", systemImage: "clock.fill")
                }

                // Encryption Verification
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            Task { await viewModel.verifyEncryption() }
                        } label: {
                            if viewModel.isVerifying {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Verify Encryption", systemImage: "lock.shield")
                            }
                        }
                        .disabled(viewModel.isVerifying)

                        if let report = viewModel.encryptionReport {
                            Divider()
                            encryptionReportView(report)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Encryption Verification", systemImage: "lock.fill")
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func encryptionReportView(_ report: HIPAAEncryptionReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            statusRow("Audit Log Encryption", status: report.auditEncryptionActive)
            statusRow("Sync Encryption", status: report.syncEncryptionActive)
            statusRow("Disk Encryption (FileVault)", status: report.localDiskEncrypted)
            Divider()
            HStack {
                Text("Overall:")
                    .fontWeight(.medium)
                if report.overallCompliant {
                    Label("All Checks Passed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Issues Found", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func statusRow(_ title: String, status: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(status ? .green : .red)
        }
    }
}
