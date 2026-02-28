//
//  SSOSession.swift
//  PasteShelf
//
//  Model representing an active Enterprise SSO session.
//  Supports both SAML and OIDC session data.
//

import Foundation

// MARK: - SSOSession

/// An active SSO authentication session for an enterprise user
struct SSOSession: Codable, Sendable, Identifiable, Equatable {
    // MARK: - Identity

    /// Unique identifier for this session record
    let id: UUID

    /// The identity provider that authenticated this session
    let providerId: UUID

    // MARK: - User Information

    /// The user's unique identifier as returned by the identity provider
    let userId: String

    /// The user's email address (may be absent for some providers)
    var email: String?

    /// Human-readable display name for the user
    var displayName: String?

    /// Group memberships asserted by the identity provider
    var groups: [String]

    // MARK: - Session Timing

    /// When the user successfully authenticated
    let authenticatedAt: Date

    /// When this session expires; nil means the session does not expire
    var expiresAt: Date?

    // MARK: - SAML-Specific Fields

    /// SAML SessionIndex used to correlate SLO (Single Logout) requests
    var sessionIndex: String?

    // MARK: - OIDC-Specific Fields

    /// OAuth 2.0 / OIDC access token
    var accessToken: String?

    /// OAuth 2.0 refresh token for obtaining new access tokens
    var refreshToken: String?

    /// OIDC ID token containing identity claims
    var idToken: String?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        providerId: UUID,
        userId: String,
        email: String? = nil,
        displayName: String? = nil,
        groups: [String] = [],
        authenticatedAt: Date = Date(),
        expiresAt: Date? = nil,
        sessionIndex: String? = nil,
        accessToken: String? = nil,
        refreshToken: String? = nil,
        idToken: String? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.groups = groups
        self.authenticatedAt = authenticatedAt
        self.expiresAt = expiresAt
        self.sessionIndex = sessionIndex
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
    }

    // MARK: - Computed Properties

    /// Whether this session has passed its expiration time
    var isExpired: Bool {
        guard let expiresAt else {
            // No expiry set — session does not expire
            return false
        }
        return Date() >= expiresAt
    }

    /// Whether this session is currently valid (not expired)
    var isValid: Bool {
        !isExpired
    }

    /// Time remaining until expiry; nil if the session does not expire
    var timeUntilExpiry: TimeInterval? {
        guard let expiresAt else { return nil }
        return expiresAt.timeIntervalSinceNow
    }

    /// Whether this session has a refresh token available for renewal
    var canRefresh: Bool {
        refreshToken != nil
    }

    // MARK: - Equatable

    static func == (lhs: SSOSession, rhs: SSOSession) -> Bool {
        lhs.id == rhs.id
    }
}
