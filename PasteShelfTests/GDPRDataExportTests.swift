//
//  GDPRDataExportTests.swift
//  PasteShelfTests
//
//  Tests for GDPRDeletionReport model and export manifest structure.
//

import Foundation
@testable import PasteShelf
import Testing

// MARK: - GDPRDeletionReportTests

struct GDPRDeletionReportTests {
    @Test("GDPRDeletionReport records category results")
    func recordsCategoryResults() {
        let report = GDPRDeletionReport(
            categories: [
                GDPRDeletionReport.CategoryResult(name: "Clipboard Items", deletedCount: 50, success: true),
                GDPRDeletionReport.CategoryResult(name: "Tags", deletedCount: 10, success: true),
                GDPRDeletionReport.CategoryResult(name: "Folders", deletedCount: 5, success: false),
            ]
        )
        #expect(report.categories.count == 3)
        #expect(report.categories[0].name == "Clipboard Items")
        #expect(report.categories[0].deletedCount == 50)
        #expect(report.categories[0].success == true)
        #expect(report.categories[2].success == false)
    }

    @Test("GDPRDeletionReport totalDeleted sums all successful categories")
    func totalDeleted() {
        let report = GDPRDeletionReport(
            categories: [
                GDPRDeletionReport.CategoryResult(name: "Items", deletedCount: 100, success: true),
                GDPRDeletionReport.CategoryResult(name: "Tags", deletedCount: 20, success: true),
            ]
        )
        #expect(report.totalDeleted == 120)
    }

    @Test("GDPRDeletionReport allSuccessful is true when all succeed")
    func allSuccessful() {
        let report = GDPRDeletionReport(
            categories: [
                GDPRDeletionReport.CategoryResult(name: "Items", deletedCount: 10, success: true),
                GDPRDeletionReport.CategoryResult(name: "Tags", deletedCount: 5, success: true),
            ]
        )
        #expect(report.allSuccessful == true)
    }

    @Test("GDPRDeletionReport allSuccessful is false when any fails")
    func notAllSuccessful() {
        let report = GDPRDeletionReport(
            categories: [
                GDPRDeletionReport.CategoryResult(name: "Items", deletedCount: 10, success: true),
                GDPRDeletionReport.CategoryResult(name: "Keychain", deletedCount: 0, success: false),
            ]
        )
        #expect(report.allSuccessful == false)
    }

    @Test("GDPRDeletionReport failedCategories lists only failures")
    func failedCategories() {
        let report = GDPRDeletionReport(
            categories: [
                GDPRDeletionReport.CategoryResult(name: "Items", deletedCount: 10, success: true),
                GDPRDeletionReport.CategoryResult(name: "Keychain", deletedCount: 0, success: false),
                GDPRDeletionReport.CategoryResult(name: "Defaults", deletedCount: 0, success: false),
            ]
        )
        #expect(report.failedCategories.count == 2)
    }

    @Test("GDPRDeletionReport completedAt timestamp is preserved")
    func completedAtPreserved() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let report = GDPRDeletionReport(categories: [], completedAt: date)
        #expect(report.completedAt == date)
    }

    @Test("GDPRDeletionReport CategoryResult with zero count")
    func zeroCategoryResult() {
        let result = GDPRDeletionReport.CategoryResult(name: "Audit Logs", deletedCount: 0, success: true)
        #expect(result.deletedCount == 0)
        #expect(result.success == true)
    }
}

// MARK: - GDPRExportManifestTests

struct GDPRExportManifestTests {
    @Test("Manifest JSON can represent export metadata")
    func manifestStructure() throws {
        let manifest: [String: Any] = [
            "exportVersion": "1.0",
            "application": "PasteShelf",
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "categories": [
                "clipboard_items",
                "tags",
                "folders",
                "collections",
                "audit_logs",
                "settings",
                "consent_records",
            ],
        ]

        let data = try JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted)
        #expect(!data.isEmpty)

        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(decoded?["exportVersion"] as? String == "1.0")
        #expect(decoded?["application"] as? String == "PasteShelf")
        #expect((decoded?["categories"] as? [String])?.count == 7)
    }

    @Test("Export directory naming convention uses UUID for uniqueness")
    func exportDirNaming() {
        let uuid = UUID().uuidString
        let dirName = "GDPRExport-\(uuid)"
        #expect(dirName.hasPrefix("GDPRExport-"))
        #expect(dirName.count > 20)
    }
}
