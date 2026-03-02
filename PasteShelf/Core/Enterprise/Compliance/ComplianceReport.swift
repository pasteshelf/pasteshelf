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
