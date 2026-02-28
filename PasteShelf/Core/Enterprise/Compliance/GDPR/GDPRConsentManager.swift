//
//  GDPRConsentManager.swift
//  PasteShelf
//
//  Manages GDPR consent records for data processing categories.
//

import Combine
import CoreData
import Foundation
import os.log

/// Manages user consent preferences for GDPR data processing categories.
///
/// `GDPRConsentManager` is the central authority for tracking which data processing activities
/// the user has consented to. It reads and writes `ConsentRecord` CoreData entities and publishes
/// the current consent state so that SwiftUI views can react to changes.
///
/// All consent changes are audit-logged via `AuditManager.shared.logComplianceEvent()`.
@MainActor
final class GDPRConsentManager: ObservableObject {

    // MARK: - Singleton

    static let shared = GDPRConsentManager()

    // MARK: - Published State

    /// Current consent status for each category.
    @Published private(set) var consentStatuses: [GDPRConsentCategory: Bool] = [:]

    /// The most recent error encountered, if any.
    @Published var lastError: ComplianceError?

    // MARK: - Dependencies

    private let logger = Logger.compliance

    /// The current consent version string used for re-consent tracking.
    private let consentVersion = "1.0"

    // MARK: - Initialization

    private init() {
        loadConsentStatuses()
    }

    /// Designated initializer for dependency injection in tests.
    init(context: NSManagedObjectContext) {
        loadConsentStatuses(in: context)
    }

    // MARK: - Public API

    /// Returns whether consent is granted for the given category.
    ///
    /// - Parameter category: The data processing category to check.
    /// - Returns: `true` if the user has granted consent, `false` otherwise.
    func isConsentGranted(for category: GDPRConsentCategory) -> Bool {
        consentStatuses[category] ?? false
    }

    /// Grants consent for the given category.
    ///
    /// Creates or updates a `ConsentRecord` entity in CoreData and logs the change
    /// via the audit system.
    ///
    /// - Parameter category: The data processing category to grant consent for.
    func grantConsent(for category: GDPRConsentCategory) async {
        await updateConsent(for: category, granted: true)
    }

    /// Revokes consent for the given category.
    ///
    /// Updates the `ConsentRecord` entity in CoreData and logs the change
    /// via the audit system.
    ///
    /// - Parameter category: The data processing category to revoke consent for.
    func revokeConsent(for category: GDPRConsentCategory) async {
        await updateConsent(for: category, granted: false)
    }

    /// Returns all consent records sorted by category.
    ///
    /// - Returns: An array of tuples containing the category, grant status, and last updated date.
    func fetchAllRecords() async -> [(category: GDPRConsentCategory, isGranted: Bool, updatedAt: Date?)] {
        let context = StorageManager.shared.newBackgroundContext()
        return await context.perform {
            let request = ConsentRecord.allRecordsFetchRequest()
            guard let records = try? context.fetch(request) else { return [] }
            return records.compactMap { record in
                guard let categoryRaw = record.category,
                      let category = GDPRConsentCategory(rawValue: categoryRaw)
                else { return nil }
                return (category: category, isGranted: record.isGranted, updatedAt: record.updatedAt)
            }
        }
    }

    // MARK: - Private Helpers

    private func loadConsentStatuses(in context: NSManagedObjectContext? = nil) {
        let ctx = context ?? StorageManager.shared.viewContext
        let request = ConsentRecord.allRecordsFetchRequest()
        guard let records = try? ctx.fetch(request) else { return }

        var statuses: [GDPRConsentCategory: Bool] = [:]
        for record in records {
            if let categoryRaw = record.category,
               let category = GDPRConsentCategory(rawValue: categoryRaw) {
                statuses[category] = record.isGranted
            }
        }
        consentStatuses = statuses
    }

    private func updateConsent(for category: GDPRConsentCategory, granted: Bool) async {
        let context = StorageManager.shared.newBackgroundContext()
        await context.perform {
            let request = ConsentRecord.fetchRequest(forCategory: category.rawValue)
            let record: ConsentRecord
            if let existing = try? context.fetch(request).first {
                record = existing
            } else {
                record = ConsentRecord(context: context)
                record.id = UUID()
                record.category = category.rawValue
            }

            record.isGranted = granted
            record.updatedAt = Date()
            record.version = self.consentVersion

            if granted {
                record.grantedAt = Date()
            } else {
                record.revokedAt = Date()
            }

            try? context.save()
        }

        // Update published state
        consentStatuses[category] = granted

        // Log the consent change
        await AuditManager.shared.logComplianceEvent(
            action: .consentChanged,
            detail: [
                "category": category.rawValue,
                "granted": granted ? "true" : "false",
                "version": consentVersion
            ]
        )

        logger.info("GDPR consent \(granted ? "granted" : "revoked") for \(category.rawValue)")
    }
}
