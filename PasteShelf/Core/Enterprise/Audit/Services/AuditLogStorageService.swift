//
//  AuditLogStorageService.swift
//  PasteShelf
//
//  CoreData-backed persistence for audit log events with AES-256-GCM encrypted detail payloads.
//

import CoreData
import Foundation
import os.log

// MARK: - AuditLogStorageService

/// Persists, queries, and prunes `AuditLogEntry` CoreData entities on behalf of the audit subsystem.
///
/// `AuditLogStorageService` conforms to `AuditLogStoring` and delegates all managed-object
/// context work to `PersistenceController`. Reads use the shared `viewContext`; writes use a
/// fresh background context to avoid blocking the main thread.
///
/// The `detail` dictionary of every `AuditEvent` is encrypted via `AuditEncryptionService`
/// before being stored in the `encryptedDetail` binary attribute of `AuditLogEntry`.
final class AuditLogStorageService: AuditLogStoring, @unchecked Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates an `AuditLogStorageService` with the given persistence controller and encryption service.
    ///
    /// - Parameters:
    ///   - persistenceController: The `PersistenceController` that owns the CoreData stack.
    ///     Defaults to the application singleton.
    ///   - encryption: The encryption service used to protect detail payloads.
    ///     Defaults to a new `AuditEncryptionService` instance.
    init(
        persistenceController: PersistenceController = .shared,
        encryption: AuditEncryptionService = AuditEncryptionService()
    ) {
        self.persistenceController = persistenceController
        self.encryption = encryption
    }

    // MARK: Internal

    // MARK: - AuditLogStoring

    /// Persists a single audit event to CoreData with its detail payload encrypted.
    ///
    /// Uses a background context to avoid blocking the main thread. The detail dictionary
    /// is encrypted before the managed object is created, so no plaintext is written to disk.
    ///
    /// - Parameter event: The `AuditEvent` to persist.
    /// - Throws: `AuditError.encryptionFailed` if encryption fails, or
    ///   `AuditError.storageFailure` if the CoreData save fails.
    func save(_ event: AuditEvent) async throws {
        // Encrypt the detail payload before touching CoreData
        let encryptedDetail: Data?
        if event.detail.isEmpty {
            encryptedDetail = nil
        } else {
            do {
                encryptedDetail = try self.encryption.encrypt(event.detail)
            } catch let auditError as AuditError {
                logger.error("Failed to encrypt detail for event \(event.id): \(auditError.localizedDescription)")
                throw auditError
            } catch {
                self.logger.error("Unexpected encryption error for event \(event.id): \(error.localizedDescription)")
                throw AuditError.encryptionFailed(error.localizedDescription)
            }
        }

        let context = self.persistenceController.newBackgroundContext()
        try await context.perform {
            _ = AuditLogEntry(context: context, event: event, encryptedDetail: encryptedDetail)

            do {
                try context.save()
                self.logger.debug("Saved audit event \(event.id) (action: \(event.action.rawValue))")
            } catch {
                self.logger.error("CoreData save failed for audit event \(event.id): \(error.localizedDescription)")
                throw AuditError.storageFailure(error.localizedDescription)
            }
        }
    }

    /// Fetches stored audit log entries with optional category and date-range filters.
    ///
    /// Uses the shared `viewContext` and `AuditLogEntry.viewerFetchRequest` to return results
    /// sorted by timestamp descending.
    ///
    /// - Parameters:
    ///   - category: If non-nil, only entries in this category are returned.
    ///   - from: If non-nil, only entries at or after this date are returned.
    ///   - to: If non-nil, only entries at or before this date are returned.
    ///   - limit: The maximum number of entries to return.
    /// - Returns: An array of `AuditLogEntry` managed objects.
    /// - Throws: `AuditError.storageFailure` if the CoreData fetch fails.
    func fetchEvents(
        category: AuditEventCategory?,
        from: Date?,
        to: Date?,
        limit: Int
    ) async throws -> [AuditLogEntry] {
        let viewContext = self.persistenceController.container.viewContext
        return try await viewContext.perform {
            let request = AuditLogEntry.viewerFetchRequest(category: category, from: from, to: to)
            request.fetchLimit = limit
            do {
                let results = try viewContext.fetch(request)
                self.logger.debug("Fetched \(results.count) audit entries (limit: \(limit))")
                return results
            } catch {
                self.logger.error("CoreData fetch failed for audit viewer: \(error.localizedDescription)")
                throw AuditError.storageFailure(error.localizedDescription)
            }
        }
    }

    /// Fetches audit log entries that have not yet been synced to the admin console.
    ///
    /// Uses `AuditLogEntry.unsyncedFetchRequest` to return entries sorted by timestamp
    /// ascending for chronological upload order.
    ///
    /// - Parameter limit: The maximum number of unsynced entries to return.
    /// - Returns: An array of unsynced `AuditLogEntry` managed objects.
    /// - Throws: `AuditError.storageFailure` if the CoreData fetch fails.
    func fetchUnsyncedEvents(limit: Int) async throws -> [AuditLogEntry] {
        let viewContext = self.persistenceController.container.viewContext
        return try await viewContext.perform {
            let request = AuditLogEntry.unsyncedFetchRequest(limit: limit)
            do {
                let results = try viewContext.fetch(request)
                self.logger.debug("Fetched \(results.count) unsynced audit entries")
                return results
            } catch {
                self.logger.error("CoreData fetch failed for unsynced audit entries: \(error.localizedDescription)")
                throw AuditError.storageFailure(error.localizedDescription)
            }
        }
    }

    /// Marks the audit log entries with the given IDs as synced.
    ///
    /// Uses a background context to batch-update `isSynced = true` and `syncedAt = now`
    /// on all matching entries.
    ///
    /// - Parameter ids: The UUIDs of the `AuditLogEntry` records to mark as synced.
    /// - Throws: `AuditError.storageFailure` if the CoreData save fails.
    func markSynced(_ ids: [UUID]) async throws {
        guard !ids.isEmpty else {
            return
        }

        let context = self.persistenceController.newBackgroundContext()
        try await context.perform {
            let request = AuditLogEntry.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", ids as CVarArg)

            let entries: [AuditLogEntry]
            do {
                entries = try context.fetch(request)
            } catch {
                self.logger.error("CoreData fetch for markSynced failed: \(error.localizedDescription)")
                throw AuditError.storageFailure(error.localizedDescription)
            }

            let now = Date()
            for entry in entries {
                entry.isSynced = true
                entry.syncedAt = now
            }

            do {
                try context.save()
                self.logger.debug("Marked \(entries.count) audit entries as synced")
            } catch {
                self.logger.error("CoreData save failed in markSynced: \(error.localizedDescription)")
                throw AuditError.storageFailure(error.localizedDescription)
            }
        }
    }

    /// Deletes audit log entries whose timestamp predates the retention cutoff.
    ///
    /// Computes a cutoff date of `now - retentionDays` days and deletes all matching
    /// `AuditLogEntry` records using a background context.
    ///
    /// - Parameter retentionDays: The number of days to retain entries.
    /// - Returns: The number of entries that were deleted.
    /// - Throws: `AuditError.storageFailure` if the CoreData fetch or delete fails.
    func pruneExpired(retentionDays: Int) async throws -> Int {
        guard let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -retentionDays,
            to: Date()
        ) else {
            self.logger.error("Failed to compute retention cutoff date for \(retentionDays) days")
            throw AuditError.storageFailure("Failed to compute retention cutoff date")
        }

        let context = self.persistenceController.newBackgroundContext()
        return try await context.perform {
            let request = AuditLogEntry.retentionCleanupFetchRequest(olderThan: cutoff)
            let entries: [AuditLogEntry]
            do {
                entries = try context.fetch(request)
            } catch {
                self.logger.error("CoreData fetch for pruneExpired failed: \(error.localizedDescription)")
                throw AuditError.storageFailure(error.localizedDescription)
            }

            guard !entries.isEmpty else {
                self.logger.debug("No audit entries to prune (cutoff: \(cutoff))")
                return 0
            }

            for entry in entries {
                context.delete(entry)
            }

            do {
                try context.save()
                self.logger.info("Pruned \(entries.count) expired audit entries (cutoff: \(cutoff))")
                return entries.count
            } catch {
                self.logger.error("CoreData save failed in pruneExpired: \(error.localizedDescription)")
                throw AuditError.storageFailure(error.localizedDescription)
            }
        }
    }

    /// Decrypts and returns the detail dictionary for a given audit log entry.
    ///
    /// - Parameter entry: The `AuditLogEntry` whose `encryptedDetail` should be decrypted.
    /// - Returns: The plaintext key/value detail dictionary, or an empty dictionary if
    ///   `encryptedDetail` is `nil`.
    /// - Throws: `AuditError.decryptionFailed` if the payload cannot be decrypted.
    func decryptDetail(for entry: AuditLogEntry) throws -> [String: String] {
        guard let encryptedDetail = entry.encryptedDetail else {
            return [:]
        }
        return try self.encryption.decrypt(encryptedDetail)
    }

    // MARK: Private

    // MARK: - Dependencies

    private let persistenceController: PersistenceController
    private let encryption: AuditEncryptionService
    private let logger = Logger.audit
}
