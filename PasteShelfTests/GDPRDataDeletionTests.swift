//
//  GDPRDataDeletionTests.swift
//  PasteShelfTests
//
//  Tests for GDPRDeletionReport model and deletion service contract.
//

import Foundation
@testable import PasteShelf
import Testing

// MARK: - GDPRDeletionCategoryResultTests

struct GDPRDeletionCategoryResultTests {
    @Test("CategoryResult preserves all values")
    func preservesValues() {
        let result = GDPRDeletionReport.CategoryResult(
            name: "Clipboard Items",
            deletedCount: 42,
            success: true
        )
        #expect(result.name == "Clipboard Items")
        #expect(result.deletedCount == 42)
        #expect(result.success == true)
    }

    @Test("CategoryResult with failure status")
    func failureStatus() {
        let result = GDPRDeletionReport.CategoryResult(
            name: "Audit Logs",
            deletedCount: 0,
            success: false
        )
        #expect(result.success == false)
    }

    @Test("CategoryResult with large count")
    func largeCount() {
        let result = GDPRDeletionReport.CategoryResult(
            name: "Items",
            deletedCount: 1_000_000,
            success: true
        )
        #expect(result.deletedCount == 1_000_000)
    }

    @Test("CategoryResult default id is unique")
    func uniqueIds() {
        let result1 = GDPRDeletionReport.CategoryResult(name: "A", deletedCount: 1, success: true)
        let result2 = GDPRDeletionReport.CategoryResult(name: "A", deletedCount: 1, success: true)
        #expect(result1.id != result2.id)
    }

    @Test("CategoryResult survives Codable round-trip")
    func codableRoundTrip() throws {
        let original = GDPRDeletionReport.CategoryResult(name: "Items", deletedCount: 50, success: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GDPRDeletionReport.CategoryResult.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.deletedCount == original.deletedCount)
        #expect(decoded.success == original.success)
    }
}

// MARK: - GDPRDeletionReportStructTests

struct GDPRDeletionReportStructTests {
    @Test("Report with all successful deletions")
    func allSuccess() {
        let results = [
            GDPRDeletionReport.CategoryResult(name: "Items", deletedCount: 100, success: true),
            GDPRDeletionReport.CategoryResult(name: "Tags", deletedCount: 20, success: true),
            GDPRDeletionReport.CategoryResult(name: "Folders", deletedCount: 5, success: true),
        ]
        let report = GDPRDeletionReport(categories: results)
        #expect(report.allSuccessful)
    }

    @Test("Report with partial failures")
    func partialFailures() {
        let results = [
            GDPRDeletionReport.CategoryResult(name: "Items", deletedCount: 100, success: true),
            GDPRDeletionReport.CategoryResult(name: "Keychain", deletedCount: 0, success: false),
        ]
        let report = GDPRDeletionReport(categories: results)
        #expect(!report.allSuccessful)
        #expect(report.failedCategories.count == 1)
    }

    @Test("Report with empty category results")
    func emptyResults() {
        let report = GDPRDeletionReport(categories: [])
        #expect(report.categories.isEmpty)
        #expect(report.totalDeleted == 0)
        #expect(report.allSuccessful)
    }

    @Test("Report total deleted items sums correctly")
    func totalDeletedItems() {
        let results = [
            GDPRDeletionReport.CategoryResult(name: "Items", deletedCount: 100, success: true),
            GDPRDeletionReport.CategoryResult(name: "Tags", deletedCount: 20, success: true),
            GDPRDeletionReport.CategoryResult(name: "Folders", deletedCount: 5, success: true),
        ]
        let report = GDPRDeletionReport(categories: results)
        #expect(report.totalDeleted == 125)
    }

    @Test("Report preserves completedAt timestamp")
    func preservesTimestamp() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let report = GDPRDeletionReport(categories: [], completedAt: date)
        #expect(report.completedAt == date)
    }

    @Test("Report can represent all GDPR deletion categories")
    func allGDPRCategories() {
        let categories = [
            "Clipboard Items", "Tags", "Folders", "Collections",
            "Embeddings", "OCR Cache", "Consent Records",
            "Audit Logs", "Keychain Items", "User Defaults",
        ]
        let results = categories.map {
            GDPRDeletionReport.CategoryResult(name: $0, deletedCount: 1, success: true)
        }
        let report = GDPRDeletionReport(categories: results)
        #expect(report.categories.count == 10)
    }

    @Test("Report default id is unique")
    func uniqueId() {
        let report1 = GDPRDeletionReport(categories: [])
        let report2 = GDPRDeletionReport(categories: [])
        #expect(report1.id != report2.id)
    }

    @Test("Report survives Codable round-trip")
    func codableRoundTrip() throws {
        let original = GDPRDeletionReport(
            categories: [
                GDPRDeletionReport.CategoryResult(name: "Items", deletedCount: 50, success: true),
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(GDPRDeletionReport.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.totalDeleted == 50)
        #expect(decoded.allSuccessful)
    }
}

// MARK: - GDPRDeletionErrorTests

struct GDPRDeletionErrorTests {
    // MARK: Internal

    @Test("ComplianceError.deletionFailed wraps underlying error")
    func deletionFailedCapturesReason() {
        let underlying = TestError(message: "CoreData save failed")
        let error = ComplianceError.deletionFailed(underlying: underlying)
        if case let .deletionFailed(wrapped) = error {
            #expect(wrapped.localizedDescription == "CoreData save failed")
        } else {
            Issue.record("Expected deletionFailed case")
        }
    }

    @Test("ComplianceError.notConfigured is distinct from other errors")
    func notConfiguredDistinct() {
        let error = ComplianceError.notConfigured
        if case .notConfigured = error {
            // Expected
        } else {
            Issue.record("Expected notConfigured case")
        }
    }

    // MARK: Private

    private struct TestError: Error, LocalizedError {
        let message: String

        var errorDescription: String? {
            message
        }
    }
}
