//
//  Tag+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch request for Tag entity.
//

import CoreData
import Foundation

extension Tag {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Tag> {
        NSFetchRequest<Tag>(entityName: "Tag")
    }

    // MARK: - Attributes

    /// Unique identifier
    @NSManaged public var id: UUID?

    /// Tag display name
    @NSManaged public var name: String?

    /// Tag color as hex string (e.g., "#FF5733")
    @NSManaged public var color: String?

    // MARK: - Relationships

    /// Clipboard items with this tag (many-to-many)
    @NSManaged public var items: NSSet?
}

// MARK: - Generated accessors for items

extension Tag {
    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: ClipboardItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: ClipboardItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)
}

extension Tag: Identifiable {}
