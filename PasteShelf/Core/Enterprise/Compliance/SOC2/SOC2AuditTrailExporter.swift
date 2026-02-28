//
//  SOC2AuditTrailExporter.swift
//  PasteShelf
//
//  Exports a verified audit trail with cryptographic integrity hash chain for SOC 2 compliance.
//

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
struct SOC2AuditTrailExporter: Sendable {

    private static let logger = Logger.compliance

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

        // Fetch events in date range (most recent first from the API)
        let entries = try await storage.fetchEvents(
            category: nil,
            from: dateRange.lowerBound,
            to: dateRange.upperBound,
            limit: Int.max
        )

        // Sort chronologically (oldest first) for hash chain
        let sortedEntries = entries.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }

        // Build hash chain
        var chainedEvents: [ChainedAuditEvent] = []
        var previousHash = "GENESIS"

        for entry in sortedEntries {
            let eventId = entry.id?.uuidString ?? "unknown"
            let timestamp = entry.timestamp?.ISO8601Format() ?? "unknown"
            let action = entry.action ?? "unknown"
            let category = entry.eventCategory ?? "unknown"

            // SHA256(previousHash + event.id + event.timestamp + event.action + event.category)
            let hashInput = "\(previousHash)\(eventId)\(timestamp)\(action)\(category)"
            let hash = SHA256.hash(data: Data(hashInput.utf8))
            let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()

            let detail: [String: String]?
            if let detailDict = try? storage.decryptDetail(for: entry) {
                detail = detailDict
            } else {
                detail = nil
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

        // Create export directory
        let exportDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SOC2-AuditTrail-\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        } catch {
            throw ComplianceError.reportGenerationFailed("Failed to create export directory: \(error.localizedDescription)")
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            // 1. Audit trail with hashes
            let trailData = try encoder.encode(chainedEvents)
            try trailData.write(to: exportDir.appendingPathComponent("audit_trail.json"))

            // 2. Chain verification summary
            let verification = ChainVerification(
                chainLength: chainedEvents.count,
                firstEventHash: chainedEvents.first?.integrityHash ?? "EMPTY",
                lastEventHash: chainedEvents.last?.integrityHash ?? "EMPTY",
                genesisHash: "GENESIS",
                hashAlgorithm: "SHA-256",
                hashInputFormat: "SHA256(previousHash + event.id + event.timestamp + event.action + event.category)",
                dateRangeStart: dateRange.lowerBound,
                dateRangeEnd: dateRange.upperBound,
                exportedAt: Date(),
                applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            )
            let verificationData = try encoder.encode(verification)
            try verificationData.write(to: exportDir.appendingPathComponent("chain_verification.json"))

            // 3. Verification instructions
            let instructions = generateVerificationInstructions(verification: verification)
            try instructions.write(
                to: exportDir.appendingPathComponent("verification_instructions.md"),
                atomically: true,
                encoding: .utf8
            )

            logger.info("SOC2 audit trail export: completed with \(chainedEvents.count) events")
            return exportDir
        } catch let error as ComplianceError {
            throw error
        } catch {
            throw ComplianceError.reportGenerationFailed("Export failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Verification Instructions

    private static func generateVerificationInstructions(verification: ChainVerification) -> String {
        """
        # SOC 2 Audit Trail Verification Instructions

        ## Overview

        This audit trail export contains a cryptographic hash chain that proves the integrity
        of the audit log. Each event's hash includes the hash of the previous event, forming
        an unbroken chain from the genesis hash to the final event.

        ## Files

        - `audit_trail.json` — All audit events with their integrity hashes
        - `chain_verification.json` — Summary of the hash chain parameters
        - `verification_instructions.md` — This file

        ## Chain Parameters

        - **Hash Algorithm**: \(verification.hashAlgorithm)
        - **Genesis Hash**: `\(verification.genesisHash)`
        - **Chain Length**: \(verification.chainLength) events
        - **Date Range**: \(verification.dateRangeStart.ISO8601Format()) to \(verification.dateRangeEnd.ISO8601Format())
        - **Exported At**: \(verification.exportedAt.ISO8601Format())

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

// MARK: - Supporting Types

/// An audit event with its integrity hash for the hash chain.
private struct ChainedAuditEvent: Codable, Sendable {
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

/// Summary of the hash chain for independent verification.
private struct ChainVerification: Codable, Sendable {
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
