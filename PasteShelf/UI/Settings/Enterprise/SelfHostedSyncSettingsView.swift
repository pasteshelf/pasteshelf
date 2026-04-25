//
//  SelfHostedSyncSettingsView.swift
//  PasteShelf
//
//  Settings view for configuring the self-hosted sync server connection.
//

import SwiftUI

// MARK: - SelfHostedSyncSettingsView

struct SelfHostedSyncSettingsView: View {

    // MARK: - Properties

    @StateObject private var viewModel = SelfHostedSyncSettingsViewModel()

    // MARK: - Body

    var body: some View {
        Form {
            // MARK: Server Configuration
            Section("Server Configuration") {
                TextField("Server URL", text: $viewModel.serverURLString, prompt: Text("https://sync.company.internal"))
                    .textFieldStyle(.roundedBorder)

                TextField("Organization ID", text: $viewModel.organizationID, prompt: Text("your-org-id"))
                    .textFieldStyle(.roundedBorder)

                SecureField("API Key", text: $viewModel.apiKey, prompt: Text("ps_..."))
                    .textFieldStyle(.roundedBorder)
            }

            // MARK: Security
            Section("Security") {
                Toggle("Certificate Pinning", isOn: $viewModel.certificatePinningEnabled)

                if viewModel.certificatePinningEnabled {
                    Text("When enabled, the client verifies the server's TLS certificate against pinned certificates.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: Connection Test
            Section("Connection Test") {
                Button(action: {
                    Task { await viewModel.testConnection() }
                }) {
                    HStack {
                        if viewModel.isTestingConnection {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(viewModel.isTestingConnection ? String(localized: "Testing...") : String(localized: "Test Connection"))
                    }
                }
                .disabled(viewModel.serverURLString.isEmpty || viewModel.isTestingConnection)

                if !viewModel.testSteps.isEmpty {
                    ForEach(viewModel.testSteps) { step in
                        ConnectionTestStepRow(step: step)
                    }
                }
            }

            // MARK: Enable/Disable
            Section {
                Toggle("Enable Self-Hosted Sync", isOn: $viewModel.isEnabled)

                if viewModel.isEnabled {
                    Text("Sync data will be sent to your self-hosted server instead of iCloud.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: Actions
            Section {
                Button("Save Configuration") {
                    viewModel.saveConfiguration()
                }
                .disabled(viewModel.serverURLString.isEmpty)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Self-Hosted Sync")
    }
}

// MARK: - ConnectionTestStepRow

struct ConnectionTestStepRow: View {
    let step: ConnectionTestStep

    var body: some View {
        HStack {
            Image(systemName: step.status.icon)
                .foregroundStyle(stepColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
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

    private var stepColor: Color {
        switch step.status {
        case .inProgress: return .blue
        case .passed: return .green
        case .failed: return .red
        case .warning: return .orange
        case .skipped: return .gray
        }
    }
}
