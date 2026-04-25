//
//  AutomationAction.swift
//  PasteShelf
//
//  Defines actions that can be executed by automation rules.
//  Actions modify clipboard content or trigger external operations.
//

import Foundation

// MARK: - Automation Action

/// Actions that can be executed when an automation rule matches
enum AutomationAction: Codable, Equatable, Identifiable, Sendable {
    /// Unique identifier for this action instance
    var id: UUID {
        switch self {
        case .transform(let id, _): return id
        case .addTag(let id, _): return id
        case .removeTag(let id, _): return id
        case .setFavorite(let id, _): return id
        case .moveToFolder(let id, _): return id
        case .copyToClipboard(let id): return id
        case .notify(let id, _, _): return id
        case .openURL(let id, _): return id
        #if !APP_STORE
        case .runScript(let id, _): return id
        #endif
        case .webhook(let id, _): return id
        case .markSensitive(let id, _): return id
        case .delete(let id): return id
        }
    }

    // MARK: - Action Cases

    /// Apply a text transformation preset
    case transform(id: UUID = UUID(), preset: TransformPreset)

    /// Add a tag to the clipboard item
    case addTag(id: UUID = UUID(), tagName: String)

    /// Remove a tag from the clipboard item
    case removeTag(id: UUID = UUID(), tagName: String)

    /// Set the favorite status
    case setFavorite(id: UUID = UUID(), isFavorite: Bool)

    /// Move item to a folder
    case moveToFolder(id: UUID = UUID(), folderName: String)

    /// Re-copy content to system clipboard
    case copyToClipboard(id: UUID = UUID())

    /// Show a notification
    case notify(id: UUID = UUID(), title: String, message: String)

    /// Open a URL (supports template variables)
    case openURL(id: UUID = UUID(), urlTemplate: String)

    #if !APP_STORE
    /// Run an AppleScript
    case runScript(id: UUID = UUID(), scriptPath: String)
    #endif

    /// Send a webhook request
    case webhook(id: UUID = UUID(), endpointId: UUID)

    /// Mark item as sensitive/not sensitive
    case markSensitive(id: UUID = UUID(), isSensitive: Bool)

    /// Delete the item (prevents storage)
    case delete(id: UUID = UUID())

    // MARK: - Properties

    /// Type identifier for the action
    var actionType: ActionType {
        switch self {
        case .transform: return .transform
        case .addTag: return .addTag
        case .removeTag: return .removeTag
        case .setFavorite: return .setFavorite
        case .moveToFolder: return .moveToFolder
        case .copyToClipboard: return .copyToClipboard
        case .notify: return .notify
        case .openURL: return .openURL
        #if !APP_STORE
        case .runScript: return .runScript
        #endif
        case .webhook: return .webhook
        case .markSensitive: return .markSensitive
        case .delete: return .delete
        }
    }

    /// Human-readable display name
    var displayName: String {
        actionType.displayName
    }

    /// Localized description of what this action does
    var description: String {
        switch self {
        case .transform(_, let preset):
            return String(localized: "Transform: \(String(localized: preset.displayNameKey))")
        case .addTag(_, let tagName):
            return String(localized: "Add tag: \(tagName)")
        case .removeTag(_, let tagName):
            return String(localized: "Remove tag: \(tagName)")
        case .setFavorite(_, let isFavorite):
            return isFavorite
                ? String(localized: "Mark as favorite")
                : String(localized: "Remove from favorites")
        case .moveToFolder(_, let folderName):
            return String(localized: "Move to folder: \(folderName)")
        case .copyToClipboard:
            return String(localized: "Copy to clipboard")
        case .notify(_, let title, _):
            return String(localized: "Show notification: \(title)")
        case .openURL(_, let urlTemplate):
            return String(localized: "Open URL: \(urlTemplate)")
        #if !APP_STORE
        case .runScript(_, let scriptPath):
            return String(localized: "Run script: \(scriptPath)")
        #endif
        case .webhook(_, _):
            return String(localized: "Send webhook")
        case .markSensitive(_, let isSensitive):
            return isSensitive
                ? String(localized: "Mark as sensitive")
                : String(localized: "Mark as not sensitive")
        case .delete:
            return String(localized: "Delete item")
        }
    }

    /// SF Symbol icon for the action
    var iconName: String {
        actionType.iconName
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case preset
        case tagName
        case isFavorite
        case folderName
        case title
        case message
        case urlTemplate
        case scriptPath
        case endpointId
        case isSensitive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let id = try container.decode(UUID.self, forKey: .id)

        switch type {
        case "transform":
            let preset = try container.decode(TransformPreset.self, forKey: .preset)
            self = .transform(id: id, preset: preset)

        case "addTag":
            let tagName = try container.decode(String.self, forKey: .tagName)
            self = .addTag(id: id, tagName: tagName)

        case "removeTag":
            let tagName = try container.decode(String.self, forKey: .tagName)
            self = .removeTag(id: id, tagName: tagName)

        case "setFavorite":
            let isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
            self = .setFavorite(id: id, isFavorite: isFavorite)

        case "moveToFolder":
            let folderName = try container.decode(String.self, forKey: .folderName)
            self = .moveToFolder(id: id, folderName: folderName)

        case "copyToClipboard":
            self = .copyToClipboard(id: id)

        case "notify":
            let title = try container.decode(String.self, forKey: .title)
            let message = try container.decode(String.self, forKey: .message)
            self = .notify(id: id, title: title, message: message)

        case "openURL":
            let urlTemplate = try container.decode(String.self, forKey: .urlTemplate)
            self = .openURL(id: id, urlTemplate: urlTemplate)

        #if !APP_STORE
        case "runScript":
            let scriptPath = try container.decode(String.self, forKey: .scriptPath)
            self = .runScript(id: id, scriptPath: scriptPath)
        #endif

        case "webhook":
            let endpointId = try container.decode(UUID.self, forKey: .endpointId)
            self = .webhook(id: id, endpointId: endpointId)

        case "markSensitive":
            let isSensitive = try container.decode(Bool.self, forKey: .isSensitive)
            self = .markSensitive(id: id, isSensitive: isSensitive)

        case "delete":
            self = .delete(id: id)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown action type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(actionType.rawValue, forKey: .type)
        try container.encode(id, forKey: .id)

        switch self {
        case .transform(_, let preset):
            try container.encode(preset, forKey: .preset)

        case .addTag(_, let tagName), .removeTag(_, let tagName):
            try container.encode(tagName, forKey: .tagName)

        case .setFavorite(_, let isFavorite):
            try container.encode(isFavorite, forKey: .isFavorite)

        case .moveToFolder(_, let folderName):
            try container.encode(folderName, forKey: .folderName)

        case .copyToClipboard:
            break

        case .notify(_, let title, let message):
            try container.encode(title, forKey: .title)
            try container.encode(message, forKey: .message)

        case .openURL(_, let urlTemplate):
            try container.encode(urlTemplate, forKey: .urlTemplate)

        #if !APP_STORE
        case .runScript(_, let scriptPath):
            try container.encode(scriptPath, forKey: .scriptPath)
        #endif

        case .webhook(_, let endpointId):
            try container.encode(endpointId, forKey: .endpointId)

        case .markSensitive(_, let isSensitive):
            try container.encode(isSensitive, forKey: .isSensitive)

        case .delete:
            break
        }
    }
}

// MARK: - Action Type

/// Types of automation actions
enum ActionType: String, Codable, CaseIterable, Sendable {
    case transform
    case addTag
    case removeTag
    case setFavorite
    case moveToFolder
    case copyToClipboard
    case notify
    case openURL
    #if !APP_STORE
    case runScript
    #endif
    case webhook
    case markSensitive
    case delete

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .transform:
            return String(localized: "Transform Content")
        case .addTag:
            return String(localized: "Add Tag")
        case .removeTag:
            return String(localized: "Remove Tag")
        case .setFavorite:
            return String(localized: "Set Favorite")
        case .moveToFolder:
            return String(localized: "Move to Folder")
        case .copyToClipboard:
            return String(localized: "Copy to Clipboard")
        case .notify:
            return String(localized: "Show Notification")
        case .openURL:
            return String(localized: "Open URL")
        #if !APP_STORE
        case .runScript:
            return String(localized: "Run Script")
        #endif
        case .webhook:
            return String(localized: "Send Webhook")
        case .markSensitive:
            return String(localized: "Mark Sensitive")
        case .delete:
            return String(localized: "Delete Item")
        }
    }

    /// Description of the action type
    var description: String {
        switch self {
        case .transform:
            return String(localized: "Apply a text transformation to the content")
        case .addTag:
            return String(localized: "Add a tag to the clipboard item")
        case .removeTag:
            return String(localized: "Remove a tag from the clipboard item")
        case .setFavorite:
            return String(localized: "Mark or unmark the item as a favorite")
        case .moveToFolder:
            return String(localized: "Move the item to a specific folder")
        case .copyToClipboard:
            return String(localized: "Copy the modified content back to the clipboard")
        case .notify:
            return String(localized: "Display a system notification")
        case .openURL:
            return String(localized: "Open a URL in the default browser")
        #if !APP_STORE
        case .runScript:
            return String(localized: "Execute an AppleScript file")
        #endif
        case .webhook:
            return String(localized: "Send an HTTP request to a webhook endpoint")
        case .markSensitive:
            return String(localized: "Mark or unmark the item as sensitive")
        case .delete:
            return String(localized: "Delete the item and prevent storage")
        }
    }

    /// SF Symbol icon for the action type
    var iconName: String {
        switch self {
        case .transform:
            return "wand.and.stars"
        case .addTag:
            return "tag.fill"
        case .removeTag:
            return "tag.slash"
        case .setFavorite:
            return "star.fill"
        case .moveToFolder:
            return "folder.fill"
        case .copyToClipboard:
            return "doc.on.doc.fill"
        case .notify:
            return "bell.fill"
        case .openURL:
            return "link"
        #if !APP_STORE
        case .runScript:
            return "applescript"
        #endif
        case .webhook:
            return "network"
        case .markSensitive:
            return "lock.shield.fill"
        case .delete:
            return "trash.fill"
        }
    }

}

// MARK: - JSON Serialization

extension Array where Element == AutomationAction {
    /// Serializes actions array to JSON string
    func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Deserializes actions array from JSON string
    static func fromJSON(_ json: String?) -> [AutomationAction]? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([AutomationAction].self, from: data)
    }
}
