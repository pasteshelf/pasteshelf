//
//  ClipboardItem+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch request for ClipboardItem entity.
//

import CoreData
import Foundation

extension ClipboardItem {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ClipboardItem> {
        NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
    }

    // MARK: - Attributes

    /// Unique identifier for this clipboard item
    @NSManaged public var id: UUID?

    /// Timestamp when the content was captured
    @NSManaged public var timestamp: Date?

    /// Primary content type (UTI raw value)
    @NSManaged public var contentType: String?

    /// SHA256 hash of content for deduplication
    @NSManaged public var contentHash: String?

    /// First 500 characters of plain text content
    @NSManaged public var plainTextPreview: String?

    /// Bundle identifier of source application
    @NSManaged public var sourceAppBundleId: String?

    /// Display name of source application
    @NSManaged public var sourceAppName: String?

    /// Whether this item contains sensitive data
    @NSManaged public var isSensitive: Bool

    /// Whether this item is marked as favorite
    @NSManaged public var isFavorite: Bool

    /// Number of times this item has been accessed/pasted
    @NSManaged public var accessCount: Int32

    // MARK: - Sync Attributes

    /// Sync state: 0 = pending, 1 = synced, 2 = conflicted, 3 = deleted
    @NSManaged public var syncState: Int16

    /// CloudKit record identifier for this item
    @NSManaged public var cloudKitRecordID: String?

    /// Timestamp when item was last synced to CloudKit
    @NSManaged public var lastSyncedAt: Date?

    /// Timestamp when item was last modified locally (for conflict resolution)
    @NSManaged public var modifiedAt: Date?

    // MARK: - Relationships

    /// Binary content data (one-to-one)
    @NSManaged public var content: ClipboardContentData?

    /// Thumbnail preview (one-to-one)
    @NSManaged public var preview: ContentPreview?

    /// Tags assigned to this item (many-to-many)
    @NSManaged public var tags: NSSet?

    /// Folder containing this item (optional, many-to-one)
    @NSManaged public var folder: Folder?

    /// Collections containing this item (many-to-many)
    @NSManaged public var collections: NSSet?
}

// MARK: - Generated accessors for tags

extension ClipboardItem {
    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: Tag)

    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: Tag)

    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)
}

// MARK: - Generated accessors for collections

extension ClipboardItem {
    @objc(addCollectionsObject:)
    @NSManaged public func addToCollections(_ value: SmartCollection)

    @objc(removeCollectionsObject:)
    @NSManaged public func removeFromCollections(_ value: SmartCollection)

    @objc(addCollections:)
    @NSManaged public func addToCollections(_ values: NSSet)

    @objc(removeCollections:)
    @NSManaged public func removeFromCollections(_ values: NSSet)
}

extension ClipboardItem: Identifiable {}
