//
//  AuditManager.swift
//  PasteShelf
//
//  @MainActor singleton orchestrator for the Enterprise audit logging subsystem.
//  Coordinates AuditLogger, AuditLogSyncService, AuditRetentionService, and AuditLogStorageService.
//

import Combine
import Foundation
import os.log

// MARK: - AuditManager

/// Central manager for the Enterprise audit logging subsystem.
///
/// `AuditManager` orchestrates all audit-related services — logging, sync, retention, and
/// storage — behind a single entry point. It follows the same `@MainActor` singleton pattern
/// as `AdminManager` and `SSOManager`.
///
/// The manager exposes typed logging entry points that delegate to `AuditLogger` so that
/// call sites throughout the application do not need to interact with the service layer
/// directly. The `storage` property grants the audit log viewer read access to `AuditLogStoring`.
@MainActor
final class AuditManager: ObservableObject {

    // MARK: - Singleton

    /// The shared application-wide `AuditManager` instance.
    static let shared = AuditManager()

    // MARK: - Published State

    /// Whether the audit logging system has been configured and is active.
    @Published private(set) var isEnabled: Bool = false

    /// The active retention policy, controlling how long entries are kept locally.
    @Published private(set) var retentionConfiguration: AuditRetentionConfiguration = .default

    /// The most recent error encountered by the audit subsystem, if any.
    @Published var lastError: AuditError?

    // MARK: - Dependencies

    private var auditLogger: AuditLogger?
    private var syncService: AuditLogSyncService?
    private var retentionService: AuditRetentionService?
    private var storageService: AuditLogStorageService?

    private let logger = Logger.audit

    // MARK: - Initialization

    /// Private initializer for the shared singleton.
    private init() {}

    /// Designated initializer for dependency injection in tests.
    ///
    /// - Parameters:
    ///   - auditLogger: The logger that persists individual audit events.
    ///   - syncService: The service that flushes stored events to the admin console.
    ///   - retentionService: The service that prunes expired events on a daily schedule.
    ///   - storageService: The CoreData storage backend exposed to the audit log viewer.
    init(
        auditLogger: AuditLogger,
        syncService: AuditLogSyncService,
        retentionService: AuditRetentionService,
        storageService: AuditLogStorageService
    ) {
        self.auditLogger = auditLogger
        self.syncService = syncService
        self.retentionService = retentionService
        self.storageService = storageService
    }

    // MARK: - Configuration

    /// Configures the audit manager with production dependencies and activates the subsystem.
    ///
    /// Call this from `AdminManager.configure(with:)` after the admin console API client
    /// has been created. All internal services are wired together using production defaults;
    /// call `startMonitoring()` separately to begin the auto-flush and retention timers.
    ///
    /// - Parameter apiClient: The admin console API client used by the sync service.
    func configure(with apiClient: AdminAPIProviding) {
        let storage = AuditLogStorageService()
        self.storageService = storage

        let loggerService = AuditLogger(
            storage: storage,
            deviceIdProvider: { AdminManager.shared.deviceRegistration?.deviceId },
            userIdProvider: { SSOManager.shared.currentSession?.userId }
        )
        self.auditLogger = loggerService

        let sync = AuditLogSyncService(apiClient: apiClient, storage: storage)
        self.syncService = sync

        let retention = AuditRetentionService(storage: storage, configuration: retentionConfiguration)
        self.retentionService = retention

        isEnabled = true

        // Observe DLP violations to create audit trail entries
        setupDLPViolationObserver()

        logger.info("AuditManager configured and enabled")
    }

    /// Observes DLP violation notifications and logs them as audit events
    private func setupDLPViolationObserver() {
        NotificationCenter.default.addObserver(
            forName: .dlpViolationDetected,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, self.isEnabled else { return }
            let violation = notification.userInfo?["violation"]
            let violationDesc = violation.map { String(describing: $0) } ?? "unknown"
            Task {
                await self.logUserAction(
                    action: .policyViolation,
                    detail: ["violation": violationDesc]
                )
            }
        }
    }

    // MARK: - Monitoring

    /// Starts the auto-flush timer and the daily retention pruning schedule.
    ///
    /// Call this after `configure(with:)` when the device has enrolled with the admin console
    /// and monitoring should begin.
    func startMonitoring() {
        syncService?.startAutoFlush()
        retentionService?.start()
        logger.info("Audit monitoring started")
    }

    /// Stops the auto-flush timer and the daily retention pruning schedule.
    ///
    /// Call this when the admin console session ends or the device is unenrolled.
    func stopMonitoring() {
        syncService?.stopAutoFlush()
        retentionService?.stop()
        logger.info("Audit monitoring stopped")
    }

    // MARK: - Logging Entry Points

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
        await auditLogger?.logClipboardEvent(action: action, resourceId: resourceId, detail: detail)
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
        await auditLogger?.logUserAction(action: action, resourceId: resourceId, detail: detail)
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
        await auditLogger?.logPolicyEvent(action: action, policyId: policyId, detail: detail)
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
        await auditLogger?.logAuthEvent(action: action, severity: severity, detail: detail)
    }

    /// Records a compliance-related audit event.
    ///
    /// - Parameters:
    ///   - action: The compliance action being recorded.
    ///   - severity: The operational significance of this event. Defaults to `.info`.
    ///   - resourceType: The type of resource affected, if applicable.
    ///   - resourceId: The identifier of the affected resource, if applicable.
    ///   - detail: Arbitrary key/value context for this event. Defaults to empty.
    func logComplianceEvent(
        action: AuditAction,
        severity: AuditEventSeverity = .info,
        resourceType: String? = nil,
        resourceId: String? = nil,
        detail: [String: String] = [:]
    ) async {
        let event = AuditEvent(
            category: .compliance,
            action: action,
            severity: severity,
            userId: SSOManager.shared.currentSession?.userId,
            deviceId: AdminManager.shared.deviceRegistration?.deviceId,
            resourceType: resourceType,
            resourceId: resourceId,
            detail: detail
        )
        try? await storageService?.save(event)
    }

    // MARK: - Storage Access

    /// The `AuditLogStoring` backend, exposed for use by the audit log viewer.
    ///
    /// `nil` until `configure(with:)` has been called.
    var storage: AuditLogStoring? {
        storageService
    }
}
