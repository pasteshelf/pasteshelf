//
//  LicenseServerClient.swift
//  PasteShelf
//
//  HTTP client for license server API communication.
//  Implements LicenseServerClient protocol with async/await URLSession.
//

import Foundation
import os.log

/// HTTP client for license server API
final class HTTPLicenseServerClient: LicenseServerClient {
    // MARK: - Configuration

    /// Base URL for the license server
    private let baseURL: URL

    /// URL session for network requests
    private let session: URLSession

    /// Logger for network operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "license-server"
    )

    /// App version for user agent
    private let appVersion: String

    // MARK: - Initialization

    /// Initialize with default production configuration
    convenience init() {
        let url = URL(string: "https://license.pasteshelf.app")!
        self.init(baseURL: url)
    }

    /// Initialize with custom base URL
    init(baseURL: URL) {
        self.baseURL = baseURL

        // Configure URL session with appropriate timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)

        // Get app version
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Initialize with custom session (for testing)
    init(baseURL: URL, session: URLSession) {
        self.baseURL = baseURL
        self.session = session
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - LicenseServerClient Implementation

    /// Activate a license on this device
    func activate(
        licenseKey: String,
        deviceId: String,
        deviceName: String
    ) async throws -> String {
        logger.info("Activating license...")

        let request = ActivationRequest(
            licenseKey: licenseKey,
            deviceId: deviceId,
            deviceName: deviceName,
            hardwareId: getHardwareId(),
            platform: "macos",
            appVersion: appVersion
        )

        let response: ActivationResponse = try await post(
            endpoint: "/api/v1/licenses/activate",
            body: request
        )

        if response.success {
            logger.info("License activated successfully")
            return response.token
        } else {
            let error = mapServerError(response.error, message: response.message)
            logger.error("Activation failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Validate an existing license token
    func validate(token: String) async throws -> LicenseValidationResponse {
        logger.debug("Validating license...")

        let request = ValidationRequest(token: token)

        let response: LicenseValidationResponse = try await post(
            endpoint: "/api/v1/licenses/validate",
            body: request,
            authToken: token
        )

        logger.debug("Validation response: isValid=\(response.isValid)")
        return response
    }

    /// Refresh a license token
    func refresh(token: String) async throws -> String {
        logger.info("Refreshing license token...")

        let request = RefreshRequest(token: token)

        let response: RefreshResponse = try await post(
            endpoint: "/api/v1/licenses/refresh",
            body: request,
            authToken: token
        )

        if response.success {
            logger.info("Token refreshed successfully")
            return response.token
        } else {
            let error = mapServerError(response.error, message: response.message)
            logger.error("Refresh failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Deactivate a device
    func deactivate(token: String, deviceId: String) async throws {
        logger.info("Deactivating device...")

        let request = DeactivationRequest(deviceId: deviceId)

        let response: DeactivationResponse = try await post(
            endpoint: "/api/v1/licenses/deactivate",
            body: request,
            authToken: token
        )

        if !response.success {
            let error = mapServerError(response.error, message: response.message)
            logger.error("Deactivation failed: \(error.localizedDescription)")
            throw error
        }

        logger.info("Device deactivated successfully")
    }

    // MARK: - Network Methods

    /// Perform POST request with JSON body
    private func post<Request: Encodable, Response: Decodable>(
        endpoint: String,
        body: Request,
        authToken: String? = nil
    ) async throws -> Response {
        let url = baseURL.appendingPathComponent(endpoint)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("PasteShelf/\(appVersion) (macOS)", forHTTPHeaderField: "User-Agent")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LicenseError.networkError("Invalid response")
        }

        // Log response status
        logger.debug("Response status: \(httpResponse.statusCode)")

        // Handle HTTP errors
        switch httpResponse.statusCode {
        case 200 ... 299:
            break // Success
        case 401:
            throw LicenseError.invalidSignature
        case 403:
            throw LicenseError.revoked
        case 404:
            throw LicenseError.serverError("Endpoint not found")
        case 429:
            throw LicenseError.networkError("Rate limited. Please try again later.")
        case 500 ... 599:
            throw LicenseError.serverError("Server error (\(httpResponse.statusCode))")
        default:
            throw LicenseError.serverError("HTTP \(httpResponse.statusCode)")
        }

        // Decode response
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            logger.error("Failed to decode response: \(error.localizedDescription)")
            throw LicenseError.serverError("Invalid response format")
        }
    }

    // MARK: - Helper Methods

    /// Get hardware identifier
    private func getHardwareId() -> String {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )

        guard platformExpert != 0,
              let serialNumberAsCFString = IORegistryEntryCreateCFProperty(
                  platformExpert,
                  kIOPlatformSerialNumberKey as CFString,
                  kCFAllocatorDefault,
                  0
              )?.takeRetainedValue() as? String
        else {
            IOObjectRelease(platformExpert)
            return UUID().uuidString
        }

        IOObjectRelease(platformExpert)
        return serialNumberAsCFString
    }

    /// Map server error code to LicenseError
    private func mapServerError(_ errorCode: String?, message: String?) -> LicenseError {
        guard let code = errorCode else {
            return .serverError(message ?? "Unknown error")
        }

        switch code {
        case "invalid_key":
            return .malformedToken
        case "expired":
            return .expired
        case "revoked":
            return .revoked
        case "device_limit":
            return .deviceLimitExceeded
        case "device_mismatch":
            return .deviceMismatch
        case "invalid_signature":
            return .invalidSignature
        default:
            return .serverError(message ?? code)
        }
    }
}

// MARK: - Request/Response Models

/// Activation request payload
private struct ActivationRequest: Encodable {
    let licenseKey: String
    let deviceId: String
    let deviceName: String
    let hardwareId: String
    let platform: String
    let appVersion: String

    enum CodingKeys: String, CodingKey {
        case licenseKey = "license_key"
        case deviceId = "device_id"
        case deviceName = "device_name"
        case hardwareId = "hardware_id"
        case platform
        case appVersion = "app_version"
    }
}

/// Activation response payload
private struct ActivationResponse: Decodable {
    let success: Bool
    let token: String
    let error: String?
    let message: String?
}

/// Validation request payload
private struct ValidationRequest: Encodable {
    let token: String
}

/// Refresh request payload
private struct RefreshRequest: Encodable {
    let token: String
}

/// Refresh response payload
private struct RefreshResponse: Decodable {
    let success: Bool
    let token: String
    let error: String?
    let message: String?
}

/// Deactivation request payload
private struct DeactivationRequest: Encodable {
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
    }
}

/// Deactivation response payload
private struct DeactivationResponse: Decodable {
    let success: Bool
    let error: String?
    let message: String?
}
