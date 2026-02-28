//
//  AdminAPIClient.swift
//  PasteShelf
//
//  HTTP client for communicating with the centralized admin console server.
//  Implements AdminAPIProviding using URLSession for all REST operations.
//

import Foundation
import os.log

// MARK: - AdminAPIClient

/// HTTP client that communicates with the centralized admin console REST API.
///
/// `AdminAPIClient` translates protocol-level operations (register device, fetch
/// policy, etc.) into concrete HTTP requests against the admin console server.
/// Authentication is handled via either a Bearer token sourced from an active SSO
/// session or an API key passed in the `AdminConsoleConfiguration`.
///
/// All requests target the `/api/v1/` namespace on the configured server URL.
/// Responses are expected to be JSON; non-2xx status codes are mapped to
/// `AdminError` cases for structured error handling.
final class AdminAPIClient: AdminAPIProviding, @unchecked Sendable {

    // MARK: - Properties

    private let configuration: AdminConsoleConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "com.pasteshelf", category: "admin-api")

    /// An optional Bearer token injected from an active SSO session.
    ///
    /// When set, it takes precedence over the API key in `configuration`.
    var bearerToken: String?

    // MARK: - Initialization

    /// Creates an admin API client with the given configuration and optional URL session.
    ///
    /// - Parameters:
    ///   - configuration: The admin console connection parameters.
    ///   - session: The `URLSession` to use for requests. Defaults to `.shared`.
    ///   - bearerToken: An optional SSO access token for Bearer authentication.
    init(
        configuration: AdminConsoleConfiguration,
        session: URLSession = .shared,
        bearerToken: String? = nil
    ) {
        self.configuration = configuration
        self.session = session
        self.bearerToken = bearerToken

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: - AdminAPIProviding

    func registerDevice(_ registration: DeviceRegistration) async throws -> DeviceRegistration {
        let request = try makeRequest(
            path: "/api/v1/devices/register",
            method: "POST",
            body: registration
        )
        return try await perform(request)
    }

    func unregisterDevice(deviceId: String) async throws {
        let request = try makeRequest(
            path: "/api/v1/devices/\(deviceId)",
            method: "DELETE"
        )
        try await performVoid(request)
    }

    func fetchPolicy(for deviceId: String) async throws -> AdminPolicy {
        let request = try makeRequest(
            path: "/api/v1/devices/\(deviceId)/policy",
            method: "GET"
        )
        return try await perform(request)
    }

    func submitHealthReport(_ report: DeviceHealthReport) async throws {
        let request = try makeRequest(
            path: "/api/v1/devices/\(report.deviceId)/health",
            method: "POST",
            body: report
        )
        try await performVoid(request)
    }

    func submitAnalyticsEvents(_ events: [AdminAnalyticsEvent]) async throws {
        let request = try makeRequest(
            path: "/api/v1/analytics/events",
            method: "POST",
            body: events
        )
        try await performVoid(request)
    }

    func fetchDeviceStatus(deviceId: String) async throws -> DeviceEnrollmentStatus {
        let request = try makeRequest(
            path: "/api/v1/devices/\(deviceId)/status",
            method: "GET"
        )
        let wrapper: StatusResponse = try await perform(request)
        return wrapper.status
    }

    // MARK: - Request Construction

    /// Builds a `URLRequest` for the given path, HTTP method, and optional body.
    ///
    /// - Parameters:
    ///   - path: The URL path relative to the server root (e.g., `/api/v1/devices/register`).
    ///   - method: The HTTP method (GET, POST, DELETE, etc.).
    ///   - body: An optional `Encodable` payload to include in the request body.
    /// - Returns: A fully constructed `URLRequest` with auth headers.
    /// - Throws: `AdminError.notConfigured` if no server URL is available.
    private func makeRequest<T: Encodable>(
        path: String,
        method: String,
        body: T
    ) throws -> URLRequest {
        var request = try makeBaseRequest(path: path, method: method)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return request
    }

    /// Builds a `URLRequest` without a body.
    private func makeRequest(
        path: String,
        method: String
    ) throws -> URLRequest {
        try makeBaseRequest(path: path, method: method)
    }

    /// Shared request construction: URL resolution, headers, and authentication.
    private func makeBaseRequest(path: String, method: String) throws -> URLRequest {
        guard let serverURL = configuration.serverURL else {
            throw AdminError.notConfigured
        }

        guard let url = URL(string: path, relativeTo: serverURL) else {
            throw AdminError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Auth: Bearer token (SSO) takes precedence over API key
        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if let apiKey = configuration.apiKey {
            request.setValue("Api-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    // MARK: - Response Handling

    /// Performs a request and decodes the JSON response into the given type.
    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await executeRequest(request)
        try validateResponse(response, data: data)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("Failed to decode response: \(error.localizedDescription)")
            throw AdminError.invalidResponse
        }
    }

    /// Performs a request that does not return a meaningful body.
    private func performVoid(_ request: URLRequest) async throws {
        let (data, response) = try await executeRequest(request)
        try validateResponse(response, data: data)
    }

    /// Executes the URL request, mapping transport errors to `AdminError.networkError`.
    private func executeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            logger.debug("\(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "nil")")
            return try await session.data(for: request)
        } catch {
            logger.error("Network request failed: \(error.localizedDescription)")
            throw AdminError.networkError(error.localizedDescription)
        }
    }

    /// Validates that the HTTP response indicates success (2xx), throwing appropriate
    /// `AdminError` cases for common failure status codes.
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AdminError.invalidResponse
        }

        let statusCode = httpResponse.statusCode

        switch statusCode {
        case 200...299:
            return // Success
        case 401:
            throw AdminError.authenticationRequired
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.warning("Server error \(statusCode): \(message)")
            throw AdminError.serverError(statusCode, message)
        }
    }
}

// MARK: - Internal Response Types

/// Wrapper for the device status endpoint response.
private struct StatusResponse: Decodable {
    let status: DeviceEnrollmentStatus
}
