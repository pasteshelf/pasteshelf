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

    // MARK: - Singleton

    /// The shared application-wide `ComplianceManager` instance.
    static let shared = ComplianceManager()

    // MARK: - Published State

    /// Whether the compliance subsystem has been configured and is active.
    @Published private(set) var isEnabled: Bool = false

    /// Whether HIPAA compliance mode is currently active.
    @Published private(set) var isHIPAAActive: Bool = false

    /// Whether GDPR consent management is active.
    @Published private(set) var isGDPRActive: Bool = true

    /// The most recent error encountered by the compliance subsystem, if any.
    @Published var lastError: ComplianceError?

    // MARK: - Dependencies

    private let logger = Logger.compliance

    // MARK: - Initialization

    private init() {}

    // MARK: - Configuration

    /// Configures the compliance manager and initializes sub-frameworks.
    ///
    /// Call this once during app startup. Individual frameworks (HIPAA, GDPR, SOC2)
    /// have their own enable toggles; this method sets up their initial state.
    func configure() {
        isEnabled = true

        // Load HIPAA mode and configure access control if enabled
        let hipaaMode = HIPAAComplianceMode.load()
        isHIPAAActive = hipaaMode.isEnabled
        if hipaaMode.isEnabled {
            HIPAAAccessControlService.shared.configure()
        }

        // GDPR consent manager is always available (opt-in consent model)
        isGDPRActive = true

        logger.info("ComplianceManager configured (HIPAA=\(hipaaMode.isEnabled), GDPR=active)")
    }

    /// Disables the compliance subsystem.
    func disable() {
        isEnabled = false
        isHIPAAActive = false
        logger.info("ComplianceManager disabled")
    }

    /// Refreshes HIPAA state after configuration changes.
    func refreshHIPAAState() {
        let hipaaMode = HIPAAComplianceMode.load()
        isHIPAAActive = hipaaMode.isEnabled
        if hipaaMode.isEnabled {
            HIPAAAccessControlService.shared.configure()
        }
        logger.debug("HIPAA state refreshed: \(hipaaMode.isEnabled)")
    }
}
