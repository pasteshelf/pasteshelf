import JWT
import Vapor

// MARK: - TokenExchangeRequest

struct TokenExchangeRequest: Content {
    let ssoToken: String
    let provider: String
    let deviceID: String
    let deviceName: String?
    let osVersion: String?
    let appVersion: String?
}

// MARK: - TokenExchangeResponse

struct TokenExchangeResponse: Content {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let userID: String
}

// MARK: - TokenRefreshRequest

struct TokenRefreshRequest: Content {
    let refreshToken: String
}

// MARK: - TokenRefreshResponse

struct TokenRefreshResponse: Content {
    let accessToken: String
    let expiresIn: Int
}

// MARK: - APIKeyCreateRequest

struct APIKeyCreateRequest: Content {
    let deviceID: String
    let deviceName: String?
}

// MARK: - APIKeyCreateResponse

struct APIKeyCreateResponse: Content {
    let apiKey: String
    let keyPrefix: String
    let expiresAt: Date?
}

// MARK: - JWTPayload

struct JWTPayload: Vapor.JWTPayload, Equatable {
    enum CodingKeys: String, CodingKey {
        case sub
        case exp
        case orgID = "org_id"
        case deviceID = "device_id"
    }

    let sub: SubjectClaim
    let exp: ExpirationClaim
    let orgID: String
    let deviceID: String?

    var userID: UUID? {
        UUID(uuidString: sub.value)
    }

    func verify(using algorithm: some JWTAlgorithm) async throws {
        try exp.verifyNotExpired()
    }
}
