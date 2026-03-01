//
//  ClipboardContentMapper.swift
//  PasteShelf
//
//  Maps between in-memory ClipboardContent and CoreData entities.
//

import CoreData
import Foundation

/// Maps between ClipboardContent (in-memory) and CoreData entities
enum ClipboardContentMapper {
    // MARK: - Map to CoreData

    /// Creates CoreData entities from in-memory ClipboardContent
    /// - Parameters:
    ///   - content: The in-memory clipboard content
    ///   - sourceApp: The source application (optional)
    ///   - context: The managed object context
    /// - Returns: A tuple of the created ClipboardItem and ClipboardContentData
    static func mapToEntities(
        _ content: ClipboardContent,
        sourceApp: SourceApp?,
        context: NSManagedObjectContext
    ) -> (item: ClipboardItem, contentData: ClipboardContentData) {
        // Create ClipboardItem
        let item = ClipboardItem(context: context)
        item.id = content.id
        item.timestamp = content.timestamp
        item.contentType = content.primaryType.rawValue
        item.contentHash = content.contentHash
        item.plainTextPreview = content.previewText
        item.sourceAppBundleId = sourceApp?.bundleId
        item.sourceAppName = sourceApp?.name
        item.isSensitive = content.isSensitive
        item.sensitiveTypesJSON = content.sensitiveTypes.isEmpty ? nil : (try? JSONEncoder().encode(content.sensitiveTypes)).flatMap { String(data: $0, encoding: .utf8) }
        item.isFavorite = false
        item.accessCount = 0

        // Create ClipboardContentData
        let contentData = ClipboardContentData(context: context)
        contentData.id = UUID()
        contentData.plainTextData = content.plainText
        contentData.rtfData = content.rtfData
        contentData.htmlContent = content.html
        contentData.imageData = content.imageData
        contentData.pdfData = content.pdfData
        contentData.url = content.url
        contentData.fileURLs = content.fileURLs
        contentData.availableTypes = content.availableTypes.map(\.rawValue)
        contentData.isImageCompressed = content.isImageCompressed
        contentData.imageWidth = Int32(content.imageWidth ?? 0)
        contentData.imageHeight = Int32(content.imageHeight ?? 0)

        // Set relationship
        item.content = contentData

        // Create ContentPreview if thumbnail exists
        if let thumbnailData = content.thumbnailData {
            let preview = ContentPreview(context: context)
            preview.id = UUID()
            preview.thumbnailData = thumbnailData
            preview.width = Int32(content.imageWidth ?? 0)
            preview.height = Int32(content.imageHeight ?? 0)
            item.preview = preview
        }

        return (item, contentData)
    }

    // MARK: - Map from CoreData

    /// Creates in-memory ClipboardContent from CoreData entities
    /// - Parameters:
    ///   - item: The CoreData ClipboardItem
    ///   - contentData: The CoreData ClipboardContentData
    /// - Returns: An in-memory ClipboardContent, or nil if required data is missing
    static func mapFromEntities(
        item: ClipboardItem,
        contentData: ClipboardContentData?
    ) -> ClipboardContent? {
        guard let id = item.id,
              let timestamp = item.timestamp,
              let contentTypeRaw = item.contentType,
              let primaryType = ContentType(rawValue: contentTypeRaw)
        else {
            return nil
        }

        // Parse available types
        var availableTypes: [ContentType] = [primaryType]
        if let typeStrings = contentData?.availableTypes {
            availableTypes = typeStrings.compactMap { ContentType(rawValue: $0) }
            if availableTypes.isEmpty {
                availableTypes = [primaryType]
            }
        }

        // Build SourceApp if available
        var sourceApp: SourceApp?
        if let bundleId = item.sourceAppBundleId, let name = item.sourceAppName {
            sourceApp = SourceApp(bundleId: bundleId, name: name, iconData: nil)
        }

        // Prefer full plain text from contentData, fall back to preview
        let plainText = contentData?.plainTextData ?? item.plainTextPreview

        return ClipboardContent(
            id: id,
            timestamp: timestamp,
            primaryType: primaryType,
            availableTypes: availableTypes,
            plainText: plainText,
            rtfData: contentData?.rtfData,
            html: contentData?.htmlContent,
            imageData: contentData?.imageData,
            thumbnailData: item.preview?.thumbnailData,
            imageWidth: contentData.map { Int($0.imageWidth) },
            imageHeight: contentData.map { Int($0.imageHeight) },
            isImageCompressed: contentData?.isImageCompressed ?? false,
            pdfData: contentData?.pdfData,
            url: contentData?.url,
            fileURLs: contentData?.fileURLs,
            contentHash: item.contentHash,
            isSensitive: item.isSensitive,
            sensitiveTypes: item.sensitiveTypesJSON.flatMap { json in
                json.data(using: .utf8).flatMap { try? JSONDecoder().decode([String].self, from: $0) }
            } ?? [],
            sourceApp: sourceApp
        )
    }

    /// Creates an in-memory ClipboardContent from a ClipboardItem (convenience)
    /// - Parameter item: The CoreData ClipboardItem
    /// - Returns: An in-memory ClipboardContent, or nil if required data is missing
    static func mapFromEntity(_ item: ClipboardItem) -> ClipboardContent? {
        mapFromEntities(item: item, contentData: item.content)
    }

    // MARK: - Update Existing Entity

    /// Updates an existing ClipboardItem with new content
    /// - Parameters:
    ///   - item: The existing CoreData ClipboardItem
    ///   - content: The new in-memory content
    ///   - context: The managed object context
    static func updateEntity(
        _ item: ClipboardItem,
        with content: ClipboardContent,
        context: NSManagedObjectContext
    ) {
        item.timestamp = content.timestamp
        item.contentType = content.primaryType.rawValue
        item.contentHash = content.contentHash
        item.plainTextPreview = content.previewText
        item.isSensitive = content.isSensitive
        item.sensitiveTypesJSON = content.sensitiveTypes.isEmpty ? nil : (try? JSONEncoder().encode(content.sensitiveTypes)).flatMap { String(data: $0, encoding: .utf8) }

        // Update or create content data
        if let contentData = item.content {
            contentData.plainTextData = content.plainText
            contentData.rtfData = content.rtfData
            contentData.htmlContent = content.html
            contentData.imageData = content.imageData
            contentData.pdfData = content.pdfData
            contentData.url = content.url
            contentData.fileURLs = content.fileURLs
            contentData.availableTypes = content.availableTypes.map(\.rawValue)
            contentData.isImageCompressed = content.isImageCompressed
            contentData.imageWidth = Int32(content.imageWidth ?? 0)
            contentData.imageHeight = Int32(content.imageHeight ?? 0)
        } else {
            let contentData = ClipboardContentData(context: context)
            contentData.id = UUID()
            contentData.plainTextData = content.plainText
            contentData.rtfData = content.rtfData
            contentData.htmlContent = content.html
            contentData.imageData = content.imageData
            contentData.pdfData = content.pdfData
            contentData.url = content.url
            contentData.fileURLs = content.fileURLs
            contentData.availableTypes = content.availableTypes.map(\.rawValue)
            contentData.isImageCompressed = content.isImageCompressed
            contentData.imageWidth = Int32(content.imageWidth ?? 0)
            contentData.imageHeight = Int32(content.imageHeight ?? 0)
            item.content = contentData
        }

        // Update or create preview
        if let thumbnailData = content.thumbnailData {
            if let preview = item.preview {
                preview.thumbnailData = thumbnailData
                preview.width = Int32(content.imageWidth ?? 0)
                preview.height = Int32(content.imageHeight ?? 0)
            } else {
                let preview = ContentPreview(context: context)
                preview.id = UUID()
                preview.thumbnailData = thumbnailData
                preview.width = Int32(content.imageWidth ?? 0)
                preview.height = Int32(content.imageHeight ?? 0)
                item.preview = preview
            }
        }
    }
}
