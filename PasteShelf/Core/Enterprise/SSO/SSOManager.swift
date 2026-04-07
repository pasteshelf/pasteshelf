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

        self.isAuthenticating = true
        self.lastError = nil

        defer { isAuthenticating = false }

        do {
            let session = try await performAuthentication(with: provider)
            try await sessionStore?.save(session)
            self.currentSession = session

            self.logger.info("SSO authentication successful for user: \(session.userId)")

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
            await logAuthFailure(provider: provider, error: error)
            throw error
        } catch {
            let ssoError = SSOError.authenticationFailed(error.localizedDescription)
            self.lastError = ssoError
            await self.logAuthFailure(provider: provider, error: error)
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

        return try await self.authenticate(with: provider)
    }

    // MARK: - Session Management

    /// Loads the stored session for a provider, if one exists and is still valid
    func loadSession(for providerId: UUID) async throws -> SSOSession? {
        guard let session = try await sessionStore?.load(for: providerId) else {
            return nil
        }

        guard session.isValid else {
            // Clean up expired session
            try await self.sessionStore?.delete(for: providerId)
            if self.currentSession?.providerId == providerId {
                self.currentSession = nil
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

        guard self.oidcTokenManager.needsRefresh(session) else {
            return
        }

        do {
            let refreshed = try await oidcTokenManager.refreshTokens(session: session, config: oidcConfig)
            try await self.sessionStore?.save(refreshed)
            self.currentSession = refreshed
            self.logger.info("OIDC tokens refreshed for session: \(session.id)")
        } catch {
            self.logger.error("Token refresh failed: \(error.localizedDescription)")
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
            self.currentSession = nil
            try await self.sessionStore?.delete(for: session.providerId)
            return false
        }

        return true
    }

    // MARK: - Logout

    /// Signs out from the current SSO session
    func logout() async throws {
        guard let session = currentSession else {
            self.logger.info("No active session to log out")
            return
        }

        self.logger.info("Starting SSO logout for session: \(session.id)")

        // Determine the provider type and delegate logout
        if let providerStore,
           let provider = try await providerStore.load(id: session.providerId)
        {
            switch provider.type {
            case .saml:
                try await self.samlAuthenticator.logout(session: session)
            case .oidc:
                try await self.oidcAuthenticator.logout(session: session)
            }
        }

        // Clear local session
        try await self.sessionStore?.delete(for: session.providerId)
        self.currentSession = nil

        self.logger.info("SSO logout completed")

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
        try await self.sessionStore?.deleteAll()
        self.currentSession = nil
        self.logger.info("All SSO sessions cleared")
    }

    // MARK: Private

    private let logger = Logger(subsystem: "com.pasteshelf", category: "sso")
    private let samlAuthenticator = SAMLAuthenticator()
    private let oidcAuthenticator = OIDCAuthenticator()
    private let oidcTokenManager = OIDCTokenManager()

    /// Delegates to the appropriate SSO authenticator based on provider type.
    private func performAuthentication(with provider: IdentityProvider) async throws -> SSOSession {
        switch provider.type {
        case .saml:
            self.logger.info("Starting SAML authentication with '\(provider.name)'")
            return try await self.samlAuthenticator.authenticate(config: provider)
        case .oidc:
            self.logger.info("Starting OIDC authentication with '\(provider.name)'")
            return try await self.oidcAuthenticator.authenticate(config: provider)
        }
    }

    /// Logs a failed SSO authentication attempt to the audit trail.
    private func logAuthFailure(provider: IdentityProvider, error: Error) async {
        self.logger.error("SSO authentication failed: \(error.localizedDescription)")
        await AuditManager.shared.logAuthEvent(
            action: .loginFailure,
            severity: .warning,
            detail: [
                "provider": provider.name,
                "error": error.localizedDescription,
            ]
        )
    }
}
