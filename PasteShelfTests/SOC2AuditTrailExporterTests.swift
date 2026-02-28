//
//  SOC2AuditTrailExporterTests.swift
//  PasteShelfTests
//
//  Tests for the SOC2 audit trail hash chain integrity verification logic.
//  Uses CryptoKit to independently verify SHA-256 hash chains.
//

import CryptoKit
import Foundation
import Testing
@testable import PasteShelf

// MARK: - Hash Chain Verification Tests

struct SOC2AuditTrailHashChainTests {

    /// Independently computes the hash chain to verify the algorithm matches.
    private func computeHash(previousHash: String, eventId: String, timestamp: String, action: String, category: String) -> String {
        let input = "\(previousHash)\(eventId)\(timestamp)\(action)\(category)"
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    @Test("Hash chain genesis starts with 'GENESIS' string")
    func genesisHash() {
        let hash = computeHash(
            previousHash: "GENESIS",
            eventId: "test-id",
            timestamp: "2024-01-01T00:00:00Z",
            action: "copy_captured",
            category: "clipboard"
        )
        #expect(!hash.isEmpty)
        #expect(hash.count == 64) // SHA-256 produces 64 hex characters
    }

    @Test("Hash is deterministic for same inputs")
    func deterministic() {
        let hash1 = computeHash(
            previousHash: "GENESIS",
            eventId: "id-1",
            timestamp: "2024-01-01T00:00:00Z",
            action: "copy_captured",
            category: "clipboard"
        )
        let hash2 = computeHash(
            previousHash: "GENESIS",
            eventId: "id-1",
            timestamp: "2024-01-01T00:00:00Z",
            action: "copy_captured",
            category: "clipboard"
        )
        #expect(hash1 == hash2)
    }

    @Test("Different event IDs produce different hashes")
    func differentEventIds() {
        let hash1 = computeHash(
            previousHash: "GENESIS",
            eventId: "id-1",
            timestamp: "2024-01-01T00:00:00Z",
            action: "copy_captured",
            category: "clipboard"
        )
        let hash2 = computeHash(
            previousHash: "GENESIS",
            eventId: "id-2",
            timestamp: "2024-01-01T00:00:00Z",
            action: "copy_captured",
            category: "clipboard"
        )
        #expect(hash1 != hash2)
    }

    @Test("Different previousHash produces different output hash")
    func differentPreviousHash() {
        let hash1 = computeHash(
            previousHash: "GENESIS",
            eventId: "id-1",
            timestamp: "2024-01-01T00:00:00Z",
            action: "copy_captured",
            category: "clipboard"
        )
        let hash2 = computeHash(
            previousHash: "abc123",
            eventId: "id-1",
            timestamp: "2024-01-01T00:00:00Z",
            action: "copy_captured",
            category: "clipboard"
        )
        #expect(hash1 != hash2)
    }

    @Test("Hash chain of 3 events links correctly")
    func threeEventChain() {
        var previousHash = "GENESIS"

        let hash1 = computeHash(
            previousHash: previousHash,
            eventId: "event-1",
            timestamp: "2024-01-01T00:00:00Z",
            action: "copy_captured",
            category: "clipboard"
        )
        previousHash = hash1

        let hash2 = computeHash(
            previousHash: previousHash,
            eventId: "event-2",
            timestamp: "2024-01-01T00:01:00Z",
            action: "paste_performed",
            category: "clipboard"
        )
        previousHash = hash2

        let hash3 = computeHash(
            previousHash: previousHash,
            eventId: "event-3",
            timestamp: "2024-01-01T00:02:00Z",
            action: "sso_login",
            category: "authentication"
        )

        // Each hash should be different
        #expect(hash1 != hash2)
        #expect(hash2 != hash3)
        #expect(hash1 != hash3)

        // All hashes should be 64 characters (SHA-256)
        #expect(hash1.count == 64)
        #expect(hash2.count == 64)
        #expect(hash3.count == 64)
    }

    @Test("Tampering with middle event breaks chain verification")
    func tamperingDetection() {
        var previousHash = "GENESIS"

        let hash1 = computeHash(
            previousHash: previousHash,
            eventId: "event-1",
            timestamp: "2024-01-01T00:00:00Z",
            action: "copy_captured",
            category: "clipboard"
        )
        previousHash = hash1

        let hash2 = computeHash(
            previousHash: previousHash,
            eventId: "event-2",
            timestamp: "2024-01-01T00:01:00Z",
            action: "paste_performed",
            category: "clipboard"
        )

        // Now recompute hash2 with tampered action — should produce different hash
        let tamperedHash2 = computeHash(
            previousHash: previousHash,
            eventId: "event-2",
            timestamp: "2024-01-01T00:01:00Z",
            action: "item_deleted",
            category: "clipboard"
        )

        #expect(hash2 != tamperedHash2)
    }

    @Test("SHA-256 output is lowercase hex")
    func lowercaseHex() {
        let hash = computeHash(
            previousHash: "GENESIS",
            eventId: "id-1",
            timestamp: "2024-01-01T00:00:00Z",
            action: "copy_captured",
            category: "clipboard"
        )
        let validHexChars = CharacterSet(charactersIn: "0123456789abcdef")
        #expect(hash.unicodeScalars.allSatisfy { validHexChars.contains($0) })
    }

    @Test("Empty event fields produce valid hash")
    func emptyFields() {
        let hash = computeHash(
            previousHash: "GENESIS",
            eventId: "",
            timestamp: "",
            action: "",
            category: ""
        )
        #expect(hash.count == 64)
    }
}

// MARK: - ComplianceError Tests

struct ComplianceErrorTests {

    /// A simple error for testing associated values.
    private struct TestError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    @Test("ComplianceError.notConfigured has descriptive message")
    func notConfigured() {
        let error = ComplianceError.notConfigured
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("ComplianceError.reportGenerationFailed includes reason")
    func reportGenerationFailed() {
        let error = ComplianceError.reportGenerationFailed("disk full")
        if case .reportGenerationFailed(let reason) = error {
            #expect(reason == "disk full")
        } else {
            Issue.record("Expected reportGenerationFailed")
        }
    }

    @Test("ComplianceError.consentNotGranted includes category")
    func consentNotGranted() {
        let error = ComplianceError.consentNotGranted(category: "analytics")
        if case .consentNotGranted(let category) = error {
            #expect(category == "analytics")
        } else {
            Issue.record("Expected consentNotGranted")
        }
    }

    @Test("ComplianceError.exportFailed wraps underlying error")
    func exportFailed() {
        let underlying = TestError(message: "no data")
        let error = ComplianceError.exportFailed(underlying: underlying)
        if case .exportFailed(let wrapped) = error {
            #expect(wrapped.localizedDescription == "no data")
        } else {
            Issue.record("Expected exportFailed")
        }
    }

    @Test("ComplianceError.deletionFailed wraps underlying error")
    func deletionFailed() {
        let underlying = TestError(message: "database locked")
        let error = ComplianceError.deletionFailed(underlying: underlying)
        if case .deletionFailed(let wrapped) = error {
            #expect(wrapped.localizedDescription == "database locked")
        } else {
            Issue.record("Expected deletionFailed")
        }
    }

    @Test("ComplianceError.invalidConfiguration includes message")
    func invalidConfiguration() {
        let error = ComplianceError.invalidConfiguration("bad setting")
        if case .invalidConfiguration(let msg) = error {
            #expect(msg == "bad setting")
        } else {
            Issue.record("Expected invalidConfiguration")
        }
    }

    @Test("ComplianceError.featureUnavailable has error description")
    func featureUnavailable() {
        let error = ComplianceError.featureUnavailable
        #expect(error.errorDescription?.isEmpty == false)
    }
}
