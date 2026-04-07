//
//  WebhookEndpoint+CoreDataProperties.swift
//  PasteShelf
//
//  CoreData properties and fetch requests for WebhookEndpoint entity.
//  Enterprise feature for sending webhook notifications on clipboard events.
//

import CoreData
import Foundation

// MARK: - CoreData Properties

public extension WebhookEndpoint {
    @nonobjc class func fetchRequest() -> NSFetchRequest<WebhookEndpoint> {
        NSFetchRequest<WebhookEndpoint>(entityName: "WebhookEndpoint")
    }

    /// Unique identifier
    @NSManaged var id: UUID?

    /// Display name for the endpoint
    @NSManaged var name: String?

    /// Webhook URL to POST to
    @NSManaged var url: String?

    /// HMAC secret key for signing payloads
    @NSManaged var secretKey: String?

    /// Whether the endpoint is active
    @NSManaged var isEnabled: Bool

    /// JSON array of event types to send (e.g., ["clipboard.created", "clipboard.deleted"])
    @NSManaged var eventsJSON: String?

    /// JSON object of content type filters (e.g., {"contentTypes": ["text", "url"]})
    @NSManaged var filtersJSON: String?

    /// JSON object of custom HTTP headers
    @NSManaged var headersJSON: String?

    /// Number of consecutive failures
    @NSManaged var failureCount: Int32

    /// Last successful delivery timestamp
    @NSManaged var lastSuccessAt: Date?

    /// Last failure timestamp
    @NSManaged var lastFailureAt: Date?

    /// Last failure error message
    @NSManaged var lastFailureMessage: String?

    /// Creation timestamp
    @NSManaged var createdAt: Date?

    /// Last modification timestamp
    @NSManaged var modifiedAt: Date?
}

// MARK: - WebhookEndpoint + Identifiable

extension WebhookEndpoint: Identifiable {}

// MARK: - Convenience Fetch Requests

public extension WebhookEndpoint {
    /// Fetch all enabled webhook endpoints
    @nonobjc class func enabledEndpointsFetchRequest() -> NSFetchRequest<WebhookEndpoint> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isEnabled == YES")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \WebhookEndpoint.name, ascending: true),
        ]
        return request
    }

    /// Fetch endpoints for a specific event type
    @nonobjc class func endpointsForEventFetchRequest(event: String) -> NSFetchRequest<WebhookEndpoint> {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "isEnabled == YES AND eventsJSON CONTAINS %@",
            event
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \WebhookEndpoint.name, ascending: true),
        ]
        return request
    }

    /// Fetch all endpoints sorted by name
    @nonobjc class func allEndpointsFetchRequest() -> NSFetchRequest<WebhookEndpoint> {
        let request = fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \WebhookEndpoint.name, ascending: true),
        ]
        return request
    }

    /// Fetch endpoints with failures
    @nonobjc class func failedEndpointsFetchRequest(minFailures: Int32 = 1) -> NSFetchRequest<WebhookEndpoint> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "failureCount >= %d", minFailures)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \WebhookEndpoint.failureCount, ascending: false),
        ]
        return request
    }
}

// MARK: - WebhookEventType

enum WebhookEventType: String, CaseIterable, Codable {
    case clipboardCreated = "clipboard.created"
    case clipboardDeleted = "clipboard.deleted"
    case clipboardFavorited = "clipboard.favorited"
    case clipboardUnfavorited = "clipboard.unfavorited"
    case clipboardPasted = "clipboard.pasted"
    case ruleExecuted = "rule.executed"

    // MARK: Internal

    var displayName: String {
        switch self {
        case .clipboardCreated: "Clipboard Created"
        case .clipboardDeleted: "Clipboard Deleted"
        case .clipboardFavorited: "Clipboard Favorited"
        case .clipboardUnfavorited: "Clipboard Unfavorited"
        case .clipboardPasted: "Clipboard Pasted"
        case .ruleExecuted: "Rule Executed"
        }
    }

    var description: String {
        switch self {
        case .clipboardCreated: "Triggered when a new item is captured"
        case .clipboardDeleted: "Triggered when an item is deleted"
        case .clipboardFavorited: "Triggered when an item is favorited"
        case .clipboardUnfavorited: "Triggered when an item is unfavorited"
        case .clipboardPasted: "Triggered when an item is pasted"
        case .ruleExecuted: "Triggered when an automation rule executes"
        }
    }
}

// MARK: - JSON Helpers

extension WebhookEndpoint {
    /// Get subscribed event types
    var events: [WebhookEventType] {
        get {
            guard let json = eventsJSON,
                  let data = json.data(using: .utf8),
                  let events = try? JSONDecoder().decode([String].self, from: data)
            else {
                return []
            }
            return events.compactMap { WebhookEventType(rawValue: $0) }
        }
        set {
            let rawValues = newValue.map(\.rawValue)
            if let data = try? JSONEncoder().encode(rawValues),
               let json = String(data: data, encoding: .utf8)
            {
                eventsJSON = json
            }
        }
    }

    /// Get content type filters
    var contentTypeFilters: [String] {
        get {
            guard let json = filtersJSON,
                  let data = json.data(using: .utf8),
                  let filters = try? JSONDecoder().decode(
                      [String: [String]].self,
                      from: data
                  ),
                  let types = filters["contentTypes"]
            else {
                return []
            }
            return types
        }
        set {
            let filters = ["contentTypes": newValue]
            if let data = try? JSONEncoder().encode(filters),
               let json = String(data: data, encoding: .utf8)
            {
                filtersJSON = json
            }
        }
    }

    /// Get custom headers
    var customHeaders: [String: String] {
        get {
            guard let json = headersJSON,
                  let data = json.data(using: .utf8),
                  let headers = try? JSONDecoder().decode(
                      [String: String].self,
                      from: data
                  )
            else {
                return [:]
            }
            return headers
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8)
            {
                headersJSON = json
            }
        }
    }

    /// Check if endpoint should receive a specific event
    func shouldReceive(event: WebhookEventType) -> Bool {
        let subscribedEvents = events
        return subscribedEvents.isEmpty || subscribedEvents.contains(event)
    }

    /// Check if endpoint should receive events for a content type
    func shouldReceive(contentType: String) -> Bool {
        let filters = contentTypeFilters
        return filters.isEmpty || filters.contains(contentType)
    }

    /// Record a successful delivery (caller must save context)
    func recordSuccess() {
        lastSuccessAt = Date()
        failureCount = 0
        lastFailureMessage = nil
        modifiedAt = Date()
    }

    /// Record a failed delivery (caller must save context)
    func recordFailure(message: String) {
        lastFailureAt = Date()
        failureCount += 1
        lastFailureMessage = message
        modifiedAt = Date()

        // Auto-disable after 10 consecutive failures
        if failureCount >= 10 {
            isEnabled = false
        }
    }
}

// MARK: - WebhookEndpoint Configuration

extension WebhookEndpoint {
    /// Create a configuration struct from the entity
    func toConfiguration() -> WebhookConfiguration {
        WebhookConfiguration(
            id: id ?? UUID(),
            name: name ?? "",
            url: url ?? "",
            secretKey: secretKey,
            isEnabled: isEnabled,
            events: events,
            contentTypeFilters: contentTypeFilters,
            customHeaders: customHeaders
        )
    }

    /// Update entity from configuration (caller must save context)
    func update(from config: WebhookConfiguration) {
        name = config.name
        url = config.url
        secretKey = config.secretKey
        isEnabled = config.isEnabled
        events = config.events
        contentTypeFilters = config.contentTypeFilters
        customHeaders = config.customHeaders
        modifiedAt = Date()
    }
}

// MARK: - WebhookConfiguration

/// Lightweight configuration for webhook endpoint
struct WebhookConfiguration: Identifiable, Codable, Equatable {
    // MARK: Lifecycle

    init(
        id: UUID = UUID(),
        name: String,
        url: String,
        secretKey: String? = nil,
        isEnabled: Bool = true,
        events: [WebhookEventType] = [.clipboardCreated],
        contentTypeFilters: [String] = [],
        customHeaders: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.secretKey = secretKey
        self.isEnabled = isEnabled
        self.events = events
        self.contentTypeFilters = contentTypeFilters
        self.customHeaders = customHeaders
    }

    // MARK: Internal

    let id: UUID
    var name: String
    var url: String
    var secretKey: String?
    var isEnabled: Bool
    var events: [WebhookEventType]
    var contentTypeFilters: [String]
    var customHeaders: [String: String]

    /// Validate the configuration
    var isValid: Bool {
        !name.isEmpty && URL(string: url) != nil
    }
}
