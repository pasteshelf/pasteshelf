//
//  PrivacyDashboardViewModel.swift
//  PasteShelf
//
//  ViewModel for the GDPR Privacy Dashboard.
//

import Combine
import Foundation
import os.log

// MARK: - DataCategoryItem

/// Represents a single data category in the privacy dashboard.
struct DataCategoryItem {
    let name: String
    let count: Int
    let icon: String
}

// MARK: - ConnectedServiceItem

/// Represents a connected service entry in the privacy dashboard.
struct ConnectedServiceItem {
    let name: String
    let isActive: Bool
    let icon: String
}

// MARK: - PrivacyDashboardViewModel

/// View model for the GDPR privacy dashboard.
///
/// Assembles data from StorageManager, AuditManager, and GDPRConsentManager
/// to present a comprehensive privacy overview.
@MainActor
final class PrivacyDashboardViewModel: ObservableObject {
    // MARK: Internal

    // MARK: - Published State

    @Published var dataCategories: [DataCategoryItem] = []
    @Published var connectedServices: [ConnectedServiceItem] = []
    @Published var storageDuration: String = "Not configured"
    @Published var isLoading = false

    // MARK: - Load Data

    /// Loads all dashboard data from the various managers.
    func loadDashboardData() async {
        isLoading = true
        defer { isLoading = false }

        // Data categories
        let clipboardItems = await StorageManager.shared.fetchRecentItems(limit: Int.max)
        let tags = await StorageManager.shared.fetchTags()
        let folders = await StorageManager.shared.fetchFolders()
        let collections = await StorageManager.shared.fetchCollections()

        dataCategories = [
            DataCategoryItem(name: "Clipboard Items", count: clipboardItems.count, icon: "doc.on.clipboard"),
            DataCategoryItem(name: "Tags", count: tags.count, icon: "tag"),
            DataCategoryItem(name: "Folders", count: folders.count, icon: "folder"),
            DataCategoryItem(name: "Collections", count: collections.count, icon: "tray.full"),
        ]

        // Connected services
        let auditEnabled = AuditManager.shared.isEnabled

        connectedServices = [
            ConnectedServiceItem(name: "Audit Logging", isActive: auditEnabled, icon: "list.clipboard.fill"),
            ConnectedServiceItem(name: "SSO", isActive: SSOManager.shared.currentSession != nil, icon: "key.fill"),
        ]

        // Storage duration
        let retentionDays = AuditManager.shared.retentionConfiguration.retentionDays
        if retentionDays >= 365 {
            let years = retentionDays / 365
            storageDuration = "\(years) year\(years > 1 ? "s" : "") (\(retentionDays) days)"
        } else {
            storageDuration = "\(retentionDays) days"
        }

        logger.info("Privacy dashboard loaded: \(clipboardItems.count) items")
    }

    // MARK: Private

    private let logger = Logger.compliance
}
