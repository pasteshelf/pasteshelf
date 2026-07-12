//
//  Persistence.swift
//  PasteShelf
//
//  CoreData persistence controller with CloudKit support.
//

import CoreData
import os.log

struct PersistenceController {
    static let shared = PersistenceController()

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf", category: "storage")

    @MainActor static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "PasteShelf")

        if inMemory {
            // swiftlint:disable:next force_unwrapping
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        // Enable lightweight migration
        container.persistentStoreDescriptions.first?.setOption(
            true as NSNumber,
            forKey: NSMigratePersistentStoresAutomaticallyOption
        )
        container.persistentStoreDescriptions.first?.setOption(
            true as NSNumber,
            forKey: NSInferMappingModelAutomaticallyOption
        )

        // Configure for better CloudKit compatibility
        container.persistentStoreDescriptions.first?.setOption(
            true as NSNumber,
            forKey: NSPersistentHistoryTrackingKey
        )
        container.persistentStoreDescriptions.first?.setOption(
            true as NSNumber,
            forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
        )

        // The store must stay local-only: NSPersistentCloudKitContainer would
        // otherwise mirror ALL entities to the user's private iCloud database
        // automatically (ignoring the app's sync toggle and bypassing the
        // E2E-encrypted sync engine in Core/Sync, which owns iCloud sync).
        container.persistentStoreDescriptions.first?.cloudKitContainerOptions = nil

        container.loadPersistentStores { storeDescription, error in
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

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Creates a new background context for write operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}
