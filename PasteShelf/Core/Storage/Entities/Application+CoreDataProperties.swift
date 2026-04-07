//
//  Application+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch request for Application entity.
//

import CoreData
import Foundation

public extension Application {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Application> {
        NSFetchRequest<Application>(entityName: "Application")
    }

    // MARK: - Attributes

    /// Bundle identifier of the application (e.g., "com.apple.Safari")
    @NSManaged var bundleId: String?

    /// Display name of the application
    @NSManaged var name: String?

    /// Whether this application is excluded from clipboard monitoring
    @NSManaged var isExcluded: Bool
}

// MARK: - Application + Identifiable

extension Application: Identifiable {
    public var id: String? {
        bundleId
    }
}
