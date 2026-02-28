//
//  WebhookManager.swift
//  PasteShelf
//
//  Manages webhook delivery for enterprise automation.
//  Handles HMAC signing, retry logic, and delivery tracking.
//

import CoreData
import CryptoKit
import Foundation
import os.log

// MARK: - Webhook Manager

/// Manages webhook endpoint configuration and delivery
final class WebhookManager {
    // MARK: - Singleton

    static let shared = WebhookManager()

    // MARK: - Private Properties

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "webhooks"
    )

    /// URLSession for webhook requests
    private let session: URLSession

    /// Serial queue for webhook delivery
    private let deliveryQueue = DispatchQueue(
        label: "com.pasteshelf.webhooks.delivery",
        qos: .utility
    )

    /// Maximum number of retry attempts
    private let maxRetries = 3

    /// Base delay between retries (exponential backoff)
    private let baseRetryDelay: TimeInterval = 1.0

    /// Request timeout in seconds
    private let requestTimeout: TimeInterval = 30.0

    // MARK: - Initialization

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = requestTimeout * 2
        configuration.waitsForConnectivity = true
        session = URLSession(configuration: configuration)
    }

    // MARK: - Public API

    /// Send a webhook payload to all subscribed endpoints
    /// - Parameters:
    ///   - event: The event type
    ///   - payload: The webhook payload
    func send(event: WebhookEventType, payload: WebhookPayload) async {
        let endpoints = await fetchEnabledEndpoints(for: event)

        guard !endpoints.isEmpty else {
            logger.debug("No endpoints subscribed to event: \(event.rawValue)")
            return
        }

        logger.info("Sending webhook event \(event.rawValue) to \(endpoints.count) endpoints")

        // Send to all endpoints concurrently
        await withTaskGroup(of: Void.self) { group in
            for endpoint in endpoints {
                group.addTask {
                    await self.deliver(payload: payload, to: endpoint)
                }
            }
        }
    }

    /// Send a clipboard created event
    func sendClipboardCreated(item: ClipboardItem) async {
        let payload = WebhookPayload.clipboardCreated(item: item)
        await send(event: .clipboardCreated, payload: payload)
    }

    /// Send a clipboard created event from content
    func sendClipboardCreated(content: ClipboardContent) async {
        let payload = WebhookPayload.clipboardCreated(content: content)
        await send(event: .clipboardCreated, payload: payload)
    }

    /// Send a clipboard deleted event
    func sendClipboardDeleted(itemId: UUID, contentType: String) async {
        let payload = WebhookPayload.clipboardDeleted(itemId: itemId, contentType: contentType)
        await send(event: .clipboardDeleted, payload: payload)
    }

    /// Send a clipboard favorited event
    func sendClipboardFavorited(item: ClipboardItem) async {
        let payload = WebhookPayload.clipboardFavorited(item: item)
        await send(event: .clipboardFavorited, payload: payload)
    }

    /// Send a clipboard pasted event
    func sendClipboardPasted(item: ClipboardItem) async {
        let payload = WebhookPayload.clipboardPasted(item: item)
        await send(event: .clipboardPasted, payload: payload)
    }

    /// Send a rule executed event
    func sendRuleExecuted(
        rule: AutomationRule,
        actionsExecuted: [AutomationAction],
        success: Bool,
        errorMessage: String? = nil,
        durationMs: Int? = nil
    ) async {
        let payload = WebhookPayload.ruleExecuted(
            rule: rule,
            actionsExecuted: actionsExecuted,
            success: success,
            errorMessage: errorMessage,
            durationMs: durationMs
        )
        await send(event: .ruleExecuted, payload: payload)
    }

    // MARK: - Endpoint Management

    /// Fetch all enabled endpoints for an event
    private func fetchEnabledEndpoints(for event: WebhookEventType) async -> [WebhookConfiguration] {
        let context = StorageManager.shared.viewContext

        return await context.perform {
            let request = WebhookEndpoint.endpointsForEventFetchRequest(event: event.rawValue)

            do {
                let endpoints = try context.fetch(request)
                return endpoints.map { $0.toConfiguration() }
            } catch {
                return []
            }
        }
    }

    /// Create a new webhook endpoint
    func createEndpoint(_ config: WebhookConfiguration) async throws -> UUID {
        let context = StorageManager.shared.viewContext

        return try await context.perform {
            let endpoint = WebhookEndpoint(context: context)
            endpoint.id = config.id
            endpoint.name = config.name
            endpoint.url = config.url
            endpoint.secretKey = config.secretKey
            endpoint.isEnabled = config.isEnabled
            endpoint.events = config.events
            endpoint.contentTypeFilters = config.contentTypeFilters
            endpoint.customHeaders = config.customHeaders
            endpoint.createdAt = Date()
            endpoint.modifiedAt = Date()

            try context.save()
            return config.id
        }
    }

    /// Update an existing webhook endpoint
    func updateEndpoint(_ config: WebhookConfiguration) async throws {
        let context = StorageManager.shared.viewContext

        try await context.perform {
            let request = WebhookEndpoint.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", config.id as CVarArg)
            request.fetchLimit = 1

            guard let endpoint = try context.fetch(request).first else {
                throw WebhookError.endpointNotFound
            }

            endpoint.update(from: config, context: context)
        }
    }

    /// Delete a webhook endpoint
    func deleteEndpoint(id: UUID) async throws {
        let context = StorageManager.shared.viewContext

        try await context.perform {
            let request = WebhookEndpoint.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let endpoint = try context.fetch(request).first else {
                throw WebhookError.endpointNotFound
            }

            context.delete(endpoint)
            try context.save()
        }
    }

    /// Fetch all webhook endpoints
    func fetchAllEndpoints() async -> [WebhookConfiguration] {
        let context = StorageManager.shared.viewContext

        return await context.perform {
            let request = WebhookEndpoint.allEndpointsFetchRequest()

            do {
                let endpoints = try context.fetch(request)
                return endpoints.map { $0.toConfiguration() }
            } catch {
                return []
            }
        }
    }

    /// Test a webhook endpoint with a test payload
    func testEndpoint(_ config: WebhookConfiguration) async -> WebhookTestResult {
        let testPayload = WebhookPayload(
            event: .clipboardCreated,
            data: WebhookData(extra: ["test": "true"])
        )

        do {
            let result = try await deliverOnce(payload: testPayload, to: config)
            return WebhookTestResult(
                success: result.success,
                statusCode: result.statusCode,
                responseTime: result.responseTime,
                errorMessage: result.errorMessage
            )
        } catch {
            return WebhookTestResult(
                success: false,
                statusCode: nil,
                responseTime: nil,
                errorMessage: error.localizedDescription
            )
        }
    }

    // MARK: - Delivery

    /// Deliver payload to an endpoint with retries
    private func deliver(payload: WebhookPayload, to endpoint: WebhookConfiguration) async {
        var lastError: Error?

        for attempt in 0 ..< maxRetries {
            if attempt > 0 {
                // Exponential backoff
                let delay = baseRetryDelay * pow(2.0, Double(attempt - 1))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            do {
                let result = try await deliverOnce(payload: payload, to: endpoint)

                if result.success {
                    logger.info("Webhook delivered to \(endpoint.name): \(result.statusCode ?? 0)")
                    await recordSuccess(for: endpoint.id)
                    return
                } else {
                    lastError = WebhookError.httpError(
                        statusCode: result.statusCode ?? 0,
                        message: result.errorMessage
                    )
                }
            } catch {
                lastError = error
                logger.warning("Webhook delivery attempt \(attempt + 1) failed: \(error.localizedDescription)")
            }
        }

        // All retries exhausted
        let errorMessage = lastError?.localizedDescription ?? "Unknown error"
        logger.error("Webhook delivery to \(endpoint.name) failed after \(self.maxRetries) attempts: \(errorMessage)")
        await recordFailure(for: endpoint.id, message: errorMessage)
    }

    /// Deliver payload once (no retries)
    private func deliverOnce(
        payload: WebhookPayload,
        to endpoint: WebhookConfiguration
    ) async throws -> DeliveryResult {
        guard let url = URL(string: endpoint.url) else {
            throw WebhookError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("PasteShelf/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")", forHTTPHeaderField: "User-Agent")

        // Add custom headers
        for (key, value) in endpoint.customHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Encode payload
        let jsonData = try payload.toJSON()
        request.httpBody = jsonData

        // Add HMAC signature if secret key is configured
        if let secretKey = endpoint.secretKey, !secretKey.isEmpty {
            let signature = sign(data: jsonData, with: secretKey)
            request.setValue(signature, forHTTPHeaderField: "X-PasteShelf-Signature")
            request.setValue("sha256", forHTTPHeaderField: "X-PasteShelf-Signature-Algorithm")
        }

        // Add delivery metadata
        request.setValue(payload.metadata.deliveryId, forHTTPHeaderField: "X-PasteShelf-Delivery-ID")
        request.setValue(payload.event, forHTTPHeaderField: "X-PasteShelf-Event")

        let startTime = Date()

        let (_, response) = try await session.data(for: request)

        let responseTime = Date().timeIntervalSince(startTime)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebhookError.invalidResponse
        }

        let statusCode = httpResponse.statusCode
        let success = (200 ... 299).contains(statusCode)

        return DeliveryResult(
            success: success,
            statusCode: statusCode,
            responseTime: responseTime,
            errorMessage: success ? nil : "HTTP \(statusCode)"
        )
    }

    // MARK: - Signing

    /// Sign payload data with HMAC-SHA256
    private func sign(data: Data, with secretKey: String) -> String {
        let key = SymmetricKey(data: Data(secretKey.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return "sha256=\(signature.map { String(format: "%02x", $0) }.joined())"
    }

    // MARK: - Recording

    /// Record successful delivery
    private func recordSuccess(for endpointId: UUID) async {
        let context = StorageManager.shared.viewContext

        await context.perform {
            let request = WebhookEndpoint.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", endpointId as CVarArg)
            request.fetchLimit = 1

            do {
                if let endpoint = try context.fetch(request).first {
                    endpoint.recordSuccess(context: context)
                }
            } catch {
                // Ignore recording errors
            }
        }
    }

    /// Record failed delivery
    private func recordFailure(for endpointId: UUID, message: String) async {
        let context = StorageManager.shared.viewContext

        await context.perform {
            let request = WebhookEndpoint.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", endpointId as CVarArg)
            request.fetchLimit = 1

            do {
                if let endpoint = try context.fetch(request).first {
                    endpoint.recordFailure(message: message, context: context)
                }
            } catch {
                // Ignore recording errors
            }
        }
    }
}

// MARK: - Supporting Types

/// Result of a single delivery attempt
private struct DeliveryResult {
    let success: Bool
    let statusCode: Int?
    let responseTime: TimeInterval?
    let errorMessage: String?
}

/// Result of testing a webhook endpoint
struct WebhookTestResult {
    let success: Bool
    let statusCode: Int?
    let responseTime: TimeInterval?
    let errorMessage: String?

    var statusDescription: String {
        if success {
            return "Success (\(statusCode ?? 200))"
        } else if let code = statusCode {
            return "Failed (HTTP \(code))"
        } else {
            return errorMessage ?? "Failed"
        }
    }

    var responseTimeDescription: String? {
        guard let time = responseTime else { return nil }
        return String(format: "%.0f ms", time * 1000)
    }
}

/// Webhook-related errors
enum WebhookError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case endpointNotFound
    case featureNotAvailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid webhook URL"
        case .invalidResponse:
            return "Invalid response from webhook endpoint"
        case let .httpError(statusCode, message):
            return "HTTP error \(statusCode): \(message ?? "Unknown error")"
        case .endpointNotFound:
            return "Webhook endpoint not found"
        case .featureNotAvailable:
            return "Webhooks feature requires PasteShelf Enterprise"
        }
    }
}
