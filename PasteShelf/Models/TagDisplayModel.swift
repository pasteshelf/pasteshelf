//
//  TagDisplayModel.swift
//  PasteShelf
//
//  UI-friendly display model for tags.
//  Used for presenting tags in SwiftUI views.
//

import SwiftUI

/// UI-friendly model for displaying tags
struct TagDisplayModel: Identifiable, Hashable, Sendable {
    // MARK: - Properties

    /// Unique identifier
    let id: UUID

    /// Tag name
    let name: String

    /// Tag color as hex string
    let colorHex: String

    // MARK: - Computed Properties

    /// SwiftUI Color from hex string
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    /// Whether this is a valid tag
    var isValid: Bool {
        !name.isEmpty
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TagDisplayModel, rhs: TagDisplayModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Factory

extension TagDisplayModel {
    /// Creates a display model from a CoreData Tag entity
    /// - Parameter tag: The CoreData entity
    /// - Returns: A display model, or nil if the tag has invalid data
    static func from(_ tag: Tag) -> TagDisplayModel? {
        guard let id = tag.id,
              let name = tag.name
        else {
            return nil
        }

        return TagDisplayModel(
            id: id,
            name: name,
            colorHex: tag.color ?? "#007AFF"
        )
    }

    /// Creates display models from an array of CoreData tags
    /// - Parameter tags: Array of CoreData entities
    /// - Returns: Array of display models (invalid tags are filtered out)
    static func from(_ tags: [Tag]) -> [TagDisplayModel] {
        tags.compactMap { from($0) }
    }

    /// Creates display models from an NSSet of CoreData tags
    /// - Parameter tagSet: NSSet of CoreData entities
    /// - Returns: Array of display models (invalid tags are filtered out)
    static func from(_ tagSet: NSSet?) -> [TagDisplayModel] {
        guard let tagSet,
              let tags = tagSet.allObjects as? [Tag]
        else {
            return []
        }
        return from(tags)
    }
}

// MARK: - Preview Support

#if DEBUG
    extension TagDisplayModel {
        static let sampleWork = TagDisplayModel(id: UUID(), name: "Work", colorHex: "#007AFF")
        static let samplePersonal = TagDisplayModel(id: UUID(), name: "Personal", colorHex: "#34C759")
        static let sampleImportant = TagDisplayModel(id: UUID(), name: "Important", colorHex: "#FF3B30")
        static let sampleCode = TagDisplayModel(id: UUID(), name: "Code", colorHex: "#5856D6")

        static let samples: [TagDisplayModel] = [
            sampleWork,
            samplePersonal,
            sampleImportant,
            sampleCode,
        ]
    }
#endif

// MARK: - Color Extension

extension Color {
    /// Creates a Color from a hex string
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count

        switch length {
        case 3: // RGB (12-bit)
            let r = Double((rgb >> 8) & 0xF) / 15.0
            let g = Double((rgb >> 4) & 0xF) / 15.0
            let b = Double(rgb & 0xF) / 15.0
            self.init(red: r, green: g, blue: b)

        case 6: // RRGGBB (24-bit)
            let r = Double((rgb >> 16) & 0xFF) / 255.0
            let g = Double((rgb >> 8) & 0xFF) / 255.0
            let b = Double(rgb & 0xFF) / 255.0
            self.init(red: r, green: g, blue: b)

        case 8: // AARRGGBB (32-bit)
            let a = Double((rgb >> 24) & 0xFF) / 255.0
            let r = Double((rgb >> 16) & 0xFF) / 255.0
            let g = Double((rgb >> 8) & 0xFF) / 255.0
            let b = Double(rgb & 0xFF) / 255.0
            self.init(red: r, green: g, blue: b, opacity: a)

        default:
            return nil
        }
    }

    /// Returns the hex string representation of the color
    func toHex() -> String? {
        guard let components = NSColor(self).cgColor.components,
              components.count >= 3
        else {
            return nil
        }

        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
