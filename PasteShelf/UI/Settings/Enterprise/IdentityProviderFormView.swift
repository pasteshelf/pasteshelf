//
//  IdentityProviderFormView.swift
//  PasteShelf
//
// swiftlint:disable file_length
//  Form for adding or editing an Identity Provider configuration.
//  Supports both SAML 2.0 and OpenID Connect (OIDC) providers.
//
// swiftformat:disable organizeDeclarations
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
                Text(self.provider == nil ? "Add Identity Provider" : "Edit Identity Provider")
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
                    self.generalSection
                    self.typeSpecificSection
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
        guard !self.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }
        switch self.providerType {
        case .saml:
            return !self.samlSSOURL.isEmpty && !self.samlCertificate.isEmpty && !self.samlACSURL.isEmpty
        case .oidc:
            let hasEndpoints = self.oidcUseDiscovery
                ? !self.oidcAuthorizationEndpoint.isEmpty // populated after discovery
                : !self.oidcAuthorizationEndpoint.isEmpty && !self.oidcTokenEndpoint.isEmpty && !self.oidcJWKSURL
                .isEmpty
            return !self.oidcIssuerURL.isEmpty && !self.oidcClientId.isEmpty && !self.oidcRedirectURI
                .isEmpty && hasEndpoints
        }
    }

    private var canTest: Bool {
        switch self.providerType {
        case .saml: !self.samlSSOURL.isEmpty
        case .oidc: !self.oidcIssuerURL.isEmpty
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section {
            LabeledContent("Name") {
                TextField("e.g. Okta, Azure AD, Google Workspace", text: self.$name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Provider name")
            }

            LabeledContent("Entity ID / Issuer URI") {
                TextField("https://idp.example.com/saml", text: self.$entityId)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Entity ID")
            }

            LabeledContent("Protocol") {
                Picker("Protocol", selection: self.$providerType) {
                    ForEach(IdentityProviderType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 260)
            }

            Toggle("Enable this provider", isOn: self.$isEnabled)
                .accessibilityLabel("Enable provider")
                .accessibilityHint("When enabled, this provider is offered to users at sign-in")
        } header: {
            Text("General")
        }
    }

    // MARK: - Type-Specific Section

    @ViewBuilder private var typeSpecificSection: some View {
        switch self.providerType {
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
            self.samlMetadataSection
            self.samlEndpointsSection
            self.samlCertificateSection
            self.samlProtocolSection
            self.samlServiceProviderSection
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
                    TextField("https://idp.example.com/metadata.xml", text: self.$samlMetadataURL)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("IdP metadata URL")

                    Button {
                        fetchSAMLMetadata()
                    } label: {
                        if self.isFetchingMetadata {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Fetch")
                        }
                    }
                    .disabled(self.samlMetadataURL.isEmpty || self.isFetchingMetadata)
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
                TextField("https://idp.example.com/sso/saml", text: self.$samlSSOURL)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Single Sign-On URL")
            }

            LabeledContent("SLO URL") {
                TextField("https://idp.example.com/slo/saml (optional)", text: self.$samlSLOURL)
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

                TextEditor(text: self.$samlCertificate)
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
                Picker("NameID Format", selection: self.$samlNameIDFormat) {
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
                Picker("HTTP Binding", selection: self.$samlBinding) {
                    ForEach(SAMLBinding.allCases, id: \.self) { binding in
                        Text(binding.displayName).tag(binding)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
            }

            Toggle("Sign AuthnRequests", isOn: self.$samlSignAuthnRequests)
                .accessibilityLabel("Sign outgoing AuthnRequest messages")
        } header: {
            Text("Protocol Settings")
        }
    }

    var samlServiceProviderSection: some View {
        Section {
            LabeledContent("ACS URL") {
                TextField("https://app.pasteshelf.app/sso/acs", text: self.$samlACSURL)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Assertion Consumer Service URL")
            }

            LabeledContent("Audience Restriction") {
                TextField("https://app.pasteshelf.app", text: self.$samlAudienceRestriction)
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
                    if self.isTestingConnection {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button("Test Connection") {
                        guard let built = buildProvider() else {
                            return
                        }
                        self.onTestConnection(built)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(self.isTestingConnection || !self.canTest)
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
            if !self.validationErrors.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(self.validationErrors, id: \.self) { error in
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
                self.onCancel()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                saveProvider()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!self.isFormValid)
        }
    }
}

// MARK: - IdentityProviderFormView + OIDC Sections

extension IdentityProviderFormView {
    var oidcSection: some View {
        Group {
            self.oidcDiscoverySection
            self.oidcEndpointsSection
            self.oidcClientCredentialsSection
            self.oidcFlowConfigSection
        }
    }

    var oidcDiscoverySection: some View {
        Section {
            Toggle("Use Discovery Document", isOn: self.$oidcUseDiscovery)
            LabeledContent("Issuer URL") {
                HStack(spacing: 8) {
                    TextField("https://accounts.google.com", text: self.$oidcIssuerURL)
                        .textFieldStyle(.roundedBorder)
                    if self.oidcUseDiscovery {
                        Button { discoverOIDCConfig() } label: {
                            if self.isDiscovering {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Discover")
                            }
                        }
                        .disabled(self.oidcIssuerURL.isEmpty || self.isDiscovering)
                        .buttonStyle(.bordered)
                        .frame(width: 90)
                    }
                }
            }
            if let error = discoveryError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Provider Discovery")
        } footer: {
            Text("Enable discovery to auto-populate endpoints from the issuer's well-known document.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder var oidcEndpointsSection: some View {
        if !self.oidcUseDiscovery {
            Section {
                LabeledContent("Authorization Endpoint") {
                    TextField("https://example.com/oauth/authorize", text: self.$oidcAuthorizationEndpoint)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Token Endpoint") {
                    TextField("https://example.com/oauth/token", text: self.$oidcTokenEndpoint)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("JWKS URL") {
                    TextField("https://example.com/.well-known/jwks.json", text: self.$oidcJWKSURL)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("UserInfo Endpoint") {
                    TextField("https://example.com/userinfo (optional)", text: self.$oidcUserInfoEndpoint)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("End-Session Endpoint") {
                    TextField("https://example.com/logout (optional)", text: self.$oidcEndSessionEndpoint)
                        .textFieldStyle(.roundedBorder)
                }
            } header: { Text("Endpoints") }
        } else if !self.oidcAuthorizationEndpoint.isEmpty {
            Section {
                LabeledContent("Authorization") {
                    Text(self.oidcAuthorizationEndpoint).font(.caption.monospaced()).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                }
                LabeledContent("Token") {
                    Text(self.oidcTokenEndpoint).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                        .truncationMode(.middle).textSelection(.enabled)
                }
                LabeledContent("JWKS") {
                    Text(self.oidcJWKSURL).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                        .truncationMode(.middle).textSelection(.enabled)
                }
            } header: { Text("Discovered Endpoints") }
                footer: {
                    Text("Populated automatically from the discovery document.").font(.caption)
                        .foregroundStyle(.secondary)
                }
        }
    }

    var oidcClientCredentialsSection: some View {
        Section {
            LabeledContent("Client ID") {
                TextField("your-client-id", text: self.$oidcClientId).textFieldStyle(.roundedBorder)
            }
            LabeledContent("Client Secret") {
                SecureField("Leave blank for public clients", text: self.$oidcClientSecret)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent("Redirect URI") {
                TextField("pasteshelf://auth/callback", text: self.$oidcRedirectURI).textFieldStyle(.roundedBorder)
            }
        } header: { Text("Client Credentials") }
    }

    var oidcFlowConfigSection: some View {
        Section {
            LabeledContent("Scopes") {
                TextField("openid profile email", text: self.$oidcScopes).textFieldStyle(.roundedBorder)
            }
            Toggle("Use PKCE", isOn: self.$oidcUsePKCE)
        } header: { Text("Flow Configuration") }
            footer: { Text("PKCE is recommended for desktop clients.").font(.caption).foregroundStyle(.secondary) }
    }
}

// MARK: - IdentityProviderFormView + Actions

extension IdentityProviderFormView {
    func saveProvider() {
        self.validationErrors = []
        guard !self.name.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            self.validationErrors = ["Provider name is required."]; return
        }
        guard let built = buildProvider() else {
            return
        }
        self.onSave(built)
    }

    func buildProvider() -> IdentityProvider? {
        switch self.providerType {
        case .saml: self.buildSAMLProvider()
        case .oidc: self.buildOIDCProvider()
        }
    }

    func buildSAMLProvider() -> IdentityProvider? {
        let id = self.provider?.id ?? UUID()
        let now = Date()
        guard let ssoURL = URL(string: samlSSOURL),
              !samlSSOURL.isEmpty
        else {
            self.validationErrors = ["SSO URL is not a valid URL."]; return nil
        }
        let sloURL = self.samlSLOURL.isEmpty ? nil : URL(string: self.samlSLOURL)
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
            name: self.name.trimmingCharacters(in: .whitespaces),
            type: .saml,
            entityId: self.entityId,
            isEnabled: self.isEnabled,
            createdAt: self.provider?.createdAt ?? now,
            updatedAt: now,
            samlConfig: saml,
            oidcConfig: nil
        )
    }

    func buildOIDCProvider() -> IdentityProvider? {
        let id = self.provider?.id ?? UUID()
        let now = Date()
        guard let issuer = URL(string: oidcIssuerURL), !oidcIssuerURL.isEmpty,
              let authEndpoint = URL(string: oidcAuthorizationEndpoint), !oidcAuthorizationEndpoint.isEmpty,
              let tokenEndpoint = URL(string: oidcTokenEndpoint), !oidcTokenEndpoint.isEmpty,
              let jwksURL = URL(string: oidcJWKSURL),
              !oidcJWKSURL.isEmpty
        else {
            self.validationErrors = ["One or more OIDC endpoint URLs are invalid."]; return nil
        }
        let userInfo = self.oidcUserInfoEndpoint.isEmpty ? nil : URL(string: self.oidcUserInfoEndpoint)
        let endSession = self.oidcEndSessionEndpoint.isEmpty ? nil : URL(string: self.oidcEndSessionEndpoint)
        let secret: String? = self.oidcClientSecret.isEmpty ? nil : self.oidcClientSecret
        let scopes = self.oidcScopes.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
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
            usePKCE: self.oidcUsePKCE,
            redirectURI: self.oidcRedirectURI
        )
        return IdentityProvider(
            id: id,
            name: self.name.trimmingCharacters(in: .whitespaces),
            type: .oidc,
            entityId: self.entityId,
            isEnabled: self.isEnabled,
            createdAt: self.provider?.createdAt ?? now,
            updatedAt: now,
            samlConfig: nil,
            oidcConfig: oidc
        )
    }

    func populateFromProvider() {
        guard let existing = provider else {
            return
        }
        self.name = existing.name; self.entityId = existing.entityId; self.providerType = existing.type; self
            .isEnabled = existing.isEnabled
        if let saml = existing
            .samlConfig
        {
            self.samlSSOURL = saml.ssoURL.absoluteString; self.samlSLOURL = saml.sloURL?.absoluteString ?? ""; self
                .samlCertificate = saml.certificate; self.samlSignAuthnRequests = saml.signAuthnRequests; self
                .samlNameIDFormat = saml.nameIDFormat; self.samlBinding = saml.binding; self.samlACSURL = saml
                .assertionConsumerServiceURL; self.samlAudienceRestriction = saml.audienceRestriction
        }
        if let oidc = existing
            .oidcConfig
        {
            self.oidcIssuerURL = oidc.issuerURL.absoluteString; self.oidcAuthorizationEndpoint = oidc
                .authorizationEndpoint.absoluteString; self.oidcTokenEndpoint = oidc.tokenEndpoint.absoluteString; self
                .oidcUserInfoEndpoint = oidc.userInfoEndpoint?.absoluteString ?? ""; self.oidcJWKSURL = oidc.jwksURL
                .absoluteString; self.oidcEndSessionEndpoint = oidc.endSessionEndpoint?.absoluteString ?? ""; self
                .oidcClientId = oidc.clientId; self.oidcClientSecret = oidc.clientSecret ?? ""; self
                .oidcRedirectURI = oidc
                .redirectURI; self.oidcScopes = oidc.scopeString; self.oidcUsePKCE = oidc.usePKCE; self
                .oidcUseDiscovery = true
        }
    }

    func discoverOIDCConfig() {
        guard let url = URL(string: oidcIssuerURL) else {
            self.discoveryError = "Invalid issuer URL."; return
        }
        self.isDiscovering = true; self.discoveryError = nil
        Task {
            defer { isDiscovering = false }
            do {
                let discovery = OIDCDiscovery(); let doc = try await discovery.discover(issuerURL: url)
                self.oidcAuthorizationEndpoint = doc.authorizationEndpoint; self.oidcTokenEndpoint = doc
                    .tokenEndpoint; self.oidcJWKSURL = doc.jwksUri; self.oidcUserInfoEndpoint = doc
                    .userinfoEndpoint ?? ""; self.oidcEndSessionEndpoint = doc.endSessionEndpoint ?? ""
                if self.oidcScopes.trimmingCharacters(in: .whitespaces).isEmpty,
                   let supported = doc.scopesSupported
                {
                    self.oidcScopes = [
                        "openid",
                        "profile",
                        "email",
                    ].filter { supported.contains($0) }.joined(separator: " ")
                }
                if self.entityId.isEmpty {
                    self.entityId = doc.issuer
                }
            } catch { self.discoveryError = error.localizedDescription }
        }
    }

    func fetchSAMLMetadata() {
        guard let url = URL(string: samlMetadataURL) else {
            self.metadataFetchError = "Invalid metadata URL."; return
        }
        self.isFetchingMetadata = true; self.metadataFetchError = nil
        Task {
            defer { isFetchingMetadata = false }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse,
                      http.statusCode == 200
                else {
                    self.metadataFetchError = "Server returned an unexpected response."; return
                }
                guard let xml = String(data: data, encoding: .utf8)
                else {
                    self.metadataFetchError = "Could not decode metadata document."; return
                }
                self.applySAMLMetadataFields(from: xml); self.metadataFetchError = nil
            } catch { self.metadataFetchError = "Failed to fetch metadata: \(error.localizedDescription)" }
        }
    }

    func applySAMLMetadataFields(from xml: String) {
        if let ssoRange = xml.range(of: "SingleSignOnService"),
           let locationStart = xml[ssoRange.upperBound...].range(of: "Location=\""),
           let locationEnd = xml[locationStart.upperBound...]
           .range(of: "\"")
        {
            let extracted = String(xml[locationStart.upperBound ..< locationEnd.lowerBound]); if !extracted
                .isEmpty
            {
                self.samlSSOURL = extracted
            }
        }
        if let entityRange = xml.range(of: "entityID=\""),
           let entityEnd = xml[entityRange.upperBound...]
           .range(of: "\"")
        {
            let extracted = String(xml[entityRange.upperBound ..< entityEnd.lowerBound]); if !extracted
                .isEmpty
            {
                self.entityId = extracted
            }
        }
        if let certStart = xml.range(of: "<ds:X509Certificate>") ?? xml.range(of: "<X509Certificate>"),
           let certTag = xml
           .range(of: certStart.lowerBound == xml.startIndex ? "<ds:X509Certificate>" : "<X509Certificate>"),
           let certEnd = xml[certTag.upperBound...]
           .range(of: "</")
        {
            let rawCert = String(xml[certTag.upperBound ..< certEnd.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines); if !rawCert
                .isEmpty
            {
                self.samlCertificate = "-----BEGIN CERTIFICATE-----\n\(rawCert)\n-----END CERTIFICATE-----"
            }
        }
    }
}

// MARK: - SAMLNameIDFormat + CaseIterable

extension SAMLNameIDFormat: CaseIterable {
    static var allCases: [SAMLNameIDFormat] {
        [
            .emailAddress,
            .persistent,
            .transient,
            .unspecified,
            .entity,
            .kerberos,
            .windowsDomainQualifiedName,
            .x509SubjectName,
        ]
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
            ).frame(width: 560, height: 560)
        }
    }
#endif
