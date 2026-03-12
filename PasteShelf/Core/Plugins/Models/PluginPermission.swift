#if !APP_STORE
//
//  PluginPermission.swift
//  PasteShelf
//
//  Defines permissions that plugins can request.
//  Each permission gates access to specific host APIs.
//

import Foundation

/// Permissions that plugins can request for host API access
public enum PluginPermission: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
    /// Read clipboard items (history access)
    case clipboardRead = "clipboard.read"

    /// Write to the system clipboard
    case clipboardWrite = "clipboard.write"

    /// Make network requests
    case network = "network"

    /// Post system notifications
    case notifications = "notifications"

    /// Access persistent storage
    case storage = "storage"

    /// Register automation actions
    case automation = "automation"

    // MARK: - Display Properties

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .clipboardRead:
            return String(localized: "Read Clipboard")
        case .clipboardWrite:
            return String(localized: "Write Clipboard")
        case .network:
            return String(localized: "Network Access")
        case .notifications:
            return String(localized: "Notifications")
        case .storage:
            return String(localized: "Storage")
        case .automation:
            return String(localized: "Automation")
        }
    }

    /// Description of what this permission allows
    var description: String {
        switch self {
        case .clipboardRead:
            return String(localized: "Access clipboard history and read item content")
        case .clipboardWrite:
            return String(localized: "Copy transformed content to the system clipboard")
        case .network:
            return String(localized: "Make HTTP requests to external services")
        case .notifications:
            return String(localized: "Display system notifications")
        case .storage:
            return String(localized: "Store persistent data between sessions")
        case .automation:
            return String(localized: "Register custom automation actions")
        }
    }

    /// SF Symbol icon for the permission
    var iconName: String {
        switch self {
        case .clipboardRead:
            return "doc.on.clipboard"
        case .clipboardWrite:
            return "doc.on.clipboard.fill"
        case .network:
            return "network"
        case .notifications:
            return "bell.fill"
        case .storage:
            return "externaldrive.fill"
        case .automation:
            return "gearshape.2.fill"
        }
    }

    /// Risk level for user information
    var riskLevel: PermissionRiskLevel {
        switch self {
        case .clipboardRead:
            return .high // Access to potentially sensitive clipboard data
        case .clipboardWrite:
            return .medium // Can modify clipboard content
        case .network:
            return .high // Can exfiltrate data
        case .notifications:
            return .low // Minimal impact
        case .storage:
            return .low // Isolated per-plugin storage
        case .automation:
            return .medium // Can execute actions automatically
        }
    }

    /// Creates permissions from Info.plist array
    /// - Parameter rawValues: Array of permission strings from plist
    /// - Returns: Set of valid permissions
    static func from(rawValues: [String]) -> Set<PluginPermission> {
        Set(rawValues.compactMap { PluginPermission(rawValue: $0) })
    }
}

/// Risk level for permission display
enum PermissionRiskLevel: String, Codable, Sendable, Comparable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low:
            return String(localized: "Low Risk")
        case .medium:
            return String(localized: "Medium Risk")
        case .high:
            return String(localized: "High Risk")
        }
    }

    var color: String {
        switch self {
        case .low:
            return "green"
        case .medium:
            return "orange"
        case .high:
            return "red"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }

    static func < (lhs: PermissionRiskLevel, rhs: PermissionRiskLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

/// Tracks granted permissions for a plugin
struct PluginPermissionGrant: Codable, Equatable, Sendable {
    /// Plugin identifier
    let pluginId: String

    /// Permission that was granted
    let permission: PluginPermission

    /// When the permission was granted
    let grantedAt: Date

    /// Whether the grant is permanent or per-session
    let isPermanent: Bool

    init(pluginId: String, permission: PluginPermission, isPermanent: Bool = true) {
        self.pluginId = pluginId
        self.permission = permission
        self.grantedAt = Date()
        self.isPermanent = isPermanent
    }
}

#endif
