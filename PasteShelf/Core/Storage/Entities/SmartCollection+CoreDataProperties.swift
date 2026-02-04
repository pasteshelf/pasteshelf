//
//  SmartCollection+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch request for SmartCollection entity.
//

import CoreData
import Foundation

extension SmartCollection {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SmartCollection> {
        NSFetchRequest<SmartCollection>(entityName: "SmartCollection")
    }

    // MARK: - Attributes

    /// Unique identifier
    @NSManaged public var id: UUID?

    /// Collection display name
    @NSManaged public var name: String?

    /// SF Symbol icon name (e.g., "folder.fill")
    @NSManaged public var icon: String?

    /// Color as hex string (e.g., "#FF5733"), optional
    @NSManaged public var colorHex: String?

    /// JSON-serialized CollectionRules for automatic collections
    @NSManaged public var rulesJSON: String?

    /// Whether this collection uses automatic rule-based filtering (true) or manual item assignment (false)
    @NSManaged public var isAutomatic: Bool

    /// Sort order for display
    @NSManaged public var sortOrder: Int32

    /// Timestamp when the collection was created
    @NSManaged public var createdAt: Date?

    /// Timestamp when the collection was last modified
    @NSManaged public var modifiedAt: Date?

    // MARK: - Relationships

    /// Clipboard items in this collection (many-to-many, used for manual collections)
    @NSManaged public var items: NSSet?
}

// MARK: - Generated accessors for items

extension SmartCollection {
    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: ClipboardItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: ClipboardItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)
}

extension SmartCollection: Identifiable {}
