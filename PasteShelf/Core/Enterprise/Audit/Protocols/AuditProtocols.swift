//
//  AuditProtocols.swift
//  PasteShelf
//
//  Protocols defining the Enterprise audit logging layer.
//

import CoreData
import Foundation

// MARK: - AuditLogging

/// Accepts and records audit events on behalf of the application.
///
/// Implementations enqueue events in memory, persist them via an `AuditLogStoring`
/// implementation, and optionally forward them to the admin console. Both single-event
/// and batch-event entry points are provided to accommodate low-frequency user actions
/// and high-frequency clipboard captures respectively.
protocol AuditLogging: Sendable {
    /// Records a single audit event.
    ///
    /// The event is persisted to local storage and, if auto-flush is active, included
    /// in the next sync cycle to the admin console.
    ///
    /// - Parameter event: The `AuditEvent` to record.
    func log(_ event: AuditEvent) async

    /// Records a batch of audit events in a single operation.
    ///
    /// Use this when multiple related actions occur in quick succession (e.g. a bulk
    /// item delete) to reduce per-event overhead and ensure atomicity of the batch.
    ///
    /// - Parameter events: The array of `AuditEvent` values to record.
    func logBatch(_ events: [AuditEvent]) async
}

// MARK: - AuditLogStoring

/// Provides CoreData-backed persistence for audit log events.
///
/// Implementations store events as `AuditLogEntry` managed objects with encrypted
/// detail payloads, support filtered queries for the audit log viewer, track sync
/// state for the flush cycle, and enforce the configured retention window.
protocol AuditLogStoring: Sendable {
    /// Persists a single audit event to local CoreData storage.
    ///
    /// The event's `detail` dictionary is encrypted before being written to the
    /// `encryptedDetail` binary attribute of the `AuditLogEntry` entity.
    ///
    /// - Parameter event: The `AuditEvent` to persist.
    /// - Throws: `AuditError.storageFailure` if the CoreData save fails, or
    ///   `AuditError.encryptionFailed` if the detail payload cannot be encrypted.
    func save(_ event: AuditEvent) async throws

    /// Fetches stored audit log entries, optionally filtered by category and date range.
    ///
    /// Results are returned sorted by timestamp descending (most recent first).
    ///
    /// - Parameters:
    ///   - category: If non-nil, only entries with this category are returned.
    ///   - from: If non-nil, only entries at or after this date are returned.
    ///   - to: If non-nil, only entries at or before this date are returned.
    ///   - limit: The maximum number of entries to return.
    /// - Returns: An array of `AuditLogEntry` managed objects matching the filters.
    /// - Throws: `AuditError.storageFailure` if the CoreData fetch fails.
    func fetchEvents(
        category: AuditEventCategory?,
        from: Date?,
        to: Date?,
        limit: Int
    ) async throws -> [AuditLogEntry]

    /// Fetches audit log entries that have not yet been synced to the admin console.
    ///
    /// Results are sorted by timestamp ascending so that events are uploaded in
    /// chronological order during the flush cycle.
    ///
    /// - Parameter limit: The maximum number of unsynced entries to return.
    /// - Returns: An array of `AuditLogEntry` managed objects with `isSynced == false`.
    /// - Throws: `AuditError.storageFailure` if the CoreData fetch fails.
    func fetchUnsyncedEvents(limit: Int) async throws -> [AuditLogEntry]

    /// Marks the audit log entries with the given IDs as synced.
    ///
    /// Called after a successful flush to the admin console to prevent the same
    /// events from being uploaded again in subsequent sync cycles.
    ///
    /// - Parameter ids: The UUIDs of the `AuditLogEntry` records to mark as synced.
    /// - Throws: `AuditError.storageFailure` if the CoreData save fails.
    func markSynced(_ ids: [UUID]) async throws

    /// Deletes audit log entries whose timestamp predates the retention cutoff.
    ///
    /// This method computes the cutoff date as `now - retentionDays` and batch-deletes
    /// all matching `AuditLogEntry` records.
    ///
    /// - Parameter retentionDays: The number of days to retain entries. Entries older
    ///   than this are permanently deleted.
    /// - Returns: The number of entries that were pruned.
    /// - Throws: `AuditError.storageFailure` if the CoreData delete operation fails.
    func pruneExpired(retentionDays: Int) async throws -> Int

    /// Decrypts and returns the detail dictionary for a given audit log entry.
    ///
    /// - Parameter entry: The `AuditLogEntry` whose `encryptedDetail` binary should be decrypted.
    /// - Returns: The plaintext key/value detail dictionary.
    /// - Throws: `AuditError.decryptionFailed` if the payload cannot be decrypted.
    func decryptDetail(for entry: AuditLogEntry) throws -> [String: String]
}

// MARK: - AuditLogSyncing

/// Flushes locally stored unsynced audit events to the admin console.
///
/// Implementations manage an auto-flush timer that periodically uploads pending
/// events, and expose a manual `flush()` entry point for immediate upload (e.g.
/// after a high-severity event or during device unenrollment).
protocol AuditLogSyncing: Sendable {
    /// Starts the periodic auto-flush timer.
    ///
    /// After calling this method, the implementation will automatically flush
    /// unsynced events to the admin console on a regular schedule. Calling
    /// `startAutoFlush()` when already running replaces the existing timer.
    func startAutoFlush()

    /// Stops the periodic auto-flush timer.
    ///
    /// After calling this method, no automatic flushes are performed until
    /// `startAutoFlush()` is called again.
    func stopAutoFlush()

    /// Immediately uploads all pending unsynced audit events to the admin console.
    ///
    /// Use this to force an upload outside the regular schedule, for example before
    /// the user logs out or when a critical audit event must be relayed without delay.
    ///
    /// - Throws: `AuditError.syncFailed` if the upload fails, or
    ///   `AuditError.notConfigured` if the admin console has not been set up.
    func flush() async throws

    /// The number of audit log entries that have not yet been synced to the admin console.
    var pendingCount: Int { get }
}

// MARK: - AuditError

/// Errors that may be thrown during audit log operations.
enum AuditError: Error, LocalizedError, Sendable {
    /// The audit logging system has not been configured with the required credentials.
    case notConfigured

    /// The detail payload for an audit event could not be encrypted before storage.
    ///
    /// The associated `String` provides a human-readable reason from the encryption layer.
    case encryptionFailed(String)

    /// The encrypted detail payload for an audit log entry could not be decrypted.
    ///
    /// The associated `String` provides a human-readable reason from the decryption layer.
    case decryptionFailed(String)

    /// A CoreData read or write operation failed.
    ///
    /// The associated `String` is the underlying `NSError` description.
    case storageFailure(String)

    /// Uploading pending events to the admin console failed.
    ///
    /// The associated `String` provides the reason, such as a network error message.
    case syncFailed(String)

    /// The audit logging feature is not currently enabled.
    case featureUnavailable

    // MARK: Internal

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Audit logging has not been configured. Admin console credentials are required."
        case let .encryptionFailed(reason):
            "Failed to encrypt audit event detail: \(reason)"
        case let .decryptionFailed(reason):
            "Failed to decrypt audit log entry detail: \(reason)"
        case let .storageFailure(reason):
            "A storage error occurred while processing the audit log: \(reason)"
        case let .syncFailed(reason):
            "Failed to sync audit events to the admin console: \(reason)"
        case .featureUnavailable:
            "Audit logging is not enabled."
        }
    }

    var failureReason: String? {
        switch self {
        case .notConfigured:
            "No admin console server URL or API credentials have been provided."
        case let .encryptionFailed(reason):
            reason
        case let .decryptionFailed(reason):
            reason
        case let .storageFailure(reason):
            reason
        case let .syncFailed(reason):
            reason
        case .featureUnavailable:
            "The audit logging feature is not currently available."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notConfigured:
            "Open Settings > Enterprise > Admin Console and enter the server URL and credentials."
        case .encryptionFailed:
            "Verify that the encryption key is available in the Keychain and retry."
        case .decryptionFailed:
            "The encryption key may have changed. Contact your IT administrator if the issue persists."
        case .storageFailure:
            "Restart the application. If the problem continues, check available disk space."
        case .syncFailed:
            "Check your network connection and verify the admin console server is reachable."
        case .featureUnavailable:
            "Enable audit logging in Enterprise settings."
        }
    }
}
