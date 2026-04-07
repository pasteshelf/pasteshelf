//
//  CloudKitRecordMapper.swift
//  PasteShelf
//
//  Maps between ClipboardItem and CKRecord with encryption.
//

import CloudKit
import CoreData
import Foundation
import os.log

// MARK: - CloudKitRecordMapper

/// Maps CoreData entities to CloudKit records with E2E encryption
final class CloudKitRecordMapper: Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        zoneID: CKRecordZone.ID,
        encryptionManager: SyncEncryptionManager
    ) {
        self.zoneID = zoneID
        self.encryptionManager = encryptionManager
    }

    // MARK: Internal

    // MARK: - Create Record

    /// Create a CKRecord from a SyncChange with encrypted data
    func createRecord(
        for change: SyncChange,
        encryptedData: Data
    ) -> CKRecord {
        let recordID = change.makeRecordID(zoneID: self.zoneID)
        let recordType = change.entityType.recordType

        let record: CKRecord = if let existingRecord = change.serverRecord {
            existingRecord
        } else {
            CKRecord(recordType: recordType, recordID: recordID)
        }

        // Set fields
        record[Fields.entityID] = change.entityID.uuidString
        record[Fields.entityType] = change.entityType.rawValue
        record[Fields.encryptedData] = encryptedData
        record[Fields.timestamp] = change.localTimestamp
        record[Fields.modifiedAt] = Date()
        record[Fields.syncVersion] = Self.currentSyncVersion

        Self.logger.debug("Created record for \(change.entityType.rawValue): \(change.entityID)")

        return record
    }

    /// Create a CKRecord from a ClipboardItem
    func createRecord(
        from item: ClipboardItem,
        context: NSManagedObjectContext
    ) async throws -> CKRecord {
        guard let itemID = item.id else {
            throw SyncError.invalidData(reason: "Item has no ID")
        }

        // Create payload to encrypt
        let payload = try createPayload(from: item, context: context)

        // Encrypt the payload
        let encryptedData = try await encryptionManager.encrypt(payload)

        // Create record
        let recordID = CKRecord.ID(
            recordName: itemID.uuidString,
            zoneID: self.zoneID
        )

        let record = CKRecord(
            recordType: SyncChange.EntityType.clipboardItem.recordType,
            recordID: recordID
        )

        record[Fields.entityID] = itemID.uuidString
        record[Fields.entityType] = SyncChange.EntityType.clipboardItem.rawValue
        record[Fields.encryptedData] = encryptedData
        record[Fields.contentHash] = item.contentHash
        record[Fields.timestamp] = item.timestamp
        record[Fields.modifiedAt] = item.modifiedAt ?? Date()
        record[Fields.syncVersion] = Self.currentSyncVersion

        return record
    }

    // MARK: - Parse Record

    /// Convert a CKRecord to a SyncChange
    func toSyncChange(from record: CKRecord) -> SyncChange? {
        guard let entityIDString = record[Fields.entityID] as? String,
              let entityID = UUID(uuidString: entityIDString),
              let entityTypeString = record[Fields.entityType] as? String,
              let entityType = SyncChange.EntityType(rawValue: entityTypeString)
        else {
            Self.logger.warning("Invalid record format: \(record.recordID.recordName)")
            return nil
        }

        let encryptedData = record[Fields.encryptedData] as? Data
        let timestamp = record[Fields.timestamp] as? Date
        let modifiedAt = record[Fields.modifiedAt] as? Date

        return SyncChange(
            changeType: .remoteUpdate,
            entityType: entityType,
            entityID: entityID,
            cloudKitRecordID: record.recordID.recordName,
            localTimestamp: timestamp ?? Date(),
            serverTimestamp: modifiedAt,
            encryptedData: encryptedData,
            serverRecord: record
        )
    }

    /// Decrypt and parse a record to ClipboardItem data
    func parseClipboardItem(
        from record: CKRecord
    ) async throws -> ClipboardItemPayload {
        guard let encryptedData = record[Fields.encryptedData] as? Data else {
            throw SyncError.invalidData(reason: "No encrypted data in record")
        }

        // Decrypt the payload
        let decryptedData = try await encryptionManager.decrypt(encryptedData)

        // Decode the payload
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let payload = try decoder.decode(ClipboardItemPayload.self, from: decryptedData)

        Self.logger.debug("Parsed clipboard item: \(payload.id)")

        return payload
    }

    // MARK: - Entity Type Mapping

    /// Get entity type from CloudKit record type
    func entityType(from recordType: CKRecord.RecordType) -> SyncChange.EntityType {
        // CloudKit record types are prefixed with "CD_" by NSPersistentCloudKitContainer
        let cleanType = recordType.hasPrefix("CD_")
            ? String(recordType.dropFirst(3))
            : recordType

        return SyncChange.EntityType(rawValue: cleanType) ?? .clipboardItem
    }

    // MARK: Private

    // MARK: - Record Field Names

    private enum Fields {
        static let entityID = "entityID"
        static let entityType = "entityType"
        static let encryptedData = "encryptedData"
        static let contentHash = "contentHash"
        static let timestamp = "timestamp"
        static let modifiedAt = "modifiedAt"
        static let syncVersion = "syncVersion"
    }

    /// Current sync schema version
    private static let currentSyncVersion = 1

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "cloudkit-mapper"
    )

    private let zoneID: CKRecordZone.ID
    private let encryptionManager: SyncEncryptionManager

    // MARK: - Private Methods

    /// Create a JSON payload from a ClipboardItem
    private func createPayload(
        from item: ClipboardItem,
        context _: NSManagedObjectContext
    ) throws -> Data {
        var payload = ClipboardItemPayload(
            id: item.id ?? UUID(),
            timestamp: item.timestamp ?? Date(),
            contentType: item.contentType ?? "",
            contentHash: item.contentHash ?? "",
            plainTextPreview: item.plainTextPreview,
            sourceAppBundleId: item.sourceAppBundleId,
            sourceAppName: item.sourceAppName,
            isFavorite: item.isFavorite,
            isSensitive: item.isSensitive,
            accessCount: Int(item.accessCount)
        )

        // Include content data if available
        if let content = item.content {
            payload.contentData = ClipboardContentPayload(from: content)
        }

        // Include tags
        if let tags = item.tags as? Set<Tag> {
            payload.tagNames = tags.compactMap(\.name)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        return try encoder.encode(payload)
    }
}

// MARK: - ClipboardItemPayload

/// Serializable payload for ClipboardItem
struct ClipboardItemPayload: Codable {
    let id: UUID
    let timestamp: Date
    let contentType: String
    let contentHash: String
    var plainTextPreview: String?
    var sourceAppBundleId: String?
    var sourceAppName: String?
    var isFavorite: Bool
    var isSensitive: Bool
    var accessCount: Int

    /// Optional content data
    var contentData: ClipboardContentPayload?

    /// Tags (just names for sync)
    var tagNames: [String]?
}

// MARK: - ClipboardContentPayload

/// Serializable payload for ClipboardContentData
struct ClipboardContentPayload: Codable {
    // MARK: Lifecycle

    init(from content: ClipboardContentData) {
        // Note: We don't sync plainText directly as it's in the main payload
        self.htmlContent = content.htmlContent
        self.rtfData = content.rtfData
        self.imageData = content.imageData
        self.imageWidth = content.imageWidth > 0 ? Int(content.imageWidth) : nil
        self.imageHeight = content.imageHeight > 0 ? Int(content.imageHeight) : nil
        self.isImageCompressed = content.isImageCompressed
        self.urlString = content.urlString
        self.fileURLsJSON = content.fileURLsJSON
        self.pdfData = content.pdfData
    }

    // MARK: Internal

    var plainText: String?
    var htmlContent: String?
    var rtfData: Data?
    var imageData: Data?
    var imageWidth: Int?
    var imageHeight: Int?
    var isImageCompressed: Bool
    var urlString: String?
    var fileURLsJSON: String?
    var pdfData: Data?
}
