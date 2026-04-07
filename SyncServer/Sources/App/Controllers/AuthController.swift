//
//  AuthController.swift
//  SyncServer
//
//  Authentication endpoints: SSO token exchange, refresh, API key management.
//

import Crypto
import JWT
import Vapor

struct AuthController: RouteCollection {
    // MARK: Internal

    func boot(routes: any RoutesBuilder) throws {
        let auth = routes.grouped("api", "v1", "auth")
        auth.post("token", use: exchangeToken)
        auth.post("refresh", use: refreshToken)

        // API key creation requires existing auth
        let protected = auth.grouped(JWTAuthMiddleware())
        protected.post("api-key", use: createAPIKey)
    }

    // MARK: - Token Exchange

    /// Exchange an SSO token for a server JWT.
    ///
    /// In production this would validate the SSO token against the IdP.
    /// For now, it performs a simplified flow: creates the user if needed
    /// and issues a JWT.
    @Sendable
    func exchangeToken(req: Request) async throws -> TokenExchangeResponse {
        let body = try req.content.decode(TokenExchangeRequest.self)

        // In production: validate body.ssoToken against the configured IdP
        // For now, we treat the ssoToken as a trusted external_id
        let externalID = body.ssoToken
        let orgID = Environment.get("ORG_ID") ?? "default"

        // Find or create user
        let user: User
        if let existing = try await User.query(on: req.db)
            .filter(\.$externalID == externalID)
            .filter(\.$orgID == orgID)
            .first()
        {
            user = existing
        } else {
            user = User(externalID: externalID, orgID: orgID)
            try await user.save(on: req.db)
        }

        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "User ID missing after save")
        }

        // Register or update device
        let device: Device
        if let existing = try await Device.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$deviceID == body.deviceID)
            .first()
        {
            existing.lastSeen = Date()
            existing.deviceName = body.deviceName ?? existing.deviceName
            existing.osVersion = body.osVersion ?? existing.osVersion
            existing.appVersion = body.appVersion ?? existing.appVersion
            try await existing.save(on: req.db)
            device = existing
        } else {
            device = Device(
                userID: userID,
                deviceID: body.deviceID,
                deviceName: body.deviceName,
                osVersion: body.osVersion,
                appVersion: body.appVersion
            )
            try await device.save(on: req.db)
        }

        // Issue JWT (1 hour expiry)
        let payload = JWTPayload(
            sub: .init(value: userID.uuidString),
            exp: .init(value: Date().addingTimeInterval(3600)),
            orgID: orgID,
            deviceID: body.deviceID
        )
        let accessToken = try await req.jwt.sign(payload)

        // Issue refresh token (7 day expiry)
        let refreshPayload = JWTPayload(
            sub: .init(value: userID.uuidString),
            exp: .init(value: Date().addingTimeInterval(7 * 24 * 3600)),
            orgID: orgID,
            deviceID: body.deviceID
        )
        let refreshToken = try await req.jwt.sign(refreshPayload)

        return TokenExchangeResponse(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: 3600,
            userID: userID.uuidString
        )
    }

    // MARK: - Token Refresh

    @Sendable
    func refreshToken(req: Request) async throws -> TokenRefreshResponse {
        let body = try req.content.decode(TokenRefreshRequest.self)
        let payload = try await req.jwt.verify(body.refreshToken, as: JWTPayload.self)

        guard let userID = payload.userID else {
            throw Abort(.unauthorized, reason: "Invalid refresh token")
        }

        // Issue new access token
        let newPayload = JWTPayload(
            sub: .init(value: userID.uuidString),
            exp: .init(value: Date().addingTimeInterval(3600)),
            orgID: payload.orgID,
            deviceID: payload.deviceID
        )
        let newToken = try await req.jwt.sign(newPayload)

        return TokenRefreshResponse(accessToken: newToken, expiresIn: 3600)
    }

    // MARK: - API Key

    @Sendable
    func createAPIKey(req: Request) async throws -> APIKeyCreateResponse {
        let authUser = try req.auth.require(AuthenticatedUser.self)
        let body = try req.content.decode(APIKeyCreateRequest.self)

        // Find the device
        guard let device = try await Device.query(on: req.db)
            .filter(\.$user.$id == authUser.id)
            .filter(\.$deviceID == body.deviceID)
            .first()
        else {
            throw Abort(.notFound, reason: "Device not found. Register the device first.")
        }

        guard let devicePK = device.id else {
            throw Abort(.internalServerError)
        }

        // Generate a random API key
        let rawKey = generateAPIKey()
        let keyHash = APIKeyHasher.hash(rawKey)
        let keyPrefix = String(rawKey.prefix(8))

        // Default 30-day expiry
        let expiresAt = Date().addingTimeInterval(30 * 24 * 3600)

        let apiKey = APIKey(
            userID: authUser.id,
            deviceID: devicePK,
            keyHash: keyHash,
            keyPrefix: keyPrefix,
            expiresAt: expiresAt
        )
        try await apiKey.save(on: req.db)

        return APIKeyCreateResponse(
            apiKey: rawKey,
            keyPrefix: keyPrefix,
            expiresAt: expiresAt
        )
    }

    // MARK: Private

    // MARK: - Helpers

    private func generateAPIKey() -> String {
        let bytes = (0 ..< 32).map { _ in UInt8.random(in: 0 ... 255) }
        return "ps_" + Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
