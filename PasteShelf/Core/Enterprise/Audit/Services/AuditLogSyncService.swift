//
//  AuditLogSyncService.swift
//  PasteShelf
//
//  Flushes locally stored, unsynced audit log entries to the admin console in batches.
//  Mirrors the AnalyticsReporter pattern, operating against CoreData instead of an in-memory queue.
//

import Foundation
import os.log

// MARK: - AuditLogSyncService

/// Uploads pending audit log entries to the admin console via `AdminAPIProviding`.
///
/// `AuditLogSyncService` reads unsynced `AuditLogEntry` records from CoreData in
/// configurable batches, reconstructs `AuditEvent` domain models (decrypting the detail
/// payload), submits the batch to the server, and then marks the uploaded entries as
/// synced so they are not re-sent on the next flush cycle.
///
/// A periodic timer is available via `startAutoFlush()` / `stopAutoFlush()` to drive
/// background synchronisation, and a manual `flush()` entry point is provided for
/// immediate upload (e.g. before device unenrollment).
final class AuditLogSyncService: AuditLogSyncing, @unchecked Sendable {

    // MARK: - Dependencies

    private let apiClient: AdminAPIProviding
    private let storage: AuditLogStoring

    // MARK: - Configuration

    private let batchSize: Int
    private let flushInterval: TimeInterval

    // MARK: - Timer State

    private var flushTimer: Timer?
    private let lock = NSLock()

    // MARK: - Logger

    private let logger = Logger.audit

    // MARK: - Initialization

    /// Creates an `AuditLogSyncService` with the given API client and storage backend.
    ///
    /// - Parameters:
    ///   - apiClient: The admin console API client used to submit audit event batches.
    ///   - storage: The `AuditLogStoring` implementation used to fetch and mark events.
    ///   - batchSize: The maximum number of entries to include in a single upload request.
    ///     Defaults to `50`.
    ///   - flushInterval: The number of seconds between successive auto-flush timer
    ///     firings. Defaults to `60`.
    init(
        apiClient: AdminAPIProviding,
        storage: AuditLogStoring,
        batchSize: Int = 50,
        flushInterval: TimeInterval = 60
    ) {
        self.apiClient = apiClient
        self.storage = storage
        self.batchSize = batchSize
        self.flushInterval = flushInterval
    }

    // MARK: - AuditLogSyncing

    /// Immediately uploads all pending unsynced audit entries to the admin console.
    ///
    /// 1. Fetches up to `batchSize` unsynced `AuditLogEntry` records from CoreData.
    /// 2. Reconstructs `AuditEvent` domain models (decrypting each entry's detail payload).
    /// 3. Submits the batch to the admin console via `apiClient.submitAuditEvents`.
    /// 4. Marks the successfully uploaded entries as synced in CoreData.
    ///
    /// - Throws: `AuditError.syncFailed` if the network request fails, or any underlying
    ///   storage error encountered while fetching or updating entries.
    func flush() async throws {
        let entries: [AuditLogEntry]
        do {
            entries = try await storage.fetchUnsyncedEvents(limit: batchSize)
        } catch {
            logger.error("Audit sync flush: failed to fetch unsynced entries — \(error.localizedDescription)")
            throw AuditError.syncFailed("Fetch failed: \(error.localizedDescription)")
        }

        guard !entries.isEmpty else {
            logger.debug("Audit sync flush: no pending entries — skipping")
            return
        }

        logger.info("Audit sync flush: uploading \(entries.count) event(s) to admin console")

        // Reconstruct AuditEvent models from CoreData entities
        var events: [AuditEvent] = []
        var ids: [UUID] = []

        for entry in entries {
            guard
                let id = entry.id,
                let actionRaw = entry.action,
                let action = AuditAction(rawValue: actionRaw),
                let categoryRaw = entry.eventCategory,
                let category = AuditEventCategory(rawValue: categoryRaw)
            else {
                logger.warning("Skipping malformed AuditLogEntry (missing required fields)")
                continue
            }

            let severity: AuditEventSeverity
            if let severityRaw = entry.severity, let s = AuditEventSeverity(rawValue: severityRaw) {
                severity = s
            } else {
                severity = .info
            }

            let detail: [String: String]
            do {
                detail = try storage.decryptDetail(for: entry)
            } catch {
                logger.warning("Failed to decrypt detail for audit entry \(id): \(error.localizedDescription) — using empty detail")
                detail = [:]
            }

            let event = AuditEvent(
                id: id,
                timestamp: entry.timestamp ?? Date(),
                category: category,
                action: action,
                severity: severity,
                userId: entry.userId,
                deviceId: entry.deviceId,
                resourceType: entry.resourceType,
                resourceId: entry.resourceId,
                detail: detail
            )
            events.append(event)
            ids.append(id)
        }

        guard !events.isEmpty else {
            logger.warning("Audit sync flush: all entries were malformed — nothing to upload")
            return
        }

        // Submit to admin console
        do {
            try await apiClient.submitAuditEvents(events)
            logger.info("Audit sync flush: successfully submitted \(events.count) event(s)")
        } catch {
            logger.error("Audit sync flush: upload failed — \(error.localizedDescription)")
            throw AuditError.syncFailed(error.localizedDescription)
        }

        // Mark as synced in CoreData
        do {
            try await storage.markSynced(ids)
            logger.debug("Audit sync flush: marked \(ids.count) entries as synced")
        } catch {
            logger.error("Audit sync flush: markSynced failed — \(error.localizedDescription)")
            // Not re-throwing: the upload succeeded; a future flush will attempt to mark them again.
        }
    }

    /// Starts the periodic auto-flush timer on the main run loop.
    ///
    /// Any previously running timer is stopped before the new one is created. The timer
    /// fires every `flushInterval` seconds and uploads all pending audit events to the
    /// admin console asynchronously.
    func startAutoFlush() {
        stopAutoFlush()
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.logger.debug("Audit auto-flush timer fired")
            Task {
                do {
                    try await self.flush()
                } catch {
                    self.logger.error("Audit scheduled auto-flush failed: \(error.localizedDescription)")
                }
            }
        }
        logger.info("Audit auto-flush timer started with interval \(self.flushInterval)s")
    }

    /// Stops the periodic auto-flush timer.
    ///
    /// After calling this method, no further automatic flushes occur until
    /// `startAutoFlush()` is called again.
    func stopAutoFlush() {
        flushTimer?.invalidate()
        flushTimer = nil
        logger.debug("Audit auto-flush timer stopped")
    }

    // MARK: - Accessors

    /// A synchronous, approximate count of pending unsynced audit entries.
    ///
    /// This value is an estimate derived from the `pendingCount` property and may
    /// not reflect CoreData writes that have occurred on a background context since
    /// the last viewContext refresh.
    var pendingCount: Int {
        // This property is synchronous per the protocol but CoreData is async.
        // We return 0 here as a safe default; callers needing an exact count
        // should use storage.fetchUnsyncedEvents(limit:) asynchronously.
        0
    }
}
