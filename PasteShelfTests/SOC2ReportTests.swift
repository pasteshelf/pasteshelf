//
//  SOC2ReportTests.swift
//  PasteShelfTests
//
//  Tests for SOC2SecurityControlsReport model types and structure.
//

import Foundation
@testable import PasteShelf
import Testing

// MARK: - SOC2SecurityControlTests

struct SOC2SecurityControlTests {
    @Test("SecurityControl preserves all provided values")
    func preservesValues() {
        let id = UUID()
        let control = SOC2SecurityControlsReport.SecurityControl(
            id: id,
            name: "TLS Encryption",
            description: "All traffic uses TLS 1.2+",
            status: .pass,
            evidence: "ATS enforced",
            recommendation: nil
        )
        #expect(control.id == id)
        #expect(control.name == "TLS Encryption")
        #expect(control.description == "All traffic uses TLS 1.2+")
        #expect(control.status == .pass)
        #expect(control.evidence == "ATS enforced")
        #expect(control.recommendation == nil)
    }

    @Test("SecurityControl default id is unique")
    func defaultIdUnique() {
        let control1 = SOC2SecurityControlsReport.SecurityControl(
            name: "A", description: "d", status: .pass, evidence: "e"
        )
        let control2 = SOC2SecurityControlsReport.SecurityControl(
            name: "A", description: "d", status: .pass, evidence: "e"
        )
        #expect(control1.id != control2.id)
    }

    @Test("SecurityControl with recommendation preserves it")
    func preservesRecommendation() {
        let control = SOC2SecurityControlsReport.SecurityControl(
            name: "SSO",
            description: "Enterprise SSO",
            status: .warning,
            evidence: "Not configured",
            recommendation: "Enable SSO in settings"
        )
        #expect(control.recommendation == "Enable SSO in settings")
    }

    @Test("SecurityControl survives Codable round-trip")
    func codableRoundTrip() throws {
        let original = SOC2SecurityControlsReport.SecurityControl(
            name: "Encryption",
            description: "AES-256",
            status: .pass,
            evidence: "CryptoKit",
            recommendation: nil
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SOC2SecurityControlsReport.SecurityControl.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.status == original.status)
    }
}

// MARK: - SOC2ControlCategoryTests

struct SOC2ControlCategoryTests {
    @Test("ControlCategory preserves all values")
    func preservesValues() {
        let controls = [
            SOC2SecurityControlsReport.SecurityControl(
                name: "TLS", description: "TLS 1.2+", status: .pass, evidence: "ATS"
            ),
        ]
        let category = SOC2SecurityControlsReport.ControlCategory(
            name: "Network",
            description: "Network security controls",
            controls: controls
        )
        #expect(category.name == "Network")
        #expect(category.description == "Network security controls")
        #expect(category.controls.count == 1)
    }

    @Test("ControlCategory default id is unique")
    func defaultIdUnique() {
        let category1 = SOC2SecurityControlsReport.ControlCategory(name: "A", description: "d", controls: [])
        let category2 = SOC2SecurityControlsReport.ControlCategory(name: "A", description: "d", controls: [])
        #expect(category1.id != category2.id)
    }

    @Test("ControlCategory survives Codable round-trip")
    func codableRoundTrip() throws {
        let controls = [
            SOC2SecurityControlsReport.SecurityControl(
                name: "Audit", description: "Logging", status: .pass, evidence: "AuditManager"
            ),
        ]
        let original = SOC2SecurityControlsReport.ControlCategory(
            name: "Monitoring",
            description: "Activity monitoring",
            controls: controls
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SOC2SecurityControlsReport.ControlCategory.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.controls.count == 1)
    }
}

// MARK: - SOC2ReportModelTests

struct SOC2ReportModelTests {
    @Test("Report preserves all values")
    func preservesValues() {
        let controls = [
            SOC2SecurityControlsReport.SecurityControl(
                name: "TLS", description: "TLS 1.2+", status: .pass, evidence: "ATS"
            ),
        ]
        let categories = [
            SOC2SecurityControlsReport.ControlCategory(
                name: "Network",
                description: "Network security",
                controls: controls
            ),
        ]
        let report = SOC2SecurityControlsReport.Report(
            applicationVersion: "2.1.0",
            categories: categories,
            overallScore: 100,
            summary: "All controls passing"
        )
        #expect(report.applicationVersion == "2.1.0")
        #expect(report.categories.count == 1)
        #expect(report.overallScore == 100)
        #expect(report.summary == "All controls passing")
    }

    @Test("Report score is 100 when all controls pass")
    func scoreAllPass() {
        let controls = [
            SOC2SecurityControlsReport.SecurityControl(name: "A", description: "d", status: .pass, evidence: "e"),
            SOC2SecurityControlsReport.SecurityControl(name: "B", description: "d", status: .pass, evidence: "e"),
        ]
        let category = SOC2SecurityControlsReport.ControlCategory(name: "C", description: "d", controls: controls)
        let allControls = category.controls
        let passCount = allControls.filter { $0.status == .pass }.count
        let score = !allControls.isEmpty ? (passCount * 100) / allControls.count : 0
        #expect(score == 100)
    }

    @Test("Report score is 0 when no controls pass")
    func scoreNoPass() {
        let controls = [
            SOC2SecurityControlsReport.SecurityControl(name: "A", description: "d", status: .fail, evidence: "e"),
            SOC2SecurityControlsReport.SecurityControl(name: "B", description: "d", status: .warning, evidence: "e"),
        ]
        let category = SOC2SecurityControlsReport.ControlCategory(name: "C", description: "d", controls: controls)
        let allControls = category.controls
        let passCount = allControls.filter { $0.status == .pass }.count
        let score = !allControls.isEmpty ? (passCount * 100) / allControls.count : 0
        #expect(score == 0)
    }

    @Test("Report score is 50 when half controls pass")
    func scoreHalfPass() {
        let controls = [
            SOC2SecurityControlsReport.SecurityControl(name: "A", description: "d", status: .pass, evidence: "e"),
            SOC2SecurityControlsReport.SecurityControl(name: "B", description: "d", status: .fail, evidence: "e"),
        ]
        let allControls = controls
        let passCount = allControls.filter { $0.status == .pass }.count
        let score = !allControls.isEmpty ? (passCount * 100) / allControls.count : 0
        #expect(score == 50)
    }

    @Test("Report survives Codable round-trip")
    func codableRoundTrip() throws {
        let controls = [
            SOC2SecurityControlsReport.SecurityControl(
                name: "E2E", description: "Encryption", status: .pass, evidence: "CryptoKit"
            ),
        ]
        let categories = [
            SOC2SecurityControlsReport.ControlCategory(
                name: "Encryption",
                description: "Crypto controls",
                controls: controls
            ),
        ]
        let original = SOC2SecurityControlsReport.Report(
            applicationVersion: "2.1.0",
            categories: categories,
            overallScore: 100,
            summary: "All good"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SOC2SecurityControlsReport.Report.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.overallScore == original.overallScore)
        #expect(decoded.categories.count == 1)
    }

    @Test("Report exportAsJSON produces valid JSON")
    func exportAsJSON() throws {
        let report = SOC2SecurityControlsReport.Report(
            applicationVersion: "2.1.0",
            categories: [],
            overallScore: 0,
            summary: "Empty report"
        )
        let data = try SOC2SecurityControlsReport.exportAsJSON(report)
        #expect(!data.isEmpty)

        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json != nil)
        #expect(json?["overallScore"] as? Int == 0)
    }
}
