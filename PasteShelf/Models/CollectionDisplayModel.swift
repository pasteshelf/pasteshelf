//
//  CollectionDisplayModel.swift
//  PasteShelf
//
//  UI-friendly display model for smart collections.
//  Used for presenting collections in SwiftUI views.
//

import SwiftUI

/// UI-friendly model for displaying smart collections
struct CollectionDisplayModel: Identifiable, Hashable, Sendable {
    // MARK: - Properties

    /// Unique identifier
    let id: UUID

    /// Collection name
    let name: String

    /// SF Symbol icon name
    let icon: String

    /// Optional color as hex string
    let colorHex: String?

    /// Whether this is an automatic (rule-based) collection
    let isAutomatic: Bool

    /// Number of items in the collection
    let itemCount: Int

    /// Sort order for display
    let sortOrder: Int32

    /// Collection rules (only for automatic collections)
    let rules: CollectionRules?

    // MARK: - Computed Properties

    /// SwiftUI Color from hex string, or default color
    var color: Color {
        if let colorHex {
            return Color(hex: colorHex) ?? .accentColor
        }
        return .accentColor
    }

    /// Whether this collection has a custom color
    var hasCustomColor: Bool {
        colorHex != nil
    }

    /// Whether this is a valid collection
    var isValid: Bool {
        !name.isEmpty
    }

    /// Description of the collection type
    var typeDescription: String {
        isAutomatic ? "Smart Collection" : "Manual Collection"
    }

    /// Summary of rules (for automatic collections)
    var rulesSummary: String? {
        guard isAutomatic, let rules, !rules.isEmpty else { return nil }

        let conditionCount = rules.conditions.count
        let operatorText = rules.logicalOperator == .and ? "all" : "any"

        if conditionCount == 1 {
            return "1 rule"
        } else {
            return "\(conditionCount) rules (\(operatorText))"
        }
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        colorHex: String? = nil,
        isAutomatic: Bool = true,
        itemCount: Int = 0,
        sortOrder: Int32 = 0,
        rules: CollectionRules? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isAutomatic = isAutomatic
        self.itemCount = itemCount
        self.sortOrder = sortOrder
        self.rules = rules
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CollectionDisplayModel, rhs: CollectionDisplayModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Factory

extension CollectionDisplayModel {
    /// Creates a display model from a CoreData SmartCollection entity
    /// - Parameters:
    ///   - collection: The CoreData entity
    ///   - itemCount: Optional pre-computed item count
    /// - Returns: A display model, or nil if the collection has invalid data
    static func from(_ collection: SmartCollection, itemCount: Int = 0) -> CollectionDisplayModel? {
        guard let id = collection.id,
              let name = collection.name
        else {
            return nil
        }

        let rules: CollectionRules?
        if collection.isAutomatic, let rulesJSON = collection.rulesJSON {
            rules = CollectionRules.fromJSON(rulesJSON)
        } else {
            rules = nil
        }

        return CollectionDisplayModel(
            id: id,
            name: name,
            icon: collection.icon ?? "folder",
            colorHex: collection.colorHex,
            isAutomatic: collection.isAutomatic,
            itemCount: itemCount,
            sortOrder: collection.sortOrder,
            rules: rules
        )
    }

    /// Creates display models from an array of CoreData collections
    /// - Parameter collections: Array of CoreData entities
    /// - Returns: Array of display models (invalid collections are filtered out)
    static func from(_ collections: [SmartCollection]) -> [CollectionDisplayModel] {
        collections.compactMap { from($0) }
    }

    /// Creates a new model for editing with updated properties
    func updated(
        name: String? = nil,
        icon: String? = nil,
        colorHex: String?? = nil,
        isAutomatic: Bool? = nil,
        itemCount: Int? = nil,
        sortOrder: Int32? = nil,
        rules: CollectionRules? = nil
    ) -> CollectionDisplayModel {
        CollectionDisplayModel(
            id: self.id,
            name: name ?? self.name,
            icon: icon ?? self.icon,
            colorHex: colorHex ?? self.colorHex,
            isAutomatic: isAutomatic ?? self.isAutomatic,
            itemCount: itemCount ?? self.itemCount,
            sortOrder: sortOrder ?? self.sortOrder,
            rules: rules ?? self.rules
        )
    }
}

// MARK: - Preview Support

#if DEBUG
    extension CollectionDisplayModel {
        static let sampleImages = CollectionDisplayModel(
            id: UUID(),
            name: "Images",
            icon: "photo.stack",
            colorHex: "#FF9500",
            isAutomatic: true,
            itemCount: 42,
            sortOrder: 0,
            rules: CollectionRules(
                conditions: [
                    RuleCondition(field: .contentType, comparisonOperator: .equals, value: "images"),
                ],
                logicalOperator: .and
            )
        )

        static let sampleFromSafari = CollectionDisplayModel(
            id: UUID(),
            name: "From Safari",
            icon: "safari",
            colorHex: "#007AFF",
            isAutomatic: true,
            itemCount: 18,
            sortOrder: 1,
            rules: CollectionRules(
                conditions: [
                    RuleCondition(
                        field: .sourceApp,
                        comparisonOperator: .contains,
                        value: "Safari"
                    ),
                ],
                logicalOperator: .and
            )
        )

        static let sampleRecentLinks = CollectionDisplayModel(
            id: UUID(),
            name: "Recent Links",
            icon: "link",
            colorHex: "#5856D6",
            isAutomatic: true,
            itemCount: 12,
            sortOrder: 2,
            rules: CollectionRules(
                conditions: [
                    RuleCondition(field: .contentType, comparisonOperator: .equals, value: "links"),
                    RuleCondition(field: .dateCreated, comparisonOperator: .withinLast, value: "7d"),
                ],
                logicalOperator: .and
            )
        )

        static let sampleFavorites = CollectionDisplayModel(
            id: UUID(),
            name: "My Favorites",
            icon: "star.fill",
            colorHex: "#FFCC00",
            isAutomatic: false,
            itemCount: 8,
            sortOrder: 3,
            rules: nil
        )

        static let samples: [CollectionDisplayModel] = [
            sampleImages,
            sampleFromSafari,
            sampleRecentLinks,
            sampleFavorites,
        ]
    }
#endif
