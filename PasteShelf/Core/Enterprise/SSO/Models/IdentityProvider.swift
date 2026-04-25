//
//  IdentityProvider.swift
//  PasteShelf
//
//  Model representing an identity provider configuration for Enterprise SSO.
//  Supports both SAML 2.0 and OpenID Connect (OIDC) providers.
//

import Foundation

// MARK: - IdentityProviderType

/// The protocol type used by an identity provider
enum IdentityProviderType: String, Codable, Sendable, CaseIterable {
    case saml = "saml"
    case oidc = "oidc"

    /// Human-readable label (English; used for logs and tests)
    var displayName: String {
        switch self {
        case .saml:
            return "SAML 2.0"
        case .oidc:
            return "OpenID Connect"
        }
    }

    /// Localized display name key (use in SwiftUI views)
    var displayNameKey: LocalizedStringResource {
        switch self {
        case .saml:
            return "SAML 2.0"
        case .oidc:
            return "OpenID Connect"
        }
    }

    init(rawValue: String) {
        switch rawValue {
        case IdentityProviderType.saml.rawValue:
            self = .saml
        case IdentityProviderType.oidc.rawValue:
            self = .oidc
        default:
            self = .saml
        }
    }
}

// MARK: - IdentityProvider

/// Configuration for an enterprise identity provider
struct IdentityProvider: Codable, Sendable, Identifiable, Equatable {
    // MARK: - Properties

    /// Unique identifier for this provider configuration
    let id: UUID

    /// Human-readable display name (e.g. "Okta", "Azure AD", "Google Workspace")
    var name: String

    /// Protocol type used by this provider
    var type: IdentityProviderType

    /// The identity provider's entity ID / issuer URI
    var entityId: String

    /// Whether this provider is active and should be presented to users
    var isEnabled: Bool

    /// When this configuration was first created
    let createdAt: Date

    /// When this configuration was last modified
    var updatedAt: Date

    /// SAML-specific configuration; non-nil when type == .saml
    var samlConfig: SAMLProviderConfig?

    /// OIDC-specific configuration; non-nil when type == .oidc
    var oidcConfig: OIDCProviderConfig?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        type: IdentityProviderType,
        entityId: String,
        isEnabled: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        samlConfig: SAMLProviderConfig? = nil,
        oidcConfig: OIDCProviderConfig? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.entityId = entityId
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.samlConfig = samlConfig
        self.oidcConfig = oidcConfig
    }

    // MARK: - Validation

    /// Whether this provider has a valid configuration for its type
    var isConfigured: Bool {
        switch type {
        case .saml:
            return samlConfig != nil
        case .oidc:
            return oidcConfig != nil
        }
    }
}

// MARK: - SAMLBinding

/// HTTP binding type for SAML protocol messages
enum SAMLBinding: String, Codable, Sendable, CaseIterable {
    case httpPost = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
    case httpRedirect = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"

    /// Human-readable label (English; used for logs and tests)
    var displayName: String {
        switch self {
        case .httpPost:
            return "HTTP POST"
        case .httpRedirect:
            return "HTTP Redirect"
        }
    }

    /// Localized display name key (use in SwiftUI views)
    var displayNameKey: LocalizedStringResource {
        switch self {
        case .httpPost:
            return "HTTP POST"
        case .httpRedirect:
            return "HTTP Redirect"
        }
    }

    init(rawValue: String) {
        switch rawValue {
        case SAMLBinding.httpPost.rawValue:
            self = .httpPost
        case SAMLBinding.httpRedirect.rawValue:
            self = .httpRedirect
        default:
            self = .httpPost
        }
    }
}

// MARK: - SAMLProviderConfig

/// SAML 2.0 identity provider configuration
struct SAMLProviderConfig: Codable, Sendable, Equatable {
    // MARK: - IdP Endpoints

    /// The identity provider's single sign-on endpoint
    var ssoURL: URL

    /// The identity provider's single logout endpoint (optional)
    var sloURL: URL?

    // MARK: - Certificate & Security

    /// PEM-encoded X.509 certificate used to verify IdP-signed assertions
    var certificate: String

    /// Whether to sign outgoing AuthnRequest messages
    var signAuthnRequests: Bool

    // MARK: - NameID & Binding

    /// Format of the NameID attribute returned by the IdP
    var nameIDFormat: SAMLNameIDFormat

    /// HTTP binding to use for AuthnRequest messages
    var binding: SAMLBinding

    // MARK: - Service Provider Configuration

    /// Our Assertion Consumer Service (ACS) URL where the IdP posts the response
    var assertionConsumerServiceURL: String

    /// Our SP entity ID used as the audience restriction value
    var audienceRestriction: String

    // MARK: - Initialization

    init(
        ssoURL: URL,
        sloURL: URL? = nil,
        certificate: String,
        signAuthnRequests: Bool = false,
        nameIDFormat: SAMLNameIDFormat = .emailAddress,
        binding: SAMLBinding = .httpPost,
        assertionConsumerServiceURL: String,
        audienceRestriction: String
    ) {
        self.ssoURL = ssoURL
        self.sloURL = sloURL
        self.certificate = certificate
        self.signAuthnRequests = signAuthnRequests
        self.nameIDFormat = nameIDFormat
        self.binding = binding
        self.assertionConsumerServiceURL = assertionConsumerServiceURL
        self.audienceRestriction = audienceRestriction
    }
}

// MARK: - OIDCProviderConfig

/// OpenID Connect identity provider configuration
struct OIDCProviderConfig: Codable, Sendable, Equatable {
    // MARK: - Discovery / Endpoints

    /// The issuer URL (used for discovery and token validation)
    var issuerURL: URL

    /// Authorization endpoint where the user is redirected to authenticate
    var authorizationEndpoint: URL

    /// Token endpoint used to exchange authorization codes for tokens
    var tokenEndpoint: URL

    /// UserInfo endpoint for fetching additional claims (optional)
    var userInfoEndpoint: URL?

    /// JSON Web Key Set (JWKS) endpoint for verifying token signatures
    var jwksURL: URL

    /// End-session endpoint for RP-initiated logout (optional)
    var endSessionEndpoint: URL?

    // MARK: - Client Credentials

    /// Client identifier registered with the identity provider
    var clientId: String

    /// Client secret; may be nil for public clients relying on PKCE
    var clientSecret: String?

    // MARK: - Flow Configuration

    /// OAuth 2.0 / OIDC scopes to request (default: ["openid", "profile", "email"])
    var scopes: [String]

    /// OAuth 2.0 response type (default: "code" for authorization code flow)
    var responseType: String

    /// Whether to use Proof Key for Code Exchange (PKCE) for public clients
    var usePKCE: Bool

    /// The redirect URI registered with the identity provider
    var redirectURI: String

    // MARK: - Initialization

    init(
        issuerURL: URL,
        authorizationEndpoint: URL,
        tokenEndpoint: URL,
        userInfoEndpoint: URL? = nil,
        jwksURL: URL,
        endSessionEndpoint: URL? = nil,
        clientId: String,
        clientSecret: String? = nil,
        scopes: [String] = ["openid", "profile", "email"],
        responseType: String = "code",
        usePKCE: Bool = true,
        redirectURI: String
    ) {
        self.issuerURL = issuerURL
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.userInfoEndpoint = userInfoEndpoint
        self.jwksURL = jwksURL
        self.endSessionEndpoint = endSessionEndpoint
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.scopes = scopes
        self.responseType = responseType
        self.usePKCE = usePKCE
        self.redirectURI = redirectURI
    }

    // MARK: - Computed Properties

    /// Whether this is a confidential client (has a client secret)
    var isConfidentialClient: Bool {
        clientSecret != nil
    }

    /// The scope string formatted for OAuth 2.0 requests
    var scopeString: String {
        scopes.joined(separator: " ")
    }
}
