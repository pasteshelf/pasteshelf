//
//  ConsentRecord+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch requests for the ConsentRecord CoreData entity.
//

import CoreData
import Foundation

extension ConsentRecord {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ConsentRecord> {
        NSFetchRequest<ConsentRecord>(entityName: "ConsentRecord")
    }

    // MARK: - Attributes

    /// The consent category identifier (e.g. "clipboardMonitoring", "analytics").
    @NSManaged public var category: String?

    /// When consent was granted for this category.
    @NSManaged public var grantedAt: Date?

    /// A locally generated UUID that uniquely identifies this consent record.
    @NSManaged public var id: UUID?

    /// Whether consent is currently granted for this category.
    @NSManaged public var isGranted: Bool

    /// When consent was last revoked for this category, if applicable.
    @NSManaged public var revokedAt: Date?

    /// When this record was last updated.
    @NSManaged public var updatedAt: Date?

    /// The consent version string for re-consent tracking.
    @NSManaged public var version: String?
}

extension ConsentRecord: Identifiable {}

// MARK: - Fetch Requests

extension ConsentRecord {

    /// Returns a fetch request for the consent record matching a specific category.
    ///
    /// - Parameter category: The consent category to look up.
    /// - Returns: A configured fetch request limited to one result.
    static func fetchRequest(forCategory category: String) -> NSFetchRequest<ConsentRecord> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", category)
        request.fetchLimit = 1
        return request
    }

    /// Returns a fetch request for all consent records sorted by category.
    static func allRecordsFetchRequest() -> NSFetchRequest<ConsentRecord> {
        let request = fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ConsentRecord.category, ascending: true)
        ]
        return request
    }
}
