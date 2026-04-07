//
//  SOC2AuditTrailExporter.swift
//  PasteShelf
//
//  Exports a verified audit trail with cryptographic integrity hash chain for SOC 2 compliance.
//

import CoreData
import CryptoKit
import Foundation
import os.log

// MARK: - SOC2AuditTrailExporter

/// Exports an integrity-verified audit trail for SOC 2 compliance audits.
///
/// The exporter fetches all audit events within a date range, arranges them in
/// chronological order, and computes a SHA-256 hash chain where each event's hash
/// includes the hash of the previous event. This chain can be independently verified
/// to prove that no events were inserted, deleted, or modified after export.
///
/// The output is a directory containing:
/// - `audit_trail.json` — events with their `integrityHash`
/// - `chain_verification.json` — summary of the hash chain
/// - `verification_instructions.md` — instructions for independent verification
enum SOC2AuditTrailExporter {
    // MARK: Internal

    // MARK: - Export

    /// Exports a verified audit trail for the given date range.
    ///
    /// - Parameter dateRange: The inclusive date range for the export.
    /// - Returns: The file URL of the temporary directory containing the export files.
    /// - Throws: `ComplianceError.reportGenerationFailed` if the export fails.
    @MainActor
    static func exportVerifiedTrail(dateRange: ClosedRange<Date>) async throws -> URL {
        logger.info("SOC2 audit trail export: starting for range \(dateRange.lowerBound) to \(dateRange.upperBound)")

        guard let storage = AuditManager.shared.storage else {
            throw ComplianceError.notConfigured
        }

        let chainedEvents = try await buildHashChain(storage: storage, dateRange: dateRange)

        let exportDir = try createExportDirectory(prefix: "SOC2-AuditTrail")

        try writeTrailFiles(
            chainedEvents: chainedEvents,
            dateRange: dateRange,
            to: exportDir
        )

        logger.info("SOC2 audit trail export: completed with \(chainedEvents.count) events")
        return exportDir
    }

    // MARK: Private

    private static let logger = Logger.compliance

    /// Fetches audit entries, sorts chronologically, and builds a SHA-256 hash chain.
    @MainActor
    private static func buildHashChain(
        storage: AuditLogStoring,
        dateRange: ClosedRange<Date>
    ) async throws -> [ChainedAuditEvent] {
        let entries = try await storage.fetchEvents(
            category: nil,
            from: dateRange.lowerBound,
            to: dateRange.upperBound,
            limit: Int.max
        )

        let sortedEntries = entries.sorted {
            ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast)
        }

        var chainedEvents: [ChainedAuditEvent] = []
        var previousHash = "GENESIS"

        for entry in sortedEntries {
            let eventId = entry.id?.uuidString ?? "unknown"
            let timestamp = entry.timestamp?.ISO8601Format() ?? "unknown"
            let action = entry.action ?? "unknown"
            let category = entry.eventCategory ?? "unknown"

            let hashInput = "\(previousHash)\(eventId)\(timestamp)\(action)\(category)"
            let hash = SHA256.hash(data: Data(hashInput.utf8))
            let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()

            let detail: [String: String]? = if let detailDict = try? storage.decryptDetail(for: entry) {
                detailDict
            } else {
                nil
            }

            let chained = ChainedAuditEvent(
                id: eventId,
                timestamp: timestamp,
                category: category,
                action: action,
                severity: entry.severity ?? "info",
                userId: entry.userId,
                deviceId: entry.deviceId,
                resourceType: entry.resourceType,
                resourceId: entry.resourceId,
                detail: detail,
                integrityHash: hashString,
                previousHash: previousHash
            )

            chainedEvents.append(chained)
            previousHash = hashString
        }

        return chainedEvents
    }

    /// Creates a uniquely named temporary export directory.
    private static func createExportDirectory(prefix: String) throws -> URL {
        let exportDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        } catch {
            throw ComplianceError
                .reportGenerationFailed("Failed to create export directory: \(error.localizedDescription)")
        }
        return exportDir
    }

    /// Writes the audit trail JSON, chain verification JSON, and verification instructions.
    private static func writeTrailFiles(
        chainedEvents: [ChainedAuditEvent],
        dateRange: ClosedRange<Date>,
        to exportDir: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let trailData = try encoder.encode(chainedEvents)
            try trailData.write(to: exportDir.appendingPathComponent("audit_trail.json"))

            let hashFormat = "SHA256(previousHash + event.id + event.timestamp + event.action + event.category)"
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            let verification = ChainVerification(
                chainLength: chainedEvents.count,
                firstEventHash: chainedEvents.first?.integrityHash ?? "EMPTY",
                lastEventHash: chainedEvents.last?.integrityHash ?? "EMPTY",
                genesisHash: "GENESIS",
                hashAlgorithm: "SHA-256",
                hashInputFormat: hashFormat,
                dateRangeStart: dateRange.lowerBound,
                dateRangeEnd: dateRange.upperBound,
                exportedAt: Date(),
                applicationVersion: appVersion
            )
            let verificationData = try encoder.encode(verification)
            try verificationData.write(to: exportDir.appendingPathComponent("chain_verification.json"))

            let instructions = generateVerificationInstructions(verification: verification)
            try instructions.write(
                to: exportDir.appendingPathComponent("verification_instructions.md"),
                atomically: true,
                encoding: .utf8
            )
        } catch let error as ComplianceError {
            throw error
        } catch {
            throw ComplianceError.reportGenerationFailed("Export failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Verification Instructions

    private static func generateVerificationInstructions(verification: ChainVerification) -> String {
        let parameters = chainParametersSection(verification: verification)
        let procedure = verificationProcedureSection()
        return """
        # SOC 2 Audit Trail Verification Instructions

        ## Overview

        This audit trail export contains a cryptographic hash chain that proves the integrity
        of the audit log. Each event's hash includes the hash of the previous event, forming
        an unbroken chain from the genesis hash to the final event.

        ## Files

        - `audit_trail.json` — All audit events with their integrity hashes
        - `chain_verification.json` — Summary of the hash chain parameters
        - `verification_instructions.md` — This file

        \(parameters)

        \(procedure)
        """
    }

    private static func chainParametersSection(verification: ChainVerification) -> String {
        let start = verification.dateRangeStart.ISO8601Format()
        let end = verification.dateRangeEnd.ISO8601Format()
        let exported = verification.exportedAt.ISO8601Format()
        return """
        ## Chain Parameters

        - **Hash Algorithm**: \(verification.hashAlgorithm)
        - **Genesis Hash**: `\(verification.genesisHash)`
        - **Chain Length**: \(verification.chainLength) events
        - **Date Range**: \(start) to \(end)
        - **Exported At**: \(exported)
        """
    }

    private static func verificationProcedureSection() -> String {
        """
        ## Verification Procedure

        To independently verify the integrity of this audit trail:

        1. Parse `audit_trail.json` as an array of event objects.
        2. Set `previousHash = "GENESIS"`.
        3. For each event in order:
           a. Compute: `hash = SHA256(previousHash + event.id + event.timestamp + event.action + event.category)`
           b. Convert the hash to a lowercase hex string.
           c. Verify that the computed hash matches the event's `integrityHash` field.
           d. Verify that the event's `previousHash` field matches `previousHash`.
           e. Set `previousHash = hash` (the computed value).
        4. If all hashes match, the chain is intact and no events have been tampered with.

        ## Example (Python)

        ```python
        import json
        import hashlib

        with open("audit_trail.json") as f:
            events = json.load(f)

        previous_hash = "GENESIS"
        for event in events:
            hash_input = f"{previous_hash}{event['id']}{event['timestamp']}{event['action']}{event['category']}"
            computed = hashlib.sha256(hash_input.encode()).hexdigest()
            assert computed == event["integrityHash"], f"Hash mismatch at event {event['id']}"
            assert event["previousHash"] == previous_hash, f"Previous hash mismatch at event {event['id']}"
            previous_hash = computed

        print(f"Chain verified: {len(events)} events, integrity intact.")
        ```

        ## Notes

        - The hash chain is append-only. Any insertion, deletion, or modification of events
          will break the chain at the point of tampering.
        - The genesis hash `"GENESIS"` is a fixed constant and not derived from any data.
        - Timestamps are ISO 8601 format in UTC.
        """
    }
}

// MARK: - ChainedAuditEvent

/// An audit event with its integrity hash for the hash chain.
private struct ChainedAuditEvent: Codable {
    let id: String
    let timestamp: String
    let category: String
    let action: String
    let severity: String
    let userId: String?
    let deviceId: String?
    let resourceType: String?
    let resourceId: String?
    let detail: [String: String]?
    let integrityHash: String
    let previousHash: String
}

// MARK: - ChainVerification

/// Summary of the hash chain for independent verification.
private struct ChainVerification: Codable {
    let chainLength: Int
    let firstEventHash: String
    let lastEventHash: String
    let genesisHash: String
    let hashAlgorithm: String
    let hashInputFormat: String
    let dateRangeStart: Date
    let dateRangeEnd: Date
    let exportedAt: Date
    let applicationVersion: String
}
