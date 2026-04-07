//
//  Tag+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch request for Tag entity.
//

import CoreData
import Foundation

public extension Tag {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<Tag> {
        NSFetchRequest<Tag>(entityName: "Tag")
    }

    // MARK: - Attributes

    /// Unique identifier
    @NSManaged var id: UUID?

    /// Tag display name
    @NSManaged var name: String?

    /// Tag color as hex string (e.g., "#FF5733")
    @NSManaged var color: String?

    // MARK: - Relationships

    /// Clipboard items with this tag (many-to-many)
    @NSManaged var items: NSSet?
}

// MARK: - Generated accessors for items

public extension Tag {
    @objc(addItemsObject:)
    @NSManaged func addToItems(_ value: ClipboardItem)

    @objc(removeItemsObject:)
    @NSManaged func removeFromItems(_ value: ClipboardItem)

    @objc(addItems:)
    @NSManaged func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged func removeFromItems(_ values: NSSet)
}

// MARK: - Tag + Identifiable

extension Tag: Identifiable {}
