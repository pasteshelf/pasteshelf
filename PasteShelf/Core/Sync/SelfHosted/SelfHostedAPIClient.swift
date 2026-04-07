//
//  SelfHostedAPIClient.swift
//  PasteShelf
//
//  HTTP client for the self-hosted sync server REST API.
//  Handles authentication, request signing, and response parsing.
//

import Foundation
import os.log

// MARK: - SelfHostedAPIClient

/// HTTP client for the self-hosted PasteShelf sync server REST API.
///
/// Uses URLSession with optional certificate pinning. Supports both
/// JWT Bearer tokens and API key authentication.
final class SelfHostedAPIClient: @unchecked Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(configuration: SelfHostedSyncConfiguration, urlSessionDelegate: URLSessionDelegate? = nil) {
        self.configuration = configuration
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 120
        session = URLSession(configuration: sessionConfig, delegate: urlSessionDelegate, delegateQueue: nil)
    }

    // MARK: Internal

    // MARK: - Auth Endpoints

    /// Exchange an SSO token for server access and refresh tokens.
    func exchangeToken(
        ssoToken: String,
        deviceID: String,
        deviceName: String?,
        osVersion: String?,
        appVersion: String?
    ) async throws -> TokenExchangeResult {
        let body: [String: Any?] = [
            "ssoToken": ssoToken,
            "provider": "sso",
            "deviceID": deviceID,
            "deviceName": deviceName,
            "osVersion": osVersion,
            "appVersion": appVersion,
        ]
        let result: TokenExchangeResult = try await post(path: "/api/v1/auth/token", body: body)
        accessToken = result.accessToken
        refreshToken = result.refreshToken
        return result
    }

    /// Refresh the access token using the refresh token.
    func refreshAccessToken() async throws {
        guard let refreshToken else {
            throw SyncError.authenticationTokenExpired
        }
        let body: [String: Any] = ["refreshToken": refreshToken]
        let result: TokenRefreshResult = try await post(path: "/api/v1/auth/refresh", body: body)
        accessToken = result.accessToken
    }

    /// Create a persistent API key for this device.
    func createAPIKey(deviceID: String, deviceName: String?) async throws -> APIKeyResult {
        let body: [String: Any?] = [
            "deviceID": deviceID,
            "deviceName": deviceName,
        ]
        return try await post(path: "/api/v1/auth/api-key", body: body)
    }

    // MARK: - Device Endpoints

    /// Register this device with the sync server.
    func registerDevice(deviceID: String, deviceName: String?, osVersion: String?,
                        appVersion: String?) async throws -> DeviceResult
    {
        let body: [String: Any?] = [
            "deviceID": deviceID,
            "deviceName": deviceName,
            "osVersion": osVersion,
            "appVersion": appVersion,
        ]
        return try await post(path: "/api/v1/devices/register", body: body)
    }

    /// List all devices registered for the current user.
    func listDevices() async throws -> DeviceListResult {
        try await get(path: "/api/v1/devices")
    }

    /// Unregister a device.
    func removeDevice(deviceID: String) async throws {
        try await delete(path: "/api/v1/devices/\(deviceID)")
    }

    // MARK: - Sync Endpoints

    /// Push encrypted changes to the server.
    func pushChanges(_ changes: [SyncChangePayload], deviceID: String) async throws -> SyncPushAPIResult {
        let body: [String: Any] = [
            "changes": changes.map { $0.toDictionary() },
            "deviceID": deviceID,
        ]
        return try await post(path: "/api/v1/sync/push", body: body)
    }

    /// Pull changes from the server since the given token.
    func pullChanges(since token: String?, limit: Int = 200) async throws -> SyncPullAPIResult {
        let body: [String: Any?] = [
            "since": token,
            "limit": limit,
        ]
        return try await post(path: "/api/v1/sync/pull", body: body)
    }

    /// Get the current sync status for this device.
    func syncStatus() async throws -> SyncStatusResult {
        try await get(path: "/api/v1/sync/status")
    }

    /// Reset all sync data for the current user.
    func resetSync() async throws -> SyncResetResult {
        try await post(path: "/api/v1/sync/reset", body: [:] as [String: Any])
    }

    // MARK: - Health

    /// Check server health.
    func healthCheck() async throws -> HealthResult {
        try await get(path: "/health")
    }

    // MARK: - Token Management

    /// Set the access token directly (e.g., from stored keychain value).
    func setAccessToken(_ token: String) {
        accessToken = token
    }

    /// Set the API key for authentication.
    func setAPIKey(_ key: String) {
        configuration.apiKey != nil ? () : ()
        // API key is read from configuration
    }

    // MARK: Private

    private let configuration: SelfHostedSyncConfiguration
    private let session: URLSession
    private let logger = Logger(subsystem: "com.pasteshelf", category: "self-hosted-api")

    /// Current JWT access token (short-lived, ~1 hour).
    private var accessToken: String?

    /// Current JWT refresh token (long-lived, ~7 days).
    private var refreshToken: String?

    // MARK: - Internal HTTP Methods

    private func get<T: Decodable>(path: String) async throws -> T {
        let url = try buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuth(&request)
        return try await execute(request)
    }

    private func post<T: Decodable>(path: String, body: [String: Any?]) async throws -> T {
        let url = try buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)

        let cleanBody = body.compactMapValues { $0 }
        request.httpBody = try JSONSerialization.data(withJSONObject: cleanBody)
        return try await execute(request)
    }

    @discardableResult
    private func delete(path: String) async throws -> Data {
        let url = try buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        applyAuth(&request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return data
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        logger.debug("Request: \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func buildURL(path: String) throws -> URL {
        guard let serverURL = configuration.serverURL else {
            throw SyncError.serverConnectionFailed(message: "No server URL configured")
        }
        return serverURL.appendingPathComponent(path)
    }

    private func applyAuth(_ request: inout URLRequest) {
        if let apiKey = configuration.apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        } else if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.serverConnectionFailed(message: "Invalid response")
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            return
        case 401:
            throw SyncError.authenticationTokenExpired
        case 429:
            throw SyncError.selfHostedServerError(code: 429, message: "Rate limited")
        default:
            throw SyncError.selfHostedServerError(code: httpResponse.statusCode, message: "Server error")
        }
    }
}

// MARK: - TokenExchangeResult

struct TokenExchangeResult: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let userID: String
}

// MARK: - TokenRefreshResult

struct TokenRefreshResult: Codable {
    let accessToken: String
    let expiresIn: Int
}

// MARK: - APIKeyResult

struct APIKeyResult: Codable {
    let apiKey: String
    let keyPrefix: String
    let expiresAt: Date?
}

// MARK: - DeviceResult

struct DeviceResult: Codable {
    let id: UUID
    let deviceID: String
    let deviceName: String?
    let osVersion: String?
    let appVersion: String?
    let lastSeen: Date
    let createdAt: Date?
}

// MARK: - DeviceListResult

struct DeviceListResult: Codable {
    let devices: [DeviceResult]
}

// MARK: - SyncChangePayload

struct SyncChangePayload {
    let entityID: UUID
    let entityType: String
    let encryptedData: String?
    let contentHash: String?
    let isDeleted: Bool
    let clientVersion: Int64?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "entityID": entityID.uuidString,
            "entityType": entityType,
            "isDeleted": isDeleted,
        ]
        if let data = encryptedData {
            dict["encryptedData"] = data
        }
        if let hash = contentHash {
            dict["contentHash"] = hash
        }
        if let version = clientVersion {
            dict["clientVersion"] = version
        }
        return dict
    }
}

// MARK: - SyncPushAPIResult

struct SyncPushAPIResult: Codable {
    let accepted: Int
    let conflicts: [SyncConflictAPIResult]
    let serverTimestamp: Date
}

// MARK: - SyncConflictAPIResult

struct SyncConflictAPIResult: Codable {
    let entityID: UUID
    let entityType: String
    let serverVersion: Int64
    let serverEncryptedData: String?
    let serverContentHash: String?
}

// MARK: - SyncPullAPIResult

struct SyncPullAPIResult: Codable {
    let changes: [SyncPullChangeAPIResult]
    let newToken: String
    let hasMore: Bool
}

// MARK: - SyncPullChangeAPIResult

struct SyncPullChangeAPIResult: Codable {
    let entityID: UUID
    let entityType: String
    let changeType: String
    let encryptedData: String?
    let contentHash: String?
    let isDeleted: Bool
    let version: Int64
    let sourceDevice: String?
    let timestamp: Date
}

// MARK: - SyncStatusResult

struct SyncStatusResult: Codable {
    let deviceID: String
    let lastSyncToken: String?
    let totalRecords: Int
    let serverTimestamp: Date
}

// MARK: - SyncResetResult

struct SyncResetResult: Codable {
    let deletedRecords: Int
    let message: String
}

// MARK: - HealthResult

struct HealthResult: Codable {
    let status: String
    let version: String
    let database: String
}
