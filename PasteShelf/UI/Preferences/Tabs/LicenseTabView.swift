//
//  LicenseTabView.swift
//  PasteShelf
//
//  License settings tab for preferences window.
//  Displays license status, tier, expiration, and activation controls.
//

import SwiftUI

/// License settings tab view
struct LicenseTabView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: LicenseViewModel

    // MARK: - Body

    var body: some View {
        Form {
            // Current License Section
            Section {
                currentLicenseView
            } header: {
                Text("Current License")
            }

            // License Details Section (when active)
            if viewModel.isLicenseActive {
                Section {
                    licenseDetailsView
                } header: {
                    Text("License Details")
                }
            }

            // Activation Section
            Section {
                activationView
            } header: {
                Text(viewModel.isLicenseActive ? "Manage License" : "Activate License")
            }

            // Pro Features Section
            Section {
                proFeaturesView
            } header: {
                Text("Pro Features")
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Activate License", isPresented: $viewModel.showActivationDialog) {
            TextField("License Key", text: $viewModel.licenseKeyInput)
                .textFieldStyle(.plain)
            Button("Cancel", role: .cancel) {
                viewModel.cancelActivation()
            }
            Button("Activate") {
                Task {
                    await viewModel.activateLicense()
                }
            }
            .disabled(viewModel.licenseKeyInput.isEmpty)
        } message: {
            Text("Enter your license key in the format PS-XXX-XXXX-XXXX-XXXX")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    // MARK: - Subviews

    private var currentLicenseView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Tier badge
                tierBadge

                Spacer()

                // Status indicator
                statusIndicator
            }

            // Status description
            Text(viewModel.statusDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var tierBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: viewModel.currentTier.iconName)
                .font(.title2)
                .foregroundColor(tierColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentTier.displayName)
                    .font(.headline)

                Text(viewModel.currentTier.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var tierColor: Color {
        switch viewModel.currentTier {
        case .community:
            return .secondary
        case .pro:
            return .orange
        case .enterprise:
            return .purple
        }
    }

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(viewModel.statusLabel)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var statusColor: Color {
        switch viewModel.status {
        case .inactive:
            return .secondary
        case .active:
            return .green
        case .expired, .invalid:
            return .red
        case .trial, .offlineGrace:
            return .yellow
        }
    }

    private var licenseDetailsView: some View {
        Group {
            if let info = viewModel.licenseInfo {
                LabeledContent("Email") {
                    Text(info.email)
                        .foregroundColor(.secondary)
                }

                LabeledContent("License Type") {
                    Text(info.type.displayName)
                        .foregroundColor(.secondary)
                }

                if let expiration = info.expirationDate {
                    LabeledContent("Expires") {
                        Text(expiration, style: .date)
                            .foregroundColor(info.isExpired ? .red : .secondary)
                    }
                }

                LabeledContent("Device") {
                    Text("\(viewModel.deviceName)")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var activationView: some View {
        Group {
            if viewModel.isLicenseActive {
                Button("Deactivate License") {
                    Task {
                        await viewModel.deactivateLicense()
                    }
                }
                .disabled(viewModel.isProcessing)
            } else {
                HStack {
                    Button("Enter License Key") {
                        viewModel.showActivationDialog = true
                    }
                    .disabled(viewModel.isProcessing)

                    Spacer()

                    Link("Purchase Pro", destination: URL(string: "https://pasteshelf.app/pro")!)
                        .buttonStyle(.borderedProminent)
                }
            }

            if viewModel.isProcessing {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Processing...")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var proFeaturesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(LicensedFeature.proFeatures, id: \.rawValue) { feature in
                featureRow(feature)
            }
        }
    }

    private func featureRow(_ feature: LicensedFeature) -> some View {
        HStack(spacing: 12) {
            Image(systemName: feature.iconName)
                .font(.body)
                .foregroundColor(viewModel.isFeatureAvailable(feature) ? .accentColor : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.displayName)
                    .font(.body)
                    .foregroundColor(viewModel.isFeatureAvailable(feature) ? .primary : .secondary)

                Text(feature.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if viewModel.isFeatureAvailable(feature) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#if DEBUG
    struct LicenseTabView_Previews: PreviewProvider {
        static var previews: some View {
            LicenseTabView(viewModel: LicenseViewModel())
                .frame(width: 500, height: 500)
        }
    }
#endif
