//
//  ChangeTracker.swift
//  PasteShelf
//
//  Tracks local CoreData changes for sync using NSPersistentHistoryChangeRequest.
//

import CoreData
import Foundation
import os.log

/// Tracks local CoreData changes for synchronization
final class ChangeTracker: ChangeTracking, @unchecked Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        persistenceController: PersistenceController = .shared,
        encryptionManager: SyncEncryptionManager = SyncEncryptionManager()
    ) {
        self.persistenceController = persistenceController
        self.encryptionManager = encryptionManager
    }

    // MARK: Internal

    // MARK: - ChangeTracking Protocol

    func getPendingChanges() async throws -> [SyncChange] {
        let context = persistenceController.newBackgroundContext()

        return try await context.perform {
            try self.fetchPendingChanges(in: context)
        }
    }

    func markAsSynced(_ changes: [SyncChange]) async throws {
        let context = persistenceController.newBackgroundContext()

        try await context.perform {
            for change in changes {
                try self.markItemAsSynced(change, in: context)
            }

            if context.hasChanges {
                try context.save()
            }
        }

        Self.logger.info("Marked \(changes.count) changes as synced")
    }

    func recordChange(_ change: SyncChange) async throws {
        // Changes are tracked automatically via CoreData persistent history
        // This method is used for manual change recording if needed
        Self.logger.debug("Recorded change: \(change.changeType.rawValue) \(change.entityType.rawValue)")
    }

    func clearHistory(before date: Date) async throws {
        let context = persistenceController.newBackgroundContext()

        try await context.perform {
            let request = NSPersistentHistoryChangeRequest.deleteHistory(before: date)

            do {
                try context.execute(request)
                Self.logger.info("Cleared history before \(date)")
            } catch {
                Self.logger.error("Failed to clear history: \(error.localizedDescription)")
                throw error
            }
        }
    }

    // MARK: - History Token Management

    /// Get the last processed history token
    func getLastHistoryToken() -> NSPersistentHistoryToken? {
        guard let tokenData = UserDefaults.standard.data(forKey: Self.lastTokenKey) else {
            return nil
        }

        do {
            return try NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSPersistentHistoryToken.self,
                from: tokenData
            )
        } catch {
            Self.logger.warning("Failed to unarchive history token: \(error.localizedDescription)")
            return nil
        }
    }

    /// Save the last processed history token
    func saveLastHistoryToken(_ token: NSPersistentHistoryToken) {
        do {
            let tokenData = try NSKeyedArchiver.archivedData(
                withRootObject: token,
                requiringSecureCoding: true
            )
            UserDefaults.standard.set(tokenData, forKey: Self.lastTokenKey)
        } catch {
            Self.logger.error("Failed to archive history token: \(error.localizedDescription)")
        }
    }

    /// Clear the history token (for reset)
    func clearHistoryToken() {
        UserDefaults.standard.removeObject(forKey: Self.lastTokenKey)
    }

    // MARK: - Preparing Changes for Sync

    /// Prepare changes with encrypted data for sync
    func prepareChangesForSync(_ changes: [SyncChange]) async throws -> [SyncChange] {
        let context = persistenceController.newBackgroundContext()

        var preparedChanges: [SyncChange] = []

        for var change in changes {
            guard change.changeType != .delete else {
                preparedChanges.append(change)
                continue
            }

            // Build payload data inside context.perform (CoreData access)
            let payloadData: Data? = try await context.perform {
                try self.buildPayloadData(for: change, in: context)
            }

            // Encrypt outside context.perform (async-safe, no semaphore needed)
            if let data = payloadData {
                change.encryptedData = try await encryptionManager.encrypt(data)
            }

            preparedChanges.append(change)
        }

        return preparedChanges
    }

    // MARK: Private

    /// UserDefaults key for storing last processed history token
    private static let lastTokenKey = "com.pasteshelf.sync.lastHistoryToken"

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "change-tracker"
    )

    private let persistenceController: PersistenceController
    private let encryptionManager: SyncEncryptionManager

    // MARK: - Private Methods

    /// Fetch pending changes from CoreData
    private func fetchPendingChanges(in context: NSManagedObjectContext) throws -> [SyncChange] {
        var changes: [SyncChange] = []

        // Fetch items with pending sync state
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "syncState == %d OR syncState == %d",
            ItemSyncState.pending.rawValue,
            ItemSyncState.conflicted.rawValue
        )

        let items = try context.fetch(request)

        for item in items {
            guard let itemID = item.id else {
                continue
            }

            let changeType: SyncChange.ChangeType = item.cloudKitRecordID == nil ? .insert : .update

            let change = SyncChange(
                changeType: changeType,
                entityType: .clipboardItem,
                entityID: itemID,
                cloudKitRecordID: item.cloudKitRecordID,
                localTimestamp: item.modifiedAt ?? item.timestamp ?? Date()
            )

            changes.append(change)
        }

        // Also check for deleted items
        let deletedChanges = try fetchDeletedItems(in: context)
        changes.append(contentsOf: deletedChanges)

        Self.logger.debug("Found \(changes.count) pending changes")
        return changes
    }

    /// Fetch items marked for deletion
    private func fetchDeletedItems(in context: NSManagedObjectContext) throws -> [SyncChange] {
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "syncState == %d", ItemSyncState.deleted.rawValue)

        let items = try context.fetch(request)

        return items.compactMap { item -> SyncChange? in
            guard let itemID = item.id else {
                return nil
            }

            return SyncChange(
                changeType: .delete,
                entityType: .clipboardItem,
                entityID: itemID,
                cloudKitRecordID: item.cloudKitRecordID,
                localTimestamp: item.modifiedAt ?? Date()
            )
        }
    }

    /// Mark an item as synced in CoreData
    private func markItemAsSynced(_ change: SyncChange, in context: NSManagedObjectContext) throws {
        guard change.entityType == .clipboardItem else {
            return
        }

        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", change.entityID as CVarArg)
        request.fetchLimit = 1

        guard let item = try context.fetch(request).first else {
            // Item might have been deleted, that's okay
            return
        }

        item.syncState = ItemSyncState.synced.rawValue
        item.lastSyncedAt = Date()

        if let cloudKitRecordID = change.cloudKitRecordID {
            item.cloudKitRecordID = cloudKitRecordID
        }
    }

    /// Build JSON payload data for a change (synchronous, safe inside context.perform)
    private func buildPayloadData(
        for change: SyncChange,
        in context: NSManagedObjectContext
    ) throws -> Data? {
        guard change.entityType == .clipboardItem else {
            return nil
        }

        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", change.entityID as CVarArg)
        request.fetchLimit = 1

        guard let item = try context.fetch(request).first else {
            return nil
        }

        // Create payload
        let payload = ClipboardItemPayload(
            id: item.id ?? UUID(),
            timestamp: item.timestamp ?? Date(),
            contentType: item.contentType ?? "",
            contentHash: item.contentHash ?? "",
            plainTextPreview: item.plainTextPreview,
            sourceAppBundleId: item.sourceAppBundleId,
            sourceAppName: item.sourceAppName,
            isFavorite: item.isFavorite,
            isSensitive: item.isSensitive,
            accessCount: Int(item.accessCount),
            contentData: item.content.map { ClipboardContentPayload(from: $0) },
            tagNames: (item.tags as? Set<Tag>)?.compactMap(\.name)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }
}
