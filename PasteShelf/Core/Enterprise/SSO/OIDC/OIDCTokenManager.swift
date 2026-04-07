//
//  OIDCTokenManager.swift
//  PasteShelf
//
//  Manages OIDC token lifecycle including proactive refresh and expiry tracking.
//  Uses the refresh_token grant type to obtain new access tokens before expiry.
//

import Foundation
import os.log

/// Manages OIDC token lifecycle including refresh and expiry tracking
final class OIDCTokenManager: Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: Internal

    // MARK: - Public API

    /// Refreshes the access token using the refresh token grant type.
    ///
    /// - Parameters:
    ///   - session: Current SSO session containing the refresh token.
    ///   - config: OIDC provider configuration with the token endpoint.
    /// - Returns: An updated `SSOSession` with new tokens and expiry.
    /// - Throws: `SSOError` if the refresh request fails or the session has no refresh token.
    func refreshTokens(session: SSOSession, config: OIDCProviderConfig) async throws -> SSOSession {
        guard let refreshToken = session.refreshToken else {
            throw SSOError.sessionInvalid
        }

        self.logger.info("Refreshing OIDC tokens for session: \(session.id)")

        var bodyParams: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": config.clientId,
        ]

        // Include client secret for confidential clients
        if let clientSecret = config.clientSecret {
            bodyParams["client_secret"] = clientSecret
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
            self.logger.error("Token refresh failed (\(httpResponse.statusCode)): \(errorBody)")

            // A 400 or 401 typically means the refresh token is invalid or revoked,
            // meaning the user must re-authenticate.
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                throw SSOError.sessionExpired
            }

            throw SSOError.authenticationFailed("Token refresh failed: HTTP \(httpResponse.statusCode)")
        }

        let tokenResponse = try JSONDecoder().decode(OIDCTokenResponse.self, from: data)

        guard let newAccessToken = tokenResponse.accessToken else {
            throw SSOError.authenticationFailed("No access token in refresh response")
        }

        self.logger.info("Token refresh successful for session: \(session.id)")

        // Build an updated session, preserving identity fields and replacing token fields.
        // The refresh token returned by the server may be rotated; fall back to the existing
        // one if the server did not return a new one (some providers reuse the same token).
        return SSOSession(
            id: session.id,
            providerId: session.providerId,
            userId: session.userId,
            email: session.email,
            displayName: session.displayName,
            groups: session.groups,
            authenticatedAt: session.authenticatedAt,
            expiresAt: tokenResponse.expiresAt,
            sessionIndex: session.sessionIndex,
            accessToken: newAccessToken,
            refreshToken: tokenResponse.refreshToken ?? session.refreshToken,
            idToken: tokenResponse.idToken ?? session.idToken
        )
    }

    /// Returns `true` when the session should be proactively refreshed.
    ///
    /// Refresh is triggered when 80% of the token's lifetime has elapsed, giving
    /// the application a window to obtain new tokens before the current ones expire.
    /// If the session has no expiry information, this method returns `false`.
    func needsRefresh(_ session: SSOSession) -> Bool {
        guard session.canRefresh else {
            return false
        }

        guard let expiresAt = session.expiresAt else {
            // No expiry set — token does not expire, no refresh needed.
            return false
        }

        let totalLifetime = expiresAt.timeIntervalSince(session.authenticatedAt)
        guard totalLifetime > 0 else {
            // Degenerate case: token was already expired at authentication time.
            return true
        }

        let elapsed = Date().timeIntervalSince(session.authenticatedAt)
        let fractionElapsed = elapsed / totalLifetime

        return fractionElapsed >= self.refreshThreshold
    }

    /// Refreshes the session if a proactive refresh is warranted; otherwise returns the
    /// session unchanged.
    ///
    /// - Parameters:
    ///   - session: Current SSO session to evaluate.
    ///   - config: OIDC provider configuration with the token endpoint.
    /// - Returns: A refreshed session if refresh was needed, or the original session.
    /// - Throws: `SSOError` if the refresh network request fails.
    func refreshIfNeeded(session: SSOSession, config: OIDCProviderConfig) async throws -> SSOSession {
        guard self.needsRefresh(session) else {
            return session
        }

        return try await self.refreshTokens(session: session, config: config)
    }

    // MARK: Private

    private let logger = Logger(subsystem: "com.pasteshelf", category: "oidc-token")
    private let urlSession: URLSession

    /// The fraction of token lifetime that must elapse before a proactive refresh is triggered.
    /// At 0.8, a refresh is triggered when 80% of the token's lifetime has passed.
    private let refreshThreshold: Double = 0.8
}
