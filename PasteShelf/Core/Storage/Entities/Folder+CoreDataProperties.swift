//
//  Folder+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch request for Folder entity.
//

import CoreData
import Foundation

extension Folder {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Folder> {
        NSFetchRequest<Folder>(entityName: "Folder")
    }

    // MARK: - Attributes

    /// Unique identifier
    @NSManaged public var id: UUID?

    /// Folder display name
    @NSManaged public var name: String?

    /// SF Symbol icon name (optional)
    @NSManaged public var icon: String?

    /// Sort order for display (lower values appear first)
    @NSManaged public var sortOrder: Int32

    // MARK: - Relationships

    /// Clipboard items in this folder (one-to-many)
    @NSManaged public var items: NSSet?

    /// Parent folder (optional, for nested hierarchy)
    @NSManaged public var parentFolder: Folder?

    /// Child folders (one-to-many)
    @NSManaged public var subfolders: NSSet?
}

// MARK: - Generated accessors for items

extension Folder {
    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: ClipboardItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: ClipboardItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)
}

// MARK: - Generated accessors for subfolders

extension Folder {
    @objc(addSubfoldersObject:)
    @NSManaged public func addToSubfolders(_ value: Folder)

    @objc(removeSubfoldersObject:)
    @NSManaged public func removeFromSubfolders(_ value: Folder)

    @objc(addSubfolders:)
    @NSManaged public func addToSubfolders(_ values: NSSet)

    @objc(removeSubfolders:)
    @NSManaged public func removeFromSubfolders(_ values: NSSet)
}

extension Folder: Identifiable {}
