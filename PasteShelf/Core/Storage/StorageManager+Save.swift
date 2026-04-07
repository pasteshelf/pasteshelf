//
//  StorageManager+Save.swift
//  PasteShelf
//
//  Save operations for StorageManager.
//

import CoreData
import Foundation
import os.log

// MARK: - ApplicationEntry

/// Represents an application to be saved or updated
struct ApplicationEntry {
    let bundleId: String
    let name: String
    let isExcluded: Bool
}

extension StorageManager {
    // MARK: - Tag Operations

    /// Saves a new tag
    /// - Parameters:
    ///   - name: The tag name
    ///   - color: The tag color as hex string (e.g., "#FF5733")
    /// - Returns: The created Tag, or nil if save failed
    func saveTag(name: String, color: String) async -> Tag? {
        await performBackgroundTaskSafe { context in
            let tag = Tag(context: context)
            tag.id = UUID()
            tag.name = name
            tag.color = color
            return tag
        }
    }

    /// Saves multiple tags at once
    /// - Parameter tags: Array of (name, color) tuples
    /// - Returns: Array of created tags
    func saveTags(_ tags: [(name: String, color: String)]) async -> [Tag] {
        let result = await performBackgroundTaskSafe { context -> [Tag] in
            tags.map { name, color in
                let tag = Tag(context: context)
                tag.id = UUID()
                tag.name = name
                tag.color = color
                return tag
            }
        }
        return result ?? []
    }

    // MARK: - Folder Operations

    /// Saves a new folder
    /// - Parameters:
    ///   - name: The folder name
    ///   - icon: Optional SF Symbol icon name
    ///   - parent: Optional parent folder for nesting
    /// - Returns: The created Folder, or nil if save failed
    func saveFolder(name: String, icon: String? = nil, parent: Folder? = nil) async -> Folder? {
        await performBackgroundTaskSafe { context in
            let folder = Folder(context: context)
            folder.id = UUID()
            folder.name = name
            folder.icon = icon
            folder.sortOrder = 0

            // Handle parent relationship in same context
            if let parentId = parent?.id {
                let request = Folder.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", parentId as CVarArg)
                request.fetchLimit = 1

                if let parentInContext = try? context.fetch(request).first {
                    folder.parentFolder = parentInContext
                }
            }

            return folder
        }
    }

    /// Updates folder sort order
    /// - Parameters:
    ///   - folder: The folder to update
    ///   - sortOrder: The new sort order
    /// - Returns: True if update succeeded
    func updateFolderSortOrder(_ folder: Folder, sortOrder: Int32) async -> Bool {
        guard let folderId = folder.id else {
            return false
        }

        do {
            try await performBackgroundTask { context in
                let request = Folder.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", folderId as CVarArg)
                request.fetchLimit = 1

                if let folderInContext = try context.fetch(request).first {
                    folderInContext.sortOrder = sortOrder
                }
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Application Exclusion Operations

    /// Saves or updates an application exclusion
    /// - Parameters:
    ///   - bundleId: The application bundle identifier
    ///   - name: The application display name
    ///   - isExcluded: Whether the app should be excluded
    /// - Returns: The created/updated Application, or nil if save failed
    func saveApplication(bundleId: String, name: String, isExcluded: Bool) async -> Application? {
        await performBackgroundTaskSafe { context in
            // Check if application already exists
            let request = Application.fetchRequest()
            request.predicate = NSPredicate(format: "bundleId == %@", bundleId)
            request.fetchLimit = 1

            if let existing = try? context.fetch(request).first {
                existing.name = name
                existing.isExcluded = isExcluded
                return existing
            }

            // Create new application
            let app = Application(context: context)
            app.bundleId = bundleId
            app.name = name
            app.isExcluded = isExcluded
            return app
        }
    }

    /// Saves multiple applications at once
    /// - Parameter applications: Array of (bundleId, name, isExcluded) tuples
    /// - Returns: Number of applications saved
    func saveApplications(_ applications: [ApplicationEntry]) async -> Int {
        let result = await performBackgroundTaskSafe { context -> Int in
            var count = 0
            for entry in applications {
                let bundleId = entry.bundleId
                let name = entry.name
                let isExcluded = entry.isExcluded
                let request = Application.fetchRequest()
                request.predicate = NSPredicate(format: "bundleId == %@", bundleId)
                request.fetchLimit = 1

                if let existing = try? context.fetch(request).first {
                    existing.name = name
                    existing.isExcluded = isExcluded
                } else {
                    let app = Application(context: context)
                    app.bundleId = bundleId
                    app.name = name
                    app.isExcluded = isExcluded
                }
                count += 1
            }
            return count
        }
        return result ?? 0
    }
}
