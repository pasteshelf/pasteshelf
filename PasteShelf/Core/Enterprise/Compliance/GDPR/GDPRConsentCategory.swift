//
//  GDPRConsentCategory.swift
//  PasteShelf
//
//  Data processing categories for GDPR consent tracking.
//

import Foundation

/// Categories of data processing that require explicit user consent under GDPR.
///
/// Each category represents a distinct purpose for which PasteShelf processes user data.
/// Users can grant or revoke consent for each category independently, and the application
/// must respect these preferences by enabling or disabling the corresponding functionality.
enum GDPRConsentCategory: String, Codable, Sendable, CaseIterable {

    /// Monitoring the system clipboard for new content.
    case clipboardMonitoring = "clipboard_monitoring"

    /// Collecting anonymous usage analytics and crash reports.
    case analytics = "analytics"

    /// Syncing clipboard data to iCloud or a self-hosted server.
    case cloudSync = "cloud_sync"

    /// Recording audit log events for enterprise compliance.
    case auditLogging = "audit_logging"

    /// Enabling third-party plugin access to clipboard data.
    case thirdPartyPlugins = "third_party_plugins"

    /// Human-readable display name for this category.
    var displayName: String {
        switch self {
        case .clipboardMonitoring:
            return String(localized: "Clipboard Monitoring")
        case .analytics:
            return String(localized: "Usage Analytics")
        case .cloudSync:
            return String(localized: "Cloud Sync")
        case .auditLogging:
            return String(localized: "Audit Logging")
        case .thirdPartyPlugins:
            return String(localized: "Third-Party Plugins")
        }
    }

    /// Description of what data this category processes and why.
    var purposeDescription: String {
        switch self {
        case .clipboardMonitoring:
            return String(localized: "Monitor your clipboard to capture and store copied items for quick access.")
        case .analytics:
            return String(localized: "Collect anonymous usage statistics to improve the application.")
        case .cloudSync:
            return String(localized: "Sync your clipboard history across devices via iCloud or self-hosted server.")
        case .auditLogging:
            return String(localized: "Record activity logs for enterprise compliance and security auditing.")
        case .thirdPartyPlugins:
            return String(localized: "Allow installed plugins to access and transform clipboard content.")
        }
    }

    /// SF Symbol icon name for this category.
    var iconName: String {
        switch self {
        case .clipboardMonitoring:
            return "doc.on.clipboard"
        case .analytics:
            return "chart.bar.fill"
        case .cloudSync:
            return "icloud.fill"
        case .auditLogging:
            return "list.clipboard.fill"
        case .thirdPartyPlugins:
            return "puzzlepiece.extension.fill"
        }
    }
}
