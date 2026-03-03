//
//  SOC2AccessControlEvidence.swift
//  PasteShelf
//
//  Exports authentication events and policy changes as a ZIP evidence package
//  for SOC 2 access control audits.
//

import CoreData
import Foundation
import os.log

// MARK: - SOC2AccessControlEvidence

/// Exports audit log events related to authentication and policy changes as a
/// structured evidence package for SOC 2 access control audits.
///
/// `SOC2AccessControlEvidence` queries `AuditManager.shared.storage` for events
/// in a caller-supplied date range, splits them into authentication and policy
/// categories, and writes four artefacts into a unique temporary directory:
///
/// - `authentication_events.json` — all `.authentication` category events as JSON
/// - `policy_changes.json` — all `.policy` category events as JSON
/// - `access_summary.csv` — a flat CSV with date, userId, action, and result columns
/// - `evidence_metadata.json` — package metadata (date range, event counts, version)
///
/// The method returns the URL of the temporary directory that contains those four
/// files. The caller is responsible for compressing the directory into a ZIP
/// archive if required (e.g. via `Process` + `zip`).
struct SOC2AccessControlEvidence: Sendable {

    private static let logger = Logger.compliance

    // MARK: - Evidence Package Errors

    /// Errors that can be thrown during evidence package generation.
    enum EvidenceError: Error, LocalizedError {

        /// The audit storage backend is not configured.
        case storageUnavailable

        /// Writing one of the evidence files failed.
        case fileWriteFailed(String)

        var errorDescription: String? {
            switch self {
            case .storageUnavailable:
                return "Audit storage is not available. Ensure AuditManager has been configured."
            case .fileWriteFailed(let reason):
                return "Failed to write evidence file: \(reason)"
            }
        }
    }

    // MARK: - Public API

    /// Exports authentication and policy audit events as a structured evidence package.
    ///
    /// Queries `AuditManager.shared.storage` using the built-in category and date-range
    /// filters, then writes four files into a uniquely named directory inside
    /// `FileManager.default.temporaryDirectory`.
    ///
    /// - Parameter dateRange: The inclusive date range for which events are exported.
    /// - Returns: The `URL` of the temporary directory containing the four evidence files.
    /// - Throws: `EvidenceError.storageUnavailable` if audit storage is not configured,
    ///   or `EvidenceError.fileWriteFailed` if any file cannot be written.
    @MainActor
    static func exportEvidencePackage(dateRange: ClosedRange<Date>) async throws -> URL {
        logger.info("Starting SOC 2 access control evidence export (range: \(dateRange.lowerBound) – \(dateRange.upperBound))")

        guard let storage = AuditManager.shared.storage else {
            logger.error("Audit storage unavailable — AuditManager not configured")
            throw EvidenceError.storageUnavailable
        }

        // Fetch authentication events via the storage service's built-in filter.
        let authEntries = try await storage.fetchEvents(
            category: .authentication,
            from: dateRange.lowerBound,
            to: dateRange.upperBound,
            limit: Int.max
        )

        // Fetch policy events via the storage service's built-in filter.
        let policyEntries = try await storage.fetchEvents(
            category: .policy,
            from: dateRange.lowerBound,
            to: dateRange.upperBound,
            limit: Int.max
        )

        // Convert CoreData entries to domain models for encoding.
        let authEvents = authEntries.compactMap { AuditEvent(from: $0) }
        let policyEvents = policyEntries.compactMap { AuditEvent(from: $0) }

        logger.info("Fetched \(authEvents.count) authentication event(s) and \(policyEvents.count) policy event(s)")

        // Create a unique output directory for this export run.
        let exportDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SOC2AccessControlEvidence-\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create evidence export directory: \(error.localizedDescription)")
            throw EvidenceError.fileWriteFailed("Could not create export directory: \(error.localizedDescription)")
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        // 1. authentication_events.json
        try writeJSON(
            try encoder.encode(authEvents),
            to: exportDir.appendingPathComponent("authentication_events.json")
        )

        // 2. policy_changes.json
        try writeJSON(
            try encoder.encode(policyEvents),
            to: exportDir.appendingPathComponent("policy_changes.json")
        )

        // 3. access_summary.csv — combines both authentication and policy events
        let allAccessEvents = authEvents + policyEvents
        let csvString = generateAccessSummaryCSV(allAccessEvents)
        guard let csvData = csvString.data(using: .utf8) else {
            throw EvidenceError.fileWriteFailed("Failed to encode CSV string as UTF-8")
        }
        try writeData(csvData, to: exportDir.appendingPathComponent("access_summary.csv"))

        // 4. evidence_metadata.json
        let metadataData = generateMetadata(
            dateRange: dateRange,
            authCount: authEvents.count,
            policyCount: policyEvents.count
        )
        try writeJSON(metadataData, to: exportDir.appendingPathComponent("evidence_metadata.json"))

        logger.info("SOC 2 access control evidence package written to \(exportDir.path)")
        return exportDir
    }

    // MARK: - Helper: Filter Events by Category

    /// Filters an array of `AuditEvent` values to those matching a given category.
    ///
    /// - Parameters:
    ///   - events: The full set of audit events to filter.
    ///   - category: The category to retain.
    /// - Returns: All events whose `category` matches the provided value.
    static func filterEvents(_ events: [AuditEvent], category: AuditEventCategory) -> [AuditEvent] {
        events.filter { $0.category == category }
    }

    // MARK: - Helper: Generate Access Summary CSV

    /// Produces a CSV string summarising the provided audit events.
    ///
    /// The CSV includes a header row followed by one data row per event with the
    /// columns: `date`, `userId`, `action`, and `result`.
    ///
    /// - Parameter events: The audit events to summarise.
    /// - Returns: A UTF-8 CSV string with CRLF line endings.
    static func generateAccessSummaryCSV(_ events: [AuditEvent]) -> String {
        let isoFormatter = ISO8601DateFormatter()

        var rows: [String] = ["date,userId,action,result"]

        for event in events.sorted(by: { $0.timestamp < $1.timestamp }) {
            let date = isoFormatter.string(from: event.timestamp)
            let userId = csvEscape(event.userId ?? "")
            let action = csvEscape(event.action.rawValue)
            let result = csvEscape(event.detail["result"] ?? event.severity.rawValue)
            rows.append("\(date),\(userId),\(action),\(result)")
        }

        return rows.joined(separator: "\r\n") + "\r\n"
    }

    // MARK: - Helper: Generate Metadata

    /// Produces JSON-encoded metadata describing this evidence package.
    ///
    /// The metadata object includes:
    /// - `dateRange` — start and end of the queried period (ISO 8601)
    /// - `generatedAt` — when this package was created (ISO 8601)
    /// - `eventCounts` — a breakdown of event counts by category
    /// - `applicationVersion` — the running app's short version string
    ///
    /// - Parameters:
    ///   - dateRange: The date range used to query audit events.
    ///   - authCount: The number of authentication events included.
    ///   - policyCount: The number of policy events included.
    /// - Returns: Pretty-printed, sorted JSON data.
    static func generateMetadata(
        dateRange: ClosedRange<Date>,
        authCount: Int,
        policyCount: Int
    ) -> Data {
        let isoFormatter = ISO8601DateFormatter()
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

        let metadata: [String: Any] = [
            "dateRange": [
                "start": isoFormatter.string(from: dateRange.lowerBound),
                "end": isoFormatter.string(from: dateRange.upperBound)
            ],
            "generatedAt": isoFormatter.string(from: Date()),
            "eventCounts": [
                "authentication": authCount,
                "policy": policyCount,
                "total": authCount + policyCount
            ],
            "applicationVersion": appVersion
        ]

        // JSONSerialization handles the [String: Any] dictionary; sort keys for determinism.
        guard let data = try? JSONSerialization.data(
            withJSONObject: metadata,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            // Fall back to a minimal valid JSON object if serialization unexpectedly fails.
            return Data("{\"error\":\"metadata serialization failed\"}".utf8)
        }

        return data
    }

    // MARK: - Private Helpers

    /// Writes `data` to `url`, wrapping any file-system error in `EvidenceError.fileWriteFailed`.
    private static func writeJSON(_ data: Data, to url: URL) throws {
        try writeData(data, to: url)
    }

    /// Writes `data` to `url`, wrapping any file-system error in `EvidenceError.fileWriteFailed`.
    private static func writeData(_ data: Data, to url: URL) throws {
        do {
            try data.write(to: url, options: .atomic)
            logger.debug("Wrote evidence file: \(url.lastPathComponent) (\(data.count) bytes)")
        } catch {
            logger.error("Failed to write \(url.lastPathComponent): \(error.localizedDescription)")
            throw EvidenceError.fileWriteFailed("\(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    /// Escapes a single CSV field value by wrapping in double-quotes if the value
    /// contains a comma, double-quote, or newline character.
    private static func csvEscape(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")
        if needsQuoting {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}

// MARK: - AuditEvent + CoreData Convenience Init

private extension AuditEvent {

    /// Creates an `AuditEvent` from a CoreData `AuditLogEntry` managed object.
    ///
    /// Returns `nil` if any required field (id, timestamp, category, action, or severity)
    /// is missing or cannot be decoded from the stored raw-string values.
    ///
    /// - Parameter entry: The `AuditLogEntry` to convert.
    init?(from entry: AuditLogEntry) {
        guard
            let id = entry.id,
            let timestamp = entry.timestamp,
            let categoryRaw = entry.eventCategory,
            let category = AuditEventCategory(rawValue: categoryRaw),
            let actionRaw = entry.action,
            let action = AuditAction(rawValue: actionRaw),
            let severityRaw = entry.severity,
            let severity = AuditEventSeverity(rawValue: severityRaw)
        else {
            return nil
        }

        self.init(
            id: id,
            timestamp: timestamp,
            category: category,
            action: action,
            severity: severity,
            userId: entry.userId,
            deviceId: entry.deviceId,
            resourceType: entry.resourceType,
            resourceId: entry.resourceId,
            detail: [:]
        )
    }
}
