//
//  AdminAPIClientTests.swift
//  PasteShelfTests
//
//  Tests for AdminAPIClient: request construction, auth headers, error mapping,
//  and response decoding using a mock URLProtocol.
//

import Foundation
@testable import PasteShelf
import Testing

// MARK: - MockURLProtocol

/// A custom `URLProtocol` that intercepts all requests and returns a pre-configured
/// response. This allows unit testing of `AdminAPIClient` without hitting a real server.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    /// Handler called for each intercepted request. Must be set before the test begins.
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    /// Captures the most recent request for assertion purposes.
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request

        guard let handler = Self.requestHandler else {
            let error = NSError(
                domain: "MockURLProtocol",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "No request handler set"]
            )
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Test Helpers

/// Creates a mock URL session configured to use `MockURLProtocol`.
private func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

/// Creates an `AdminAPIClient` wired to the mock session with a standard test configuration.
private func makeClient(
    bearerToken: String? = nil,
    apiKey: String? = nil
) -> AdminAPIClient {
    let config = AdminConsoleConfiguration(
        serverURL: URL(string: "https://admin.example.com"),
        organizationID: "org-test",
        apiKey: apiKey
    )
    return AdminAPIClient(
        configuration: config,
        session: makeMockSession(),
        bearerToken: bearerToken
    )
}

/// Creates a successful JSON HTTP response for the test server URL.
private func makeSuccessResponse(
    for url: URL?,
    statusCode: Int = 200
) -> HTTPURLResponse {
    HTTPURLResponse(
        url: url ?? URL(string: "https://admin.example.com")!,
        statusCode: statusCode,
        httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "application/json"]
    )!
}

// MARK: - AdminAPIClientTests

struct AdminAPIClientTests {
    // MARK: - Request Construction

    @Test("registerDevice sends POST to /api/v1/devices/register")
    func registerDevicePath() async throws {
        let client = makeClient(bearerToken: "test-token")
        let registration = DeviceRegistration(
            deviceId: "",
            organizationID: "org-test",
            userId: "user-1",
            enrollmentStatus: .enrolling,
            deviceName: "Test Mac",
            osVersion: "14.0",
            appVersion: "1.0.0"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let confirmed = DeviceRegistration(
            deviceId: "dev-123",
            organizationID: "org-test",
            userId: "user-1",
            enrollmentStatus: .enrolled,
            deviceName: "Test Mac",
            osVersion: "14.0",
            appVersion: "1.0.0"
        )
        let responseData = try encoder.encode(confirmed)

        MockURLProtocol.requestHandler = { request in
            let response = makeSuccessResponse(for: request.url)
            return (response, responseData)
        }

        let result = try await client.registerDevice(registration)

        #expect(result.deviceId == "dev-123")
        #expect(result.enrollmentStatus == .enrolled)
        #expect(MockURLProtocol.lastRequest?.httpMethod == "POST")
        #expect(MockURLProtocol.lastRequest?.url?.path == "/api/v1/devices/register")
    }

    @Test("unregisterDevice sends DELETE to /api/v1/devices/{deviceId}")
    func unregisterDevicePath() async throws {
        let client = makeClient(bearerToken: "test-token")

        MockURLProtocol.requestHandler = { request in
            let response = makeSuccessResponse(for: request.url, statusCode: 204)
            return (response, Data())
        }

        try await client.unregisterDevice(deviceId: "dev-456")

        #expect(MockURLProtocol.lastRequest?.httpMethod == "DELETE")
        #expect(MockURLProtocol.lastRequest?.url?.path == "/api/v1/devices/dev-456")
    }

    @Test("fetchPolicy sends GET to /api/v1/devices/{deviceId}/policy")
    func fetchPolicyPath() async throws {
        let client = makeClient(bearerToken: "test-token")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let policy = AdminPolicy(id: "pol-1", version: "1", name: "Default", updatedAt: Date())
        let responseData = try encoder.encode(policy)

        MockURLProtocol.requestHandler = { request in
            let response = makeSuccessResponse(for: request.url)
            return (response, responseData)
        }

        let result = try await client.fetchPolicy(for: "dev-789")

        #expect(result.id == "pol-1")
        #expect(result.name == "Default")
        #expect(MockURLProtocol.lastRequest?.httpMethod == "GET")
        #expect(MockURLProtocol.lastRequest?.url?.path == "/api/v1/devices/dev-789/policy")
    }

    @Test("submitHealthReport sends POST to /api/v1/devices/{deviceId}/health")
    func submitHealthReportPath() async throws {
        let client = makeClient(bearerToken: "test-token")
        let report = DeviceHealthReport(
            deviceId: "dev-100",
            timestamp: Date(),
            appVersion: "1.0.0",
            osVersion: "14.0",
            isSSOActive: false,
            isMDMManaged: false,
            isSyncEnabled: false,
            isEncryptionEnabled: false,
            clipboardItemCount: 0,
            complianceStatus: .unknown
        )

        MockURLProtocol.requestHandler = { request in
            let response = makeSuccessResponse(for: request.url, statusCode: 200)
            return (response, Data())
        }

        try await client.submitHealthReport(report)

        #expect(MockURLProtocol.lastRequest?.httpMethod == "POST")
        #expect(MockURLProtocol.lastRequest?.url?.path == "/api/v1/devices/dev-100/health")
    }

    @Test("submitAnalyticsEvents sends POST to /api/v1/analytics/events")
    func submitAnalyticsEventsPath() async throws {
        let client = makeClient(bearerToken: "test-token")
        let events = [
            AdminAnalyticsEvent(deviceId: "dev-1", eventType: .appLaunched),
        ]

        MockURLProtocol.requestHandler = { request in
            let response = makeSuccessResponse(for: request.url, statusCode: 200)
            return (response, Data())
        }

        try await client.submitAnalyticsEvents(events)

        #expect(MockURLProtocol.lastRequest?.httpMethod == "POST")
        #expect(MockURLProtocol.lastRequest?.url?.path == "/api/v1/analytics/events")
    }

    @Test("fetchDeviceStatus sends GET to /api/v1/devices/{deviceId}/status")
    func fetchDeviceStatusPath() async throws {
        let client = makeClient(bearerToken: "test-token")
        let statusJSON = #"{"status":"enrolled"}"#

        MockURLProtocol.requestHandler = { request in
            let response = makeSuccessResponse(for: request.url)
            return (response, Data(statusJSON.utf8))
        }

        let status = try await client.fetchDeviceStatus(deviceId: "dev-200")

        #expect(status == .enrolled)
        #expect(MockURLProtocol.lastRequest?.httpMethod == "GET")
        #expect(MockURLProtocol.lastRequest?.url?.path == "/api/v1/devices/dev-200/status")
    }

    // MARK: - Auth Headers

    @Test("Bearer token is included in Authorization header when set")
    func bearerTokenInAuthHeader() async throws {
        let client = makeClient(bearerToken: "my-sso-token")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let policy = AdminPolicy(id: "pol-1", version: "1", name: "Default", updatedAt: Date())
        let responseData = try encoder.encode(policy)

        MockURLProtocol.requestHandler = { request in
            (makeSuccessResponse(for: request.url), responseData)
        }

        _ = try await client.fetchPolicy(for: "dev-1")

        let authHeader = MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization")
        #expect(authHeader == "Bearer my-sso-token")
    }

    @Test("API key is included in Authorization header when no bearer token")
    func apiKeyInAuthHeader() async throws {
        let client = makeClient(bearerToken: nil, apiKey: "api-key-123")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let policy = AdminPolicy(id: "pol-1", version: "1", name: "Default", updatedAt: Date())
        let responseData = try encoder.encode(policy)

        MockURLProtocol.requestHandler = { request in
            (makeSuccessResponse(for: request.url), responseData)
        }

        _ = try await client.fetchPolicy(for: "dev-1")

        let authHeader = MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization")
        #expect(authHeader == "Api-Key api-key-123")
    }

    @Test("Bearer token takes precedence over API key")
    func bearerTokenPrecedenceOverApiKey() async throws {
        let client = makeClient(bearerToken: "bearer-token", apiKey: "api-key")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let policy = AdminPolicy(id: "pol-1", version: "1", name: "Default", updatedAt: Date())
        let responseData = try encoder.encode(policy)

        MockURLProtocol.requestHandler = { request in
            (makeSuccessResponse(for: request.url), responseData)
        }

        _ = try await client.fetchPolicy(for: "dev-1")

        let authHeader = MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization")
        #expect(authHeader == "Bearer bearer-token")
    }

    @Test("Accept header is set to application/json")
    func acceptHeaderIsJSON() async throws {
        let client = makeClient(bearerToken: "token")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let policy = AdminPolicy(id: "pol-1", version: "1", name: "Default", updatedAt: Date())
        let responseData = try encoder.encode(policy)

        MockURLProtocol.requestHandler = { request in
            (makeSuccessResponse(for: request.url), responseData)
        }

        _ = try await client.fetchPolicy(for: "dev-1")

        let acceptHeader = MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Accept")
        #expect(acceptHeader == "application/json")
    }

    @Test("Content-Type header is set for POST requests with body")
    func contentTypeHeaderForPOST() async throws {
        let client = makeClient(bearerToken: "token")
        let events = [AdminAnalyticsEvent(deviceId: "dev-1", eventType: .appLaunched)]

        MockURLProtocol.requestHandler = { request in
            (makeSuccessResponse(for: request.url), Data())
        }

        try await client.submitAnalyticsEvents(events)

        let contentType = MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type")
        #expect(contentType == "application/json")
    }

    // MARK: - Error Mapping

    @Test("401 response throws authenticationRequired")
    func error401MapsToAuthenticationRequired() async throws {
        let client = makeClient(bearerToken: "expired-token")

        MockURLProtocol.requestHandler = { request in
            let response = makeSuccessResponse(for: request.url, statusCode: 401)
            return (response, Data("Unauthorized".utf8))
        }

        do {
            _ = try await client.fetchPolicy(for: "dev-1")
            #expect(Bool(false), "Expected AdminError.authenticationRequired")
        } catch let error as AdminError {
            if case .authenticationRequired = error {
                // Expected
            } else {
                #expect(Bool(false), "Expected authenticationRequired, got \(error)")
            }
        }
    }

    @Test("500 response throws serverError with status code and message")
    func error500MapsToServerError() async throws {
        let client = makeClient(bearerToken: "token")

        MockURLProtocol.requestHandler = { request in
            let response = makeSuccessResponse(for: request.url, statusCode: 500)
            return (response, Data("Internal Server Error".utf8))
        }

        do {
            _ = try await client.fetchPolicy(for: "dev-1")
            #expect(Bool(false), "Expected AdminError.serverError")
        } catch let error as AdminError {
            if case let .serverError(code, message) = error {
                #expect(code == 500)
                #expect(message == "Internal Server Error")
            } else {
                #expect(Bool(false), "Expected serverError, got \(error)")
            }
        }
    }

    @Test("403 response throws serverError")
    func error403MapsToServerError() async throws {
        let client = makeClient(bearerToken: "token")

        MockURLProtocol.requestHandler = { request in
            let response = makeSuccessResponse(for: request.url, statusCode: 403)
            return (response, Data("Forbidden".utf8))
        }

        do {
            _ = try await client.fetchPolicy(for: "dev-1")
            #expect(Bool(false), "Expected AdminError.serverError")
        } catch let error as AdminError {
            if case let .serverError(code, _) = error {
                #expect(code == 403)
            } else {
                #expect(Bool(false), "Expected serverError, got \(error)")
            }
        }
    }

    @Test("Invalid JSON response throws invalidResponse")
    func invalidJSONThrowsInvalidResponse() async throws {
        let client = makeClient(bearerToken: "token")

        MockURLProtocol.requestHandler = { request in
            let response = makeSuccessResponse(for: request.url, statusCode: 200)
            return (response, Data("not json".utf8))
        }

        do {
            _ = try await client.fetchPolicy(for: "dev-1")
            #expect(Bool(false), "Expected AdminError.invalidResponse")
        } catch let error as AdminError {
            if case .invalidResponse = error {
                // Expected
            } else {
                #expect(Bool(false), "Expected invalidResponse, got \(error)")
            }
        }
    }

    @Test("notConfigured thrown when serverURL is nil")
    func notConfiguredWhenNoServerURL() async throws {
        let config = AdminConsoleConfiguration(serverURL: nil, organizationID: "org")
        let client = AdminAPIClient(configuration: config, session: makeMockSession())

        do {
            _ = try await client.fetchPolicy(for: "dev-1")
            #expect(Bool(false), "Expected AdminError.notConfigured")
        } catch let error as AdminError {
            if case .notConfigured = error {
                // Expected
            } else {
                #expect(Bool(false), "Expected notConfigured, got \(error)")
            }
        }
    }

    // MARK: - Response Decoding

    @Test("registerDevice correctly decodes server response with ISO 8601 dates")
    func registerDeviceDecodesISO8601Dates() async throws {
        let client = makeClient(bearerToken: "token")
        let registration = DeviceRegistration(
            deviceId: "",
            organizationID: "org-test",
            userId: "user-1",
            enrollmentStatus: .enrolling,
            deviceName: "Test Mac",
            osVersion: "14.0",
            appVersion: "1.0.0"
        )

        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let confirmed = DeviceRegistration(
            deviceId: "dev-confirmed",
            organizationID: "org-test",
            userId: "user-1",
            enrollmentStatus: .enrolled,
            enrolledAt: fixedDate,
            lastCheckIn: fixedDate,
            deviceName: "Test Mac",
            osVersion: "14.0",
            appVersion: "1.0.0"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let responseData = try encoder.encode(confirmed)

        MockURLProtocol.requestHandler = { request in
            (makeSuccessResponse(for: request.url), responseData)
        }

        let result = try await client.registerDevice(registration)

        #expect(result.deviceId == "dev-confirmed")
        #expect(result.enrollmentStatus == .enrolled)
        #expect(result.enrolledAt == fixedDate)
        #expect(result.lastCheckIn == fixedDate)
    }

    @Test("fetchDeviceStatus decodes all enrollment status values")
    func fetchDeviceStatusDecodesAllValues() async throws {
        let client = makeClient(bearerToken: "token")

        for status in [DeviceEnrollmentStatus.enrolled, .suspended, .revoked, .notEnrolled, .enrolling] {
            let json = #"{"status":"\#(status.rawValue)"}"#

            MockURLProtocol.requestHandler = { request in
                (makeSuccessResponse(for: request.url), Data(json.utf8))
            }

            let result = try await client.fetchDeviceStatus(deviceId: "dev-1")
            #expect(result == status)
        }
    }
}
