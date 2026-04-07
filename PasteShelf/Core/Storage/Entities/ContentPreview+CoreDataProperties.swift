//
//  ContentPreview+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch request for ContentPreview entity.
//

import CoreData
import Foundation

public extension ContentPreview {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<ContentPreview> {
        NSFetchRequest<ContentPreview>(entityName: "ContentPreview")
    }

    // MARK: - Attributes

    /// Unique identifier
    @NSManaged var id: UUID?

    /// Thumbnail image data (PNG, max 256px dimension)
    @NSManaged var thumbnailData: Data?

    /// Thumbnail width in pixels
    @NSManaged var width: Int32

    /// Thumbnail height in pixels
    @NSManaged var height: Int32

    // MARK: - Relationships

    /// Parent clipboard item (inverse relationship)
    @NSManaged var clipboardItem: ClipboardItem?
}

// MARK: - ContentPreview + Identifiable

extension ContentPreview: Identifiable {}
