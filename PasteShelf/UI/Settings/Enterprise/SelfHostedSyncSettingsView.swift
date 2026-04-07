//
//  SelfHostedSyncSettingsView.swift
//  PasteShelf
//
//  Settings view for configuring the self-hosted sync server connection.
//

import SwiftUI

// MARK: - SelfHostedSyncSettingsView

struct SelfHostedSyncSettingsView: View {
    // MARK: Internal

    // MARK: - Body

    var body: some View {
        Form {
            // MARK: Server Configuration

            Section("Server Configuration") {
                TextField(
                    "Server URL",
                    text: self.$viewModel.serverURLString,
                    prompt: Text("https://sync.company.internal")
                )
                .textFieldStyle(.roundedBorder)

                TextField("Organization ID", text: self.$viewModel.organizationID, prompt: Text("your-org-id"))
                    .textFieldStyle(.roundedBorder)

                SecureField("API Key", text: self.$viewModel.apiKey, prompt: Text("ps_..."))
                    .textFieldStyle(.roundedBorder)
            }

            // MARK: Security

            Section("Security") {
                Toggle("Certificate Pinning", isOn: self.$viewModel.certificatePinningEnabled)

                if self.viewModel.certificatePinningEnabled {
                    Text("When enabled, the client verifies the server's TLS certificate against pinned certificates.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: Connection Test

            Section("Connection Test") {
                Button {
                    Task { await self.viewModel.testConnection() }
                } label: {
                    HStack {
                        if self.viewModel.isTestingConnection {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(self.viewModel.isTestingConnection ? "Testing..." : "Test Connection")
                    }
                }
                .disabled(self.viewModel.serverURLString.isEmpty || self.viewModel.isTestingConnection)

                if !self.viewModel.testSteps.isEmpty {
                    ForEach(self.viewModel.testSteps) { step in
                        ConnectionTestStepRow(step: step)
                    }
                }
            }

            // MARK: Enable/Disable

            Section {
                Toggle("Enable Self-Hosted Sync", isOn: self.$viewModel.isEnabled)

                if self.viewModel.isEnabled {
                    Text("Sync data will be sent to your self-hosted server instead of iCloud.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: Actions

            Section {
                Button("Save Configuration") {
                    self.viewModel.saveConfiguration()
                }
                .disabled(self.viewModel.serverURLString.isEmpty)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Self-Hosted Sync")
    }

    // MARK: Private

    @StateObject private var viewModel = SelfHostedSyncSettingsViewModel()
}

// MARK: - ConnectionTestStepRow

struct ConnectionTestStepRow: View {
    // MARK: Internal

    let step: ConnectionTestStep

    var body: some View {
        HStack {
            Image(systemName: self.step.status.icon)
                .foregroundStyle(self.stepColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(self.step.title)
                    .font(.body)

                if let detail = step.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    // MARK: Private

    private var stepColor: Color {
        switch self.step.status {
        case .inProgress: .blue
        case .passed: .green
        case .failed: .red
        case .warning: .orange
        case .skipped: .gray
        }
    }
}
