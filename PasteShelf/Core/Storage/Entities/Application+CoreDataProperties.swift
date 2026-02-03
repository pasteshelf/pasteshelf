//
//  Application+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch request for Application entity.
//

import CoreData
import Foundation

extension Application {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Application> {
        NSFetchRequest<Application>(entityName: "Application")
    }

    // MARK: - Attributes

    /// Bundle identifier of the application (e.g., "com.apple.Safari")
    @NSManaged public var bundleId: String?

    /// Display name of the application
    @NSManaged public var name: String?

    /// Whether this application is excluded from clipboard monitoring
    @NSManaged public var isExcluded: Bool
}

extension Application: Identifiable {
    public var id: String? { bundleId }
}
