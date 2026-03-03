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
    @Published var soc2EncryptionReport: SOC2EncryptionReport?

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
        guard ComplianceManager.shared.isSOC2Active else {
            logger.info("SOC 2 report generation skipped — SOC 2 not active")
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        soc2Report = SOC2SecurityControlsReport.generateReport()
        logger.info("SOC 2 report generated")
    }

    /// Runs SOC 2 encryption verification across all data-protection layers.
    func verifySOC2Encryption() async {
        guard ComplianceManager.shared.isSOC2Active else {
            logger.info("SOC 2 encryption verification skipped — SOC 2 not active")
            return
        }

        isVerifying = true
        defer { isVerifying = false }

        soc2EncryptionReport = await SOC2EncryptionVerifier.verify()
        logger.info("SOC 2 encryption verification complete")
    }

    /// Exports SOC 2 access control evidence for the given date range.
    ///
    /// - Parameter dateRange: The date range to export evidence for.
    /// - Returns: The URL of the evidence directory, or nil on failure.
    func exportAccessControlEvidence(dateRange: ClosedRange<Date>) async -> URL? {
        guard ComplianceManager.shared.isSOC2Active else {
            logger.info("SOC 2 access control evidence export skipped — SOC 2 not active")
            return nil
        }

        isExporting = true
        defer { isExporting = false }

        do {
            let url = try await SOC2AccessControlEvidence.exportEvidencePackage(dateRange: dateRange)
            logger.info("SOC 2 access control evidence exported to \(url.lastPathComponent)")
            return url
        } catch {
            lastError = .reportGenerationFailed(error.localizedDescription)
            return nil
        }
    }

    // MARK: - GDPR Data Rights

    /// Whether a GDPR data export is in progress.
    @Published var isGDPRExporting = false

    /// Whether a GDPR data deletion is in progress.
    @Published var isGDPRDeleting = false

    /// Progress of the current GDPR data export (0.0–1.0).
    @Published var gdprExportProgress: Double = 0

    /// Exports all user data in a portable format (GDPR Article 20).
    ///
    /// - Returns: The URL of the export directory, or nil on failure.
    func exportGDPRData() async -> URL? {
        isGDPRExporting = true
        defer { isGDPRExporting = false }

        do {
            let url = try await GDPRDataExportService.exportUserData { [weak self] progress in
                self?.gdprExportProgress = progress
            }
            logger.info("GDPR data exported to \(url.lastPathComponent)")
            return url
        } catch {
            lastError = error as? ComplianceError
            return nil
        }
    }

    /// Permanently deletes all user data (GDPR Article 17).
    ///
    /// - Returns: `true` if deletion succeeded.
    @discardableResult
    func deleteAllGDPRData() async -> Bool {
        isGDPRDeleting = true
        defer { isGDPRDeleting = false }

        do {
            _ = try await GDPRDataDeletionService.deleteAllUserData()
            logger.info("GDPR data deletion completed")
            return true
        } catch {
            lastError = error as? ComplianceError
            return false
        }
    }

    // MARK: - Audit Trail Export

    /// Exports a verified audit trail for the given date range.
    ///
    /// - Parameter dateRange: The date range to export.
    /// - Returns: The URL of the export directory, or nil on failure.
    func exportAuditTrail(dateRange: ClosedRange<Date>) async -> URL? {
        guard ComplianceManager.shared.isSOC2Active else {
            logger.info("Audit trail export skipped — SOC 2 not active")
            return nil
        }

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
