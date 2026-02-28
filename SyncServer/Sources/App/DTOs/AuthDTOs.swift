import JWT
import Vapor

// MARK: - Token Exchange

struct TokenExchangeRequest: Content {
    let ssoToken: String
    let provider: String
    let deviceID: String
    let deviceName: String?
    let osVersion: String?
    let appVersion: String?
}

struct TokenExchangeResponse: Content {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let userID: String
}

struct TokenRefreshRequest: Content {
    let refreshToken: String
}

struct TokenRefreshResponse: Content {
    let accessToken: String
    let expiresIn: Int
}

// MARK: - API Key

struct APIKeyCreateRequest: Content {
    let deviceID: String
    let deviceName: String?
}

struct APIKeyCreateResponse: Content {
    let apiKey: String
    let keyPrefix: String
    let expiresAt: Date?
}

// MARK: - JWT Payload

struct JWTPayload: Vapor.JWTPayload, Equatable {
    let sub: SubjectClaim
    let exp: ExpirationClaim
    let orgID: String
    let deviceID: String?

    enum CodingKeys: String, CodingKey {
        case sub, exp
        case orgID = "org_id"
        case deviceID = "device_id"
    }

    func verify(using algorithm: some JWTAlgorithm) async throws {
        try exp.verifyNotExpired()
    }

    var userID: UUID? {
        UUID(uuidString: sub.value)
    }
}
