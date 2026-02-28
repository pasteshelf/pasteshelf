//
//  ConnectionTestView.swift
//  PasteShelf
//
//  Standalone connection test view for verifying self-hosted server connectivity.
//  Can be presented as a sheet from the sync settings.
//

import SwiftUI

// MARK: - ConnectionTestView

struct ConnectionTestView: View {

    // MARK: - Properties

    @ObservedObject var viewModel: SelfHostedSyncSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Image(systemName: "network")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Connection Test")
                .font(.title2.bold())

            Text("Testing connection to \(viewModel.serverURLString)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Divider()

            // Test Steps
            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.testSteps) { step in
                    ConnectionTestStepRow(step: step)
                }

                if viewModel.testSteps.isEmpty && !viewModel.isTestingConnection {
                    Text("Press \"Run Test\" to begin.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // Status
            if case .connected = viewModel.connectionStatus {
                Label("All checks passed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if case .failed = viewModel.connectionStatus {
                Label("Connection test failed", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }

            // Actions
            HStack {
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Run Test") {
                    Task { await viewModel.testConnection() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.isTestingConnection)
            }
        }
        .padding(24)
        .frame(width: 420, height: 480)
    }
}
