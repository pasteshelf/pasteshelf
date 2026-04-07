//
//  SmartCollection+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch request for SmartCollection entity.
//

import CoreData
import Foundation

public extension SmartCollection {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<SmartCollection> {
        NSFetchRequest<SmartCollection>(entityName: "SmartCollection")
    }

    // MARK: - Attributes

    /// Unique identifier
    @NSManaged var id: UUID?

    /// Collection display name
    @NSManaged var name: String?

    /// SF Symbol icon name (e.g., "folder.fill")
    @NSManaged var icon: String?

    /// Color as hex string (e.g., "#FF5733"), optional
    @NSManaged var colorHex: String?

    /// JSON-serialized CollectionRules for automatic collections
    @NSManaged var rulesJSON: String?

    /// Whether this collection uses automatic rule-based filtering (true) or manual item assignment (false)
    @NSManaged var isAutomatic: Bool

    /// Sort order for display
    @NSManaged var sortOrder: Int32

    /// Timestamp when the collection was created
    @NSManaged var createdAt: Date?

    /// Timestamp when the collection was last modified
    @NSManaged var modifiedAt: Date?

    // MARK: - Relationships

    /// Clipboard items in this collection (many-to-many, used for manual collections)
    @NSManaged var items: NSSet?
}

// MARK: - Generated accessors for items

public extension SmartCollection {
    @objc(addItemsObject:)
    @NSManaged func addToItems(_ value: ClipboardItem)

    @objc(removeItemsObject:)
    @NSManaged func removeFromItems(_ value: ClipboardItem)

    @objc(addItems:)
    @NSManaged func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged func removeFromItems(_ values: NSSet)
}

// MARK: - SmartCollection + Identifiable

extension SmartCollection: Identifiable {}
