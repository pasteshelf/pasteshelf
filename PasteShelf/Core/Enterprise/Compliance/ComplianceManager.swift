//
//  ComplianceManager.swift
//  PasteShelf
//
//  Central orchestrator for the compliance subsystem.
//

import Combine
import Foundation
import os.log

// MARK: - ComplianceManager

/// Central manager for the compliance subsystem.
///
/// `ComplianceManager` orchestrates HIPAA, GDPR, and SOC 2 compliance operations
/// behind a single entry point. It follows the same `@MainActor` singleton pattern
/// as `AuditManager` and `AdminManager`.
///
/// When enabled, it:
/// - Configures HIPAA access control (biometric lock, session timeout)
/// - Makes the GDPR consent manager available
/// - Exposes `isEnabled` for downstream services to consult
@MainActor
final class ComplianceManager: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    private init() {}

    // MARK: Internal

    // MARK: - Singleton

    /// The shared application-wide `ComplianceManager` instance.
    static let shared = ComplianceManager()

    // MARK: - Published State

    /// Whether the compliance subsystem has been configured and is active.
    @Published private(set) var isEnabled: Bool = false

    /// Whether HIPAA compliance mode is currently active.
    @Published private(set) var isHIPAAActive: Bool = false

    /// Whether GDPR consent management is active.
    @Published private(set) var isGDPRActive: Bool = false

    /// Whether SOC 2 compliance features are active.
    @Published private(set) var isSOC2Active: Bool = false

    /// The most recent error encountered by the compliance subsystem, if any.
    @Published var lastError: ComplianceError?

    // MARK: - Configuration

    /// Configures the compliance manager and initializes sub-frameworks.
    ///
    /// Call this once during app startup. Individual frameworks (HIPAA, GDPR, SOC2)
    /// have their own enable toggles; this method sets up their initial state.
    func configure() {
        isEnabled = true

        // Load HIPAA mode: active if either enterprise settings or local config is enabled
        let hipaaMode = HIPAAComplianceMode.load()
        let enterpriseSettings = SettingsManager.shared.enterprise
        isHIPAAActive = hipaaMode.isEnabled || enterpriseSettings.hipaaEnabled
        if isHIPAAActive {
            HIPAAAccessControlService.shared.configure()
        }

        // GDPR and SOC2 are gated by enterprise settings
        isGDPRActive = enterpriseSettings.gdprEnabled
        isSOC2Active = enterpriseSettings.soc2Enabled

        logger.info("ComplianceManager configured (HIPAA=\(isHIPAAActive), GDPR=\(isGDPRActive), SOC2=\(isSOC2Active))")
    }

    /// Disables the compliance subsystem.
    func disable() {
        isEnabled = false
        isHIPAAActive = false
        isGDPRActive = false
        isSOC2Active = false
        logger.info("ComplianceManager disabled")
    }

    /// Refreshes GDPR and SOC2 state from current enterprise settings.
    func refreshComplianceSettings() {
        let enterpriseSettings = SettingsManager.shared.enterprise
        isGDPRActive = enterpriseSettings.gdprEnabled
        isSOC2Active = enterpriseSettings.soc2Enabled
        logger.debug("Compliance settings refreshed: GDPR=\(isGDPRActive), SOC2=\(isSOC2Active)")
    }

    /// Refreshes HIPAA state after configuration changes.
    func refreshHIPAAState() {
        let hipaaMode = HIPAAComplianceMode.load()
        let enterpriseSettings = SettingsManager.shared.enterprise
        isHIPAAActive = hipaaMode.isEnabled || enterpriseSettings.hipaaEnabled
        if isHIPAAActive {
            HIPAAAccessControlService.shared.configure()
        }
        logger.debug("HIPAA state refreshed: \(isHIPAAActive)")
    }

    // MARK: Private

    // MARK: - Dependencies

    private let logger = Logger.compliance
}
