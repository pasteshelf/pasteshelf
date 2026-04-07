//
//  Folder+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch request for Folder entity.
//

import CoreData
import Foundation

public extension Folder {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Folder> {
        NSFetchRequest<Folder>(entityName: "Folder")
    }

    // MARK: - Attributes

    /// Unique identifier
    @NSManaged var id: UUID?

    /// Folder display name
    @NSManaged var name: String?

    /// SF Symbol icon name (optional)
    @NSManaged var icon: String?

    /// Sort order for display (lower values appear first)
    @NSManaged var sortOrder: Int32

    // MARK: - Relationships

    /// Clipboard items in this folder (one-to-many)
    @NSManaged var items: NSSet?

    /// Parent folder (optional, for nested hierarchy)
    @NSManaged var parentFolder: Folder?

    /// Child folders (one-to-many)
    @NSManaged var subfolders: NSSet?
}

// MARK: - Generated accessors for items

public extension Folder {
    @objc(addItemsObject:)
    @NSManaged func addToItems(_ value: ClipboardItem)

    @objc(removeItemsObject:)
    @NSManaged func removeFromItems(_ value: ClipboardItem)

    @objc(addItems:)
    @NSManaged func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged func removeFromItems(_ values: NSSet)
}

// MARK: - Generated accessors for subfolders

public extension Folder {
    @objc(addSubfoldersObject:)
    @NSManaged func addToSubfolders(_ value: Folder)

    @objc(removeSubfoldersObject:)
    @NSManaged func removeFromSubfolders(_ value: Folder)

    @objc(addSubfolders:)
    @NSManaged func addToSubfolders(_ values: NSSet)

    @objc(removeSubfolders:)
    @NSManaged func removeFromSubfolders(_ values: NSSet)
}

// MARK: - Folder + Identifiable

extension Folder: Identifiable {}
