//
//  CloudKitProvider.swift
//  PasteShelf
//
//  CloudKit API wrapper for push/pull operations.
//

import CloudKit
import Foundation
import os.log

/// CloudKit sync provider implementing SyncProviding protocol
final class CloudKitProvider: SyncProviding, Sendable {
    // MARK: - Properties

    /// CloudKit container
    private let container: CKContainer

    /// Private database for user data
    private let database: CKDatabase

    /// Zone manager for custom zone operations
    private let zoneManager: CloudKitZoneManager

    /// Record mapper for entity conversion
    private let recordMapper: CloudKitRecordMapper

    /// Maximum records per batch operation (CloudKit limit is 400)
    private static let maxBatchSize = 200

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "cloudkit-provider"
    )

    // MARK: - Initialization

    init(
        containerIdentifier: String = "iCloud.com.pasteshelf.PasteShelf",
        encryptionManager: SyncEncryptionManager = SyncEncryptionManager()
    ) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.database = container.privateCloudDatabase
        self.zoneManager = CloudKitZoneManager(container: container)
        self.recordMapper = CloudKitRecordMapper(
            zoneID: zoneManager.zoneID,
            encryptionManager: encryptionManager
        )
    }

    // MARK: - SyncProviding Protocol

    func checkAccountStatus() async throws -> CKAccountStatus {
        do {
            let status = try await container.accountStatus()
            Self.logger.info("iCloud account status: \(String(describing: status))")

            switch status {
            case .available:
                return status
            case .noAccount:
                throw SyncError.noAccount
            case .restricted:
                throw SyncError.accountRestricted
            case .couldNotDetermine, .temporarilyUnavailable:
                throw SyncError.accountTemporarilyUnavailable
            @unknown default:
                throw SyncError.accountTemporarilyUnavailable
            }
        } catch let error as SyncError {
            throw error
        } catch {
            Self.logger.error("Failed to check account status: \(error.localizedDescription)")
            throw SyncError.from(error as? CKError ?? CKError(.networkUnavailable))
        }
    }

    func setupZone() async throws {
        try await zoneManager.setup()
    }

    func pushChanges(_ changes: [SyncChange]) async throws {
        guard !changes.isEmpty else {
            Self.logger.debug("No changes to push")
            return
        }

        Self.logger.info("Pushing \(changes.count) changes to CloudKit")

        // Split into batches to respect CloudKit limits
        let batches = changes.chunked(into: Self.maxBatchSize)

        for (index, batch) in batches.enumerated() {
            Self.logger.debug("Processing batch \(index + 1)/\(batches.count)")
            try await pushBatch(batch)
        }

        Self.logger.info("Successfully pushed all changes")
    }

    func pullChanges(since token: CKServerChangeToken?) async throws -> (
        changes: [SyncChange],
        newToken: CKServerChangeToken?
    ) {
        Self.logger.info("Pulling changes from CloudKit")

        var allChanges: [SyncChange] = []
        var currentToken = token
        var hasMoreChanges = true

        while hasMoreChanges {
            let result = try await fetchZoneChanges(since: currentToken)
            allChanges.append(contentsOf: result.changes)
            currentToken = result.newToken
            hasMoreChanges = result.moreComing
        }

        Self.logger.info("Pulled \(allChanges.count) changes")
        return (allChanges, currentToken)
    }

    func deleteRecord(withID recordID: CKRecord.ID) async throws {
        Self.logger.info("Deleting record: \(recordID.recordName)")

        let operation = CKModifyRecordsOperation(
            recordsToSave: nil,
            recordIDsToDelete: [recordID]
        )

        operation.qualityOfService = .userInitiated

        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    Self.logger.info("Record deleted successfully")
                    continuation.resume()
                case let .failure(error):
                    Self.logger.error("Failed to delete record: \(error.localizedDescription)")
                    let syncError = SyncError.from(error as? CKError ?? CKError(.serverRejectedRequest))
                    continuation.resume(throwing: syncError)
                }
            }

            self.database.add(operation)
        }
    }

    func fetchRecord(withID recordID: CKRecord.ID) async throws -> CKRecord? {
        Self.logger.debug("Fetching record: \(recordID.recordName)")

        do {
            let record = try await database.record(for: recordID)
            return record
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch {
            Self.logger.error("Failed to fetch record: \(error.localizedDescription)")
            throw SyncError.from(error as? CKError ?? CKError(.serverRejectedRequest))
        }
    }

    func subscribeToChanges() async throws {
        try await zoneManager.createSubscriptionIfNeeded()
    }

    // MARK: - Private Methods

    /// Push a batch of changes to CloudKit
    private func pushBatch(_ changes: [SyncChange]) async throws {
        var recordsToSave: [CKRecord] = []
        var recordIDsToDelete: [CKRecord.ID] = []

        for change in changes {
            switch change.changeType {
            case .insert, .update:
                if let encryptedData = change.encryptedData {
                    let record = recordMapper.createRecord(
                        for: change,
                        encryptedData: encryptedData
                    )
                    recordsToSave.append(record)
                }
            case .delete:
                let recordID = change.makeRecordID(zoneID: zoneManager.zoneID)
                recordIDsToDelete.append(recordID)
            default:
                break // Remote changes don't need pushing
            }
        }

        guard !recordsToSave.isEmpty || !recordIDsToDelete.isEmpty else {
            return
        }

        let operation = CKModifyRecordsOperation(
            recordsToSave: recordsToSave,
            recordIDsToDelete: recordIDsToDelete
        )

        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated

        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    Self.logger.debug("Batch saved: \(recordsToSave.count) records, \(recordIDsToDelete.count) deleted")
                    continuation.resume()
                case let .failure(error):
                    Self.logger.error("Batch failed: \(error.localizedDescription)")
                    let syncError = SyncError.from(error as? CKError ?? CKError(.serverRejectedRequest))
                    continuation.resume(throwing: syncError)
                }
            }

            self.database.add(operation)
        }
    }

    /// Fetch changes from the zone
    private func fetchZoneChanges(since token: CKServerChangeToken?) async throws -> (
        changes: [SyncChange],
        newToken: CKServerChangeToken?,
        moreComing: Bool
    ) {
        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        configuration.previousServerChangeToken = token

        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneManager.zoneID],
            configurationsByRecordZoneID: [zoneManager.zoneID: configuration]
        )

        operation.qualityOfService = .userInitiated

        var changes: [SyncChange] = []
        var newToken: CKServerChangeToken?
        var moreComing = false

        return try await withCheckedThrowingContinuation { continuation in
            operation.recordWasChangedBlock = { recordID, result in
                switch result {
                case let .success(record):
                    if let change = self.recordMapper.toSyncChange(from: record) {
                        changes.append(change)
                    }
                case let .failure(error):
                    Self.logger.warning("Failed to fetch record \(recordID.recordName): \(error.localizedDescription)")
                }
            }

            operation.recordWithIDWasDeletedBlock = { recordID, recordType in
                let change = SyncChange(
                    changeType: .remoteDelete,
                    entityType: self.recordMapper.entityType(from: recordType),
                    entityID: UUID(uuidString: recordID.recordName) ?? UUID(),
                    cloudKitRecordID: recordID.recordName
                )
                changes.append(change)
            }

            operation.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
                newToken = token
            }

            operation.recordZoneFetchResultBlock = { _, result in
                switch result {
                case let .success((serverToken, _, more)):
                    newToken = serverToken
                    moreComing = more
                case let .failure(error):
                    Self.logger.error("Zone fetch failed: \(error.localizedDescription)")
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: (changes, newToken, moreComing))
                case let .failure(error):
                    let syncError = SyncError.from(error as? CKError ?? CKError(.serverRejectedRequest))
                    continuation.resume(throwing: syncError)
                }
            }

            self.database.add(operation)
        }
    }

    // MARK: - Additional Methods

    /// Get the zone ID for external use
    var zoneID: CKRecordZone.ID {
        zoneManager.zoneID
    }

    /// Reset all CloudKit data
    func reset() async throws {
        try await zoneManager.teardown()
        try await zoneManager.setup()
    }
}

// MARK: - Array Extension

private extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
