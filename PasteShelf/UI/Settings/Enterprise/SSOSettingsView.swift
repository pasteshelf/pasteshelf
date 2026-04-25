//
//  SSOSettingsView.swift
//  PasteShelf
//
//  Enterprise SSO settings panel.
//  Lists configured identity providers and provides add/edit/delete controls.
//
//

import SwiftUI

// MARK: - SSOSettingsView

/// Main SSO settings view, displayed in the Enterprise section of Preferences.
struct SSOSettingsView: View {
    // MARK: - Properties

    @StateObject private var viewModel = SSOSettingsViewModel()

    // MARK: - Body

    var body: some View {
        ssoContent
    }

    // MARK: - Main Content

    private var ssoContent: some View {
        HSplitView {
            providerList
                .frame(minWidth: 220, maxWidth: 300)

            if let provider = viewModel.selectedProvider {
                providerDetail(provider)
            } else {
                emptyDetailState
            }
        }
        .frame(minHeight: 380)
        .onAppear {
            Task { await viewModel.loadProviders() }
        }
        .sheet(isPresented: $viewModel.isShowingForm) {
            providerFormSheet
        }
        .confirmationDialog(
            "Delete Identity Provider",
            isPresented: $viewModel.isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if let provider = viewModel.selectedProvider {
                Button("Delete \"\(provider.name)\"", role: .destructive) {
                    Task { await viewModel.deleteProvider(provider) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Provider List

    private var providerList: some View {
        VStack(spacing: 0) {
            // Header toolbar
            HStack {
                Text("Identity Providers")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.addProvider()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("Add Identity Provider")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if viewModel.providers.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "key.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No providers configured")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Add Provider") {
                        viewModel.addProvider()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.accentColor)
                }
                Spacer()
            } else {
                List(selection: $viewModel.selectedProviderID) {
                    ForEach(viewModel.providers) { provider in
                        ProviderListRow(
                            provider: provider,
                            onToggle: { Task { await viewModel.toggleProvider(provider) } }
                        )
                        .tag(provider.id)
                        .contextMenu {
                            Button("Edit") { viewModel.editProvider(provider) }
                            Divider()
                            Button("Delete", role: .destructive) {
                                viewModel.requestDeleteProvider(provider)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()

            // Bottom toolbar
            HStack(spacing: 4) {
                Button {
                    viewModel.addProvider()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Add provider")

                Button {
                    if let provider = viewModel.selectedProvider {
                        viewModel.requestDeleteProvider(provider)
                    }
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.selectedProvider == nil)
                .help("Remove selected provider")

                Spacer()

                if !viewModel.providers.isEmpty {
                    Text(
                        "\(viewModel.providers.filter(\.isEnabled).count) of \(viewModel.providers.count) enabled"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Provider Detail

    private func providerDetail(_ provider: IdentityProvider) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Provider header
                providerHeader(provider)

                // Status section
                providerStatusSection(provider)

                // Configuration summary
                providerConfigSummary(provider)

                // Actions
                providerActions(provider)

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private func providerHeader(_ provider: IdentityProvider) -> some View {
        HStack(spacing: 14) {
            Image(systemName: provider.type == .saml ? "key.fill" : "lock.shield.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.accentColor)
                .frame(width: 52, height: 52)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(provider.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack(spacing: 6) {
                    ProviderTypeBadge(type: provider.type)

                    ConnectionStatusBadge(isEnabled: provider.isEnabled, isConfigured: provider.isConfigured)
                }
            }

            Spacer()

            Toggle("Enabled", isOn: .init(
                get: { provider.isEnabled },
                set: { _ in Task { await viewModel.toggleProvider(provider) } }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .help(provider.isEnabled ? String(localized: "Disable this provider") : String(localized: "Enable this provider"))
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func providerStatusSection(_ provider: IdentityProvider) -> some View {
        GroupBox("Status") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Provider ID") {
                    Text(provider.id.uuidString)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                LabeledContent("Entity ID") {
                    Text(provider.entityId.isEmpty ? "Not set" : provider.entityId)
                        .foregroundStyle(provider.entityId.isEmpty ? .tertiary : .secondary)
                        .textSelection(.enabled)
                }

                LabeledContent("Created") {
                    Text(provider.createdAt, style: .date)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Last Updated") {
                    Text(provider.updatedAt, style: .relative)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func providerConfigSummary(_ provider: IdentityProvider) -> some View {
        GroupBox("Configuration") {
            VStack(alignment: .leading, spacing: 8) {
                if !provider.isConfigured {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Provider is not fully configured. Tap Edit to complete setup.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else if provider.type == .saml, let saml = provider.samlConfig {
                    LabeledContent("SSO URL") {
                        Text(saml.ssoURL.absoluteString)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    LabeledContent("Binding") {
                        Text(saml.binding.displayNameKey)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("NameID Format") {
                        Text(saml.nameIDFormat.shortDisplayName)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Sign AuthnRequests") {
                        Text(saml.signAuthnRequests ? String(localized: "Yes") : String(localized: "No"))
                            .foregroundStyle(.secondary)
                    }
                } else if provider.type == .oidc, let oidc = provider.oidcConfig {
                    LabeledContent("Issuer URL") {
                        Text(oidc.issuerURL.absoluteString)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    LabeledContent("Client ID") {
                        Text(oidc.clientId.isEmpty ? "Not set" : oidc.clientId)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("PKCE") {
                        Text(oidc.usePKCE ? String(localized: "Enabled") : String(localized: "Disabled"))
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Scopes") {
                        Text(oidc.scopeString)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func providerActions(_ provider: IdentityProvider) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button("Edit") {
                    viewModel.editProvider(provider)
                }
                .buttonStyle(.bordered)

                Button("Delete", role: .destructive) {
                    viewModel.requestDeleteProvider(provider)
                }
                .buttonStyle(.bordered)

                Spacer()

                if viewModel.isTestingConnection {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                }

                Button("Test Connection") {
                    Task { await viewModel.testConnection(provider) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!provider.isConfigured || viewModel.isTestingConnection)
                .help("Verify connectivity to this identity provider")
            }

            // Test result banner
            if let result = viewModel.testResult {
                HStack(spacing: 8) {
                    Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.isSuccess ? Color.green : Color.red)
                    Text(result.message)
                        .font(.callout)
                        .foregroundStyle(result.isSuccess ? Color.green : Color.red)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    (result.isSuccess ? Color.green : Color.red).opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }
        }
    }

    // MARK: - Empty Detail State

    private var emptyDetailState: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Provider Selected")
                .font(.title2)

            Text("Select an identity provider from the list, or add a new one to get started.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button("Add Identity Provider") {
                viewModel.addProvider()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Form Sheet

    @ViewBuilder
    private var providerFormSheet: some View {
        IdentityProviderFormView(
            provider: viewModel.editingProvider,
            onSave: { saved in
                Task {
                    await viewModel.saveProvider(saved)
                    viewModel.isShowingForm = false
                    viewModel.selectedProvider = saved
                }
            },
            onCancel: {
                viewModel.isShowingForm = false
            },
            onTestConnection: { provider in
                Task { await viewModel.testConnection(provider) }
            },
            testResult: $viewModel.testResult,
            isTestingConnection: $viewModel.isTestingConnection
        )
        .frame(minWidth: 560, minHeight: 500)
    }

}

// MARK: - Provider List Row

private struct ProviderListRow: View {
    let provider: IdentityProvider
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: provider.type == .saml ? "key.fill" : "lock.shield.fill")
                .font(.body)
                .foregroundStyle(provider.isEnabled ? Color.accentColor : Color.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.body)
                    .lineLimit(1)

                ProviderTypeBadge(type: provider.type)
            }

            Spacer()

            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .help(statusHelp)
        }
        .padding(.vertical, 3)
    }

    private var statusColor: Color {
        if !provider.isConfigured { return .orange }
        return provider.isEnabled ? .green : .secondary
    }

    private var statusHelp: String {
        if !provider.isConfigured { return String(localized: "Incomplete configuration") }
        return provider.isEnabled ? String(localized: "Active") : String(localized: "Disabled")
    }
}

// MARK: - Provider Type Badge

private struct ProviderTypeBadge: View {
    let type: IdentityProviderType

    var body: some View {
        Text(type.displayNameKey)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15), in: Capsule())
            .foregroundStyle(badgeColor)
    }

    private var badgeColor: Color {
        switch type {
        case .saml: return .blue
        case .oidc: return .purple
        }
    }
}

// MARK: - Connection Status Badge

private struct ConnectionStatusBadge: View {
    let isEnabled: Bool
    let isConfigured: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dotColor: Color {
        if !isConfigured { return .orange }
        return isEnabled ? .green : .secondary
    }

    private var label: String {
        if !isConfigured { return String(localized: "Incomplete") }
        return isEnabled ? String(localized: "Active") : String(localized: "Disabled")
    }
}

// MARK: - SAMLNameIDFormat Display Helper

private extension SAMLNameIDFormat {
    var shortDisplayName: LocalizedStringResource {
        switch self {
        case .emailAddress: return "Email Address"
        case .persistent: return "Persistent"
        case .transient: return "Transient"
        case .entity: return "Entity"
        case .kerberos: return "Kerberos"
        case .windowsDomainQualifiedName: return "Windows Domain"
        case .x509SubjectName: return "X.509 Subject"
        case .unspecified: return "Unspecified"
        }
    }
}

// MARK: - Previews

#if DEBUG
    struct SSOSettingsView_Previews: PreviewProvider {
        static var previews: some View {
            SSOSettingsView()
                .frame(width: 700, height: 460)
        }
    }
#endif
