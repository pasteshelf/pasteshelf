import Crypto
import JWT
import Vapor

// MARK: - JWTAuthMiddleware

struct JWTAuthMiddleware: AsyncMiddleware {
    // MARK: Internal

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        if let bearer = request.headers.bearerAuthorization {
            let payload = try await request.jwt.verify(bearer.token, as: JWTPayload.self)
            guard let userID = payload.userID else {
                throw Abort(.unauthorized, reason: "Invalid user ID in token")
            }
            request.auth.login(AuthenticatedUser(id: userID, orgID: payload.orgID, deviceID: payload.deviceID))
            return try await next.respond(to: request)
        }

        if let apiKeyValue = request.headers.first(name: "X-API-Key") ?? extractAPIKeyFromAuth(request) {
            let keyHash = APIKeyHasher.hash(apiKeyValue)
            guard let apiKey = try await APIKey.query(on: request.db)
                .filter(\.$keyHash == keyHash)
                .with(\.$user)
                .with(\.$device)
                .first(),
                apiKey.isActive
            else {
                throw Abort(.unauthorized, reason: "Invalid or expired API key")
            }

            apiKey.device.lastSeen = Date()
            try await apiKey.device.save(on: request.db)

            request.auth.login(AuthenticatedUser(
                id: apiKey.$user.id,
                orgID: apiKey.user.orgID,
                deviceID: apiKey.device.deviceID
            ))
            return try await next.respond(to: request)
        }

        throw Abort(.unauthorized, reason: "Authentication required")
    }

    // MARK: Private

    private func extractAPIKeyFromAuth(_ request: Request) -> String? {
        guard let auth = request.headers.first(name: .authorization),
              auth.hasPrefix("Api-Key ")
        else {
            return nil
        }
        return String(auth.dropFirst("Api-Key ".count))
    }
}

// MARK: - AuthenticatedUser

struct AuthenticatedUser: Authenticatable {
    let id: UUID
    let orgID: String
    let deviceID: String?
}

// MARK: - APIKeyHasher

enum APIKeyHasher {
    static func hash(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = Crypto.SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
