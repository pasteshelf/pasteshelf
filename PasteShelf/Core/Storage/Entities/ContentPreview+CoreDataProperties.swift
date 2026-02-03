//
//  ContentPreview+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch request for ContentPreview entity.
//

import CoreData
import Foundation

extension ContentPreview {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ContentPreview> {
        NSFetchRequest<ContentPreview>(entityName: "ContentPreview")
    }

    // MARK: - Attributes

    /// Unique identifier
    @NSManaged public var id: UUID?

    /// Thumbnail image data (PNG, max 256px dimension)
    @NSManaged public var thumbnailData: Data?

    /// Thumbnail width in pixels
    @NSManaged public var width: Int32

    /// Thumbnail height in pixels
    @NSManaged public var height: Int32

    // MARK: - Relationships

    /// Parent clipboard item (inverse relationship)
    @NSManaged public var clipboardItem: ClipboardItem?
}

extension ContentPreview: Identifiable {}
