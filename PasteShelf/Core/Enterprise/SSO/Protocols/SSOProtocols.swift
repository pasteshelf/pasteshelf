//
//  SSOProtocols.swift
//  PasteShelf
//
//  Protocols defining the Enterprise SSO provider abstraction layer.
//  Implementations exist for SAML 2.0 and OpenID Connect (OIDC).
//

import Foundation

// MARK: - SSOProvider

/// Abstraction over a concrete SSO authentication provider (SAML or OIDC).
///
/// Implementations are expected to handle the full protocol flow, including
/// generating authentication requests, processing responses, and terminating
/// sessions at the identity provider.
protocol SSOProvider: Sendable {
    /// The identity provider protocol type this implementation handles
    var providerType: IdentityProviderType { get }

    /// Initiates the SSO authentication flow for the given provider configuration.
    ///
    /// - Parameter config: The identity provider configuration to authenticate against.
    /// - Returns: A valid `SSOSession` on successful authentication.
    /// - Throws: `SSOError` if the authentication flow fails at any step.
    func authenticate(config: IdentityProvider) async throws -> SSOSession

    /// Validates that an existing session is still active at the identity provider.
    ///
    /// - Parameter session: The session to validate.
    /// - Returns: `true` if the session is still active, `false` if it has been revoked.
    /// - Throws: `SSOError` if the validation request itself fails.
    func validateSession(_ session: SSOSession) async throws -> Bool

    /// Initiates logout at the identity provider, terminating the SSO session.
    ///
    /// - Parameter session: The session to terminate.
    /// - Throws: `SSOError.logoutFailed` if the logout request cannot be completed.
    func logout(session: SSOSession) async throws
}

// MARK: - SSOSessionStore

/// Persistent store for active SSO sessions.
///
/// Implementations should store session data securely (e.g. in the Keychain)
/// and associate each session with its originating identity provider.
protocol SSOSessionStore: Sendable {
    /// Persists a session, replacing any existing session for the same provider.
    ///
    /// - Parameter session: The session to store.
    /// - Throws: If the underlying storage operation fails.
    func save(_ session: SSOSession) async throws

    /// Retrieves the current session for a given identity provider, if one exists.
    ///
    /// - Parameter providerId: The UUID of the identity provider.
    /// - Returns: The stored session, or `nil` if none exists.
    /// - Throws: If the underlying storage operation fails.
    func load(for providerId: UUID) async throws -> SSOSession?

    /// Removes the stored session for a given identity provider.
    ///
    /// - Parameter providerId: The UUID of the identity provider whose session to remove.
    /// - Throws: If the underlying storage operation fails.
    func delete(for providerId: UUID) async throws

    /// Removes all stored SSO sessions (e.g. on sign-out or device wipe).
    ///
    /// - Throws: If the underlying storage operation fails.
    func deleteAll() async throws
}

// MARK: - IdentityProviderStore

/// Persistent store for identity provider configurations.
///
/// Manages CRUD operations for `IdentityProvider` records, typically backed
/// by a local database or encrypted file store.
protocol IdentityProviderStore: Sendable {
    /// Persists an identity provider configuration, creating or updating as needed.
    ///
    /// - Parameter provider: The provider configuration to store.
    /// - Throws: If the underlying storage operation fails.
    func save(_ provider: IdentityProvider) async throws

    /// Retrieves a single identity provider by its identifier.
    ///
    /// - Parameter id: The UUID of the identity provider to retrieve.
    /// - Returns: The provider configuration, or `nil` if not found.
    /// - Throws: If the underlying storage operation fails.
    func load(id: UUID) async throws -> IdentityProvider?

    /// Retrieves all stored identity provider configurations.
    ///
    /// - Returns: An array of all provider configurations, in no guaranteed order.
    /// - Throws: If the underlying storage operation fails.
    func loadAll() async throws -> [IdentityProvider]

    /// Removes an identity provider configuration by its identifier.
    ///
    /// - Parameter id: The UUID of the identity provider to remove.
    /// - Throws: If the underlying storage operation fails.
    func delete(id: UUID) async throws
}

// MARK: - SSOError

/// Errors that may be thrown during SSO operations
enum SSOError: Error, LocalizedError, Sendable {
    /// No identity provider has been configured for the requested operation
    case notConfigured

    /// No provider was found matching the given identifier
    case providerNotFound(UUID)

    /// The authentication flow completed but the IdP rejected the attempt
    case authenticationFailed(String)

    /// The session token has passed its expiry time
    case sessionExpired

    /// The session is present but is in an invalid state
    case sessionInvalid

    /// The logout request to the identity provider failed
    case logoutFailed(String)

    /// A network-level error prevented communication with the identity provider
    case networkError(String)

    /// The provider configuration is missing required fields or contains invalid values
    case configurationInvalid(String)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "No identity provider has been configured. Please set up an SSO provider in the enterprise settings."
        case .providerNotFound(let id):
            return "Identity provider with ID \(id.uuidString) could not be found."
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .sessionExpired:
            return "Your SSO session has expired. Please sign in again."
        case .sessionInvalid:
            return "Your SSO session is no longer valid. Please sign in again."
        case .logoutFailed(let reason):
            return "Logout could not be completed: \(reason)"
        case .networkError(let reason):
            return "A network error occurred while contacting the identity provider: \(reason)"
        case .configurationInvalid(let reason):
            return "The identity provider configuration is invalid: \(reason)"
        }
    }

    var failureReason: String? {
        switch self {
        case .authenticationFailed(let reason),
             .logoutFailed(let reason),
             .networkError(let reason),
             .configurationInvalid(let reason):
            return reason
        default:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notConfigured:
            return "Contact your IT administrator to configure an identity provider."
        case .providerNotFound:
            return "Verify the provider configuration in enterprise settings."
        case .authenticationFailed:
            return "Check your credentials and try again, or contact your IT administrator."
        case .sessionExpired, .sessionInvalid:
            return "Sign in again to start a new session."
        case .logoutFailed:
            return "Try signing out again or clear your session data manually."
        case .networkError:
            return "Check your network connection and try again."
        case .configurationInvalid:
            return "Review the identity provider configuration and correct any errors."
        }
    }
}
