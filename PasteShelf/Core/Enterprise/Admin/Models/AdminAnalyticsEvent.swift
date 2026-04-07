//
//  AdminAnalyticsEvent.swift
//  PasteShelf
//
//  Model representing a structured analytics event submitted to the admin console.
//

import Foundation

// MARK: - AdminAnalyticsEventType

/// The category of action or state change captured by an analytics event.
///
/// Each case corresponds to a meaningful lifecycle moment in the application or
/// device management workflow.  The raw `String` value is used as the event-type
/// discriminator when serializing events to the admin console API.
enum AdminAnalyticsEventType: String, Codable, Sendable {
    /// A device successfully completed enrollment with the admin console.
    case deviceEnrolled

    /// A device was unenrolled, either by the user or an administrator.
    case deviceUnenrolled

    /// A new admin policy was fetched from the server and applied to the device.
    case policyApplied

    /// A policy check detected that the device violated one or more policy rules.
    case policyViolation

    /// An iCloud sync cycle completed successfully.
    case syncCompleted

    /// A user successfully authenticated via SSO.
    case loginSuccess

    /// An SSO authentication attempt failed.
    case loginFailure

    /// The PasteShelf application was launched.
    case appLaunched

    /// The PasteShelf application was terminated.
    case appTerminated
}

// MARK: - AdminAnalyticsEvent

/// A structured analytics event submitted to the admin console.
///
/// Analytics events allow administrators to audit device activity and track key
/// lifecycle events across the managed fleet.  Events are batched locally and
/// flushed to the admin console server during each check-in cycle.
///
/// The `metadata` dictionary carries event-specific key/value pairs (e.g. policy ID,
/// error codes, or SSO provider identifiers) without requiring a rigid per-event schema.
struct AdminAnalyticsEvent: Codable, Sendable, Identifiable {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates an analytics event.
    ///
    /// - Parameters:
    ///   - id: A locally generated UUID for this event. Defaults to a new `UUID()`.
    ///   - deviceId: The server-assigned device identifier.
    ///   - userId: The SSO user ID, if a session is active. Defaults to `nil`.
    ///   - eventType: The category of action or state change.
    ///   - timestamp: When the event occurred. Defaults to the current date.
    ///   - metadata: Arbitrary key/value context for this event. Defaults to an empty dictionary.
    init(
        id: UUID = UUID(),
        deviceId: String,
        userId: String? = nil,
        eventType: AdminAnalyticsEventType,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.deviceId = deviceId
        self.userId = userId
        self.eventType = eventType
        self.timestamp = timestamp
        self.metadata = metadata
    }

    // MARK: Internal

    // MARK: - Identity

    /// A locally generated UUID that uniquely identifies this event.
    let id: UUID

    // MARK: - Source

    /// The server-assigned identifier of the device that generated this event.
    let deviceId: String

    /// The SSO user ID associated with the event, if a user session was active.
    ///
    /// `nil` for system-level events that are not tied to a specific user (e.g.
    /// `appLaunched` before any login has occurred).
    let userId: String?

    // MARK: - Event Details

    /// The type of action or state change this event represents.
    let eventType: AdminAnalyticsEventType

    /// When the event occurred.
    let timestamp: Date

    /// Arbitrary key/value metadata providing event-specific context.
    ///
    /// Examples:
    /// - `["policyId": "pol-123", "policyVersion": "4"]` for a `policyApplied` event.
    /// - `["errorCode": "SAML_ASSERTION_EXPIRED"]` for a `loginFailure` event.
    var metadata: [String: String]
}
