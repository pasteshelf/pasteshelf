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
    // MARK: Internal

    // MARK: - Body

    var body: some View {
        self.ssoContent
    }

    // MARK: Private

    @StateObject private var viewModel = SSOSettingsViewModel()

    // MARK: - Main Content

    private var ssoContent: some View {
        HSplitView {
            self.providerList
                .frame(minWidth: 220, maxWidth: 300)

            if let provider = viewModel.selectedProvider {
                providerDetail(provider)
            } else {
                self.emptyDetailState
            }
        }
        .frame(minHeight: 380)
        .onAppear {
            Task { await self.viewModel.loadProviders() }
        }
        .sheet(isPresented: self.$viewModel.isShowingForm) {
            self.providerFormSheet
        }
        .confirmationDialog(
            "Delete Identity Provider",
            isPresented: self.$viewModel.isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if let provider = viewModel.selectedProvider {
                Button("Delete \"\(provider.name)\"", role: .destructive) {
                    Task { await self.viewModel.deleteProvider(provider) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Error", isPresented: .init(
            get: { self.viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    self.viewModel.errorMessage = nil
                }
            }
        )) {
            Button("OK") { self.viewModel.errorMessage = nil }
        } message: {
            Text(self.viewModel.errorMessage ?? "")
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
                    self.viewModel.addProvider()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("Add Identity Provider")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if self.viewModel.providers.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "key.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No providers configured")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Add Provider") {
                        self.viewModel.addProvider()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.accentColor)
                }
                Spacer()
            } else {
                List(selection: self.$viewModel.selectedProviderID) {
                    ForEach(self.viewModel.providers) { provider in
                        ProviderListRow(
                            provider: provider
                        ) { Task { await self.viewModel.toggleProvider(provider) } }
                            .tag(provider.id)
                            .contextMenu {
                                Button("Edit") { self.viewModel.editProvider(provider) }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    self.viewModel.requestDeleteProvider(provider)
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
                    self.viewModel.addProvider()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Add provider")

                Button {
                    if let provider = viewModel.selectedProvider {
                        self.viewModel.requestDeleteProvider(provider)
                    }
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .disabled(self.viewModel.selectedProvider == nil)
                .help("Remove selected provider")

                Spacer()

                if !self.viewModel.providers.isEmpty {
                    Text(
                        // swiftlint:disable:next line_length
                        "\(self.viewModel.providers.filter(\.isEnabled).count) of \(self.viewModel.providers.count) enabled"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
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
                self.viewModel.addProvider()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Form Sheet

    private var providerFormSheet: some View {
        IdentityProviderFormView(
            provider: self.viewModel.editingProvider,
            onSave: { saved in
                Task {
                    await self.viewModel.saveProvider(saved)
                    self.viewModel.isShowingForm = false
                    self.viewModel.selectedProvider = saved
                }
            },
            onCancel: {
                self.viewModel.isShowingForm = false
            },
            onTestConnection: { provider in
                Task { await self.viewModel.testConnection(provider) }
            },
            testResult: self.$viewModel.testResult,
            isTestingConnection: self.$viewModel.isTestingConnection
        )
        .frame(minWidth: 560, minHeight: 500)
    }
}

// MARK: - SSOSettingsView + Provider Detail

extension SSOSettingsView {
    func providerDetail(_ provider: IdentityProvider) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                self.providerHeader(provider)
                self.providerStatusSection(provider)
                self.providerConfigSummary(provider)
                self.providerActions(provider)
                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    func providerHeader(_ provider: IdentityProvider) -> some View {
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
                    ConnectionStatusBadge(
                        isEnabled: provider.isEnabled,
                        isConfigured: provider.isConfigured
                    )
                }
            }

            Spacer()

            Toggle("Enabled", isOn: .init(
                get: { provider.isEnabled },
                set: { _ in Task { await self.viewModel.toggleProvider(provider) } }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .help(provider.isEnabled ? "Disable this provider" : "Enable this provider")
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    func providerStatusSection(_ provider: IdentityProvider) -> some View {
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

    func providerConfigSummary(_ provider: IdentityProvider) -> some View {
        GroupBox("Configuration") {
            VStack(alignment: .leading, spacing: 8) {
                if !provider.isConfigured {
                    self.configIncompleteRow
                } else if provider.type == .saml, let saml = provider.samlConfig {
                    self.samlConfigRows(saml)
                } else if provider.type == .oidc, let oidc = provider.oidcConfig {
                    self.oidcConfigRows(oidc)
                }
            }
            .padding(.vertical, 4)
        }
    }

    var configIncompleteRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Provider is not fully configured. Tap Edit to complete setup.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    func samlConfigRows(_ saml: SAMLProviderConfig) -> some View {
        LabeledContent("SSO URL") {
            Text(saml.ssoURL.absoluteString)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        LabeledContent("Binding") {
            Text(saml.binding.displayName)
                .foregroundStyle(.secondary)
        }
        LabeledContent("NameID Format") {
            Text(saml.nameIDFormat.shortDisplayName)
                .foregroundStyle(.secondary)
        }
        LabeledContent("Sign AuthnRequests") {
            Text(saml.signAuthnRequests ? "Yes" : "No")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    func oidcConfigRows(_ oidc: OIDCProviderConfig) -> some View {
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
            Text(oidc.usePKCE ? "Enabled" : "Disabled")
                .foregroundStyle(.secondary)
        }
        LabeledContent("Scopes") {
            Text(oidc.scopeString)
                .foregroundStyle(.secondary)
        }
    }

    func providerActions(_ provider: IdentityProvider) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button("Edit") {
                    self.viewModel.editProvider(provider)
                }
                .buttonStyle(.bordered)

                Button("Delete", role: .destructive) {
                    self.viewModel.requestDeleteProvider(provider)
                }
                .buttonStyle(.bordered)

                Spacer()

                if self.viewModel.isTestingConnection {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                }

                Button("Test Connection") {
                    Task { await self.viewModel.testConnection(provider) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!provider.isConfigured || self.viewModel.isTestingConnection)
                .help("Verify connectivity to this identity provider")
            }

            // Test result banner
            if let result = viewModel.testResult {
                HStack(spacing: 8) {
                    Image(
                        systemName: result.isSuccess
                            ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
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
