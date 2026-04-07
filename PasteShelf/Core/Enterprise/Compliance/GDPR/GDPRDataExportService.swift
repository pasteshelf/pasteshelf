//
//  GDPRDataExportService.swift
//  PasteShelf
//
//  GDPR Article 20 data portability — exports all user data as a structured archive.
//

import CoreData
import Foundation
import os.log

// MARK: - GDPRDataExportService

/// Exports all user data in a structured, machine-readable format for GDPR Article 20 compliance.
///
/// `GDPRDataExportService` gathers data from every storage layer — clipboard items, tags, folders,
/// collections, audit logs, settings, and consent records — and writes them to a temporary directory
/// as JSON files alongside a `manifest.json` that describes the export.
///
/// The caller is responsible for presenting the resulting directory URL to the user (e.g. via
/// `NSSavePanel`) and cleaning up the temporary files afterwards.
enum GDPRDataExportService {
    // MARK: Internal

    // MARK: - Export

    /// Exports all user data to a temporary directory.
    ///
    /// - Parameter progressHandler: An optional closure called with progress updates (0.0–1.0).
    /// - Returns: The file URL of the temporary directory containing the exported files.
    /// - Throws: `ComplianceError.exportFailed` if any step fails.
    @MainActor
    static func exportUserData(progressHandler: ((Double) -> Void)? = nil) async throws -> URL {
        logger.info("GDPR data export: starting full user data export")

        let exportDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PasteShelf-GDPR-Export-\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        } catch {
            throw ComplianceError.exportFailed(underlying: error)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let counts = try await exportAllCategories(
                to: exportDir,
                encoder: encoder,
                progressHandler: progressHandler
            )
            try writeManifest(to: exportDir, encoder: encoder, counts: counts)
            progressHandler?(1.0)

            await logExportAuditEvent(counts: counts)

            logger.info("GDPR data export: completed to \(exportDir.lastPathComponent)")
            return exportDir
        } catch let error as ComplianceError {
            throw error
        } catch {
            throw ComplianceError.exportFailed(underlying: error)
        }
    }

    // MARK: Private

    private static let logger = Logger.compliance

    /// Exports all data categories to the given directory and returns their counts.
    @MainActor
    private static func exportAllCategories(
        to exportDir: URL,
        encoder: JSONEncoder,
        progressHandler: ((Double) -> Void)?
    ) async throws -> ExportCounts {
        progressHandler?(0.0)
        let clipboardData = try await exportClipboardItems()
        try writeJSON(clipboardData, to: exportDir.appendingPathComponent("clipboard_items.json"), encoder: encoder)
        progressHandler?(0.15)

        let tagsData = try await exportTags()
        try writeJSON(tagsData, to: exportDir.appendingPathComponent("tags.json"), encoder: encoder)
        progressHandler?(0.20)

        let foldersData = try await exportFolders()
        try writeJSON(foldersData, to: exportDir.appendingPathComponent("folders.json"), encoder: encoder)
        progressHandler?(0.25)

        let collectionsData = try await exportCollections()
        try writeJSON(collectionsData, to: exportDir.appendingPathComponent("collections.json"), encoder: encoder)
        progressHandler?(0.30)

        let auditData = try await exportAuditLogs()
        try writeJSON(auditData, to: exportDir.appendingPathComponent("audit_logs.json"), encoder: encoder)
        progressHandler?(0.60)

        let settingsData = try exportSettings()
        try writeJSON(settingsData, to: exportDir.appendingPathComponent("settings.json"), encoder: encoder)
        progressHandler?(0.65)

        let consentData = try await exportConsentRecords()
        try writeJSON(consentData, to: exportDir.appendingPathComponent("consent_records.json"), encoder: encoder)
        progressHandler?(0.70)

        return ExportCounts(
            clipboard: clipboardData.count,
            tags: tagsData.count,
            folders: foldersData.count,
            collections: collectionsData.count,
            auditLogs: auditData.count,
            consent: consentData.count
        )
    }

    /// Writes the export manifest file.
    private static func writeManifest(
        to exportDir: URL,
        encoder: JSONEncoder,
        counts: ExportCounts
    ) throws {
        let manifest = ExportManifest(
            exportDate: Date(),
            applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            files: [
                "clipboard_items.json", "tags.json", "folders.json",
                "collections.json", "audit_logs.json",
                "settings.json", "consent_records.json",
            ],
            clipboardItemCount: counts.clipboard,
            tagCount: counts.tags,
            folderCount: counts.folders,
            collectionCount: counts.collections,
            auditLogCount: counts.auditLogs,
            consentRecordCount: counts.consent
        )
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: exportDir.appendingPathComponent("manifest.json"))
    }

    /// Logs the GDPR export as an audit event.
    @MainActor
    private static func logExportAuditEvent(counts: ExportCounts) async {
        await AuditManager.shared.logComplianceEvent(
            action: .dataExported,
            severity: .info,
            detail: [
                "clipboardItems": "\(counts.clipboard)",
                "tags": "\(counts.tags)",
                "folders": "\(counts.folders)",
                "collections": "\(counts.collections)",
                "auditLogs": "\(counts.auditLogs)",
                "consentRecords": "\(counts.consent)",
            ]
        )
    }

    // MARK: - Individual Exporters

    /// Exports all clipboard items as portable dictionaries.
    @MainActor
    private static func exportClipboardItems() async throws -> [[String: String?]] {
        let items = await StorageManager.shared.fetchRecentItems(limit: Int.max)
        return items.map { item in
            [
                "id": item.id?.uuidString,
                "timestamp": item.timestamp?.ISO8601Format(),
                "contentType": item.contentType,
                "plainTextPreview": item.plainTextPreview,
                "sourceAppBundleId": item.sourceAppBundleId,
                "sourceAppName": item.sourceAppName,
                "isSensitive": item.isSensitive ? "true" : "false",
                "isFavorite": item.isFavorite ? "true" : "false",
                "accessCount": "\(item.accessCount)",
                "modifiedAt": item.modifiedAt?.ISO8601Format(),
            ]
        }
    }

    /// Exports all tags.
    @MainActor
    private static func exportTags() async throws -> [[String: String?]] {
        let tags = await StorageManager.shared.fetchTags()
        return tags.map { tag in
            [
                "id": tag.id?.uuidString,
                "name": tag.name,
                "color": tag.color,
            ]
        }
    }

    /// Exports all folders.
    @MainActor
    private static func exportFolders() async throws -> [[String: String?]] {
        let folders = await StorageManager.shared.fetchFolders()
        return folders.map { folder in
            [
                "id": folder.id?.uuidString,
                "name": folder.name,
                "icon": folder.icon,
            ]
        }
    }

    /// Exports all smart collections.
    @MainActor
    private static func exportCollections() async throws -> [[String: String?]] {
        let collections = await StorageManager.shared.fetchCollections()
        return collections.map { collection in
            [
                "id": collection.id?.uuidString,
                "name": collection.name,
                "icon": collection.icon,
                "isAutomatic": collection.isAutomatic ? "true" : "false",
            ]
        }
    }

    /// Exports all audit log entries.
    @MainActor
    private static func exportAuditLogs() async throws -> [[String: String?]] {
        guard let storage = AuditManager.shared.storage else {
            return []
        }

        let entries = try await storage.fetchEvents(
            category: nil,
            from: nil,
            to: nil,
            limit: Int.max
        )

        return entries.map { entry in
            let detail: String? = if let detailDict = try? storage.decryptDetail(for: entry) {
                detailDict.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "; ")
            } else {
                nil
            }

            return [
                "id": entry.id?.uuidString,
                "timestamp": entry.timestamp?.ISO8601Format(),
                "category": entry.eventCategory,
                "action": entry.action,
                "severity": entry.severity,
                "userId": entry.userId,
                "deviceId": entry.deviceId,
                "resourceType": entry.resourceType,
                "resourceId": entry.resourceId,
                "detail": detail,
            ]
        }
    }

    /// Exports user settings relevant to data processing.
    private static func exportSettings() throws -> [String: String] {
        let defaults = UserDefaults.standard
        var settings: [String: String] = [:]

        // Export PasteShelf-relevant UserDefaults
        let keys = [
            "com.pasteshelf.hipaa.config",
            "com.pasteshelf.audit.lastRetentionCleanup",
            "selectedSyncBackend",
            "maxHistoryCount",
            "autoDeleteAfterDays",
            "excludeSensitiveData",
            "monitoringEnabled",
        ]

        for key in keys {
            if let value = defaults.object(forKey: key) {
                settings[key] = "\(value)"
            }
        }

        return settings
    }

    /// Exports all consent records.
    @MainActor
    private static func exportConsentRecords() async throws -> [[String: String?]] {
        let records = await GDPRConsentManager.shared.fetchAllRecords()
        return records.map { record in
            [
                "category": record.category.rawValue,
                "isGranted": record.isGranted ? "true" : "false",
                "updatedAt": record.updatedAt?.ISO8601Format(),
            ]
        }
    }

    // MARK: - Helpers

    /// Writes an Encodable value as JSON to the given file URL.
    private static func writeJSON(_ value: some Encodable, to url: URL, encoder: JSONEncoder) throws {
        let data = try encoder.encode(value)
        try data.write(to: url)
    }
}

// MARK: - ExportCounts

/// Internal struct holding export counts for each data category.
private struct ExportCounts {
    let clipboard: Int
    let tags: Int
    let folders: Int
    let collections: Int
    let auditLogs: Int
    let consent: Int
}

// MARK: - ExportManifest

/// Metadata describing a GDPR data export.
private struct ExportManifest: Codable {
    let exportDate: Date
    let applicationVersion: String
    let format: String = "PasteShelf GDPR Export v1"
    let files: [String]
    let clipboardItemCount: Int
    let tagCount: Int
    let folderCount: Int
    let collectionCount: Int
    let auditLogCount: Int
    let consentRecordCount: Int
}
