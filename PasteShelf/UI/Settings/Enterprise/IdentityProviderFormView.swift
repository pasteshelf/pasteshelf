//
//  IdentityProviderFormView.swift
//  PasteShelf
//
//  Form for adding or editing an Identity Provider configuration.
//  Supports both SAML 2.0 and OpenID Connect (OIDC) providers.
//
//  Covers PASTESHELF-149 (metadata URL input) and PASTESHELF-150 (test connection button).
//

import SwiftUI

// MARK: - IdentityProviderFormView

/// Add/Edit form for an Identity Provider.
///
/// When `provider` is nil, the form creates a new provider. When non-nil, it pre-fills with
/// the existing configuration and updates on save.
struct IdentityProviderFormView: View {
    // MARK: Internal

    // MARK: - Inputs

    /// Existing provider to edit; nil when creating a new one
    let provider: IdentityProvider?
    let onSave: (IdentityProvider) -> Void
    let onCancel: () -> Void
    let onTestConnection: (IdentityProvider) -> Void

    @Binding var testResult: SSOSettingsViewModel.TestConnectionResult?
    @Binding var isTestingConnection: Bool

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(provider == nil ? "Add Identity Provider" : "Edit Identity Provider")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 12)

            Divider()

            // Scrollable form body
            ScrollView {
                Form {
                    generalSection
                    typeSpecificSection
                    testConnectionSection
                }
                .formStyle(.grouped)
                .padding(.bottom, 8)
            }

            Divider()

            // Footer buttons
            footerButtons
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .onAppear { populateFromProvider() }
    }

    // MARK: Private

    // MARK: - Shared fields

    @State private var name: String = ""
    @State private var entityId: String = ""
    @State private var providerType: IdentityProviderType = .saml
    @State private var isEnabled: Bool = false

    // MARK: - SAML fields

    @State private var samlSSOURL: String = ""
    @State private var samlSLOURL: String = ""
    @State private var samlCertificate: String = ""
    @State private var samlSignAuthnRequests: Bool = false
    @State private var samlNameIDFormat: SAMLNameIDFormat = .emailAddress
    @State private var samlBinding: SAMLBinding = .httpPost
    @State private var samlACSURL: String = ""
    @State private var samlAudienceRestriction: String = ""

    // SAML metadata URL
    @State private var samlMetadataURL: String = ""
    @State private var isFetchingMetadata: Bool = false
    @State private var metadataFetchError: String?

    // MARK: - OIDC fields

    @State private var oidcIssuerURL: String = ""
    @State private var oidcAuthorizationEndpoint: String = ""
    @State private var oidcTokenEndpoint: String = ""
    @State private var oidcUserInfoEndpoint: String = ""
    @State private var oidcJWKSURL: String = ""
    @State private var oidcEndSessionEndpoint: String = ""
    @State private var oidcClientId: String = ""
    @State private var oidcClientSecret: String = ""
    @State private var oidcRedirectURI: String = ""
    @State private var oidcScopes: String = "openid profile email"
    @State private var oidcUsePKCE: Bool = true
    @State private var oidcUseDiscovery: Bool = true

    @State private var isDiscovering: Bool = false
    @State private var discoveryError: String?

    // MARK: - Validation

    @State private var validationErrors: [String] = []

    // MARK: - Validation

    private var isFormValid: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }
        switch providerType {
        case .saml:
            return !samlSSOURL.isEmpty && !samlCertificate.isEmpty && !samlACSURL.isEmpty
        case .oidc:
            let hasEndpoints = oidcUseDiscovery
                ? !oidcAuthorizationEndpoint.isEmpty // populated after discovery
                : !oidcAuthorizationEndpoint.isEmpty && !oidcTokenEndpoint.isEmpty && !oidcJWKSURL.isEmpty
            return !oidcIssuerURL.isEmpty && !oidcClientId.isEmpty && !oidcRedirectURI.isEmpty && hasEndpoints
        }
    }

    private var canTest: Bool {
        switch providerType {
        case .saml: !samlSSOURL.isEmpty
        case .oidc: !oidcIssuerURL.isEmpty
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section {
            LabeledContent("Name") {
                TextField("e.g. Okta, Azure AD, Google Workspace", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Provider name")
            }

            LabeledContent("Entity ID / Issuer URI") {
                TextField("https://idp.example.com/saml", text: $entityId)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Entity ID")
            }

            LabeledContent("Protocol") {
                Picker("Protocol", selection: $providerType) {
                    ForEach(IdentityProviderType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 260)
            }

            Toggle("Enable this provider", isOn: $isEnabled)
                .accessibilityLabel("Enable provider")
                .accessibilityHint("When enabled, this provider is offered to users at sign-in")
        } header: {
            Text("General")
        }
    }

    // MARK: - Type-Specific Section

    @ViewBuilder private var typeSpecificSection: some View {
        switch providerType {
        case .saml:
            samlSection
        case .oidc:
            oidcSection
        }
    }
}

// MARK: - IdentityProviderFormView + Subviews

extension IdentityProviderFormView {
    // MARK: - SAML Section

    var samlSection: some View {
        Group {
            samlMetadataSection
            samlEndpointsSection
            samlCertificateSection
            samlProtocolSection
            samlServiceProviderSection
        }
    }

    var samlMetadataSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(
                    "Paste the IdP metadata URL below and click Fetch"
                        + " to auto-populate the SAML configuration."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    TextField("https://idp.example.com/metadata.xml", text: $samlMetadataURL)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("IdP metadata URL")

                    Button {
                        fetchSAMLMetadata()
                    } label: {
                        if isFetchingMetadata {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Fetch")
                        }
                    }
                    .disabled(samlMetadataURL.isEmpty || isFetchingMetadata)
                    .buttonStyle(.bordered)
                    .frame(width: 70)
                    .help("Fetch and parse the IdP metadata document")
                }

                if let error = metadataFetchError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Metadata URL")
        } footer: {
            Text("Optional: auto-populate settings from your IdP's metadata document.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    var samlEndpointsSection: some View {
        Section {
            LabeledContent("SSO URL") {
                TextField("https://idp.example.com/sso/saml", text: $samlSSOURL)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Single Sign-On URL")
            }

            LabeledContent("SLO URL") {
                TextField("https://idp.example.com/slo/saml (optional)", text: $samlSLOURL)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Single Logout URL")
            }
        } header: {
            Text("Identity Provider Endpoints")
        }
    }

    var samlCertificateSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Paste the PEM-encoded X.509 certificate used to verify IdP-signed assertions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $samlCertificate)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 100, maxHeight: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .accessibilityLabel("IdP signing certificate (PEM)")
            }
            .padding(.vertical, 4)
        } header: {
            Text("Signing Certificate")
        }
    }

    var samlProtocolSection: some View {
        Section {
            LabeledContent("NameID Format") {
                Picker("NameID Format", selection: $samlNameIDFormat) {
                    Text("Email Address").tag(SAMLNameIDFormat.emailAddress)
                    Text("Persistent").tag(SAMLNameIDFormat.persistent)
                    Text("Transient").tag(SAMLNameIDFormat.transient)
                    Text("Unspecified").tag(SAMLNameIDFormat.unspecified)
                    Text("Entity").tag(SAMLNameIDFormat.entity)
                    Text("X.509 Subject").tag(SAMLNameIDFormat.x509SubjectName)
                    Text("Windows Domain").tag(SAMLNameIDFormat.windowsDomainQualifiedName)
                    Text("Kerberos").tag(SAMLNameIDFormat.kerberos)
                }
                .labelsHidden()
                .frame(maxWidth: 220)
            }

            LabeledContent("HTTP Binding") {
                Picker("HTTP Binding", selection: $samlBinding) {
                    ForEach(SAMLBinding.allCases, id: \.self) { binding in
                        Text(binding.displayName).tag(binding)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
            }

            Toggle("Sign AuthnRequests", isOn: $samlSignAuthnRequests)
                .accessibilityLabel("Sign outgoing AuthnRequest messages")
        } header: {
            Text("Protocol Settings")
        }
    }

    var samlServiceProviderSection: some View {
        Section {
            LabeledContent("ACS URL") {
                TextField("https://app.pasteshelf.app/sso/acs", text: $samlACSURL)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Assertion Consumer Service URL")
            }

            LabeledContent("Audience Restriction") {
                TextField("https://app.pasteshelf.app", text: $samlAudienceRestriction)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("SP entity ID / audience restriction")
            }
        } header: {
            Text("Service Provider")
        } footer: {
            Text("Register these values with your identity provider.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Test Connection Section (PASTESHELF-150)

    var testConnectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    "Verify that PasteShelf can reach the identity provider"
                        + " using the current configuration."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    if isTestingConnection {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button("Test Connection") {
                        guard let built = buildProvider() else {
                            return
                        }
                        onTestConnection(built)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isTestingConnection || !canTest)
                    .help("Send a connectivity check to the identity provider")
                }

                // Result banner
                if let result = testResult {
                    HStack(spacing: 8) {
                        Image(
                            systemName: result.isSuccess
                                ? "checkmark.circle.fill"
                                : "xmark.circle.fill"
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
            .padding(.vertical, 4)
        } header: {
            Text("Test Connection")
        }
    }

    // MARK: - Footer Buttons

    var footerButtons: some View {
        HStack {
            // Validation errors
            if !validationErrors.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(validationErrors, id: \.self) { error in
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }

            Spacer()

            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                saveProvider()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!isFormValid)
        }
    }
}
