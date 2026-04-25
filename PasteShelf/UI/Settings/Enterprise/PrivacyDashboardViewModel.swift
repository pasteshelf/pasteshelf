//
//  PrivacyDashboardViewModel.swift
//  PasteShelf
//
//  ViewModel for the GDPR Privacy Dashboard.
//

import Combine
import Foundation
import os.log

// MARK: - PrivacyDashboardViewModel

/// View model for the GDPR privacy dashboard.
///
/// Assembles data from StorageManager, AuditManager, and GDPRConsentManager
/// to present a comprehensive privacy overview.
@MainActor
final class PrivacyDashboardViewModel: ObservableObject {

    // MARK: - Published State

    @Published var dataCategories: [(name: String, count: Int, icon: String)] = []
    @Published var connectedServices: [(name: String, isActive: Bool, icon: String)] = []
    @Published var storageDuration: String = String(localized: "Not configured")
    @Published var isLoading = false

    private let logger = Logger.compliance

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
            (name: String(localized: "Clipboard Items"), count: clipboardItems.count, icon: "doc.on.clipboard"),
            (name: String(localized: "Tags"), count: tags.count, icon: "tag"),
            (name: String(localized: "Folders"), count: folders.count, icon: "folder"),
            (name: String(localized: "Collections"), count: collections.count, icon: "tray.full")
        ]

        // Connected services
        let auditEnabled = AuditManager.shared.isEnabled

        connectedServices = [
            (name: String(localized: "Audit Logging"), isActive: auditEnabled, icon: "list.clipboard.fill"),
            (name: String(localized: "SSO"), isActive: SSOManager.shared.currentSession != nil, icon: "key.fill")
        ]

        // Storage duration
        let retentionDays = AuditManager.shared.retentionConfiguration.retentionDays
        if retentionDays >= 365 {
            let years = retentionDays / 365
            let yearsSuffix = years > 1 ? "s" : ""
            storageDuration = String(localized: "\(years) year\(yearsSuffix) (\(retentionDays) days)")
        } else {
            storageDuration = String(localized: "\(retentionDays) days")
        }

        logger.info("Privacy dashboard loaded: \(clipboardItems.count) items")
    }
}
