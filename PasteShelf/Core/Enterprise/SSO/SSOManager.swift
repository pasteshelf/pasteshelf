//
//  SSOManager.swift
//  PasteShelf
//
//  Central orchestrator for Enterprise SSO authentication.
//  Delegates to SAML or OIDC providers based on IdP configuration.
//

import Combine
import Foundation
import os.log

/// Central manager for Enterprise SSO authentication flows
@MainActor
final class SSOManager: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    private init() {}

    // MARK: Internal

    // MARK: - Singleton

    static let shared = SSOManager()

    // MARK: - Published State

    /// The currently active SSO session, if any
    @Published private(set) var currentSession: SSOSession?

    /// Whether an authentication flow is in progress
    @Published private(set) var isAuthenticating = false

    /// The most recent SSO error, if any
    @Published var lastError: SSOError?

    private(set) var sessionStore: SSOSessionStore?
    private(set) var providerStore: IdentityProviderStore?

    /// Configure the manager with storage backends
    func configure(
        sessionStore: SSOSessionStore,
        providerStore: IdentityProviderStore
    ) {
        self.sessionStore = sessionStore
        self.providerStore = providerStore
    }

    // MARK: - Authentication

    /// Authenticates with the specified identity provider
    /// - Parameter provider: The identity provider configuration
    /// - Returns: The resulting SSO session
    @discardableResult
    func authenticate(with provider: IdentityProvider) async throws -> SSOSession {
        guard provider.isConfigured else {
            throw SSOError.configurationInvalid("Provider '\(provider.name)' is not fully configured")
        }

        guard provider.isEnabled else {
            throw SSOError.configurationInvalid("Provider '\(provider.name)' is disabled")
        }

        isAuthenticating = true
        lastError = nil

        defer { isAuthenticating = false }

        do {
            let session: SSOSession

            switch provider.type {
            case .saml:
                logger.info("Starting SAML authentication with '\(provider.name)'")
                session = try await samlAuthenticator.authenticate(config: provider)
            case .oidc:
                logger.info("Starting OIDC authentication with '\(provider.name)'")
                session = try await oidcAuthenticator.authenticate(config: provider)
            }

            // Store the session
            try await sessionStore?.save(session)
            currentSession = session

            logger.info("SSO authentication successful for user: \(session.userId)")

            // Audit: log successful SSO login
            await AuditManager.shared.logAuthEvent(
                action: .ssoLogin,
                detail: [
                    "provider": provider.name,
                    "providerType": provider.type.rawValue,
                    "userId": session.userId,
                ]
            )

            return session
        } catch let error as SSOError {
            lastError = error
            logger.error("SSO authentication failed: \(error.localizedDescription)")

            // Audit: log failed SSO login
            await AuditManager.shared.logAuthEvent(
                action: .loginFailure,
                severity: .warning,
                detail: [
                    "provider": provider.name,
                    "error": error.localizedDescription,
                ]
            )

            throw error
        } catch {
            let ssoError = SSOError.authenticationFailed(error.localizedDescription)
            lastError = ssoError
            logger.error("SSO authentication failed: \(error.localizedDescription)")

            // Audit: log failed SSO login
            await AuditManager.shared.logAuthEvent(
                action: .loginFailure,
                severity: .warning,
                detail: [
                    "provider": provider.name,
                    "error": error.localizedDescription,
                ]
            )

            throw ssoError
        }
    }

    /// Authenticates with the first enabled provider
    @discardableResult
    func authenticateWithDefaultProvider() async throws -> SSOSession {
        guard let providerStore else {
            throw SSOError.notConfigured
        }

        let providers = try await providerStore.loadAll()
        guard let provider = providers.first(where: { $0.isEnabled && $0.isConfigured }) else {
            throw SSOError.notConfigured
        }

        return try await authenticate(with: provider)
    }

    // MARK: - Session Management

    /// Loads the stored session for a provider, if one exists and is still valid
    func loadSession(for providerId: UUID) async throws -> SSOSession? {
        guard let session = try await sessionStore?.load(for: providerId) else {
            return nil
        }

        guard session.isValid else {
            // Clean up expired session
            try await sessionStore?.delete(for: providerId)
            if currentSession?.providerId == providerId {
                currentSession = nil
            }
            return nil
        }

        return session
    }

    /// Refreshes the current OIDC session's tokens if needed
    func refreshCurrentSessionIfNeeded() async throws {
        guard let session = currentSession, session.canRefresh else {
            return
        }

        guard let providerStore,
              let provider = try await providerStore.load(id: session.providerId),
              let oidcConfig = provider.oidcConfig
        else {
            return
        }

        guard oidcTokenManager.needsRefresh(session) else {
            return
        }

        do {
            let refreshed = try await oidcTokenManager.refreshTokens(session: session, config: oidcConfig)
            try await sessionStore?.save(refreshed)
            currentSession = refreshed
            logger.info("OIDC tokens refreshed for session: \(session.id)")
        } catch {
            logger.error("Token refresh failed: \(error.localizedDescription)")
            // Don't clear session — it may still be valid, just can't refresh

            // Audit: log token refresh failure
            await AuditManager.shared.logAuthEvent(
                action: .loginFailure,
                severity: .warning,
                detail: [
                    "reason": "token_refresh_failed",
                    "sessionId": session.id.uuidString,
                    "error": error.localizedDescription,
                ]
            )
        }
    }

    /// Validates the current session is still active
    func validateCurrentSession() async throws -> Bool {
        guard let session = currentSession else {
            return false
        }

        guard session.isValid else {
            currentSession = nil
            try await sessionStore?.delete(for: session.providerId)
            return false
        }

        return true
    }

    // MARK: - Logout

    /// Signs out from the current SSO session
    func logout() async throws {
        guard let session = currentSession else {
            logger.info("No active session to log out")
            return
        }

        logger.info("Starting SSO logout for session: \(session.id)")

        // Determine the provider type and delegate logout
        if let providerStore,
           let provider = try await providerStore.load(id: session.providerId)
        {
            switch provider.type {
            case .saml:
                try await samlAuthenticator.logout(session: session)
            case .oidc:
                try await oidcAuthenticator.logout(session: session)
            }
        }

        // Clear local session
        try await sessionStore?.delete(for: session.providerId)
        currentSession = nil

        logger.info("SSO logout completed")

        // Audit: log successful SSO logout
        await AuditManager.shared.logAuthEvent(
            action: .ssoLogout,
            detail: [
                "userId": session.userId,
                "sessionId": session.id.uuidString,
            ]
        )
    }

    /// Signs out from all SSO sessions
    func logoutAll() async throws {
        try await sessionStore?.deleteAll()
        currentSession = nil
        logger.info("All SSO sessions cleared")
    }

    // MARK: Private

    private let logger = Logger(subsystem: "com.pasteshelf", category: "sso")
    private let samlAuthenticator = SAMLAuthenticator()
    private let oidcAuthenticator = OIDCAuthenticator()
    private let oidcTokenManager = OIDCTokenManager()
}
