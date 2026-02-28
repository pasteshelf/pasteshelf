//
//  AuditEvent.swift
//  PasteShelf
//
//  Domain models for audit log events, including category, severity, action, and event types.
//

import Foundation

// MARK: - AuditEventCategory

/// The high-level category that groups related audit actions.
///
/// Categories allow administrators to filter the audit log by functional area,
/// such as clipboard activity, user-initiated operations, policy enforcement,
/// or authentication events. The raw `String` value is persisted in CoreData
/// and transmitted when syncing to the admin console.
enum AuditEventCategory: String, Codable, Sendable, CaseIterable {

    /// Events related to clipboard content capture, paste, and item management.
    case clipboard

    /// Events initiated directly by a user in the application UI.
    case userAction = "user"

    /// Events triggered by admin policy evaluation or enforcement.
    case policy

    /// Events related to SSO login, logout, and authentication failures.
    case authentication
}

// MARK: - AuditEventSeverity

/// The severity level assigned to an audit event.
///
/// Severity indicates the operational significance of an event. `info` covers
/// routine activity, `warning` flags anomalies or near-violations, and `critical`
/// marks events that require immediate administrator attention.
enum AuditEventSeverity: String, Codable, Sendable {

    /// Routine operational events logged for observability.
    case info

    /// Anomalous or near-violation events that may warrant review.
    case warning

    /// High-impact events that require immediate administrator attention.
    case critical
}

// MARK: - AuditAction

/// The specific action or event that was recorded in the audit log.
///
/// Each case corresponds to a meaningful user or system action within PasteShelf.
/// The raw `String` value is used as the action discriminator when persisting and
/// transmitting audit events, and is displayed in human-readable form in the UI.
enum AuditAction: String, Codable, Sendable {

    // MARK: Clipboard Actions

    /// A new clipboard item was captured from the system clipboard.
    case copyCaptured = "copy_captured"

    /// The user pasted a clipboard item into another application.
    case pastePerformed = "paste_performed"

    /// The user toggled the favorites state of a clipboard item.
    case favoritesToggled = "favorites_toggled"

    /// A clipboard item was deleted from the local history.
    case itemDeleted = "item_deleted"

    /// The user performed a search query in the clipboard history.
    case searchPerformed = "search_performed"

    // MARK: Policy Actions

    /// An admin policy was received from the server and applied to this device.
    case policyApplied = "policy_applied"

    /// A policy check detected that a user action violated an enforced policy rule.
    case policyViolation = "policy_violation"

    // MARK: Authentication Actions

    /// The user successfully authenticated via SSO.
    case ssoLogin = "sso_login"

    /// The user's SSO session was terminated.
    case ssoLogout = "sso_logout"

    /// An SSO authentication attempt failed.
    case loginFailure = "login_failure"
}

// MARK: - AuditEvent

/// A structured audit event recording a user or system action within PasteShelf.
///
/// `AuditEvent` is the primary domain model for the audit logging subsystem.
/// Events are created at the point of action, queued locally, persisted to the
/// `AuditLogEntry` CoreData entity with encrypted detail payloads, and optionally
/// synced to the admin console for centralized review.
///
/// The `detail` dictionary carries action-specific key/value pairs (e.g. item IDs,
/// search queries, policy identifiers) without requiring a per-action schema.
struct AuditEvent: Codable, Sendable, Identifiable {

    // MARK: - Identity

    /// A locally generated UUID that uniquely identifies this audit event.
    let id: UUID

    /// When the auditable action occurred.
    let timestamp: Date

    // MARK: - Classification

    /// The high-level functional area this event belongs to.
    let category: AuditEventCategory

    /// The specific action or event being recorded.
    let action: AuditAction

    /// The operational significance of this event.
    let severity: AuditEventSeverity

    // MARK: - Source

    /// The SSO user ID associated with this event, if a user session was active.
    ///
    /// `nil` for system-level events that are not tied to a specific user.
    let userId: String?

    /// The server-assigned device identifier of the device that generated this event.
    ///
    /// `nil` before the device has been enrolled with the admin console.
    let deviceId: String?

    // MARK: - Resource Context

    /// The type of resource affected by this action (e.g. `"ClipboardItem"`, `"Policy"`).
    ///
    /// `nil` for events that do not target a specific resource.
    let resourceType: String?

    /// The identifier of the specific resource affected (e.g. a UUID string or policy ID).
    ///
    /// `nil` for events that do not target a specific resource.
    let resourceId: String?

    // MARK: - Detail

    /// Arbitrary key/value pairs providing action-specific context.
    ///
    /// Examples:
    /// - `["contentType": "text/plain", "characterCount": "412"]` for `copyCaptured`.
    /// - `["policyId": "pol-007", "ruleName": "NoSensitiveData"]` for `policyViolation`.
    /// - `["provider": "Okta", "errorCode": "SAML_EXPIRED"]` for `loginFailure`.
    let detail: [String: String]

    // MARK: - Initialization

    /// Creates a new audit event.
    ///
    /// - Parameters:
    ///   - id: A locally generated UUID for this event. Defaults to a new `UUID()`.
    ///   - timestamp: When the action occurred. Defaults to the current date.
    ///   - category: The high-level functional area of the event.
    ///   - action: The specific action being recorded.
    ///   - severity: The operational significance of this event. Defaults to `.info`.
    ///   - userId: The SSO user ID, if a session is active. Defaults to `nil`.
    ///   - deviceId: The server-assigned device identifier. Defaults to `nil`.
    ///   - resourceType: The type of resource affected, if any. Defaults to `nil`.
    ///   - resourceId: The identifier of the affected resource, if any. Defaults to `nil`.
    ///   - detail: Arbitrary key/value context for this event. Defaults to an empty dictionary.
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: AuditEventCategory,
        action: AuditAction,
        severity: AuditEventSeverity = .info,
        userId: String? = nil,
        deviceId: String? = nil,
        resourceType: String? = nil,
        resourceId: String? = nil,
        detail: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.action = action
        self.severity = severity
        self.userId = userId
        self.deviceId = deviceId
        self.resourceType = resourceType
        self.resourceId = resourceId
        self.detail = detail
    }
}
