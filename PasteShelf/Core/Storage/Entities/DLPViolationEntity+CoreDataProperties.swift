//
//  DLPViolationEntity+CoreDataProperties.swift
//  PasteShelf
//
//  Properties, convenience initializers, and fetch requests for the DLPViolationEntity CoreData entity.
//

import CoreData
import Foundation

extension DLPViolationEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DLPViolationEntity> {
        NSFetchRequest<DLPViolationEntity>(entityName: "DLPViolationEntity")
    }

    // MARK: - Attributes

    /// A locally generated UUID that uniquely identifies this violation record.
    @NSManaged public var id: UUID?

    /// The UUID of the `DLPRule` that was violated.
    @NSManaged public var ruleId: UUID?

    /// The human-readable name of the violated rule, captured at the time of detection.
    @NSManaged public var ruleName: String?

    /// When the violation was detected.
    @NSManaged public var timestamp: Date?

    /// A redacted preview of the clipboard content that triggered the violation.
    @NSManaged public var contentPreview: String?

    /// The portion of the content that matched the rule's regex pattern.
    @NSManaged public var matchedPattern: String?

    /// The raw value of the `DLPAction` that was taken as the primary enforcement response.
    @NSManaged public var actionTaken: String?

    /// The bundle identifier of the application that was the clipboard's source, if known.
    @NSManaged public var sourceAppBundleId: String?

    /// The display name of the source application, if known.
    @NSManaged public var sourceAppName: String?

    /// Whether the clipboard item was prevented from being stored due to this violation.
    @NSManaged public var wasBlocked: Bool
}

extension DLPViolationEntity: Identifiable {}

// MARK: - Convenience Initializers

extension DLPViolationEntity {

    /// Creates a new `DLPViolationEntity` from a `DLPViolation` domain model.
    ///
    /// The `actionTaken` field is stored as the raw `String` value of the `DLPAction` enum.
    ///
    /// - Parameters:
    ///   - context: The `NSManagedObjectContext` in which to insert the new object.
    ///   - violation: The `DLPViolation` whose fields are copied into the entity.
    convenience init(
        context: NSManagedObjectContext,
        violation: DLPViolation
    ) {
        self.init(context: context)
        self.id = violation.id
        self.ruleId = violation.ruleId
        self.ruleName = violation.ruleName
        self.timestamp = violation.timestamp
        self.contentPreview = violation.contentPreview
        self.matchedPattern = violation.matchedPattern
        self.actionTaken = violation.actionTaken.rawValue
        self.sourceAppBundleId = violation.sourceAppBundleId
        self.sourceAppName = violation.sourceAppName
        self.wasBlocked = violation.wasBlocked
    }

    // MARK: - Domain Model Conversion

    /// Converts this entity back into a `DLPViolation` domain model.
    ///
    /// - Returns: A `DLPViolation` populated from the entity's stored values, or `nil` if
    ///   any required field (`id`, `ruleId`, `ruleName`, `contentPreview`, `matchedPattern`,
    ///   `actionTaken`) is missing or cannot be decoded.
    func toDomainModel() -> DLPViolation? {
        guard
            let id,
            let ruleId,
            let ruleName,
            let contentPreview,
            let matchedPattern,
            let actionTakenRaw = actionTaken,
            let actionTaken = DLPAction(rawValue: actionTakenRaw)
        else {
            return nil
        }

        return DLPViolation(
            id: id,
            ruleId: ruleId,
            ruleName: ruleName,
            timestamp: timestamp ?? Date(),
            contentPreview: contentPreview,
            matchedPattern: matchedPattern,
            actionTaken: actionTaken,
            sourceAppBundleId: sourceAppBundleId,
            sourceAppName: sourceAppName,
            wasBlocked: wasBlocked
        )
    }
}

// MARK: - Fetch Requests

extension DLPViolationEntity {

    /// Returns a fetch request for violations within a date range, sorted by timestamp descending.
    ///
    /// Pass `nil` for either bound to leave that side of the range open.
    ///
    /// - Parameters:
    ///   - from: If non-nil, only violations with `timestamp >= from` are returned.
    ///   - to: If non-nil, only violations with `timestamp <= to` are returned.
    /// - Returns: A configured `NSFetchRequest` filtered to the specified date range.
    static func violationsFetchRequest(
        from: Date?,
        to: Date?
    ) -> NSFetchRequest<DLPViolationEntity> {
        let request = fetchRequest()

        var predicates: [NSPredicate] = []
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
            NSSortDescriptor(keyPath: \DLPViolationEntity.timestamp, ascending: false)
        ]
        return request
    }

    /// Returns a fetch request for the most recent violations, sorted by timestamp descending.
    ///
    /// - Parameter limit: The maximum number of recent violations to return.
    /// - Returns: A configured `NSFetchRequest` limited to the `limit` most recent violations.
    static func recentViolationsFetchRequest(limit: Int) -> NSFetchRequest<DLPViolationEntity> {
        let request = fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \DLPViolationEntity.timestamp, ascending: false)
        ]
        request.fetchLimit = limit
        return request
    }

    /// Returns a fetch request for violations associated with a specific rule.
    ///
    /// - Parameter ruleId: The UUID of the `DLPRule` to filter violations by.
    /// - Returns: A configured `NSFetchRequest` targeting violations for the given rule,
    ///   sorted by timestamp descending.
    static func violationsFetchRequest(for ruleId: UUID) -> NSFetchRequest<DLPViolationEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "ruleId == %@", ruleId as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \DLPViolationEntity.timestamp, ascending: false)
        ]
        return request
    }

    /// Returns a fetch request for violations older than the given retention cutoff date.
    ///
    /// Use this during the scheduled pruning pass to identify and delete stale violation records
    /// that exceed the configured retention window.
    ///
    /// - Parameter olderThan: The cutoff date. Violations with `timestamp < olderThan` are returned.
    /// - Returns: A configured `NSFetchRequest` targeting violations eligible for deletion.
    static func retentionCleanupFetchRequest(olderThan cutoff: Date) -> NSFetchRequest<DLPViolationEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "timestamp < %@", cutoff as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \DLPViolationEntity.timestamp, ascending: true)
        ]
        return request
    }
}
