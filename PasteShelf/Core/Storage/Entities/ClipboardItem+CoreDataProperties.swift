//
//  ClipboardItem+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch request for ClipboardItem entity.
//

import CoreData
import Foundation

public extension ClipboardItem {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<ClipboardItem> {
        NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
    }

    // MARK: - Attributes

    /// Unique identifier for this clipboard item
    @NSManaged var id: UUID?

    /// Timestamp when the content was captured
    @NSManaged var timestamp: Date?

    /// Primary content type (UTI raw value)
    @NSManaged var contentType: String?

    /// SHA256 hash of content for deduplication
    @NSManaged var contentHash: String?

    /// First 500 characters of plain text content
    @NSManaged var plainTextPreview: String?

    /// Bundle identifier of source application
    @NSManaged var sourceAppBundleId: String?

    /// Display name of source application
    @NSManaged var sourceAppName: String?

    /// Whether this item contains sensitive data
    @NSManaged var isSensitive: Bool

    /// JSON-encoded array of sensitive data types detected (e.g., "password", "creditCard")
    @NSManaged var sensitiveTypesJSON: String?

    /// Whether this item is marked as favorite
    @NSManaged var isFavorite: Bool

    /// Number of times this item has been accessed/pasted
    @NSManaged var accessCount: Int32

    // MARK: - Sync Attributes

    /// Sync state: 0 = pending, 1 = synced, 2 = conflicted, 3 = deleted
    @NSManaged var syncState: Int16

    /// CloudKit record identifier for this item
    @NSManaged var cloudKitRecordID: String?

    /// Timestamp when item was last synced to CloudKit
    @NSManaged var lastSyncedAt: Date?

    /// Timestamp when item was last modified locally (for conflict resolution)
    @NSManaged var modifiedAt: Date?

    // MARK: - Relationships

    /// Binary content data (one-to-one)
    @NSManaged var content: ClipboardContentData?

    /// Thumbnail preview (one-to-one)
    @NSManaged var preview: ContentPreview?

    /// Tags assigned to this item (many-to-many)
    @NSManaged var tags: NSSet?

    /// Folder containing this item (optional, many-to-one)
    @NSManaged var folder: Folder?

    /// Collections containing this item (many-to-many)
    @NSManaged var collections: NSSet?
}

// MARK: - Generated accessors for tags

public extension ClipboardItem {
    @objc(addTagsObject:)
    @NSManaged func addToTags(_ value: Tag)

    @objc(removeTagsObject:)
    @NSManaged func removeFromTags(_ value: Tag)

    @objc(addTags:)
    @NSManaged func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged func removeFromTags(_ values: NSSet)
}

// MARK: - Generated accessors for collections

public extension ClipboardItem {
    @objc(addCollectionsObject:)
    @NSManaged func addToCollections(_ value: SmartCollection)

    @objc(removeCollectionsObject:)
    @NSManaged func removeFromCollections(_ value: SmartCollection)

    @objc(addCollections:)
    @NSManaged func addToCollections(_ values: NSSet)

    @objc(removeCollections:)
    @NSManaged func removeFromCollections(_ values: NSSet)
}

// MARK: - ClipboardItem + Identifiable

extension ClipboardItem: Identifiable {}
