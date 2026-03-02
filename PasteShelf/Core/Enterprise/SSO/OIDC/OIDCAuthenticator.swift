//
//  OIDCAuthenticator.swift
//  PasteShelf
//
//  Implements the OpenID Connect authorization code flow with PKCE
//  for Enterprise SSO authentication.
//

import AppKit
import AuthenticationServices
import CryptoKit
import Foundation
import os.log

/// OIDC SSO provider implementing authorization code flow with PKCE
final class OIDCAuthenticator: NSObject, SSOProvider, @unchecked Sendable {
    // MARK: - Properties

    let providerType: IdentityProviderType = .oidc

    private let logger = Logger(subsystem: "com.pasteshelf", category: "oidc-auth")
    private let callbackScheme = "pasteshelf"
    private let urlSession: URLSession

    // MARK: - Initialization

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        super.init()
    }

    // MARK: - SSOProvider

    func authenticate(config: IdentityProvider) async throws -> SSOSession {
        guard let oidcConfig = config.oidcConfig else {
            throw SSOError.configurationInvalid("OIDC configuration is missing")
        }

        logger.info("Starting OIDC authorization code flow for provider: \(config.name)")

        // Generate PKCE parameters if enabled
        let pkce: PKCEParameters? = oidcConfig.usePKCE ? PKCEParameters() : nil

        // Generate state parameter for CSRF protection
        let state = UUID().uuidString

        // Build authorization URL
        let authURL = try buildAuthorizationURL(config: oidcConfig, state: state, pkce: pkce)

        // Open browser for authentication
        let callbackURL = try await performBrowserAuthentication(url: authURL)

        // Extract authorization code from callback
        let (code, returnedState) = try extractAuthorizationCode(from: callbackURL)

        // Validate state parameter
        guard returnedState == state else {
            throw SSOError.authenticationFailed("State parameter mismatch — possible CSRF attack")
        }

        // Exchange authorization code for tokens
        let tokenResponse = try await exchangeCodeForTokens(
            code: code,
            config: oidcConfig,
            pkce: pkce
        )

        logger.info("OIDC authentication successful, building session")

        // Parse ID token claims to extract user info
        let claims = try parseIDTokenClaims(tokenResponse.idToken)

        return SSOSession(
            providerId: config.id,
            userId: claims.subject,
            email: claims.email,
            displayName: claims.name,
            groups: claims.groups,
            authenticatedAt: Date(),
            expiresAt: tokenResponse.expiresAt,
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            idToken: tokenResponse.idToken
        )
    }

    func validateSession(_ session: SSOSession) async throws -> Bool {
        // Check local expiry first
        guard session.isValid else { return false }

        // If we have an access token, we could validate it at the userinfo endpoint
        // For now, rely on local expiry check
        return true
    }

    func logout(session: SSOSession) async throws {
        logger.info("OIDC logout requested for session: \(session.id)")

        // OIDC logout will use the end_session_endpoint if available
        guard let providerStore = await SSOManager.shared.providerStore,
              let provider = try await providerStore.load(id: session.providerId),
              let oidcConfig = provider.oidcConfig,
              let endSessionEndpoint = oidcConfig.endSessionEndpoint
        else {
            logger.info("No end_session_endpoint configured, skipping IdP logout")
            return
        }

        // Build logout URL
        var components = URLComponents(url: endSessionEndpoint, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []

        if let idToken = session.idToken {
            queryItems.append(URLQueryItem(name: "id_token_hint", value: idToken))
        }
        queryItems.append(URLQueryItem(
            name: "post_logout_redirect_uri",
            value: oidcConfig.redirectURI
        ))

        components?.queryItems = queryItems

        guard let logoutURL = components?.url else {
            throw SSOError.logoutFailed("Failed to build logout URL")
        }

        // Open browser for logout (fire and forget — some IdPs don't redirect back)
        _ = try? await performBrowserAuthentication(url: logoutURL)
    }

    // MARK: - Authorization URL

    /// Builds the OIDC authorization endpoint URL with all required parameters
    func buildAuthorizationURL(
        config: OIDCProviderConfig,
        state: String,
        pkce: PKCEParameters?
    ) throws -> URL {
        guard var components = URLComponents(
            url: config.authorizationEndpoint,
            resolvingAgainstBaseURL: false
        ) else {
            throw SSOError.configurationInvalid("Invalid authorization endpoint URL")
        }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "response_type", value: config.responseType),
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
        ]

        // Add PKCE parameters
        if let pkce {
            queryItems.append(URLQueryItem(name: "code_challenge", value: pkce.codeChallenge))
            queryItems.append(URLQueryItem(name: "code_challenge_method", value: "S256"))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw SSOError.configurationInvalid("Failed to build authorization URL")
        }

        return url
    }

    // MARK: - Token Exchange

    /// Exchanges an authorization code for access, refresh, and ID tokens
    func exchangeCodeForTokens(
        code: String,
        config: OIDCProviderConfig,
        pkce: PKCEParameters?
    ) async throws -> OIDCTokenResponse {
        var bodyParams: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.redirectURI,
            "client_id": config.clientId,
        ]

        // Add client secret for confidential clients
        if let clientSecret = config.clientSecret {
            bodyParams["client_secret"] = clientSecret
        }

        // Add PKCE code verifier
        if let pkce {
            bodyParams["code_verifier"] = pkce.codeVerifier
        }

        let body = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")

        var request = URLRequest(url: config.tokenEndpoint)
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SSOError.networkError("Invalid response from token endpoint")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Token exchange failed (\(httpResponse.statusCode)): \(errorBody)")
            throw SSOError.authenticationFailed("Token exchange failed: HTTP \(httpResponse.statusCode)")
        }

        let tokenResponse = try JSONDecoder().decode(OIDCTokenResponse.self, from: data)

        guard tokenResponse.idToken != nil else {
            throw SSOError.authenticationFailed("No ID token in token response")
        }

        return tokenResponse
    }

    // MARK: - Browser Authentication

    @MainActor
    private func performBrowserAuthentication(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: SSOError.authenticationFailed(error.localizedDescription))
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: SSOError.authenticationFailed("No callback URL received"))
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = self
            session.start()
        }
    }

    // MARK: - Response Parsing

    /// Extracts authorization code and state from the callback URL
    private func extractAuthorizationCode(from url: URL) throws -> (code: String, state: String?) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems
        else {
            throw SSOError.authenticationFailed("Invalid callback URL format")
        }

        // Check for error response
        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            let description = queryItems.first(where: { $0.name == "error_description" })?.value ?? error
            throw SSOError.authenticationFailed(description)
        }

        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw SSOError.authenticationFailed("No authorization code in callback URL")
        }

        let state = queryItems.first(where: { $0.name == "state" })?.value
        return (code, state)
    }

    /// Parses basic claims from a JWT ID token (without signature verification)
    private func parseIDTokenClaims(_ idToken: String?) throws -> IDTokenClaims {
        guard let idToken else {
            throw SSOError.authenticationFailed("Missing ID token")
        }

        let parts = idToken.split(separator: ".")
        guard parts.count >= 2 else {
            throw SSOError.authenticationFailed("Invalid ID token format")
        }

        // Decode the payload (second part)
        var base64 = String(parts[1])
        // Pad to multiple of 4
        while base64.count % 4 != 0 {
            base64.append("=")
        }

        guard let payloadData = Data(base64Encoded: base64) else {
            throw SSOError.authenticationFailed("Failed to decode ID token payload")
        }

        let claims = try JSONDecoder().decode(IDTokenClaims.self, from: payloadData)
        return claims
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension OIDCAuthenticator: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? NSWindow()
    }
}

// MARK: - PKCE Parameters

/// PKCE (Proof Key for Code Exchange) parameters for OAuth 2.0
struct PKCEParameters: Sendable {
    /// The code verifier (random 43-128 character string)
    let codeVerifier: String

    /// The code challenge (S256 hash of verifier)
    let codeChallenge: String

    init() {
        // Generate 32 random bytes for the code verifier
        var randomBytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)

        // Base64url encode
        codeVerifier = Data(randomBytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        // S256: SHA256 hash of verifier, base64url encoded
        let verifierData = Data(codeVerifier.utf8)
        let hash = SHA256.hash(data: verifierData)
        codeChallenge = Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Token Response

/// Response from the OIDC token endpoint
struct OIDCTokenResponse: Codable, Sendable {
    let accessToken: String?
    let tokenType: String?
    let expiresIn: Int?
    let refreshToken: String?
    let idToken: String?
    let scope: String?

    /// Computed expiration date based on expiresIn
    var expiresAt: Date? {
        guard let expiresIn else { return nil }
        return Date().addingTimeInterval(TimeInterval(expiresIn))
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case scope
    }
}

// MARK: - ID Token Claims

/// Standard OIDC ID token claims
struct IDTokenClaims: Codable, Sendable {
    /// Subject identifier (unique user ID)
    let subject: String

    /// User's email address
    let email: String?

    /// Whether email is verified
    let emailVerified: Bool?

    /// User's full name
    let name: String?

    /// User's given (first) name
    let givenName: String?

    /// User's family (last) name
    let familyName: String?

    /// User's preferred username
    let preferredUsername: String?

    /// Group memberships (custom claim, common in enterprise IdPs)
    let groups: [String]

    /// Token issuer
    let issuer: String?

    /// Token audience
    let audience: IDTokenAudience?

    /// Token expiration (unix timestamp)
    let expiration: Int?

    /// Token issued-at (unix timestamp)
    let issuedAt: Int?

    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case email
        case emailVerified = "email_verified"
        case name
        case givenName = "given_name"
        case familyName = "family_name"
        case preferredUsername = "preferred_username"
        case groups
        case issuer = "iss"
        case audience = "aud"
        case expiration = "exp"
        case issuedAt = "iat"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subject = try container.decode(String.self, forKey: .subject)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        emailVerified = try container.decodeIfPresent(Bool.self, forKey: .emailVerified)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        givenName = try container.decodeIfPresent(String.self, forKey: .givenName)
        familyName = try container.decodeIfPresent(String.self, forKey: .familyName)
        preferredUsername = try container.decodeIfPresent(String.self, forKey: .preferredUsername)
        groups = (try? container.decodeIfPresent([String].self, forKey: .groups)) ?? []
        issuer = try container.decodeIfPresent(String.self, forKey: .issuer)
        audience = try container.decodeIfPresent(IDTokenAudience.self, forKey: .audience)
        expiration = try container.decodeIfPresent(Int.self, forKey: .expiration)
        issuedAt = try container.decodeIfPresent(Int.self, forKey: .issuedAt)
    }
}

/// Audience claim that can be a single string or array of strings
enum IDTokenAudience: Codable, Sendable {
    case single(String)
    case multiple([String])

    var values: [String] {
        switch self {
        case .single(let value): return [value]
        case .multiple(let values): return values
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let single = try? container.decode(String.self) {
            self = .single(single)
        } else if let multiple = try? container.decode([String].self) {
            self = .multiple(multiple)
        } else {
            throw DecodingError.typeMismatch(
                IDTokenAudience.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Expected String or [String]")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let value): try container.encode(value)
        case .multiple(let values): try container.encode(values)
        }
    }
}
