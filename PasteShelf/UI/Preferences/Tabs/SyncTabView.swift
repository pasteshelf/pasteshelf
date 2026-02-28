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

    @StateObject private var syncManager = SyncManager.shared

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

            // Sync Settings Section
            Section {
                settingsSection
            } header: {
                Text("Settings")
            }

            // Sync Actions Section
            Section {
                actionsSection
            } header: {
                Text("Actions")
            }
        }
        .formStyle(.grouped)
        .alert("Reset Sync", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetSync()
            }
        } message: {
            Text("This will delete all sync data from iCloud and re-upload your local clipboard history. This action cannot be undone.")
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
            return "Waiting for iCloud"
        }
    }

    // MARK: - Settings Section

    @ViewBuilder
    private var settingsSection: some View {
        // Enable/Disable Toggle
        Toggle("Enable iCloud Sync", isOn: Binding(
            get: { syncManager.isEnabled },
            set: { newValue in
                syncManager.isEnabled = newValue
            }
        ))

        // Sync explanation
        VStack(alignment: .leading, spacing: 4) {
            Text("iCloud Sync keeps your clipboard history synchronized across all your Mac devices signed in to the same iCloud account.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("All data is end-to-end encrypted before being uploaded to iCloud.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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

// MARK: - SyncManager Shared Instance Extension

extension SyncManager {
    /// Shared singleton instance
    @MainActor
    static let shared = SyncManager()
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
