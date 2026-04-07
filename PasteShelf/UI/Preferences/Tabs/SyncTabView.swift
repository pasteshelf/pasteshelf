//
//  SyncTabView.swift
//  PasteShelf
//
//  Sync settings tab in preferences.
//

import SwiftUI

// MARK: - SyncTabView

/// Sync settings tab view
struct SyncTabView: View {
    // MARK: Internal

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

            #if !APP_STORE
                // Self-Hosted Configuration (shown only when self-hosted is selected)
                if syncManager.activeBackendType == .selfHosted || isSelfHostedSelected {
                    Section {
                        selfHostedSection
                    } header: {
                        Text("Self-Hosted Server")
                    }
                }
            #endif

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
            Text(
                "This will delete all sync data and re-upload your local clipboard history. This action cannot be undone."
            )
        }
        .alert("Delete iCloud Data", isPresented: $showingDeleteCloudConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteCloudData()
            }
        } message: {
            Text(
                "This will permanently delete all clipboard data stored in iCloud. Your local clipboard history will not be affected. Sync will be disabled."
            )
        }
        .alert("Enable Sync", isPresented: $showingEnableSyncConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Enable") {
                syncManager.isEnabled = true
            }
        } message: {
            Text(
                "Your clipboard history will be uploaded to iCloud and kept in sync across all your Mac devices signed in to the same iCloud account.\n\nThis uses your personal iCloud storage quota. All data is end-to-end encrypted before leaving your device.\n\nYou can disable sync or delete your iCloud data at any time from this settings tab."
            )
        }
    }

    // MARK: Private

    @ObservedObject private var syncManager = SyncManager.shared

    @State private var showingResetConfirmation = false
    @State private var showingDeleteCloudConfirmation = false
    @State private var showingEnableSyncConfirmation = false
    @State private var errorMessage: String?

    /// Whether the user has selected self-hosted in the provider picker
    private var isSelfHostedSelected: Bool {
        syncManager.selfHostedConfiguration?.isEnabled == true
    }

    private var statusTitle: String {
        switch syncManager.status {
        case .disabled:
            "Sync Disabled"
        case .idle:
            "Ready"
        case .syncing:
            "Syncing..."
        case .synced:
            "Synced"
        case .error:
            "Sync Error"
        case .offline:
            "Offline"
        case .waitingForAccount:
            isSelfHostedSelected ? "Waiting for Server" : "Waiting for iCloud"
        }
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

            if case let .syncing(progress) = syncManager.status, progress > 0 {
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
                Text(lastSyncFormatted(lastSync))
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

    // MARK: - Provider Section

    @ViewBuilder
    private var providerSection: some View {
        // Enable/Disable Toggle
        Toggle("Enable Sync", isOn: Binding(
            get: { syncManager.isEnabled },
            set: { newValue in
                if newValue {
                    showingEnableSyncConfirmation = true
                } else {
                    syncManager.isEnabled = false
                }
            }
        ))

        Text("Sync is disabled by default. Your clipboard history is stored locally on this device only.")
            .font(.caption)
            .foregroundStyle(.secondary)

        // Provider Picker
        Picker("Provider", selection: Binding<SyncBackendType?>(
            get: {
                guard syncManager.isEnabled else {
                    return nil
                }
                if syncManager.selfHostedConfiguration?.isEnabled == true {
                    return .selfHosted
                }
                return syncManager.activeBackendType
            },
            set: { (newValue: SyncBackendType?) in
                switch newValue {
                case .cloudKit:
                    // Disable self-hosted, use iCloud
                    if var config = syncManager.selfHostedConfiguration {
                        config.isEnabled = false
                        syncManager.selfHostedConfiguration = config
                    }
                    // Restart sync with iCloud backend
                    if syncManager.isEnabled {
                        syncManager.stop()
                        Task {
                            try? await syncManager.start()
                        }
                    }
                case .selfHosted:
                    // Enable self-hosted
                    var config = syncManager.selfHostedConfiguration ?? .empty
                    config.isEnabled = true
                    syncManager.selfHostedConfiguration = config
                    // Only restart if server is configured
                    if syncManager.isEnabled, config.isConfigured {
                        syncManager.stop()
                        Task {
                            try? await syncManager.start()
                        }
                    }
                case .none:
                    // Clear self-hosted selection
                    if var config = syncManager.selfHostedConfiguration {
                        config.isEnabled = false
                        syncManager.selfHostedConfiguration = config
                    }
                    // Disable sync and clear backend so re-enabling doesn't auto-start
                    syncManager.isEnabled = false
                    syncManager.clearBackendSelection()
                }
            }
        )) {
            Text("None").tag(SyncBackendType?.none)
            Text("iCloud").tag(SyncBackendType?.some(.cloudKit))
            #if !APP_STORE
                Text("Self-Hosted Server").tag(SyncBackendType?.some(.selfHosted))
            #endif
        }
        .disabled(!syncManager.isEnabled)

        // Sync explanation
        if let selectedProvider = syncManager.activeBackendType ?? (isSelfHostedSelected ? .selfHosted : nil) {
            VStack(alignment: .leading, spacing: 4) {
                if selectedProvider == .selfHosted {
                    Text("Self-hosted sync connects to your organization's private sync server for data sovereignty.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(
                        "iCloud Sync keeps your clipboard history synchronized across all your Mac devices signed in to the same iCloud account."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Text("All data is end-to-end encrypted before being uploaded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
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
        .disabled(!syncManager.isEnabled || !syncManager.status.canSync)

        // Reset Sync Button
        Button(role: .destructive, action: {
            showingResetConfirmation = true
        }) {
            Label("Reset Sync...", systemImage: "arrow.counterclockwise")
        }
        .disabled(!syncManager.isEnabled)

        Text(
            "Deletes all remote sync data and re-uploads your local clipboard history. Your local data is not affected."
        )
        .font(.caption)
        .foregroundStyle(.secondary)

        // Delete iCloud Data Button
        Button(role: .destructive, action: {
            showingDeleteCloudConfirmation = true
        }) {
            Label("Delete iCloud Data...", systemImage: "trash")
        }

        Text(
            "Permanently removes all PasteShelf data from iCloud and disables sync. Your local clipboard history is preserved."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func lastSyncFormatted(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func resetSync() {
        Task {
            do {
                try await syncManager.reset()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteCloudData() {
        Task {
            do {
                try await syncManager.deleteCloudData()
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
