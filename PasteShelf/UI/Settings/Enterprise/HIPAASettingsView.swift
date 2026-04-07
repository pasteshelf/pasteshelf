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
    // MARK: Internal

    @ObservedObject var viewModel: ComplianceSettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // HIPAA Mode
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable HIPAA Compliance Mode", isOn: self.$viewModel.hipaaConfig.isEnabled)
                            .onChange(of: self.viewModel.hipaaConfig.isEnabled) { _, _ in
                                self.viewModel.saveHIPAAConfig()
                            }

                        if self.viewModel.hipaaConfig.isEnabled {
                            Divider()

                            Picker("Session Timeout", selection: self.$viewModel.hipaaConfig.sessionTimeoutMinutes) {
                                Text("5 minutes").tag(5)
                                Text("10 minutes").tag(10)
                                Text("15 minutes").tag(15)
                                Text("30 minutes").tag(30)
                            }
                            .onChange(of: self.viewModel.hipaaConfig.sessionTimeoutMinutes) { _, _ in
                                self.viewModel.saveHIPAAConfig()
                            }

                            Toggle(
                                "Require Biometric Authentication",
                                isOn: self.$viewModel.hipaaConfig.requireBiometric
                            )
                            .onChange(of: self.viewModel.hipaaConfig.requireBiometric) { _, _ in
                                self.viewModel.saveHIPAAConfig()
                            }

                            Toggle("Require SSO Authentication", isOn: self.$viewModel.hipaaConfig.requireSSO)
                                .onChange(of: self.viewModel.hipaaConfig.requireSSO) { _, _ in
                                    self.viewModel.saveHIPAAConfig()
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
                            if self.viewModel.isHIPAARetentionCompliant {
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
                            Task { await self.viewModel.verifyEncryption() }
                        } label: {
                            if self.viewModel.isVerifying {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Verify Encryption", systemImage: "lock.shield")
                            }
                        }
                        .disabled(self.viewModel.isVerifying)

                        if let report = viewModel.encryptionReport {
                            Divider()
                            self.encryptionReportView(report)
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

    // MARK: Private

    private func encryptionReportView(_ report: HIPAAEncryptionReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            self.statusRow("Audit Log Encryption", status: report.auditEncryptionActive)
            self.statusRow("Sync Encryption", status: report.syncEncryptionActive)
            self.statusRow("Disk Encryption (FileVault)", status: report.localDiskEncrypted)
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
