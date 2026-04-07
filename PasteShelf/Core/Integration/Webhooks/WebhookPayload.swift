//
//  WebhookPayload.swift
//  PasteShelf
//
//  Webhook payload structures for enterprise webhook notifications.
//  Defines the JSON format sent to webhook endpoints.
//

import Foundation

// MARK: - WebhookPayload

/// Payload sent to webhook endpoints
struct WebhookPayload: Codable {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(event: WebhookEventType, data: WebhookData) {
        self.event = event.rawValue
        timestamp = ISO8601DateFormatter().string(from: Date())
        self.data = data
        metadata = WebhookMetadata()
    }

    // MARK: Internal

    /// Event type (e.g., "clipboard.created")
    let event: String

    /// Event timestamp (ISO 8601)
    let timestamp: String

    /// Event payload data
    let data: WebhookData

    /// PasteShelf metadata
    let metadata: WebhookMetadata

    // MARK: - JSON Output

    /// Convert to JSON data
    func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(self)
    }

    /// Convert to JSON string
    func toJSONString() throws -> String {
        let data = try toJSON()
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

// MARK: - WebhookData

/// Event-specific data included in webhook payload
struct WebhookData: Codable {
    // MARK: Lifecycle

    init(
        clipboardItem: WebhookClipboardItemPayload? = nil,
        ruleExecution: RuleExecutionPayload? = nil,
        extra: [String: String]? = nil
    ) {
        self.clipboardItem = clipboardItem
        self.ruleExecution = ruleExecution
        self.extra = extra
    }

    // MARK: Internal

    /// Clipboard item data (for clipboard events)
    var clipboardItem: WebhookClipboardItemPayload?

    /// Rule execution data (for rule events)
    var ruleExecution: RuleExecutionPayload?

    /// Generic key-value data
    var extra: [String: String]?
}

// MARK: - WebhookClipboardItemPayload

/// Clipboard item data for webhook payload
struct WebhookClipboardItemPayload: Codable {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(item: ClipboardItem) {
        id = item.id?.uuidString ?? ""
        contentType = item.contentType ?? "unknown"

        // Truncate preview for security (max 200 chars)
        if let preview = item.plainTextPreview {
            if item.isSensitive {
                self.preview = "[REDACTED]"
            } else if preview.count > 200 {
                self.preview = String(preview.prefix(200)) + "..."
            } else {
                self.preview = preview
            }
        } else {
            preview = nil
        }

        sourceAppBundleId = item.sourceAppBundleId
        sourceAppName = item.sourceAppName
        isFavorite = item.isFavorite
        isSensitive = item.isSensitive
        capturedAt = ISO8601DateFormatter().string(from: item.timestamp ?? Date())
        contentHash = item.contentHash

        // Calculate text stats
        if let text = item.plainTextPreview {
            characterCount = text.count
            wordCount = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        } else {
            characterCount = nil
            wordCount = nil
        }
    }

    init(content: ClipboardContent) {
        id = content.id.uuidString
        contentType = content.primaryType.rawValue

        // Get preview text
        if let text = content.plainText {
            if text.count > 200 {
                preview = String(text.prefix(200)) + "..."
            } else {
                preview = text
            }
        } else {
            preview = nil
        }

        sourceAppBundleId = nil
        sourceAppName = nil
        isFavorite = false
        isSensitive = false
        capturedAt = ISO8601DateFormatter().string(from: Date())
        contentHash = nil

        if let text = content.plainText {
            characterCount = text.count
            wordCount = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        } else {
            characterCount = nil
            wordCount = nil
        }
    }

    // MARK: Internal

    /// Item UUID
    let id: String

    /// Content type (text, image, url, etc.)
    let contentType: String

    /// Content preview (truncated for security)
    let preview: String?

    /// Source application bundle ID
    let sourceAppBundleId: String?

    /// Source application name
    let sourceAppName: String?

    /// Whether item is marked as favorite
    let isFavorite: Bool

    /// Whether item is marked as sensitive
    let isSensitive: Bool

    /// Capture timestamp (ISO 8601)
    let capturedAt: String

    /// Content hash (for deduplication)
    let contentHash: String?

    /// Character count (for text content)
    let characterCount: Int?

    /// Word count (for text content)
    let wordCount: Int?
}

// MARK: - RuleExecutionPayload

/// Rule execution data for webhook payload
struct RuleExecutionPayload: Codable {
    // MARK: Lifecycle

    init(
        rule: AutomationRule,
        actionsExecuted: [AutomationAction],
        success: Bool,
        errorMessage: String? = nil,
        durationMs: Int? = nil
    ) {
        ruleId = rule.id.uuidString
        ruleName = rule.name
        trigger = rule.trigger.displayName
        self.actionsExecuted = actionsExecuted.map(\.actionType.displayName)
        self.success = success
        self.errorMessage = errorMessage
        self.durationMs = durationMs
    }

    // MARK: Internal

    /// Rule ID
    let ruleId: String

    /// Rule name
    let ruleName: String

    /// Trigger type
    let trigger: String

    /// Actions executed
    let actionsExecuted: [String]

    /// Whether execution was successful
    let success: Bool

    /// Error message if failed
    let errorMessage: String?

    /// Execution duration in milliseconds
    let durationMs: Int?
}

// MARK: - WebhookMetadata

/// PasteShelf metadata included in all webhook payloads
struct WebhookMetadata: Codable {
    // MARK: Lifecycle

    init() {
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        apiVersion = "1.0"
        deliveryId = UUID().uuidString
    }

    // MARK: Internal

    /// PasteShelf version
    let appVersion: String

    /// API version for payload format
    let apiVersion: String

    /// Webhook delivery ID (for idempotency)
    let deliveryId: String
}

// MARK: - Payload Builders

extension WebhookPayload {
    /// Create payload for clipboard.created event
    static func clipboardCreated(item: ClipboardItem) -> WebhookPayload {
        WebhookPayload(
            event: .clipboardCreated,
            data: WebhookData(clipboardItem: WebhookClipboardItemPayload(item: item))
        )
    }

    /// Create payload for clipboard.created event from content
    static func clipboardCreated(content: ClipboardContent) -> WebhookPayload {
        WebhookPayload(
            event: .clipboardCreated,
            data: WebhookData(clipboardItem: WebhookClipboardItemPayload(content: content))
        )
    }

    /// Create payload for clipboard.deleted event
    static func clipboardDeleted(itemId: UUID, contentType: String) -> WebhookPayload {
        WebhookPayload(
            event: .clipboardDeleted,
            data: WebhookData(extra: [
                "itemId": itemId.uuidString,
                "contentType": contentType,
            ])
        )
    }

    /// Create payload for clipboard.favorited event
    static func clipboardFavorited(item: ClipboardItem) -> WebhookPayload {
        WebhookPayload(
            event: .clipboardFavorited,
            data: WebhookData(clipboardItem: WebhookClipboardItemPayload(item: item))
        )
    }

    /// Create payload for clipboard.unfavorited event
    static func clipboardUnfavorited(item: ClipboardItem) -> WebhookPayload {
        WebhookPayload(
            event: .clipboardUnfavorited,
            data: WebhookData(clipboardItem: WebhookClipboardItemPayload(item: item))
        )
    }

    /// Create payload for clipboard.pasted event
    static func clipboardPasted(item: ClipboardItem) -> WebhookPayload {
        WebhookPayload(
            event: .clipboardPasted,
            data: WebhookData(clipboardItem: WebhookClipboardItemPayload(item: item))
        )
    }

    /// Create payload for rule.executed event
    static func ruleExecuted(
        rule: AutomationRule,
        actionsExecuted: [AutomationAction],
        success: Bool,
        errorMessage: String? = nil,
        durationMs: Int? = nil
    ) -> WebhookPayload {
        WebhookPayload(
            event: .ruleExecuted,
            data: WebhookData(
                ruleExecution: RuleExecutionPayload(
                    rule: rule,
                    actionsExecuted: actionsExecuted,
                    success: success,
                    errorMessage: errorMessage,
                    durationMs: durationMs
                )
            )
        )
    }
}
