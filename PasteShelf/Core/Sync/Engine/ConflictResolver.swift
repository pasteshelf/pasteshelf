//
//  ConflictResolver.swift
//  PasteShelf
//
//  Resolves sync conflicts using last-write-wins strategy.
//

import Foundation
import os.log

// MARK: - ConflictResolver

/// Resolves sync conflicts between local and remote changes
final class ConflictResolver: ConflictResolving, Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(encryptionManager: SyncEncryptionManager = SyncEncryptionManager()) {
        self.encryptionManager = encryptionManager
    }

    // MARK: Internal

    // MARK: - ConflictResolving Protocol

    func resolve(
        local: SyncChange,
        remote: SyncChange
    ) async throws -> ConflictResolution {
        Self.logger.info("Resolving conflict for \(local.entityType.rawValue): \(local.entityID)")

        // Get timestamps for comparison
        let localTimestamp = local.localTimestamp
        let remoteTimestamp = remote.serverTimestamp ?? remote.localTimestamp

        // Deletion always wins over update (to prevent ghost items)
        if local.isDeletion {
            Self.logger.debug("Local deletion wins")
            return .useLocal(local)
        }

        if remote.isDeletion {
            Self.logger.debug("Remote deletion wins")
            return .useRemote(remote)
        }

        // For non-deletion conflicts, use last-write-wins
        if localTimestamp > remoteTimestamp {
            Self.logger.debug("Local wins (newer: \(localTimestamp) > \(remoteTimestamp))")
            return .useLocal(local)
        } else if remoteTimestamp > localTimestamp {
            Self.logger.debug("Remote wins (newer: \(remoteTimestamp) > \(localTimestamp))")
            return .useRemote(remote)
        }

        // Same timestamp - try to merge
        return try await mergeChanges(local: local, remote: remote)
    }

    func resolveAll(
        conflicts: [(local: SyncChange, remote: SyncChange)]
    ) async throws -> [ConflictResolution] {
        Self.logger.info("Resolving \(conflicts.count) conflicts")

        var resolutions: [ConflictResolution] = []

        for (local, remote) in conflicts {
            let resolution = try await resolve(local: local, remote: remote)
            resolutions.append(resolution)
        }

        return resolutions
    }

    // MARK: Private

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "conflict-resolver"
    )

    private let encryptionManager: SyncEncryptionManager

    // MARK: - Merge Strategy

    /// Attempt to merge local and remote changes
    private func mergeChanges(
        local: SyncChange,
        remote: SyncChange
    ) async throws -> ConflictResolution {
        Self.logger.debug("Attempting to merge changes")

        // Only attempt merge for clipboard items
        guard local.entityType == .clipboardItem else {
            // For other types, prefer remote (server is source of truth)
            return .useRemote(remote)
        }

        // If we have encrypted data for both, try to merge
        guard let localData = local.encryptedData,
              let remoteData = remote.encryptedData
        else {
            // Can't merge without data - prefer local (user's current state)
            return .useLocal(local)
        }

        do {
            // Decrypt both payloads
            let localDecrypted = try await encryptionManager.decrypt(localData)
            let remoteDecrypted = try await encryptionManager.decrypt(remoteData)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let localPayload = try decoder.decode(ClipboardItemPayload.self, from: localDecrypted)
            let remotePayload = try decoder.decode(ClipboardItemPayload.self, from: remoteDecrypted)

            // Merge the payloads
            let mergedPayload = mergePayloads(local: localPayload, remote: remotePayload)

            // Re-encrypt the merged payload
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let mergedData = try encoder.encode(mergedPayload)
            let encryptedMerged = try await encryptionManager.encrypt(mergedData)

            // Create merged change
            var mergedChange = local
            mergedChange.encryptedData = encryptedMerged

            Self.logger.info("Successfully merged changes")
            return .merged(mergedChange)
        } catch {
            Self.logger.warning("Merge failed, using local: \(error.localizedDescription)")
            return .useLocal(local)
        }
    }

    /// Merge two payloads with field-level conflict resolution
    private func mergePayloads(
        local: ClipboardItemPayload,
        remote: ClipboardItemPayload
    ) -> ClipboardItemPayload {
        var merged = local // Start with local as base

        // Content fields: keep local (more recent user content)
        // These are not merged - local wins

        // Metadata fields: merge intelligently
        // Favorites: union (if either is favorite, result is favorite)
        merged.isFavorite = local.isFavorite || remote.isFavorite

        // Access count: take maximum
        merged.accessCount = max(local.accessCount, remote.accessCount)

        // Tags: union of both sets
        let localTags = Set(local.tagNames ?? [])
        let remoteTags = Set(remote.tagNames ?? [])
        merged.tagNames = Array(localTags.union(remoteTags))

        Self.logger
            .debug(
                "Merged payload: favorite=\(merged.isFavorite), accessCount=\(merged.accessCount), tags=\(merged.tagNames?.count ?? 0)"
            )

        return merged
    }
}

// MARK: - Conflict Detection

extension ConflictResolver {
    /// Check if two changes conflict
    static func conflictsExist(
        local: SyncChange,
        remote: SyncChange
    ) -> Bool {
        // Same entity being modified
        guard local.entityID == remote.entityID else {
            return false
        }

        // Both are modifications (not the same operation)
        if local.isDeletion != remote.isDeletion {
            return true // Delete vs update conflict
        }

        if !local.isDeletion, !remote.isDeletion {
            return true // Both updating same entity
        }

        return false
    }

    /// Find conflicts between local and remote change sets
    static func findConflicts(
        localChanges: [SyncChange],
        remoteChanges: [SyncChange]
    ) -> [(local: SyncChange, remote: SyncChange)] {
        var conflicts: [(SyncChange, SyncChange)] = []

        let remoteByID = Dictionary(
            uniqueKeysWithValues: remoteChanges.map { ($0.entityID, $0) }
        )

        for local in localChanges {
            if let remote = remoteByID[local.entityID] {
                if conflictsExist(local: local, remote: remote) {
                    conflicts.append((local, remote))
                }
            }
        }

        return conflicts
    }
}
