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
        case network

        /// Post system notifications
        case notifications

        /// Access persistent storage
        case storage

        /// Register automation actions
        case automation

        // MARK: Internal

        // MARK: - Display Properties

        /// Human-readable display name
        var displayName: String {
            switch self {
            case .clipboardRead:
                String(localized: "Read Clipboard")
            case .clipboardWrite:
                String(localized: "Write Clipboard")
            case .network:
                String(localized: "Network Access")
            case .notifications:
                String(localized: "Notifications")
            case .storage:
                String(localized: "Storage")
            case .automation:
                String(localized: "Automation")
            }
        }

        /// Description of what this permission allows
        var description: String {
            switch self {
            case .clipboardRead:
                String(localized: "Access clipboard history and read item content")
            case .clipboardWrite:
                String(localized: "Copy transformed content to the system clipboard")
            case .network:
                String(localized: "Make HTTP requests to external services")
            case .notifications:
                String(localized: "Display system notifications")
            case .storage:
                String(localized: "Store persistent data between sessions")
            case .automation:
                String(localized: "Register custom automation actions")
            }
        }

        /// SF Symbol icon for the permission
        var iconName: String {
            switch self {
            case .clipboardRead:
                "doc.on.clipboard"
            case .clipboardWrite:
                "doc.on.clipboard.fill"
            case .network:
                "network"
            case .notifications:
                "bell.fill"
            case .storage:
                "externaldrive.fill"
            case .automation:
                "gearshape.2.fill"
            }
        }

        /// Risk level for user information
        var riskLevel: PermissionRiskLevel {
            switch self {
            case .clipboardRead:
                .high // Access to potentially sensitive clipboard data
            case .clipboardWrite:
                .medium // Can modify clipboard content
            case .network:
                .high // Can exfiltrate data
            case .notifications:
                .low // Minimal impact
            case .storage:
                .low // Isolated per-plugin storage
            case .automation:
                .medium // Can execute actions automatically
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

        // MARK: Internal

        var displayName: String {
            switch self {
            case .low:
                String(localized: "Low Risk")
            case .medium:
                String(localized: "Medium Risk")
            case .high:
                String(localized: "High Risk")
            }
        }

        var color: String {
            switch self {
            case .low:
                "green"
            case .medium:
                "orange"
            case .high:
                "red"
            }
        }

        static func < (lhs: PermissionRiskLevel, rhs: PermissionRiskLevel) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }

        // MARK: Private

        private var sortOrder: Int {
            switch self {
            case .low: 0
            case .medium: 1
            case .high: 2
            }
        }
    }

    /// Tracks granted permissions for a plugin
    struct PluginPermissionGrant: Codable, Equatable, Sendable {
        // MARK: Lifecycle

        init(pluginId: String, permission: PluginPermission, isPermanent: Bool = true) {
            self.pluginId = pluginId
            self.permission = permission
            grantedAt = Date()
            self.isPermanent = isPermanent
        }

        // MARK: Internal

        /// Plugin identifier
        let pluginId: String

        /// Permission that was granted
        let permission: PluginPermission

        /// When the permission was granted
        let grantedAt: Date

        /// Whether the grant is permanent or per-session
        let isPermanent: Bool
    }

#endif
