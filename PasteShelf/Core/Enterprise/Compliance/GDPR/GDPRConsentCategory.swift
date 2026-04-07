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
enum GDPRConsentCategory: String, Codable, CaseIterable {
    /// Monitoring the system clipboard for new content.
    case clipboardMonitoring = "clipboard_monitoring"

    /// Collecting anonymous usage analytics and crash reports.
    case analytics

    /// Syncing clipboard data to iCloud or a self-hosted server.
    case cloudSync = "cloud_sync"

    /// Recording audit log events for enterprise compliance.
    case auditLogging = "audit_logging"

    /// Enabling third-party plugin access to clipboard data.
    case thirdPartyPlugins = "third_party_plugins"

    // MARK: Internal

    /// Human-readable display name for this category.
    var displayName: String {
        switch self {
        case .clipboardMonitoring:
            String(localized: "Clipboard Monitoring")
        case .analytics:
            String(localized: "Usage Analytics")
        case .cloudSync:
            String(localized: "Cloud Sync")
        case .auditLogging:
            String(localized: "Audit Logging")
        case .thirdPartyPlugins:
            String(localized: "Third-Party Plugins")
        }
    }

    /// Description of what data this category processes and why.
    var purposeDescription: String {
        switch self {
        case .clipboardMonitoring:
            String(localized: "Monitor your clipboard to capture and store copied items for quick access.")
        case .analytics:
            String(localized: "Collect anonymous usage statistics to improve the application.")
        case .cloudSync:
            String(localized: "Sync your clipboard history across devices via iCloud or self-hosted server.")
        case .auditLogging:
            String(localized: "Record activity logs for enterprise compliance and security auditing.")
        case .thirdPartyPlugins:
            String(localized: "Allow installed plugins to access and transform clipboard content.")
        }
    }

    /// SF Symbol icon name for this category.
    var iconName: String {
        switch self {
        case .clipboardMonitoring:
            "doc.on.clipboard"
        case .analytics:
            "chart.bar.fill"
        case .cloudSync:
            "icloud.fill"
        case .auditLogging:
            "list.clipboard.fill"
        case .thirdPartyPlugins:
            "puzzlepiece.extension.fill"
        }
    }
}
