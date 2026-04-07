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
    // MARK: Lifecycle

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

    // MARK: Internal

    let id: UUID
    let category: String
    let status: ComplianceFindingStatus
    let description: String
    let recommendation: String?
    let timestamp: Date
}

// MARK: - ComplianceReport

/// A compliance report containing findings and an overall status.
struct ComplianceReport: Codable, Sendable, Identifiable {
    // MARK: Lifecycle

    init(
        id: UUID = UUID(),
        reportType: String,
        findings: [ComplianceFinding],
        summary: String
    ) {
        self.id = id
        self.reportType = reportType
        self.findings = findings
        self.summary = summary
    }

    // MARK: Internal

    let id: UUID
    let reportType: String
    let findings: [ComplianceFinding]
    let summary: String

    /// The worst status among all findings. Returns `.pass` when there are no findings.
    var overallStatus: ComplianceFindingStatus {
        if findings.contains(where: { $0.status == .fail }) {
            return .fail
        }
        if findings.contains(where: { $0.status == .warning }) {
            return .warning
        }
        return .pass
    }
}
