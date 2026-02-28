//
//  OIDCDiscovery.swift
//  PasteShelf
//
//  Discovers OIDC provider configuration by fetching the
//  .well-known/openid-configuration document from an issuer URL.
//

import Foundation
import os.log

// MARK: - OIDCDiscovery

/// Discovers OIDC provider configuration from .well-known/openid-configuration
final class OIDCDiscovery: Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.pasteshelf", category: "oidc-discovery")
    private let urlSession: URLSession

    // MARK: - Initialization

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: - Discovery

    /// Fetches the OpenID Connect discovery document from the issuer
    ///
    /// Constructs the well-known URL from the issuer, performs a GET request,
    /// decodes the JSON response, and validates required fields and issuer match.
    ///
    /// - Parameter issuerURL: The OIDC issuer URL (e.g. https://accounts.google.com)
    /// - Returns: The parsed and validated discovery document
    /// - Throws: `SSOError` if the network request fails, the document is invalid,
    ///   or the issuer in the document does not match the requested issuer URL
    func discover(issuerURL: URL) async throws -> OIDCDiscoveryDocument {
        // Construct the discovery document URL
        let discoveryURL = issuerURL
            .appendingPathComponent(".well-known")
            .appendingPathComponent("openid-configuration")

        logger.info("Fetching OIDC discovery document from: \(discoveryURL.absoluteString)")

        // Perform GET request
        let request = URLRequest(url: discoveryURL)
        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            logger.error("Network request failed for discovery URL: \(error.localizedDescription)")
            throw SSOError.networkError("Failed to reach discovery endpoint: \(error.localizedDescription)")
        }

        // Validate HTTP 200 response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SSOError.networkError("Invalid response type from discovery endpoint")
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("Discovery endpoint returned HTTP \(httpResponse.statusCode)")
            throw SSOError.networkError(
                "Discovery endpoint returned HTTP \(httpResponse.statusCode)"
            )
        }

        // Decode the discovery document
        let document: OIDCDiscoveryDocument
        do {
            let decoder = JSONDecoder()
            document = try decoder.decode(OIDCDiscoveryDocument.self, from: data)
        } catch {
            logger.error("Failed to decode discovery document: \(error.localizedDescription)")
            throw SSOError.configurationInvalid(
                "Failed to parse discovery document: \(error.localizedDescription)"
            )
        }

        // Validate required fields
        guard !document.issuer.isEmpty else {
            throw SSOError.configurationInvalid("Discovery document is missing required field: issuer")
        }
        guard !document.authorizationEndpoint.isEmpty else {
            throw SSOError.configurationInvalid(
                "Discovery document is missing required field: authorization_endpoint"
            )
        }
        guard !document.tokenEndpoint.isEmpty else {
            throw SSOError.configurationInvalid(
                "Discovery document is missing required field: token_endpoint"
            )
        }
        guard !document.jwksUri.isEmpty else {
            throw SSOError.configurationInvalid(
                "Discovery document is missing required field: jwks_uri"
            )
        }

        // Verify issuer match: normalise by stripping trailing slashes before comparing
        let normalizedDocumentIssuer = document.issuer.trimmingCharacters(in: .init(charactersIn: "/"))
        let normalizedRequestedIssuer = issuerURL.absoluteString.trimmingCharacters(in: .init(charactersIn: "/"))

        guard normalizedDocumentIssuer == normalizedRequestedIssuer else {
            logger.error(
                "Issuer mismatch: expected '\(normalizedRequestedIssuer)', got '\(normalizedDocumentIssuer)'"
            )
            throw SSOError.configurationInvalid(
                "Issuer mismatch: document issuer '\(document.issuer)' does not match requested issuer '\(issuerURL.absoluteString)'"
            )
        }

        logger.info("Successfully fetched and validated OIDC discovery document for issuer: \(document.issuer)")
        return document
    }

    // MARK: - Config Builder

    /// Creates an OIDCProviderConfig from a discovery document
    ///
    /// Converts the string URLs in the document to `URL` objects, selects
    /// default scopes from the intersection of the document's supported scopes
    /// and the standard set ["openid", "profile", "email"], and assembles a
    /// fully populated `OIDCProviderConfig`.
    ///
    /// - Parameters:
    ///   - document: The discovery document returned by `discover(issuerURL:)`
    ///   - clientId: The client ID registered with the identity provider
    ///   - clientSecret: Optional client secret (nil for public clients using PKCE)
    ///   - redirectURI: The redirect URI registered with the identity provider
    ///   - usePKCE: Whether to use Proof Key for Code Exchange (defaults to `true`)
    /// - Returns: A populated `OIDCProviderConfig` ready for use with `OIDCAuthenticator`
    func buildConfig(
        from document: OIDCDiscoveryDocument,
        clientId: String,
        clientSecret: String?,
        redirectURI: String,
        usePKCE: Bool = true
    ) -> OIDCProviderConfig {
        // Convert string URLs to URL objects (forced-unwrap guarded by discovery validation)
        let issuerURL = URL(string: document.issuer) ?? URL(string: "https://invalid")!
        let authorizationEndpoint = URL(string: document.authorizationEndpoint) ?? issuerURL
        let tokenEndpoint = URL(string: document.tokenEndpoint) ?? issuerURL
        let userInfoEndpoint = document.userinfoEndpoint.flatMap { URL(string: $0) }
        let jwksURL = URL(string: document.jwksUri) ?? issuerURL
        let endSessionEndpoint = document.endSessionEndpoint.flatMap { URL(string: $0) }

        // Determine scopes: intersect supported scopes with the standard OIDC default set,
        // preserving order ["openid", "profile", "email"]. Fall back to full default if the
        // document provides no scope list.
        let defaultScopes = ["openid", "profile", "email"]
        let scopes: [String]

        if let supported = document.scopesSupported {
            scopes = defaultScopes.filter { supported.contains($0) }
        } else {
            scopes = defaultScopes
        }

        // Determine whether to honour PKCE: use the caller's preference, but only enable
        // PKCE if the provider actually supports S256 (or if the document doesn't advertise
        // supported methods, in which case we assume it is supported per RFC 7636).
        let effectiveUsePKCE: Bool
        if usePKCE {
            let supportedMethods = document.codeChallengeMethodsSupported
            effectiveUsePKCE = supportedMethods == nil || supportedMethods!.contains("S256")
        } else {
            effectiveUsePKCE = false
        }

        logger.info(
            "Building OIDCProviderConfig — clientId: \(clientId), scopes: \(scopes.joined(separator: " ")), usePKCE: \(effectiveUsePKCE)"
        )

        return OIDCProviderConfig(
            issuerURL: issuerURL,
            authorizationEndpoint: authorizationEndpoint,
            tokenEndpoint: tokenEndpoint,
            userInfoEndpoint: userInfoEndpoint,
            jwksURL: jwksURL,
            endSessionEndpoint: endSessionEndpoint,
            clientId: clientId,
            clientSecret: clientSecret,
            scopes: scopes.isEmpty ? defaultScopes : scopes,
            responseType: "code",
            usePKCE: effectiveUsePKCE,
            redirectURI: redirectURI
        )
    }
}

// MARK: - OIDCDiscoveryDocument

/// Represents the OpenID Connect Discovery document
///
/// See: https://openid.net/specs/openid-connect-discovery-1_0.html
struct OIDCDiscoveryDocument: Codable, Sendable {
    // MARK: - Required Fields

    /// The issuer identifier of the OpenID Provider
    let issuer: String

    /// URL of the OP's OAuth 2.0 authorization endpoint
    let authorizationEndpoint: String

    /// URL of the OP's OAuth 2.0 token endpoint
    let tokenEndpoint: String

    /// URL of the OP's JSON Web Key Set document
    let jwksUri: String

    // MARK: - Optional Fields

    /// URL of the OP's UserInfo endpoint
    let userinfoEndpoint: String?

    /// URL of the OP's end-session endpoint for RP-initiated logout
    let endSessionEndpoint: String?

    /// URL of the OP's Dynamic Client Registration endpoint
    let registrationEndpoint: String?

    /// JSON array of OAuth 2.0 scope values the server supports
    let scopesSupported: [String]?

    /// JSON array of OAuth 2.0 response_type values the OP supports
    let responseTypesSupported: [String]?

    /// JSON array of OAuth 2.0 grant_type values the OP supports
    let grantTypesSupported: [String]?

    /// JSON array of subject_type values the OP supports
    let subjectTypesSupported: [String]?

    /// JSON array of JWS signing algorithms (alg values) supported for ID tokens
    let idTokenSigningAlgValuesSupported: [String]?

    /// JSON array of client authentication methods supported by the token endpoint
    let tokenEndpointAuthMethodsSupported: [String]?

    /// JSON array of PKCE code challenge methods supported by the OP
    let codeChallengeMethodsSupported: [String]?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case issuer
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case userinfoEndpoint = "userinfo_endpoint"
        case jwksUri = "jwks_uri"
        case endSessionEndpoint = "end_session_endpoint"
        case registrationEndpoint = "registration_endpoint"
        case scopesSupported = "scopes_supported"
        case responseTypesSupported = "response_types_supported"
        case grantTypesSupported = "grant_types_supported"
        case subjectTypesSupported = "subject_types_supported"
        case idTokenSigningAlgValuesSupported = "id_token_signing_alg_values_supported"
        case tokenEndpointAuthMethodsSupported = "token_endpoint_auth_methods_supported"
        case codeChallengeMethodsSupported = "code_challenge_methods_supported"
    }

    // MARK: - Computed Properties

    /// Whether this provider supports PKCE with the S256 code challenge method
    var supportsPKCE: Bool {
        codeChallengeMethodsSupported?.contains("S256") ?? false
    }

    /// Whether this provider supports the authorization code flow
    var supportsAuthCodeFlow: Bool {
        responseTypesSupported?.contains("code") ?? true
    }
}
