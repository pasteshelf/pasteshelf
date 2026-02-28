//
//  SyncController.swift
//  SyncServer
//
//  Core sync endpoints: push, pull, status, reset.
//  Implements zero-knowledge encrypted sync with optimistic concurrency.
//

import Fluent
import SQLKit
import Vapor

struct SyncController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let sync = routes.grouped("api", "v1", "sync")
        sync.post("push", use: push)
        sync.post("pull", use: pull)
        sync.get("status", use: status)
        sync.post("reset", use: reset)
    }

    // MARK: - Push Changes

    /// Accept encrypted changes from a client device.
    ///
    /// For each change:
    /// 1. If the entity doesn't exist, insert it.
    /// 2. If it exists and the client's version matches, update it.
    /// 3. If versions conflict, return the server's version as a conflict.
    ///
    /// After processing, append entries to change_log and notify
    /// other devices via WebSocket.
    @Sendable
    func push(req: Request) async throws -> SyncPushResponse {
        let authUser = try req.auth.require(AuthenticatedUser.self)
        let body = try req.content.decode(SyncPushRequest.self)

        var accepted = 0
        var conflicts: [SyncConflictDTO] = []

        for change in body.changes {
            let encryptedBytes = change.encryptedData.flatMap { Data(base64Encoded: $0) }

            // Check if record already exists
            if let existing = try await SyncRecord.query(on: req.db)
                .filter(\.$user.$id == authUser.id)
                .filter(\.$entityID == change.entityID)
                .first()
            {
                // Version check for optimistic concurrency
                let clientVersion = change.clientVersion ?? 0
                if clientVersion != 0 && clientVersion != existing.version {
                    // Conflict: client has stale data
                    conflicts.append(SyncConflictDTO(
                        entityID: change.entityID,
                        entityType: change.entityType,
                        serverVersion: existing.version,
                        serverEncryptedData: existing.encryptedData?.base64EncodedString(),
                        serverContentHash: existing.contentHash
                    ))
                    continue
                }

                // Update existing record
                existing.encryptedData = change.isDeleted ? nil : encryptedBytes
                existing.contentHash = change.contentHash
                existing.isDeleted = change.isDeleted
                existing.sourceDevice = body.deviceID
                existing.version += 1
                try await existing.save(on: req.db)

                // Append to change log
                let changeType = change.isDeleted ? "delete" : "update"
                let logEntry = ChangeLog(
                    userID: authUser.id,
                    entityID: change.entityID,
                    entityType: change.entityType,
                    changeType: changeType,
                    sourceDevice: body.deviceID,
                    syncRecordID: existing.id
                )
                try await logEntry.save(on: req.db)
                accepted += 1

            } else {
                // Insert new record
                let record = SyncRecord(
                    userID: authUser.id,
                    entityID: change.entityID,
                    entityType: change.entityType,
                    encryptedData: change.isDeleted ? nil : encryptedBytes,
                    contentHash: change.contentHash,
                    sourceDevice: body.deviceID
                )
                record.isDeleted = change.isDeleted
                try await record.save(on: req.db)

                let logEntry = ChangeLog(
                    userID: authUser.id,
                    entityID: change.entityID,
                    entityType: change.entityType,
                    changeType: "insert",
                    sourceDevice: body.deviceID,
                    syncRecordID: record.id
                )
                try await logEntry.save(on: req.db)
                accepted += 1
            }
        }

        // Notify other devices via WebSocket
        if accepted > 0, let ws = req.application.webSocketService {
            await ws.notifyChangesAvailable(
                userID: authUser.id,
                excludeDevice: body.deviceID,
                changeCount: accepted
            )
        }

        return SyncPushResponse(
            accepted: accepted,
            conflicts: conflicts,
            serverTimestamp: Date()
        )
    }

    // MARK: - Pull Changes

    /// Return changes since the client's last sync token.
    ///
    /// The token is the last `change_log.id` the client has seen.
    /// Returns up to `limit` changes (default 200) and a new token.
    @Sendable
    func pull(req: Request) async throws -> SyncPullResponse {
        let authUser = try req.auth.require(AuthenticatedUser.self)
        let body = try req.content.decode(SyncPullRequest.self)

        let sinceID = body.since.flatMap { Int($0) } ?? 0
        let pageSize = min(body.limit ?? 200, 500)

        // Query change_log for changes after the cursor
        let changes = try await ChangeLog.query(on: req.db)
            .filter(\.$user.$id == authUser.id)
            .filter(\.$id > sinceID)
            .sort(\.$id)
            .limit(pageSize)
            .all()

        // For each change, fetch the corresponding sync_record to get encrypted data
        var pullChanges: [SyncPullChangeDTO] = []

        for change in changes {
            var encryptedData: String?
            var contentHash: String?
            var isDeleted = false
            var version: Int64 = 0

            // Try to load the sync record for full data
            if let recordID = change.$syncRecord.id,
               let record = try await SyncRecord.find(recordID, on: req.db)
            {
                encryptedData = record.encryptedData?.base64EncodedString()
                contentHash = record.contentHash
                isDeleted = record.isDeleted
                version = record.version
            } else {
                // Record may have been physically deleted; treat as tombstone
                isDeleted = change.changeType == "delete"
            }

            pullChanges.append(SyncPullChangeDTO(
                entityID: change.entityID,
                entityType: change.entityType,
                changeType: change.changeType,
                encryptedData: encryptedData,
                contentHash: contentHash,
                isDeleted: isDeleted,
                version: version,
                sourceDevice: change.sourceDevice,
                timestamp: change.createdAt ?? Date()
            ))
        }

        // Determine new token and whether more data is available
        let newToken: String
        let hasMore: Bool
        if let lastChange = changes.last, let lastID = lastChange.id {
            newToken = String(lastID)
            hasMore = changes.count == pageSize
        } else {
            newToken = String(sinceID)
            hasMore = false
        }

        // Update the device's sync token
        if let deviceID = authUser.deviceID {
            try await updateSyncToken(
                userID: authUser.id,
                deviceID: deviceID,
                tokenValue: newToken,
                on: req.db
            )
        }

        return SyncPullResponse(
            changes: pullChanges,
            newToken: newToken,
            hasMore: hasMore
        )
    }

    // MARK: - Status

    @Sendable
    func status(req: Request) async throws -> SyncStatusResponse {
        let authUser = try req.auth.require(AuthenticatedUser.self)

        let totalRecords = try await SyncRecord.query(on: req.db)
            .filter(\.$user.$id == authUser.id)
            .filter(\.$isDeleted == false)
            .count()

        var lastToken: String?
        if let deviceID = authUser.deviceID {
            if let token = try await findSyncToken(userID: authUser.id, deviceID: deviceID, on: req.db) {
                lastToken = token.tokenValue
            }
        }

        return SyncStatusResponse(
            deviceID: authUser.deviceID ?? "unknown",
            lastSyncToken: lastToken,
            totalRecords: totalRecords,
            serverTimestamp: Date()
        )
    }

    // MARK: - Reset

    @Sendable
    func reset(req: Request) async throws -> SyncResetResponse {
        let authUser = try req.auth.require(AuthenticatedUser.self)

        // Delete all sync records for this user (cascade deletes change_log refs)
        let count = try await SyncRecord.query(on: req.db)
            .filter(\.$user.$id == authUser.id)
            .count()

        try await SyncRecord.query(on: req.db)
            .filter(\.$user.$id == authUser.id)
            .delete()

        // Reset all sync tokens for this user
        try await SyncToken.query(on: req.db)
            .filter(\.$user.$id == authUser.id)
            .delete()

        // Notify all devices to force sync
        if let ws = req.application.webSocketService {
            await ws.notifyForceSync(userID: authUser.id)
        }

        return SyncResetResponse(
            deletedRecords: count,
            message: "All sync data has been reset."
        )
    }

    // MARK: - Helpers

    private func updateSyncToken(userID: UUID, deviceID: String, tokenValue: String, on db: Database) async throws {
        // Find the device record
        guard let device = try await Device.query(on: db)
            .filter(\.$user.$id == userID)
            .filter(\.$deviceID == deviceID)
            .first(),
            let devicePK = device.id
        else { return }

        // Upsert sync token
        if let existing = try await SyncToken.query(on: db)
            .filter(\.$device.$id == devicePK)
            .filter(\.$user.$id == userID)
            .first()
        {
            existing.tokenValue = tokenValue
            try await existing.save(on: db)
        } else {
            let token = SyncToken(deviceID: devicePK, userID: userID, tokenValue: tokenValue)
            try await token.save(on: db)
        }
    }

    private func findSyncToken(userID: UUID, deviceID: String, on db: Database) async throws -> SyncToken? {
        guard let device = try await Device.query(on: db)
            .filter(\.$user.$id == userID)
            .filter(\.$deviceID == deviceID)
            .first(),
            let devicePK = device.id
        else { return nil }

        return try await SyncToken.query(on: db)
            .filter(\.$device.$id == devicePK)
            .filter(\.$user.$id == userID)
            .first()
    }
}
