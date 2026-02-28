//
//  MDMSettingsView.swift
//  PasteShelf
//
//  Read-only MDM management status dashboard for the Enterprise preferences tab.
//  Displays management state, organization ID, forced settings, and default settings.
//  Requires the Enterprise license tier (mdmSupport feature flag).
//

import SwiftUI

// MARK: - MDMSettingsView

/// Read-only dashboard showing the current MDM management status.
///
/// Displays forced (locked) settings and default settings pushed by the MDM
/// profile. When the Enterprise license is not active, an upgrade prompt is
/// shown instead.
struct MDMSettingsView: View {

    // MARK: - Properties

    @StateObject private var viewModel = MDMSettingsViewModel()
    @FeatureFlag(.mdmSupport) private var mdmAvailable

    // MARK: - Body

    var body: some View {
        if mdmAvailable {
            mdmContent
        } else {
            upgradePrompt
        }
    }

    // MARK: - MDM Content

    private var mdmContent: some View {
        Form {
            // MARK: Management Status Section

            Section("Management Status") {
                LabeledContent("Status") {
                    Text(viewModel.isManaged ? "Managed" : "Not Managed")
                        .foregroundStyle(viewModel.isManaged ? .primary : .secondary)
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

            // MARK: Forced Settings Section

            if !viewModel.forcedSettings.isEmpty {
                Section("Locked Settings") {
                    ForEach(viewModel.forcedSettings, id: \.key) { item in
                        LabeledContent {
                            Text(item.value.displayValue)
                                .foregroundStyle(.secondary)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                Text(item.key.displayName)
                            }
                        }
                    }
                }
            }

            // MARK: Default Settings Section

            if !viewModel.defaultSettings.isEmpty {
                Section("Default Settings") {
                    ForEach(viewModel.defaultSettings, id: \.key) { item in
                        LabeledContent(item.key.displayName) {
                            Text(item.value.displayValue)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // MARK: Empty State (not managed)

            if !viewModel.isManaged {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "building.2")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)

                        Text("Not Managed")
                            .font(.headline)

                        Text("This device is not enrolled in an MDM program.")
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
            Image(systemName: "building.2")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)

            Text("Enterprise Feature")
                .font(.title2)
                .fontWeight(.semibold)

            Text("MDM management requires an Enterprise license.\nContact your administrator or upgrade to access this feature.")
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
    struct MDMSettingsView_Previews: PreviewProvider {
        static var previews: some View {
            MDMSettingsView()
                .frame(width: 500, height: 400)
        }
    }
#endif
