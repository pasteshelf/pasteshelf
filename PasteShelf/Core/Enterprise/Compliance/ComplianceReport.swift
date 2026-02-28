//
//  ComplianceReport.swift
//  PasteShelf
//
//  Shared types for compliance reporting across HIPAA, GDPR, SOC2.
//

import Foundation

// MARK: - ComplianceFindingStatus

/// Status of an individual compliance finding.
enum ComplianceFindingStatus: String, Codable, Sendable {
    case pass
    case fail
    case warning
}

// MARK: - ComplianceFinding

/// An individual finding in a compliance report.
struct ComplianceFinding: Codable, Sendable, Identifiable {
    let id: UUID
    let category: String
    let status: ComplianceFindingStatus
    let description: String
    let recommendation: String?
    let timestamp: Date

    init(
        id: UUID = UUID(),
        category: String,
        status: ComplianceFindingStatus,
        description: String,
        recommendation: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.status = status
        self.description = description
        self.recommendation = recommendation
        self.timestamp = timestamp
    }
}

// MARK: - ComplianceReport

/// Base compliance report model.
struct ComplianceReport: Codable, Sendable, Identifiable {
    let id: UUID
    let reportType: String
    let generatedAt: Date
    let findings: [ComplianceFinding]
    let overallStatus: ComplianceFindingStatus
    let summary: String

    init(
        id: UUID = UUID(),
        reportType: String,
        generatedAt: Date = Date(),
        findings: [ComplianceFinding],
        summary: String
    ) {
        self.id = id
        self.reportType = reportType
        self.generatedAt = generatedAt
        self.findings = findings
        self.summary = summary

        // Overall status is the worst-case finding
        if findings.contains(where: { $0.status == .fail }) {
            self.overallStatus = .fail
        } else if findings.contains(where: { $0.status == .warning }) {
            self.overallStatus = .warning
        } else {
            self.overallStatus = .pass
        }
    }
}
