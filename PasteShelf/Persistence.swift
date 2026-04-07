//
//  Persistence.swift
//  PasteShelf
//
//  CoreData persistence controller with CloudKit support.
//

import CoreData
import os.log

struct PersistenceController {
    // MARK: Lifecycle

    init(inMemory: Bool = false) {
        self.container = NSPersistentCloudKitContainer(name: "PasteShelf")

        if inMemory {
            // swiftlint:disable:next force_unwrapping
            self.container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        // Enable lightweight migration
        self.container.persistentStoreDescriptions.first?.setOption(
            true as NSNumber,
            forKey: NSMigratePersistentStoresAutomaticallyOption
        )
        self.container.persistentStoreDescriptions.first?.setOption(
            true as NSNumber,
            forKey: NSInferMappingModelAutomaticallyOption
        )

        // Configure for better CloudKit compatibility
        self.container.persistentStoreDescriptions.first?.setOption(
            true as NSNumber,
            forKey: NSPersistentHistoryTrackingKey
        )
        self.container.persistentStoreDescriptions.first?.setOption(
            true as NSNumber,
            forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
        )

        self.container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                Self.logger.error("CoreData store failed to load: \(error.localizedDescription)")
                // In production, handle gracefully instead of crashing
                #if DEBUG
                    fatalError("Unresolved CoreData error: \(error), \(error.userInfo)")
                #endif
            } else {
                Self.logger.info("CoreData store loaded: \(storeDescription.url?.absoluteString ?? "unknown")")
            }
        }

        self.container.viewContext.automaticallyMergesChangesFromParent = true
        self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: Internal

    static let shared = PersistenceController()

    @MainActor static let preview: PersistenceController = .init(inMemory: true)

    let container: NSPersistentCloudKitContainer

    /// Creates a new background context for write operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = self.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    // MARK: Private

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf", category: "storage")
}
