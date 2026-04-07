//
//  SyncChange.swift
//  PasteShelf
//
//  Model representing a change to be synced.
//

import CloudKit
import Foundation

// MARK: - SyncChange

/// Represents a change to be synced to or from CloudKit
public struct SyncChange: Identifiable, Sendable, Equatable {
    // MARK: Lifecycle

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        changeType: ChangeType,
        entityType: EntityType,
        entityID: UUID,
        cloudKitRecordID: String? = nil,
        localTimestamp: Date = Date(),
        serverTimestamp: Date? = nil,
        encryptedData: Data? = nil,
        serverRecord: CKRecord? = nil
    ) {
        self.id = id
        self.changeType = changeType
        self.entityType = entityType
        self.entityID = entityID
        self.cloudKitRecordID = cloudKitRecordID
        self.localTimestamp = localTimestamp
        self.serverTimestamp = serverTimestamp
        self.encryptedData = encryptedData
        self.serverRecord = serverRecord
    }

    // MARK: Public

    /// Unique identifier for this change
    public let id: UUID

    /// Type of change
    public let changeType: ChangeType

    /// Entity type being changed
    public let entityType: EntityType

    /// Local UUID of the entity
    public let entityID: UUID

    /// CloudKit record ID (if exists)
    public var cloudKitRecordID: String?

    /// Timestamp when the change occurred locally
    public let localTimestamp: Date

    /// Timestamp from server (for remote changes)
    public var serverTimestamp: Date?

    /// Encrypted payload data (for insert/update)
    public var encryptedData: Data?

    /// Original CloudKit record (for updates with conflicts)
    public var serverRecord: CKRecord?
}

// MARK: SyncChange.ChangeType

public extension SyncChange {
    /// Type of change operation
    enum ChangeType: String, Sendable, Codable {
        /// New item created locally
        case insert

        /// Existing item updated locally
        case update

        /// Item deleted locally
        case delete

        /// Item fetched from server (remote insert)
        case remoteInsert

        /// Item updated on server (remote update)
        case remoteUpdate

        /// Item deleted on server (remote delete)
        case remoteDelete
    }
}

// MARK: SyncChange.EntityType

public extension SyncChange {
    /// Type of entity being synced
    enum EntityType: String, Sendable, Codable {
        case clipboardItem = "ClipboardItem"
        case clipboardContentData = "ClipboardContentData"
        case contentPreview = "ContentPreview"
        case tag = "Tag"
        case folder = "Folder"

        // MARK: Public

        /// CloudKit record type name
        public var recordType: String {
            "CD_\(rawValue)"
        }
    }
}

// MARK: - Helpers

public extension SyncChange {
    /// Whether this is a local change (needs to be pushed)
    var isLocalChange: Bool {
        switch self.changeType {
        case .insert,
             .update,
             .delete:
            true
        case .remoteInsert,
             .remoteUpdate,
             .remoteDelete:
            false
        }
    }

    /// Whether this is a remote change (needs to be applied locally)
    var isRemoteChange: Bool {
        !self.isLocalChange
    }

    /// Whether this change deletes the entity
    var isDeletion: Bool {
        self.changeType == .delete || self.changeType == .remoteDelete
    }

    /// Create a CloudKit record ID from this change
    func makeRecordID(zoneID: CKRecordZone.ID) -> CKRecord.ID {
        if let recordID = cloudKitRecordID {
            return CKRecord.ID(recordName: recordID, zoneID: zoneID)
        }
        return CKRecord.ID(recordName: self.entityID.uuidString, zoneID: zoneID)
    }
}

// MARK: Codable

extension SyncChange: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case changeType
        case entityType
        case entityID
        case cloudKitRecordID
        case localTimestamp
        case serverTimestamp
        case encryptedData
        // serverRecord is not codable
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.changeType = try container.decode(ChangeType.self, forKey: .changeType)
        self.entityType = try container.decode(EntityType.self, forKey: .entityType)
        self.entityID = try container.decode(UUID.self, forKey: .entityID)
        self.cloudKitRecordID = try container.decodeIfPresent(String.self, forKey: .cloudKitRecordID)
        self.localTimestamp = try container.decode(Date.self, forKey: .localTimestamp)
        self.serverTimestamp = try container.decodeIfPresent(Date.self, forKey: .serverTimestamp)
        self.encryptedData = try container.decodeIfPresent(Data.self, forKey: .encryptedData)
        self.serverRecord = nil // Not codable
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.changeType, forKey: .changeType)
        try container.encode(self.entityType, forKey: .entityType)
        try container.encode(self.entityID, forKey: .entityID)
        try container.encodeIfPresent(self.cloudKitRecordID, forKey: .cloudKitRecordID)
        try container.encode(self.localTimestamp, forKey: .localTimestamp)
        try container.encodeIfPresent(self.serverTimestamp, forKey: .serverTimestamp)
        try container.encodeIfPresent(self.encryptedData, forKey: .encryptedData)
        // serverRecord is not encoded
    }
}

// MARK: - Equatable

public extension SyncChange {
    static func == (lhs: SyncChange, rhs: SyncChange) -> Bool {
        lhs.id == rhs.id &&
            lhs.changeType == rhs.changeType &&
            lhs.entityType == rhs.entityType &&
            lhs.entityID == rhs.entityID &&
            lhs.cloudKitRecordID == rhs.cloudKitRecordID &&
            lhs.localTimestamp == rhs.localTimestamp &&
            lhs.serverTimestamp == rhs.serverTimestamp
        // Note: encryptedData and serverRecord not compared for performance
    }
}

// MARK: CustomDebugStringConvertible

extension SyncChange: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        SyncChange(\(self.changeType.rawValue) \(self.entityType.rawValue) \(self.entityID.uuidString.prefix(8))...)
        """
    }
}
