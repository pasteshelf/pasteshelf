//
//  HIPAAEnhancedAuditLogger.swift
//  PasteShelf
//
//  Decorator around AuditLogging that injects HIPAA-required fields into audit event details.
//

import Foundation
import os.log

/// Decorator that enriches audit events with HIPAA-required metadata fields.
///
/// When HIPAA compliance mode is active, `HIPAAEnhancedAuditLogger` intercepts audit events
/// and injects the following fields into the event's `detail` dictionary before delegating
/// to the wrapped `AuditLogging` implementation:
///
/// - `hipaa.accessReason`: The stated reason for accessing the data.
/// - `hipaa.phiIndicator`: Whether the accessed data may contain Protected Health Information.
/// - `hipaa.minimumNecessary`: Whether the access follows the minimum necessary standard.
///
/// When HIPAA mode is disabled, events are passed through to the delegate unchanged.
final class HIPAAEnhancedAuditLogger: AuditLogging, @unchecked Sendable {

    // MARK: - Dependencies

    private let delegate: AuditLogging
    private let logger = Logger.compliance

    // MARK: - Initialization

    /// Creates an `HIPAAEnhancedAuditLogger` wrapping the given delegate.
    ///
    /// - Parameter delegate: The underlying `AuditLogging` implementation to forward events to.
    init(delegate: AuditLogging) {
        self.delegate = delegate
    }

    // MARK: - AuditLogging

    func log(_ event: AuditEvent) async {
        let enriched = enrichIfHIPAAEnabled(event)
        await delegate.log(enriched)
    }

    func logBatch(_ events: [AuditEvent]) async {
        let enriched = events.map { enrichIfHIPAAEnabled($0) }
        await delegate.logBatch(enriched)
    }

    // MARK: - HIPAA Enrichment

    /// Static entry point for HIPAA enrichment, callable without an instance.
    ///
    /// This allows `AuditLogger.log(_:)` to enrich events inline when HIPAA mode is active,
    /// without requiring the decorator pattern to be wired through the entire call chain.
    ///
    /// - Parameter event: The original audit event.
    /// - Returns: The event with HIPAA fields injected, or the original event if HIPAA mode is disabled.
    static func enrichIfNeeded(_ event: AuditEvent) -> AuditEvent {
        let config = HIPAAComplianceMode.load()
        guard config.isEnabled else { return event }

        var enrichedDetail = event.detail
        if enrichedDetail["hipaa.accessReason"] == nil {
            enrichedDetail["hipaa.accessReason"] = accessReason(for: event)
        }
        if enrichedDetail["hipaa.phiIndicator"] == nil {
            enrichedDetail["hipaa.phiIndicator"] = phiIndicator(for: event)
        }
        if enrichedDetail["hipaa.minimumNecessary"] == nil {
            enrichedDetail["hipaa.minimumNecessary"] = "true"
        }

        return AuditEvent(
            id: event.id,
            timestamp: event.timestamp,
            category: event.category,
            action: event.action,
            severity: event.severity,
            userId: event.userId,
            deviceId: event.deviceId,
            resourceType: event.resourceType,
            resourceId: event.resourceId,
            detail: enrichedDetail
        )
    }

    /// Enriches an audit event with HIPAA-required metadata if HIPAA mode is active.
    ///
    /// - Parameter event: The original audit event.
    /// - Returns: The event with HIPAA fields injected into `detail`, or the original event if HIPAA mode is disabled.
    private func enrichIfHIPAAEnabled(_ event: AuditEvent) -> AuditEvent {
        Self.enrichIfNeeded(event)
    }

    /// Derives a default access reason from the event's action.
    private static func accessReason(for event: AuditEvent) -> String {
        switch event.action {
        case .copyCaptured:
            return "clipboard_capture"
        case .pastePerformed:
            return "paste_operation"
        case .searchPerformed:
            return "content_search"
        case .itemDeleted:
            return "data_management"
        case .dataExported:
            return "data_portability"
        case .dataDeleted:
            return "data_erasure"
        default:
            return "system_operation"
        }
    }

    /// Determines whether the event may involve Protected Health Information.
    private static func phiIndicator(for event: AuditEvent) -> String {
        // Check if the event detail or context suggests sensitive/PHI content
        if event.detail["isSensitive"] == "true" {
            return "true"
        }
        // Clipboard capture and paste may involve PHI
        switch event.action {
        case .copyCaptured, .pastePerformed:
            return "possible"
        default:
            return "false"
        }
    }
}
