//
//  DLPRuleEntity+CoreDataProperties.swift
//  PasteShelf
//
//  Properties, convenience initializers, and fetch requests for the DLPRuleEntity CoreData entity.
//

import CoreData
import Foundation

extension DLPRuleEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DLPRuleEntity> {
        NSFetchRequest<DLPRuleEntity>(entityName: "DLPRuleEntity")
    }

    // MARK: - Attributes

    /// A locally generated UUID that uniquely identifies this rule.
    @NSManaged public var id: UUID?

    /// A human-readable name for the rule, shown in the admin UI and violation reports.
    @NSManaged public var name: String?

    /// Whether this rule is currently active.
    @NSManaged public var isEnabled: Bool

    /// The raw value of `DLPPatternCategory` representing the category of sensitive data this rule targets.
    @NSManaged public var patternCategory: String?

    /// The regular expression pattern used to match sensitive content.
    @NSManaged public var pattern: String?

    /// The raw value of `SensitiveSeverity` assigned to violations of this rule.
    @NSManaged public var severity: String?

    /// JSON-encoded array of `DLPAction` raw values representing the ordered enforcement actions.
    @NSManaged public var actionsJSON: Data?

    /// When this rule was first created.
    @NSManaged public var createdAt: Date?

    /// When this rule was last modified.
    @NSManaged public var updatedAt: Date?

    /// Whether this rule was pushed from the admin console and cannot be modified locally.
    @NSManaged public var isAdminManaged: Bool
}

extension DLPRuleEntity: Identifiable {}

// MARK: - Convenience Initializers

extension DLPRuleEntity {

    /// Creates a new `DLPRuleEntity` from a `DLPRule` domain model.
    ///
    /// The `actions` array is JSON-encoded and stored in `actionsJSON`. If encoding fails,
    /// `actionsJSON` is set to `nil` and the rule's actions will be treated as empty on read-back.
    ///
    /// - Parameters:
    ///   - context: The `NSManagedObjectContext` in which to insert the new object.
    ///   - rule: The `DLPRule` whose fields are copied into the entity.
    ///   - isAdminManaged: Whether the rule was pushed from the admin console. Defaults to `false`.
    convenience init(
        context: NSManagedObjectContext,
        rule: DLPRule,
        isAdminManaged: Bool = false
    ) {
        self.init(context: context)
        self.id = rule.id
        self.name = rule.name
        self.isEnabled = rule.isEnabled
        self.patternCategory = rule.patternCategory.rawValue
        self.pattern = rule.pattern
        self.severity = rule.severity.rawValue.description
        self.createdAt = rule.createdAt
        self.updatedAt = rule.updatedAt
        self.isAdminManaged = isAdminManaged

        let actionRawValues = rule.actions.map(\.rawValue)
        self.actionsJSON = try? JSONEncoder().encode(actionRawValues)
    }

    // MARK: - Domain Model Conversion

    /// Converts this entity back into a `DLPRule` domain model.
    ///
    /// - Returns: A `DLPRule` populated from the entity's stored values, or `nil` if
    ///   any required field (`id`, `name`, `patternCategory`, `pattern`, `severity`) is missing
    ///   or cannot be decoded.
    func toDomainModel() -> DLPRule? {
        guard
            let id,
            let name,
            let patternCategoryRaw = patternCategory,
            let patternCategory = DLPPatternCategory(rawValue: patternCategoryRaw),
            let pattern,
            let severityRaw = severity,
            let severityInt = Int(severityRaw),
            let severity = SensitiveSeverity(rawValue: severityInt)
        else {
            return nil
        }

        var actions: [DLPAction] = []
        if let data = actionsJSON,
           let rawValues = try? JSONDecoder().decode([String].self, from: data) {
            actions = rawValues.compactMap { DLPAction(rawValue: $0) }
        }

        return DLPRule(
            id: id,
            name: name,
            isEnabled: isEnabled,
            patternCategory: patternCategory,
            pattern: pattern,
            severity: severity,
            actions: actions,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }
}

// MARK: - Fetch Requests

extension DLPRuleEntity {

    /// Returns a fetch request for all rules, sorted by creation date ascending.
    ///
    /// - Returns: A configured `NSFetchRequest` returning all stored `DLPRuleEntity` records.
    static func allRulesFetchRequest() -> NSFetchRequest<DLPRuleEntity> {
        let request = fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \DLPRuleEntity.createdAt, ascending: true)
        ]
        return request
    }

    /// Returns a fetch request for enabled rules only, sorted by creation date ascending.
    ///
    /// Use this during DLP evaluation to load only the rules that should be applied.
    ///
    /// - Returns: A configured `NSFetchRequest` targeting `isEnabled == YES` rules.
    static func enabledRulesFetchRequest() -> NSFetchRequest<DLPRuleEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isEnabled == YES")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \DLPRuleEntity.createdAt, ascending: true)
        ]
        return request
    }

    /// Returns a fetch request for rules matching a specific pattern category.
    ///
    /// - Parameter category: The `DLPPatternCategory` to filter by.
    /// - Returns: A configured `NSFetchRequest` for rules of the given category, sorted by creation date.
    static func rulesFetchRequest(for category: DLPPatternCategory) -> NSFetchRequest<DLPRuleEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "patternCategory == %@", category.rawValue)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \DLPRuleEntity.createdAt, ascending: true)
        ]
        return request
    }
}
