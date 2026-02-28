//
//  ComplianceSettingsViewModel.swift
//  PasteShelf
//
//  Shared ViewModel for HIPAA, GDPR, and SOC 2 compliance settings views.
//

import Combine
import Foundation
import os.log

// MARK: - ComplianceSettingsViewModel

/// Shared view model for the compliance settings tab.
///
/// Provides state and actions for HIPAA configuration, encryption verification,
/// SOC 2 report generation, and audit trail export. Consumed by `HIPAASettingsView`,
/// `GDPRSettingsView`, and `SOC2SettingsView`.
@MainActor
final class ComplianceSettingsViewModel: ObservableObject {

    // MARK: - HIPAA State

    @Published var hipaaConfig = HIPAAComplianceMode.default
    @Published var isHIPAARetentionCompliant = false
    @Published var encryptionReport: HIPAAEncryptionReport?

    // MARK: - SOC 2 State

    @Published var soc2Report: SOC2SecurityControlsReport.Report?

    // MARK: - Loading State

    @Published var isVerifying = false
    @Published var isGenerating = false
    @Published var isExporting = false
    @Published var lastError: ComplianceError?

    private let logger = Logger.compliance

    // MARK: - Configuration

    /// Loads the current HIPAA configuration and validates retention compliance.
    func loadConfiguration() {
        hipaaConfig = HIPAAComplianceMode.load()

        let retentionConfig = AuditManager.shared.retentionConfiguration
        isHIPAARetentionCompliant = HIPAARetentionPolicy.isCompliant(retentionConfig)
    }

    /// Saves the current HIPAA configuration and reconfigures access controls.
    func saveHIPAAConfig() {
        hipaaConfig.save()
        HIPAAAccessControlService.shared.configure()
        logger.info("HIPAA configuration saved")
    }

    // MARK: - Encryption Verification

    /// Runs HIPAA encryption verification and updates the report.
    func verifyEncryption() async {
        isVerifying = true
        defer { isVerifying = false }

        encryptionReport = await HIPAAEncryptionVerifier.verify()
        logger.info("Encryption verification complete")
    }

    // MARK: - SOC 2 Report

    /// Generates a SOC 2 security controls report.
    func generateSOC2Report() {
        isGenerating = true
        defer { isGenerating = false }

        soc2Report = SOC2SecurityControlsReport.generateReport()
        logger.info("SOC 2 report generated")
    }

    // MARK: - Audit Trail Export

    /// Exports a verified audit trail for the given date range.
    ///
    /// - Parameter dateRange: The date range to export.
    /// - Returns: The URL of the export directory, or nil on failure.
    func exportAuditTrail(dateRange: ClosedRange<Date>) async -> URL? {
        isExporting = true
        defer { isExporting = false }

        do {
            let url = try await SOC2AuditTrailExporter.exportVerifiedTrail(dateRange: dateRange)
            logger.info("Audit trail exported to \(url.lastPathComponent)")
            return url
        } catch let error as ComplianceError {
            lastError = error
            return nil
        } catch {
            lastError = .reportGenerationFailed(error.localizedDescription)
            return nil
        }
    }
}
