//
//  IdentityProviderFormActions.swift
//  PasteShelf
//
//  Actions, build helpers, and data-loading logic for IdentityProviderFormView.
//

import SwiftUI

// MARK: - IdentityProviderFormView + OIDC Sections

extension IdentityProviderFormView {
    var oidcSection: some View {
        Group {
            oidcDiscoverySection
            oidcEndpointsSection
            oidcClientCredentialsSection
            oidcFlowConfigSection
        }
    }

    var oidcDiscoverySection: some View {
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
                        .help("Fetch endpoints via .well-known/openid-configuration")
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
            Text(
                "Enable discovery to auto-populate authorization, token, and JWKS"
                    + " endpoints from the issuer's well-known document."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder var oidcEndpointsSection: some View {
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
    }

    var oidcClientCredentialsSection: some View {
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
    }

    var oidcFlowConfigSection: some View {
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

// MARK: - IdentityProviderFormView + Actions

extension IdentityProviderFormView {
    // MARK: - Save

    func saveProvider() {
        validationErrors = []

        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationErrors = ["Provider name is required."]
            return
        }

        guard let built = buildProvider() else {
            return
        }
        onSave(built)
    }

    /// Constructs an IdentityProvider from the current form state
    func buildProvider() -> IdentityProvider? {
        switch providerType {
        case .saml:
            buildSAMLProvider()
        case .oidc:
            buildOIDCProvider()
        }
    }

    func buildSAMLProvider() -> IdentityProvider? {
        let id = provider?.id ?? UUID()
        let now = Date()

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
    }

    func buildOIDCProvider() -> IdentityProvider? {
        let id = provider?.id ?? UUID()
        let now = Date()

        guard let issuer = URL(string: oidcIssuerURL),
              !oidcIssuerURL.isEmpty,
              let authEndpoint = URL(string: oidcAuthorizationEndpoint),
              !oidcAuthorizationEndpoint.isEmpty,
              let tokenEndpoint = URL(string: oidcTokenEndpoint),
              !oidcTokenEndpoint.isEmpty,
              let jwksURL = URL(string: oidcJWKSURL),
              !oidcJWKSURL.isEmpty
        else {
            validationErrors = ["One or more OIDC endpoint URLs are invalid."]
            return nil
        }

        let userInfo = oidcUserInfoEndpoint.isEmpty
            ? nil : URL(string: oidcUserInfoEndpoint)
        let endSession = oidcEndSessionEndpoint.isEmpty
            ? nil : URL(string: oidcEndSessionEndpoint)
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

    // MARK: - Populate from Existing Provider

    func populateFromProvider() {
        guard let existing = provider else {
            return
        }

        name = existing.name
        entityId = existing.entityId
        providerType = existing.type
        isEnabled = existing.isEnabled

        if let saml = existing.samlConfig {
            samlSSOURL = saml.ssoURL.absoluteString
            samlSLOURL = saml.sloURL?.absoluteString ?? ""
            samlCertificate = saml.certificate
            samlSignAuthnRequests = saml.signAuthnRequests
            samlNameIDFormat = saml.nameIDFormat
            samlBinding = saml.binding
            samlACSURL = saml.assertionConsumerServiceURL
            samlAudienceRestriction = saml.audienceRestriction
        }

        if let oidc = existing.oidcConfig {
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
            oidcUseDiscovery = true
        }
    }

    // MARK: - OIDC Discovery

    func discoverOIDCConfig() {
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

                if oidcScopes.trimmingCharacters(in: .whitespaces).isEmpty,
                   let supported = doc.scopesSupported
                {
                    let defaults = ["openid", "profile", "email"]
                    let intersection = defaults.filter { supported.contains($0) }
                    oidcScopes = intersection.joined(separator: " ")
                }

                if entityId.isEmpty {
                    entityId = doc.issuer
                }

                discoveryError = nil
            } catch {
                discoveryError = error.localizedDescription
            }
        }
    }

    // MARK: - SAML Metadata Fetch

    /// Fetches and parses the IdP metadata XML document, then pre-fills SAML fields.
    func fetchSAMLMetadata() {
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

                applySAMLMetadataFields(from: xml)
                metadataFetchError = nil
            } catch {
                metadataFetchError = "Failed to fetch metadata: \(error.localizedDescription)"
            }
        }
    }

    /// Extracts common SAML fields from the raw metadata XML.
    func applySAMLMetadataFields(from xml: String) {
        if let ssoRange = xml.range(of: "SingleSignOnService"),
           let locationStart = xml[ssoRange.upperBound...].range(of: "Location=\""),
           let locationEnd = xml[locationStart.upperBound...].range(of: "\"")
        {
            let extracted = String(xml[locationStart.upperBound ..< locationEnd.lowerBound])
            if !extracted.isEmpty {
                samlSSOURL = extracted
            }
        }

        if let entityRange = xml.range(of: "entityID=\""),
           let entityEnd = xml[entityRange.upperBound...].range(of: "\"")
        {
            let extracted = String(xml[entityRange.upperBound ..< entityEnd.lowerBound])
            if !extracted.isEmpty {
                entityId = extracted
            }
        }

        if let certStart = xml.range(of: "<ds:X509Certificate>") ?? xml.range(of: "<X509Certificate>"),
           let certTag = xml
           .range(of: certStart.lowerBound == xml.startIndex ? "<ds:X509Certificate>" : "<X509Certificate>"),
           let certEnd = xml[certTag.upperBound...].range(of: "</")
        {
            let rawCert = String(xml[certTag.upperBound ..< certEnd.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !rawCert.isEmpty {
                samlCertificate = "-----BEGIN CERTIFICATE-----\n\(rawCert)\n-----END CERTIFICATE-----"
            }
        }
    }
}

// MARK: - SAMLNameIDFormat + CaseIterable

extension SAMLNameIDFormat: CaseIterable {
    static var allCases: [SAMLNameIDFormat] {
        [
            .emailAddress, .persistent, .transient, .unspecified,
            .entity, .kerberos, .windowsDomainQualifiedName, .x509SubjectName,
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
            )
            .frame(width: 560, height: 560)
        }
    }
#endif
