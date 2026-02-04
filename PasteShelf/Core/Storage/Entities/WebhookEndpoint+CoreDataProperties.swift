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

extension WebhookEndpoint {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WebhookEndpoint> {
        NSFetchRequest<WebhookEndpoint>(entityName: "WebhookEndpoint")
    }

    /// Unique identifier
    @NSManaged public var id: UUID?

    /// Display name for the endpoint
    @NSManaged public var name: String?

    /// Webhook URL to POST to
    @NSManaged public var url: String?

    /// HMAC secret key for signing payloads
    @NSManaged public var secretKey: String?

    /// Whether the endpoint is active
    @NSManaged public var isEnabled: Bool

    /// JSON array of event types to send (e.g., ["clipboard.created", "clipboard.deleted"])
    @NSManaged public var eventsJSON: String?

    /// JSON object of content type filters (e.g., {"contentTypes": ["text", "url"]})
    @NSManaged public var filtersJSON: String?

    /// JSON object of custom HTTP headers
    @NSManaged public var headersJSON: String?

    /// Number of consecutive failures
    @NSManaged public var failureCount: Int32

    /// Last successful delivery timestamp
    @NSManaged public var lastSuccessAt: Date?

    /// Last failure timestamp
    @NSManaged public var lastFailureAt: Date?

    /// Last failure error message
    @NSManaged public var lastFailureMessage: String?

    /// Creation timestamp
    @NSManaged public var createdAt: Date?

    /// Last modification timestamp
    @NSManaged public var modifiedAt: Date?
}

// MARK: - Identifiable Conformance

extension WebhookEndpoint: Identifiable {}

// MARK: - Convenience Fetch Requests

extension WebhookEndpoint {
    /// Fetch all enabled webhook endpoints
    @nonobjc public class func enabledEndpointsFetchRequest() -> NSFetchRequest<WebhookEndpoint> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isEnabled == YES")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \WebhookEndpoint.name, ascending: true),
        ]
        return request
    }

    /// Fetch endpoints for a specific event type
    @nonobjc public class func endpointsForEventFetchRequest(event: String) -> NSFetchRequest<WebhookEndpoint> {
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
    @nonobjc public class func allEndpointsFetchRequest() -> NSFetchRequest<WebhookEndpoint> {
        let request = fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \WebhookEndpoint.name, ascending: true),
        ]
        return request
    }

    /// Fetch endpoints with failures
    @nonobjc public class func failedEndpointsFetchRequest(minFailures: Int32 = 1) -> NSFetchRequest<WebhookEndpoint> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "failureCount >= %d", minFailures)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \WebhookEndpoint.failureCount, ascending: false),
        ]
        return request
    }
}

// MARK: - Webhook Event Types

enum WebhookEventType: String, CaseIterable, Codable {
    case clipboardCreated = "clipboard.created"
    case clipboardDeleted = "clipboard.deleted"
    case clipboardFavorited = "clipboard.favorited"
    case clipboardUnfavorited = "clipboard.unfavorited"
    case clipboardPasted = "clipboard.pasted"
    case ruleExecuted = "rule.executed"

    var displayName: String {
        switch self {
        case .clipboardCreated: return "Clipboard Created"
        case .clipboardDeleted: return "Clipboard Deleted"
        case .clipboardFavorited: return "Clipboard Favorited"
        case .clipboardUnfavorited: return "Clipboard Unfavorited"
        case .clipboardPasted: return "Clipboard Pasted"
        case .ruleExecuted: return "Rule Executed"
        }
    }

    var description: String {
        switch self {
        case .clipboardCreated: return "Triggered when a new item is captured"
        case .clipboardDeleted: return "Triggered when an item is deleted"
        case .clipboardFavorited: return "Triggered when an item is favorited"
        case .clipboardUnfavorited: return "Triggered when an item is unfavorited"
        case .clipboardPasted: return "Triggered when an item is pasted"
        case .ruleExecuted: return "Triggered when an automation rule executes"
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

    /// Record a successful delivery
    func recordSuccess(context: NSManagedObjectContext) {
        lastSuccessAt = Date()
        failureCount = 0
        lastFailureMessage = nil
        modifiedAt = Date()
        try? context.save()
    }

    /// Record a failed delivery
    func recordFailure(message: String, context: NSManagedObjectContext) {
        lastFailureAt = Date()
        failureCount += 1
        lastFailureMessage = message
        modifiedAt = Date()

        // Auto-disable after 10 consecutive failures
        if failureCount >= 10 {
            isEnabled = false
        }

        try? context.save()
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

    /// Update entity from configuration
    func update(from config: WebhookConfiguration, context: NSManagedObjectContext) {
        name = config.name
        url = config.url
        secretKey = config.secretKey
        isEnabled = config.isEnabled
        events = config.events
        contentTypeFilters = config.contentTypeFilters
        customHeaders = config.customHeaders
        modifiedAt = Date()
        try? context.save()
    }
}

// MARK: - Webhook Configuration Struct

/// Lightweight configuration for webhook endpoint
struct WebhookConfiguration: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var url: String
    var secretKey: String?
    var isEnabled: Bool
    var events: [WebhookEventType]
    var contentTypeFilters: [String]
    var customHeaders: [String: String]

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

    /// Validate the configuration
    var isValid: Bool {
        !name.isEmpty && URL(string: url) != nil
    }
}
