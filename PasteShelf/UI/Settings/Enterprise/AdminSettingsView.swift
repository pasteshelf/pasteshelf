//
//  AdminSettingsView.swift
//  PasteShelf
//
//  Admin Console settings dashboard for the Enterprise preferences tab.
//  Displays connection status, device enrollment state, and the active admin policy.
//  Requires the Enterprise license tier (mdmSupport feature flag).
//

import SwiftUI

// MARK: - AdminSettingsView

/// Dashboard for the Enterprise admin console management status.
///
/// Displays the admin console connection status, device enrollment lifecycle state,
/// and the currently active admin policy pushed by the server. Interactive enrollment
/// and unenrollment actions are available when the device is configured. When the
/// Enterprise license is not active, an upgrade prompt is shown instead.
struct AdminSettingsView: View {

    // MARK: - Properties

    @StateObject private var viewModel = AdminSettingsViewModel()
    @FeatureFlag(.mdmSupport) private var adminAvailable

    // MARK: - Body

    var body: some View {
        if adminAvailable {
            adminContent
        } else {
            upgradePrompt
        }
    }

    // MARK: - Admin Content

    private var adminContent: some View {
        Form {
            // MARK: Connection Status Section

            Section("Connection Status") {
                LabeledContent("Status") {
                    Text(viewModel.isConnected ? "Connected" : "Disconnected")
                        .foregroundStyle(viewModel.isConnected ? .green : .secondary)
                }

                if let url = viewModel.serverURL {
                    LabeledContent("Server") {
                        Text(url)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                if let orgID = viewModel.organizationID {
                    LabeledContent("Organization") {
                        Text(orgID)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }

            // MARK: Device Enrollment Section

            Section("Device Enrollment") {
                LabeledContent("Enrollment") {
                    Text(viewModel.enrollmentStatus.displayName)
                        .foregroundStyle(viewModel.isEnrolled ? .primary : .secondary)
                }

                if viewModel.isEnrolled {
                    Button("Unenroll Device", role: .destructive) {
                        Task { await viewModel.unenrollDevice() }
                    }
                } else {
                    Button("Enroll Device") {
                        Task { await viewModel.enrollDevice() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            // MARK: Active Policy Section

            if viewModel.isEnrolled, let policyName = viewModel.policyName {
                Section("Active Policy") {
                    LabeledContent("Policy") {
                        Text(policyName)
                    }

                    if let version = viewModel.policyVersion {
                        LabeledContent("Version") {
                            Text(version)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // MARK: Error Display Section

            if let error = viewModel.lastError {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(.red)

                        if let suggestion = error.recoverySuggestion {
                            Text(suggestion)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // MARK: Not Configured State Section

            if viewModel.serverURL == nil {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)

                        Text("Not Configured")
                            .font(.headline)

                        Text("The admin console server has not been configured.\nContact your IT administrator for enrollment.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Upgrade Prompt

    private var upgradePrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "server.rack")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)

            Text("Enterprise Feature")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Admin console management requires an Enterprise license.\nContact your administrator or upgrade to access this feature.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Link("Learn about Enterprise", destination: URL(string: "https://pasteshelf.app/enterprise")!)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#if DEBUG
    struct AdminSettingsView_Previews: PreviewProvider {
        static var previews: some View {
            AdminSettingsView()
                .frame(width: 500, height: 400)
        }
    }
#endif
