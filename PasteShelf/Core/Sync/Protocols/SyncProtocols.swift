//
//  SyncProtocols.swift
//  PasteShelf
//
//  Protocol definitions for the sync system.
//

import CloudKit
import Combine
import Foundation

// MARK: - Sync Status Types

/// Represents the current state of the sync system
public enum SyncStatus: Equatable, Sendable {
    /// Sync is not active (disabled or not configured)
    case disabled

    /// Sync is ready but idle
    case idle

    /// Currently syncing with progress information
    case syncing(progress: Double)

    /// Sync completed successfully
    case synced(lastSync: Date)

    /// Sync encountered an error
    case error(SyncError)

    /// Device is offline, changes queued
    case offline

    /// Waiting for iCloud account
    case waitingForAccount
}

/// Represents the sync state of an individual item
public enum ItemSyncState: Int16, Sendable {
    /// Item has local changes not yet synced
    case pending = 0

    /// Item is synced with CloudKit
    case synced = 1

    /// Item has conflicts that need resolution
    case conflicted = 2

    /// Item is marked for deletion
    case deleted = 3
}

// MARK: - SyncManaging Protocol

/// Main protocol for managing sync operations
@MainActor
public protocol SyncManaging: ObservableObject {
    /// Current sync status
    var status: SyncStatus { get }

    /// Publisher for sync status changes
    var statusPublisher: AnyPublisher<SyncStatus, Never> { get }

    /// Whether sync is enabled
    var isEnabled: Bool { get set }

    /// Last successful sync date
    var lastSyncDate: Date? { get }

    /// Start sync engine
    func start() async throws

    /// Stop sync engine
    func stop()

    /// Trigger immediate sync
    func syncNow() async throws

    /// Reset sync state (deletes all CloudKit data)
    func reset() async throws
}

// MARK: - SyncProviding Protocol

/// Protocol for CloudKit operations
public protocol SyncProviding: Sendable {
    /// Check if CloudKit is available
    func checkAccountStatus() async throws -> CKAccountStatus

    /// Set up custom zone for sync
    func setupZone() async throws

    /// Push local changes to CloudKit
    func pushChanges(_ changes: [SyncChange]) async throws

    /// Pull remote changes from CloudKit
    func pullChanges(since token: CKServerChangeToken?) async throws -> (changes: [SyncChange], newToken: CKServerChangeToken?)

    /// Delete a record from CloudKit
    func deleteRecord(withID recordID: CKRecord.ID) async throws

    /// Fetch a specific record
    func fetchRecord(withID recordID: CKRecord.ID) async throws -> CKRecord?

    /// Subscribe to remote change notifications
    func subscribeToChanges() async throws
}

// MARK: - SyncEncrypting Protocol

/// Protocol for end-to-end encryption operations
public protocol SyncEncrypting: Sendable {
    /// Check if encryption key exists
    var hasEncryptionKey: Bool { get async }

    /// Generate or retrieve the encryption key
    func getOrCreateKey() async throws -> Data

    /// Encrypt data for sync
    func encrypt(_ data: Data) async throws -> Data

    /// Decrypt data from sync
    func decrypt(_ data: Data) async throws -> Data

    /// Rotate encryption key (re-encrypts all data)
    func rotateKey() async throws
}

// MARK: - ChangeTracking Protocol

/// Protocol for tracking local changes
public protocol ChangeTracking: Sendable {
    /// Get pending changes since last sync
    func getPendingChanges() async throws -> [SyncChange]

    /// Mark changes as synced
    func markAsSynced(_ changes: [SyncChange]) async throws

    /// Record a new change
    func recordChange(_ change: SyncChange) async throws

    /// Clear change history (after successful sync)
    func clearHistory(before date: Date) async throws
}

// MARK: - ConflictResolving Protocol

/// Protocol for resolving sync conflicts
public protocol ConflictResolving: Sendable {
    /// Resolve a conflict between local and remote versions
    func resolve(
        local: SyncChange,
        remote: SyncChange
    ) async throws -> ConflictResolution

    /// Resolve multiple conflicts
    func resolveAll(
        conflicts: [(local: SyncChange, remote: SyncChange)]
    ) async throws -> [ConflictResolution]
}

/// Result of conflict resolution
public enum ConflictResolution: Sendable {
    /// Use the local version
    case useLocal(SyncChange)

    /// Use the remote version
    case useRemote(SyncChange)

    /// Use a merged version
    case merged(SyncChange)
}

// MARK: - Record Mapping Protocol

/// Protocol for mapping between CoreData entities and CloudKit records
public protocol CloudKitRecordMapping: Sendable {
    associatedtype Entity

    /// Convert entity to CloudKit record
    func toRecord(_ entity: Entity, encryptor: SyncEncrypting) async throws -> CKRecord

    /// Convert CloudKit record to entity data
    func fromRecord(_ record: CKRecord, decryptor: SyncEncrypting) async throws -> Entity
}
