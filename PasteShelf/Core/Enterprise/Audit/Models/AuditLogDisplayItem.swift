//
//  AuditLogDisplayItem.swift
//  PasteShelf
//
//  Plain display model derived from AuditLogEntry for use in the audit log viewer UI.
//

import CoreData
import Foundation

// MARK: - AuditLogDisplayItem

/// A lightweight, UI-ready representation of a single audit log entry.
///
/// `AuditLogDisplayItem` is derived from a `AuditLogEntry` CoreData entity and its
/// decrypted detail payload. It provides computed display properties (human-readable
/// names, SF Symbol icon names, formatted timestamps) so that SwiftUI views have no
/// dependency on CoreData or encryption logic.
///
/// Equality and hashing are based solely on `id`, allowing SwiftUI lists to efficiently
/// diff and update rows without re-evaluating computed properties.
struct AuditLogDisplayItem: Identifiable, Hashable {

    // MARK: - Identity

    /// The unique identifier of the underlying audit log entry.
    let id: UUID

    // MARK: - Core Fields

    /// When the auditable action occurred.
    let timestamp: Date

    /// The high-level functional area this event belongs to.
    let category: AuditEventCategory

    /// The specific action that was recorded.
    let action: AuditAction

    /// The operational significance of this event.
    let severity: AuditEventSeverity

    // MARK: - Source

    /// The SSO user ID associated with this event, if one was active.
    let userId: String?

    /// The server-assigned device identifier that generated this event.
    let deviceId: String?

    // MARK: - Resource Context

    /// The type of resource affected by this action, if applicable.
    let resourceType: String?

    /// The identifier of the specific resource affected, if applicable.
    let resourceId: String?

    // MARK: - Detail

    /// The decrypted key/value detail payload for this event.
    let detail: [String: String]

    // MARK: - Computed Display Properties

    /// A human-readable display name for the event's category.
    ///
    /// Maps each `AuditEventCategory` to a localized, title-cased string suitable
    /// for column headers and filter chips in the audit log viewer.
    var categoryDisplayName: String {
        switch category {
        case .clipboard:
            return "Clipboard"
        case .userAction:
            return "User Action"
        case .policy:
            return "Policy"
        case .authentication:
            return "Authentication"
        }
    }

    /// A human-readable display name derived from the action's raw value.
    ///
    /// Converts the snake_case raw value (e.g. `"copy_captured"`) to title case
    /// (e.g. `"Copy Captured"`) for display in the event action column.
    var actionDisplayName: String {
        action.rawValue
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// The SF Symbol name representing the event's severity level.
    ///
    /// Used to render a severity indicator icon alongside each event row in the audit viewer.
    var severityIconName: String {
        switch severity {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .critical:
            return "xmark.octagon"
        }
    }

    /// The event timestamp formatted as a relative string (e.g. "2 hours ago").
    ///
    /// Uses `RelativeDateTimeFormatter` to produce a locale-appropriate relative
    /// description of when the event occurred.
    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    // MARK: - Factory

    /// Creates an `AuditLogDisplayItem` from a CoreData `AuditLogEntry` and its decrypted detail.
    ///
    /// Returns `nil` if any required field (id, timestamp, category, action, or severity) is
    /// missing or cannot be decoded from the stored raw string values.
    ///
    /// - Parameters:
    ///   - entry: The `AuditLogEntry` CoreData managed object to convert.
    ///   - decryptedDetail: The decrypted key/value detail payload for this entry.
    /// - Returns: A fully populated `AuditLogDisplayItem`, or `nil` if required fields are absent.
    static func from(_ entry: AuditLogEntry, decryptedDetail: [String: String]) -> AuditLogDisplayItem? {
        guard
            let id = entry.id,
            let timestamp = entry.timestamp,
            let categoryRaw = entry.eventCategory,
            let category = AuditEventCategory(rawValue: categoryRaw),
            let actionRaw = entry.action,
            let action = AuditAction(rawValue: actionRaw),
            let severityRaw = entry.severity,
            let severity = AuditEventSeverity(rawValue: severityRaw)
        else {
            return nil
        }

        return AuditLogDisplayItem(
            id: id,
            timestamp: timestamp,
            category: category,
            action: action,
            severity: severity,
            userId: entry.userId,
            deviceId: entry.deviceId,
            resourceType: entry.resourceType,
            resourceId: entry.resourceId,
            detail: decryptedDetail
        )
    }

    // MARK: - Hashable

    /// Two items are considered equal when they share the same `id`.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    /// Hashes the item using only its `id`.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
