//
//  AuditLogger.swift
//  PasteShelf
//
//  Audit event recorder. Conforms to AuditLogging and delegates
//  persistence to an AuditLogStoring implementation.
//

import Foundation
import os.log

// MARK: - AuditLogger

/// Records audit events to local encrypted storage.
///
/// `AuditLogger` is the primary entry point for the audit logging subsystem. It provides
/// typed convenience methods that build `AuditEvent` values from
/// named parameters so call sites remain concise.
///
/// Both `deviceIdProvider` and `userIdProvider` are closure-based to allow late binding
/// from the `AdminManager` and `SSOManager` singletons without introducing a retain cycle.
@MainActor
final class AuditLogger: AuditLogging, @unchecked Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates an `AuditLogger` with the given storage backend and identity providers.
    ///
    /// - Parameters:
    ///   - storage: The `AuditLogStoring` implementation that persists events.
    ///   - deviceIdProvider: A closure returning the current device ID, or `nil`.
    ///   - userIdProvider: A closure returning the current SSO user ID, or `nil`.
    init(
        storage: AuditLogStoring,
        deviceIdProvider: @escaping @MainActor @Sendable () -> String?,
        userIdProvider: @escaping @MainActor @Sendable () -> String?
    ) {
        self.storage = storage
        self.deviceIdProvider = deviceIdProvider
        self.userIdProvider = userIdProvider
    }

    // MARK: Internal

    // MARK: - AuditLogging

    /// Records a single audit event to local storage.
    ///
    /// The call is silently dropped if audit logging is not enabled.
    /// Storage errors are logged but not re-thrown so that audit
    /// logging never disrupts the main application flow.
    ///
    /// - Parameter event: The `AuditEvent` to record.
    func log(_ event: AuditEvent) async {
        // Enrich with HIPAA metadata when HIPAA compliance mode is active
        let finalEvent = HIPAAEnhancedAuditLogger.enrichIfNeeded(event)

        do {
            try await storage.save(finalEvent)
            logger
                .debug(
                    "Logged audit event \(finalEvent.id) [\(finalEvent.category.rawValue)/\(finalEvent.action.rawValue)]"
                )
        } catch {
            logger.error("Failed to persist audit event \(finalEvent.id): \(error.localizedDescription)")
        }
    }

    /// Records a batch of audit events to local storage.
    ///
    /// Individual storage errors are logged but do not prevent subsequent events in the
    /// batch from being attempted.
    ///
    /// - Parameter events: The array of `AuditEvent` values to record.
    func logBatch(_ events: [AuditEvent]) async {
        for event in events {
            do {
                try await storage.save(event)
            } catch {
                logger.error("Failed to persist batch audit event \(event.id): \(error.localizedDescription)")
            }
        }

        logger.debug("Logged audit batch of \(events.count) event(s)")
    }

    // MARK: - Convenience Methods

    /// Records a clipboard-related audit event.
    ///
    /// - Parameters:
    ///   - action: The clipboard action being recorded.
    ///   - resourceId: The identifier of the affected clipboard item, if applicable.
    ///   - detail: Arbitrary key/value context for this event. Defaults to empty.
    func logClipboardEvent(
        action: AuditAction,
        resourceId: String? = nil,
        detail: [String: String] = [:]
    ) async {
        let event = AuditEvent(
            category: .clipboard,
            action: action,
            severity: .info,
            userId: userIdProvider(),
            deviceId: deviceIdProvider(),
            resourceType: resourceId != nil ? "ClipboardItem" : nil,
            resourceId: resourceId,
            detail: detail
        )
        await log(event)
    }

    /// Records a user-action audit event.
    ///
    /// - Parameters:
    ///   - action: The user action being recorded.
    ///   - resourceId: The identifier of the affected resource, if applicable.
    ///   - detail: Arbitrary key/value context for this event. Defaults to empty.
    func logUserAction(
        action: AuditAction,
        resourceId: String? = nil,
        detail: [String: String] = [:]
    ) async {
        let event = AuditEvent(
            category: .userAction,
            action: action,
            severity: .info,
            userId: userIdProvider(),
            deviceId: deviceIdProvider(),
            resourceId: resourceId,
            detail: detail
        )
        await log(event)
    }

    /// Records a policy-related audit event.
    ///
    /// - Parameters:
    ///   - action: The policy action being recorded.
    ///   - policyId: The identifier of the affected policy, if applicable.
    ///   - detail: Arbitrary key/value context for this event. Defaults to empty.
    func logPolicyEvent(
        action: AuditAction,
        policyId: String? = nil,
        detail: [String: String] = [:]
    ) async {
        let event = AuditEvent(
            category: .policy,
            action: action,
            severity: .info,
            userId: userIdProvider(),
            deviceId: deviceIdProvider(),
            resourceType: policyId != nil ? "Policy" : nil,
            resourceId: policyId,
            detail: detail
        )
        await log(event)
    }

    /// Records an authentication audit event.
    ///
    /// - Parameters:
    ///   - action: The authentication action being recorded.
    ///   - severity: The operational significance of this event. Defaults to `.info`.
    ///   - detail: Arbitrary key/value context for this event. Defaults to empty.
    func logAuthEvent(
        action: AuditAction,
        severity: AuditEventSeverity = .info,
        detail: [String: String] = [:]
    ) async {
        let event = AuditEvent(
            category: .authentication,
            action: action,
            severity: severity,
            userId: userIdProvider(),
            deviceId: deviceIdProvider(),
            detail: detail
        )
        await log(event)
    }

    // MARK: Private

    // MARK: - Dependencies

    private let storage: AuditLogStoring

    /// Returns the current device ID from the `DeviceRegistration`, or `nil` if not enrolled.
    private let deviceIdProvider: @MainActor @Sendable () -> String?

    /// Returns the current SSO user ID, or `nil` if no session is active.
    private let userIdProvider: @MainActor @Sendable () -> String?

    private let logger = Logger.audit
}
