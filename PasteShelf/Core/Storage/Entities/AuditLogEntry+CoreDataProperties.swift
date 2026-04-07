//
//  AuditLogEntry+CoreDataProperties.swift
//  PasteShelf
//
//  Properties and fetch requests for the AuditLogEntry CoreData entity.
//

import CoreData
import Foundation

public extension AuditLogEntry {
    @nonobjc class func fetchRequest() -> NSFetchRequest<AuditLogEntry> {
        NSFetchRequest<AuditLogEntry>(entityName: "AuditLogEntry")
    }

    // MARK: - Attributes

    /// The specific action that was recorded (raw value of `AuditAction`).
    @NSManaged var action: String?

    /// The server-assigned device identifier of the device that generated this event.
    @NSManaged var deviceId: String?

    /// The AES-encrypted JSON encoding of the event's `detail` dictionary.
    @NSManaged var encryptedDetail: Data?

    /// The high-level category of this event (raw value of `AuditEventCategory`).
    @NSManaged var eventCategory: String?

    /// A locally generated UUID that uniquely identifies this audit log entry.
    @NSManaged var id: UUID?

    /// Whether this entry has been successfully synced to the admin console.
    @NSManaged var isSynced: Bool

    /// The identifier of the specific resource affected by this action, if any.
    @NSManaged var resourceId: String?

    /// The type of resource affected by this action, if any.
    @NSManaged var resourceType: String?

    /// The operational significance of this event (raw value of `AuditEventSeverity`).
    @NSManaged var severity: String?

    /// The timestamp at which this entry was successfully synced to the admin console.
    @NSManaged var syncedAt: Date?

    /// When the auditable action occurred.
    @NSManaged var timestamp: Date?

    /// The SSO user ID associated with this event, if a user session was active.
    @NSManaged var userId: String?
}

// MARK: - AuditLogEntry + Identifiable

extension AuditLogEntry: Identifiable {}

// MARK: - Convenience Initializers

extension AuditLogEntry {
    /// Creates a new `AuditLogEntry` from an `AuditEvent` domain model and its encrypted detail payload.
    ///
    /// - Parameters:
    ///   - context: The `NSManagedObjectContext` in which to insert the new object.
    ///   - event: The `AuditEvent` whose fields are copied into the entity.
    ///   - encryptedDetail: The AES-encrypted JSON representation of `event.detail`, or `nil`
    ///     if encryption is unavailable or the detail dictionary is empty.
    convenience init(
        context: NSManagedObjectContext,
        event: AuditEvent,
        encryptedDetail: Data?
    ) {
        self.init(context: context)
        id = event.id
        timestamp = event.timestamp
        eventCategory = event.category.rawValue
        action = event.action.rawValue
        severity = event.severity.rawValue
        userId = event.userId
        deviceId = event.deviceId
        resourceType = event.resourceType
        resourceId = event.resourceId
        self.encryptedDetail = encryptedDetail
        isSynced = false
        syncedAt = nil
    }
}

// MARK: - Fetch Requests

extension AuditLogEntry {
    /// Returns a fetch request for unsynced entries sorted by timestamp ascending.
    ///
    /// Use this during the flush cycle to retrieve events that need to be uploaded
    /// to the admin console in chronological order.
    ///
    /// - Parameter limit: The maximum number of unsynced entries to return.
    /// - Returns: A configured `NSFetchRequest` targeting `isSynced == NO` entries.
    static func unsyncedFetchRequest(limit: Int) -> NSFetchRequest<AuditLogEntry> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isSynced == NO")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \AuditLogEntry.timestamp, ascending: true),
        ]
        request.fetchLimit = limit
        return request
    }

    /// Returns a fetch request for the audit log viewer, with optional category and date filters.
    ///
    /// Results are sorted by timestamp descending so that the most recent events appear first.
    ///
    /// - Parameters:
    ///   - category: If non-nil, only entries whose `eventCategory` matches this value are returned.
    ///   - from: If non-nil, only entries with `timestamp >= from` are returned.
    ///   - to: If non-nil, only entries with `timestamp <= to` are returned.
    /// - Returns: A configured `NSFetchRequest` with the appropriate predicate and sort descriptor.
    static func viewerFetchRequest(
        category: AuditEventCategory?,
        from: Date?,
        to: Date?
    ) -> NSFetchRequest<AuditLogEntry> {
        let request = fetchRequest()

        var predicates: [NSPredicate] = []

        if let category {
            predicates.append(NSPredicate(format: "eventCategory == %@", category.rawValue))
        }
        if let from {
            predicates.append(NSPredicate(format: "timestamp >= %@", from as NSDate))
        }
        if let to {
            predicates.append(NSPredicate(format: "timestamp <= %@", to as NSDate))
        }

        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \AuditLogEntry.timestamp, ascending: false),
        ]
        return request
    }

    /// Returns a fetch request for entries older than the given retention cutoff date.
    ///
    /// Use this during the scheduled pruning pass to identify and delete stale entries
    /// that exceed the configured retention window.
    ///
    /// - Parameter olderThan: The cutoff date. Entries with `timestamp < olderThan` are returned.
    /// - Returns: A configured `NSFetchRequest` targeting entries that are eligible for deletion.
    static func retentionCleanupFetchRequest(olderThan cutoff: Date) -> NSFetchRequest<AuditLogEntry> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "timestamp < %@", cutoff as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \AuditLogEntry.timestamp, ascending: true),
        ]
        return request
    }
}
