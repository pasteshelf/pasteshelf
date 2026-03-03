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
    // MARK: - Inputs

    /// Existing provider to edit; nil when creating a new one
    let provider: IdentityProvider?
    let onSave: (IdentityProvider) -> Void
    let onCancel: () -> Void
    let onTestConnection: (IdentityProvider) -> Void
    @Binding var testResult: SSOSettingsViewModel.TestConnectionResult?
    @Binding var isTestingConnection: Bool

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

    @ViewBuilder
    private var typeSpecificSection: some View {
        switch providerType {
        case .saml:
            samlSection
        case .oidc:
            oidcSection
        }
    }

    // MARK: - SAML Section

    private var samlSection: some View {
        Group {
            // Metadata URL sub-section (PASTESHELF-149)
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste the IdP metadata URL below and click Fetch to auto-populate the SAML configuration.")
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

            // IdP Endpoints
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

            // Certificate
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

            // Protocol settings
            Section {
                LabeledContent("NameID Format") {
                    Picker("NameID Format", selection: $samlNameIDFormat) {
                        Text("Email Address").tag(SAMLNameIDFormat.emailAddress)
                        Text("Persistent").tag(SAMLNameIDFormat.persistent)
                        Text("Transient").tag(SAMLNameIDFormat.transient)
                        Text("Unspecified").tag(SAMLNameIDFormat.unspecified)
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

            // Service Provider configuration
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
    }

    // MARK: - OIDC Section

    private var oidcSection: some View {
        Group {
            // Discovery / Issuer
            Section {
                Toggle("Use Discovery Document", isOn: $oidcUseDiscovery)
                    .accessibilityLabel("Auto-populate endpoints from well-known discovery document")

                LabeledContent("Issuer URL") {
                    HStack(spacing: 8) {
                        TextField("https://accounts.google.com", text: $oidcIssuerURL)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("OIDC issuer URL")

                        if oidcUseDiscovery {
                            Button {
                                discoverOIDCConfig()
                            } label: {
                                if isDiscovering {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("Discover")
                                }
                            }
                            .disabled(oidcIssuerURL.isEmpty || isDiscovering)
                            .buttonStyle(.bordered)
                            .frame(width: 90)
                            .help("Fetch endpoints from \(oidcIssuerURL)/.well-known/openid-configuration")
                        }
                    }
                }

                if let error = discoveryError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            } header: {
                Text("Provider Discovery")
            } footer: {
                Text("Enable discovery to auto-populate authorization, token, and JWKS endpoints from the issuer's well-known document.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Manual endpoints (shown when discovery is off, or populated after discovery)
            if !oidcUseDiscovery {
                Section {
                    LabeledContent("Authorization Endpoint") {
                        TextField("https://example.com/oauth/authorize", text: $oidcAuthorizationEndpoint)
                            .textFieldStyle(.roundedBorder)
                    }

                    LabeledContent("Token Endpoint") {
                        TextField("https://example.com/oauth/token", text: $oidcTokenEndpoint)
                            .textFieldStyle(.roundedBorder)
                    }

                    LabeledContent("JWKS URL") {
                        TextField("https://example.com/.well-known/jwks.json", text: $oidcJWKSURL)
                            .textFieldStyle(.roundedBorder)
                    }

                    LabeledContent("UserInfo Endpoint") {
                        TextField("https://example.com/userinfo (optional)", text: $oidcUserInfoEndpoint)
                            .textFieldStyle(.roundedBorder)
                    }

                    LabeledContent("End-Session Endpoint") {
                        TextField("https://example.com/logout (optional)", text: $oidcEndSessionEndpoint)
                            .textFieldStyle(.roundedBorder)
                    }
                } header: {
                    Text("Endpoints")
                }
            } else if !oidcAuthorizationEndpoint.isEmpty {
                // Show discovered endpoints as read-only summary
                Section {
                    LabeledContent("Authorization") {
                        Text(oidcAuthorizationEndpoint)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    LabeledContent("Token") {
                        Text(oidcTokenEndpoint)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    LabeledContent("JWKS") {
                        Text(oidcJWKSURL)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                } header: {
                    Text("Discovered Endpoints")
                } footer: {
                    Text("Populated automatically from the discovery document.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Client credentials
            Section {
                LabeledContent("Client ID") {
                    TextField("your-client-id", text: $oidcClientId)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("OIDC client identifier")
                }

                LabeledContent("Client Secret") {
                    SecureField("Leave blank for public clients", text: $oidcClientSecret)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("OIDC client secret")
                }

                LabeledContent("Redirect URI") {
                    TextField("pasteshelf://auth/callback", text: $oidcRedirectURI)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("OAuth redirect URI")
                }
            } header: {
                Text("Client Credentials")
            }

            // Flow configuration
            Section {
                LabeledContent("Scopes") {
                    TextField("openid profile email", text: $oidcScopes)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("OAuth scopes (space-separated)")
                }

                Toggle("Use PKCE", isOn: $oidcUsePKCE)
                    .accessibilityLabel("Proof Key for Code Exchange")
                    .accessibilityHint("Recommended for public clients; requires the provider to support S256")
            } header: {
                Text("Flow Configuration")
            } footer: {
                Text("PKCE is recommended for desktop clients and does not require a client secret.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Test Connection Section (PASTESHELF-150)

    private var testConnectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Verify that PasteShelf can reach the identity provider using the current configuration.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    if isTestingConnection {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button("Test Connection") {
                        guard let built = buildProvider() else { return }
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

    private var footerButtons: some View {
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

    // MARK: - Validation

    private var isFormValid: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch providerType {
        case .saml:
            return !samlSSOURL.isEmpty && !samlCertificate.isEmpty && !samlACSURL.isEmpty
        case .oidc:
            let hasEndpoints = oidcUseDiscovery
                ? !oidcAuthorizationEndpoint.isEmpty  // populated after discovery
                : !oidcAuthorizationEndpoint.isEmpty && !oidcTokenEndpoint.isEmpty && !oidcJWKSURL.isEmpty
            return !oidcIssuerURL.isEmpty && !oidcClientId.isEmpty && !oidcRedirectURI.isEmpty && hasEndpoints
        }
    }

    private var canTest: Bool {
        switch providerType {
        case .saml: return !samlSSOURL.isEmpty
        case .oidc: return !oidcIssuerURL.isEmpty
        }
    }

    // MARK: - Save

    private func saveProvider() {
        validationErrors = []

        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationErrors = ["Provider name is required."]
            return
        }

        guard let built = buildProvider() else { return }
        onSave(built)
    }

    /// Constructs an IdentityProvider from the current form state
    private func buildProvider() -> IdentityProvider? {
        let id = provider?.id ?? UUID()
        let now = Date()

        switch providerType {
        case .saml:
            guard let ssoURL = URL(string: samlSSOURL), !samlSSOURL.isEmpty else {
                validationErrors = ["SSO URL is not a valid URL."]
                return nil
            }

            let sloURL = samlSLOURL.isEmpty ? nil : URL(string: samlSLOURL)

            let saml = SAMLProviderConfig(
                ssoURL: ssoURL,
                sloURL: sloURL,
                certificate: samlCertificate,
                signAuthnRequests: samlSignAuthnRequests,
                nameIDFormat: samlNameIDFormat,
                binding: samlBinding,
                assertionConsumerServiceURL: samlACSURL,
                audienceRestriction: samlAudienceRestriction
            )

            return IdentityProvider(
                id: id,
                name: name.trimmingCharacters(in: .whitespaces),
                type: .saml,
                entityId: entityId,
                isEnabled: isEnabled,
                createdAt: provider?.createdAt ?? now,
                updatedAt: now,
                samlConfig: saml,
                oidcConfig: nil
            )

        case .oidc:
            guard let issuer = URL(string: oidcIssuerURL), !oidcIssuerURL.isEmpty,
                  let authEndpoint = URL(string: oidcAuthorizationEndpoint), !oidcAuthorizationEndpoint.isEmpty,
                  let tokenEndpoint = URL(string: oidcTokenEndpoint), !oidcTokenEndpoint.isEmpty,
                  let jwksURL = URL(string: oidcJWKSURL), !oidcJWKSURL.isEmpty
            else {
                validationErrors = ["One or more OIDC endpoint URLs are invalid."]
                return nil
            }

            let userInfo = oidcUserInfoEndpoint.isEmpty ? nil : URL(string: oidcUserInfoEndpoint)
            let endSession = oidcEndSessionEndpoint.isEmpty ? nil : URL(string: oidcEndSessionEndpoint)
            let secret: String? = oidcClientSecret.isEmpty ? nil : oidcClientSecret
            let scopes = oidcScopes
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            let oidc = OIDCProviderConfig(
                issuerURL: issuer,
                authorizationEndpoint: authEndpoint,
                tokenEndpoint: tokenEndpoint,
                userInfoEndpoint: userInfo,
                jwksURL: jwksURL,
                endSessionEndpoint: endSession,
                clientId: oidcClientId,
                clientSecret: secret,
                scopes: scopes.isEmpty ? ["openid", "profile", "email"] : scopes,
                responseType: "code",
                usePKCE: oidcUsePKCE,
                redirectURI: oidcRedirectURI
            )

            return IdentityProvider(
                id: id,
                name: name.trimmingCharacters(in: .whitespaces),
                type: .oidc,
                entityId: entityId,
                isEnabled: isEnabled,
                createdAt: provider?.createdAt ?? now,
                updatedAt: now,
                samlConfig: nil,
                oidcConfig: oidc
            )
        }
    }

    // MARK: - Populate from Existing Provider

    private func populateFromProvider() {
        guard let p = provider else { return }

        name = p.name
        entityId = p.entityId
        providerType = p.type
        isEnabled = p.isEnabled

        if let saml = p.samlConfig {
            samlSSOURL = saml.ssoURL.absoluteString
            samlSLOURL = saml.sloURL?.absoluteString ?? ""
            samlCertificate = saml.certificate
            samlSignAuthnRequests = saml.signAuthnRequests
            samlNameIDFormat = saml.nameIDFormat
            samlBinding = saml.binding
            samlACSURL = saml.assertionConsumerServiceURL
            samlAudienceRestriction = saml.audienceRestriction
        }

        if let oidc = p.oidcConfig {
            oidcIssuerURL = oidc.issuerURL.absoluteString
            oidcAuthorizationEndpoint = oidc.authorizationEndpoint.absoluteString
            oidcTokenEndpoint = oidc.tokenEndpoint.absoluteString
            oidcUserInfoEndpoint = oidc.userInfoEndpoint?.absoluteString ?? ""
            oidcJWKSURL = oidc.jwksURL.absoluteString
            oidcEndSessionEndpoint = oidc.endSessionEndpoint?.absoluteString ?? ""
            oidcClientId = oidc.clientId
            oidcClientSecret = oidc.clientSecret ?? ""
            oidcRedirectURI = oidc.redirectURI
            oidcScopes = oidc.scopeString
            oidcUsePKCE = oidc.usePKCE
            // If we have endpoints, treat as already discovered
            oidcUseDiscovery = true
        }
    }

    // MARK: - OIDC Discovery

    private func discoverOIDCConfig() {
        guard let url = URL(string: oidcIssuerURL) else {
            discoveryError = "Invalid issuer URL."
            return
        }

        isDiscovering = true
        discoveryError = nil

        Task {
            defer { isDiscovering = false }

            do {
                let discovery = OIDCDiscovery()
                let doc = try await discovery.discover(issuerURL: url)

                oidcAuthorizationEndpoint = doc.authorizationEndpoint
                oidcTokenEndpoint = doc.tokenEndpoint
                oidcJWKSURL = doc.jwksUri
                oidcUserInfoEndpoint = doc.userinfoEndpoint ?? ""
                oidcEndSessionEndpoint = doc.endSessionEndpoint ?? ""

                // Pre-fill scopes if empty
                if oidcScopes.trimmingCharacters(in: .whitespaces).isEmpty,
                   let supported = doc.scopesSupported
                {
                    let defaults = ["openid", "profile", "email"]
                    let intersection = defaults.filter { supported.contains($0) }
                    oidcScopes = intersection.joined(separator: " ")
                }

                // Auto-set entity ID from issuer if empty
                if entityId.isEmpty { entityId = doc.issuer }

                discoveryError = nil
            } catch {
                discoveryError = error.localizedDescription
            }
        }
    }

    // MARK: - SAML Metadata Fetch

    /// Fetches and parses the IdP metadata XML document, then pre-fills SAML fields.
    ///
    /// A full metadata parser is out of scope here; we extract common fields that are
    /// available in standard IdP metadata documents using basic string scanning.
    private func fetchSAMLMetadata() {
        guard let url = URL(string: samlMetadataURL) else {
            metadataFetchError = "Invalid metadata URL."
            return
        }

        isFetchingMetadata = true
        metadataFetchError = nil

        Task {
            defer { isFetchingMetadata = false }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    metadataFetchError = "Server returned an unexpected response."
                    return
                }

                guard let xml = String(data: data, encoding: .utf8) else {
                    metadataFetchError = "Could not decode metadata document."
                    return
                }

                // Extract the SSO URL from SingleSignOnService element
                if let ssoRange = xml.range(of: "SingleSignOnService"),
                   let locationStart = xml[ssoRange.upperBound...].range(of: "Location=\""),
                   let locationEnd = xml[locationStart.upperBound...].range(of: "\"")
                {
                    let extracted = String(xml[locationStart.upperBound..<locationEnd.lowerBound])
                    if !extracted.isEmpty { samlSSOURL = extracted }
                }

                // Extract entityID from EntityDescriptor
                if let entityRange = xml.range(of: "entityID=\""),
                   let entityEnd = xml[entityRange.upperBound...].range(of: "\"")
                {
                    let extracted = String(xml[entityRange.upperBound..<entityEnd.lowerBound])
                    if !extracted.isEmpty {
                        entityId = extracted
                    }
                }

                // Extract X509Certificate
                if let certStart = xml.range(of: "<ds:X509Certificate>") ?? xml.range(of: "<X509Certificate>"),
                   let certTag = xml.range(of: certStart.lowerBound == xml.startIndex ? "<ds:X509Certificate>" : "<X509Certificate>"),
                   let certEnd = xml[certTag.upperBound...].range(of: "</")
                {
                    let rawCert = String(xml[certTag.upperBound..<certEnd.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !rawCert.isEmpty {
                        samlCertificate = "-----BEGIN CERTIFICATE-----\n\(rawCert)\n-----END CERTIFICATE-----"
                    }
                }

                metadataFetchError = nil
            } catch {
                metadataFetchError = "Failed to fetch metadata: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - SAMLNameIDFormat + CaseIterable convenience

extension SAMLNameIDFormat: CaseIterable {
    static var allCases: [SAMLNameIDFormat] {
        [.emailAddress, .persistent, .transient, .unspecified,
         .entity, .kerberos, .windowsDomainQualifiedName, .x509SubjectName]
    }
}

// MARK: - Previews

#if DEBUG
    struct IdentityProviderFormView_Previews: PreviewProvider {
        static var previews: some View {
            IdentityProviderFormView(
                provider: nil,
                onSave: { _ in },
                onCancel: {},
                onTestConnection: { _ in },
                testResult: .constant(nil),
                isTestingConnection: .constant(false)
            )
            .frame(width: 560, height: 560)
        }
    }
#endif
