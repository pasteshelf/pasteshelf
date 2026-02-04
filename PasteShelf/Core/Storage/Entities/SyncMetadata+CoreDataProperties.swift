//
//  SyncMetadata+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch request for SyncMetadata entity.
//

import CoreData
import Foundation

extension SyncMetadata {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SyncMetadata> {
        NSFetchRequest<SyncMetadata>(entityName: "SyncMetadata")
    }

    // MARK: - Attributes

    /// Unique identifier for this sync metadata
    @NSManaged public var id: UUID?

    /// CloudKit zone identifier
    @NSManaged public var zoneID: String?

    /// Server change token for incremental sync (serialized CKServerChangeToken)
    @NSManaged public var changeToken: Data?

    /// Timestamp of last successful sync operation
    @NSManaged public var lastSyncAt: Date?

    /// Timestamp of last full sync (all items)
    @NSManaged public var lastFullSyncAt: Date?
}

extension SyncMetadata: Identifiable {}
