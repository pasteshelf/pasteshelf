//
//  SyncTabView.swift
//  PasteShelf
//
//  Sync settings tab in preferences.
//

import SwiftUI

/// Sync settings tab view
struct SyncTabView: View {
    // MARK: - Properties

    @ObservedObject private var syncManager = SyncManager.shared

    @State private var showingResetConfirmation = false
    @State private var errorMessage: String?

    // MARK: - Body

    var body: some View {
        Form {
            // Sync Status Section
            Section {
                statusSection
            } header: {
                Text("Sync Status")
            }

            // Sync Provider Section
            Section {
                providerSection
            } header: {
                Text("Sync Provider")
            }

            // Self-Hosted Configuration (shown only when self-hosted is selected)
            if syncManager.activeBackendType == .selfHosted || isSelfHostedSelected {
                Section {
                    selfHostedSection
                } header: {
                    Text("Self-Hosted Server")
                }
            }

            // Sync Actions Section
            Section {
                actionsSection
            } header: {
                Text("Actions")
            }
        }
        .formStyle(.grouped)
        .onAppear {}
        .alert("Reset Sync", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetSync()
            }
        } message: {
            Text("This will delete all sync data and re-upload your local clipboard history. This action cannot be undone.")
        }
    }

    /// Whether the user has selected self-hosted in the provider picker
    private var isSelfHostedSelected: Bool {
        syncManager.selfHostedConfiguration?.isEnabled == true
    }

    // MARK: - Status Section

    @ViewBuilder
    private var statusSection: some View {
        // Current Status
        HStack {
            Image(systemName: syncManager.status.symbolName)
                .font(.title2)
                .foregroundStyle(syncManager.status.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)

                Text(syncManager.status.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if case .syncing(let progress) = syncManager.status, progress > 0 {
                ProgressView(value: progress)
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 4)

        // Last Sync Time
        if let lastSync = syncManager.lastSyncDate {
            HStack {
                Text("Last synced")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(lastSync, style: .relative)
                    .foregroundStyle(.secondary)
            }
        }

        // Error Message
        if case let .error(error) = syncManager.status {
            VStack(alignment: .leading, spacing: 4) {
                Label("Error", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.caption.bold())

                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var statusTitle: String {
        switch syncManager.status {
        case .disabled:
            return "Sync Disabled"
        case .idle:
            return "Ready"
        case .syncing:
            return "Syncing..."
        case .synced:
            return "Synced"
        case .error:
            return "Sync Error"
        case .offline:
            return "Offline"
        case .waitingForAccount:
            return isSelfHostedSelected ? "Waiting for Server" : "Waiting for iCloud"
        }
    }

    // MARK: - Provider Section

    @ViewBuilder
    private var providerSection: some View {
        // Enable/Disable Toggle
        Toggle("Enable Sync", isOn: Binding(
            get: { syncManager.isEnabled },
            set: { newValue in
                syncManager.isEnabled = newValue
            }
        ))

        // Provider Picker
        Picker("Provider", selection: Binding(
            get: {
                if syncManager.selfHostedConfiguration?.isEnabled == true {
                    return SyncBackendType.selfHosted
                }
                return .cloudKit
            },
            set: { newValue in
                switch newValue {
                case .cloudKit:
                    // Disable self-hosted, use iCloud
                    if var config = syncManager.selfHostedConfiguration {
                        config.isEnabled = false
                        syncManager.selfHostedConfiguration = config
                    }
                case .selfHosted:
                    // Enable self-hosted
                    var config = syncManager.selfHostedConfiguration ?? .empty
                    config.isEnabled = true
                    syncManager.selfHostedConfiguration = config
                }
                // Restart sync with new backend if sync is enabled
                if syncManager.isEnabled {
                    syncManager.isEnabled = false
                    syncManager.isEnabled = true
                }
            }
        )) {
            Text("iCloud").tag(SyncBackendType.cloudKit)
            Text("Self-Hosted Server").tag(SyncBackendType.selfHosted)
        }
        .disabled(!syncManager.isEnabled)

        // Sync explanation
        VStack(alignment: .leading, spacing: 4) {
            if isSelfHostedSelected {
                Text("Self-hosted sync connects to your organization's private sync server for data sovereignty.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("iCloud Sync keeps your clipboard history synchronized across all your Mac devices signed in to the same iCloud account.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("All data is end-to-end encrypted before being uploaded.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Self-Hosted Section

    @ViewBuilder
    private var selfHostedSection: some View {
        // Connection status
        if let config = syncManager.selfHostedConfiguration, config.isConfigured {
            Label("Server configured", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.green)
        } else {
            Label("Server not configured", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }

        // Direct users to the Enterprise tab for full configuration
        Text("Configure your self-hosted sync server in the Enterprise tab under Self-Hosted Sync.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Actions Section

    @ViewBuilder
    private var actionsSection: some View {
        // Sync Now Button
        Button(action: {
            Task {
                try? await syncManager.syncNow()
            }
        }) {
            Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
        }
        .disabled(!syncManager.status.canSync)

        // Reset Sync Button
        Button(role: .destructive, action: {
            showingResetConfirmation = true
        }) {
            Label("Reset Sync...", systemImage: "arrow.counterclockwise")
        }
        .disabled(!syncManager.isEnabled)
    }

    // MARK: - Actions

    private func resetSync() {
        Task {
            do {
                try await syncManager.reset()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct SyncTabView_Previews: PreviewProvider {
        static var previews: some View {
            SyncTabView()
                .frame(width: 450, height: 400)
        }
    }
#endif
