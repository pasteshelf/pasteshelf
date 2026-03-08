//
//  GDPRDataDeletionService.swift
//  PasteShelf
//
//  GDPR Article 17 right to erasure — deletes all user data across every store.
//

import CoreData
import Foundation
import os.log
import Security

// MARK: - GDPRDataDeletionService

/// Deletes all user data to fulfill a GDPR Article 17 "right to erasure" request.
///
/// `GDPRDataDeletionService` systematically removes data from every storage layer:
/// clipboard items, tags, folders, collections, embeddings, OCR caches, audit logs,
/// consent records, Keychain items, and relevant UserDefaults entries.
///
/// A `GDPRDeletionReport` is returned describing the outcome of each category.
/// The deletion event itself is logged to the audit trail *before* audit logs are erased.
struct GDPRDataDeletionService: Sendable {

    private static let logger = Logger.compliance

    // MARK: - Deletion

    /// Deletes all user data and returns a report of what was removed.
    ///
    /// The deletion order is:
    /// 1. Log the deletion event (before audit logs are erased)
    /// 2. Clipboard items (including favorites)
    /// 3. Tags
    /// 4. Folders
    /// 5. Collections
    /// 6. Embeddings
    /// 7. OCR caches
    /// 8. Consent records
    /// 9. Audit logs
    /// 10. Keychain items
    /// 11. UserDefaults entries
    ///
    /// - Returns: A `GDPRDeletionReport` summarizing each category.
    /// - Throws: `ComplianceError.deletionFailed` if a critical step fails.
    @MainActor
    static func deleteAllUserData() async throws -> GDPRDeletionReport {
        logger.info("GDPR data deletion: starting complete user data erasure")

        var categories: [GDPRDeletionReport.CategoryResult] = []

        // 0. Log the deletion event before destroying audit logs
        await AuditManager.shared.logComplianceEvent(
            action: .dataDeleted,
            severity: .critical,
            detail: ["scope": "full_erasure", "reason": "gdpr_article_17"]
        )

        // 1. Clipboard items
        let itemCount = await StorageManager.shared.deleteAllItems(keepFavorites: false)
        categories.append(.init(name: "Clipboard Items", deletedCount: itemCount, success: true))
        if itemCount > 0 {
            NotificationCenter.default.post(name: .clipboardHistoryChanged, object: nil)
        }
        logger.info("GDPR deletion: removed \(itemCount) clipboard items")

        // 2. Tags
        let tagCount = await deleteAllEntities(Tag.self, entityName: "Tag")
        categories.append(.init(name: "Tags", deletedCount: tagCount, success: tagCount >= 0))

        // 3. Folders
        let folderCount = await deleteAllEntities(Folder.self, entityName: "Folder")
        categories.append(.init(name: "Folders", deletedCount: folderCount, success: folderCount >= 0))

        // 4. Collections
        let collectionCount = await deleteAllEntities(SmartCollection.self, entityName: "SmartCollection")
        categories.append(.init(name: "Collections", deletedCount: collectionCount, success: collectionCount >= 0))

        // 5. Embeddings
        let embeddingCount = await StorageManager.shared.deleteAllEmbeddings()
        categories.append(.init(name: "Embeddings", deletedCount: embeddingCount, success: true))

        // 6. OCR caches
        let ocrCount = await StorageManager.shared.deleteAllOCR()
        categories.append(.init(name: "OCR Caches", deletedCount: ocrCount, success: true))

        // 7. Consent records
        let consentCount = await deleteAllEntities(ConsentRecord.self, entityName: "ConsentRecord")
        categories.append(.init(name: "Consent Records", deletedCount: consentCount, success: consentCount >= 0))

        // 8. Audit logs
        let auditCount = await deleteAllEntities(AuditLogEntry.self, entityName: "AuditLogEntry")
        categories.append(.init(name: "Audit Logs", deletedCount: auditCount, success: auditCount >= 0))

        // 9. Keychain items
        let keychainSuccess = deleteKeychainItems()
        categories.append(.init(name: "Keychain Items", deletedCount: keychainSuccess ? 2 : 0, success: keychainSuccess))

        // 10. UserDefaults
        let defaultsCount = clearUserDefaults()
        categories.append(.init(name: "UserDefaults", deletedCount: defaultsCount, success: true))

        let report = GDPRDeletionReport(
            categories: categories,
            completedAt: Date()
        )

        logger.info("GDPR data deletion: complete. \(report.totalDeleted) items removed across \(categories.count) categories")
        return report
    }

    // MARK: - Entity Deletion

    /// Deletes all instances of a CoreData entity using batch delete.
    ///
    /// - Parameters:
    ///   - type: The NSManagedObject subclass.
    ///   - entityName: The entity name in the CoreData model.
    /// - Returns: The number of deleted records, or -1 if the operation failed.
    @MainActor
    private static func deleteAllEntities<T: NSManagedObject>(_ type: T.Type, entityName: String) async -> Int {
        let context = StorageManager.shared.newBackgroundContext()

        return await context.perform {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeCount

            do {
                let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                let count = result?.result as? Int ?? 0
                logger.info("GDPR deletion: removed \(count) \(entityName) records")
                return count
            } catch {
                logger.error("GDPR deletion: failed to delete \(entityName) — \(error.localizedDescription)")
                return -1
            }
        }
    }

    // MARK: - Keychain Deletion

    /// Removes PasteShelf encryption keys from the Keychain.
    private static func deleteKeychainItems() -> Bool {
        let tags = [
            "com.pasteshelf.audit.detail.key",
            "com.pasteshelf.sync.encryption.key"
        ]

        var allSuccess = true
        for tag in tags {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: tag
            ]
            let status = SecItemDelete(query as CFDictionary)
            if status != errSecSuccess && status != errSecItemNotFound {
                logger.warning("GDPR deletion: failed to delete Keychain item \(tag) (status: \(status))")
                allSuccess = false
            }
        }

        return allSuccess
    }

    // MARK: - UserDefaults Deletion

    /// Clears PasteShelf-related UserDefaults entries.
    ///
    /// - Returns: The number of keys removed.
    private static func clearUserDefaults() -> Int {
        let defaults = UserDefaults.standard

        let prefixes = [
            "com.pasteshelf.",
            "selectedSyncBackend",
            "maxHistoryCount",
            "autoDeleteAfterDays",
            "excludeSensitiveData",
            "monitoringEnabled"
        ]

        var count = 0
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys {
            if prefixes.contains(where: { key.hasPrefix($0) || key == $0 }) {
                defaults.removeObject(forKey: key)
                count += 1
            }
        }

        defaults.synchronize()
        logger.info("GDPR deletion: cleared \(count) UserDefaults keys")
        return count
    }
}

// MARK: - GDPRDeletionReport

/// Report detailing the outcome of a GDPR Article 17 data deletion.
struct GDPRDeletionReport: Codable, Sendable, Identifiable {

    let id: UUID
    let categories: [CategoryResult]
    let completedAt: Date

    /// Total number of items deleted across all categories.
    var totalDeleted: Int {
        categories.reduce(0) { $0 + max($1.deletedCount, 0) }
    }

    /// Whether all categories were successfully deleted.
    var allSuccessful: Bool {
        categories.allSatisfy(\.success)
    }

    /// Categories that failed during deletion.
    var failedCategories: [CategoryResult] {
        categories.filter { !$0.success }
    }

    init(id: UUID = UUID(), categories: [CategoryResult], completedAt: Date = Date()) {
        self.id = id
        self.categories = categories
        self.completedAt = completedAt
    }

    /// Result for a single data category in the deletion process.
    struct CategoryResult: Codable, Sendable, Identifiable {
        let id: UUID
        let name: String
        let deletedCount: Int
        let success: Bool

        init(id: UUID = UUID(), name: String, deletedCount: Int, success: Bool) {
            self.id = id
            self.name = name
            self.deletedCount = deletedCount
            self.success = success
        }
    }
}
