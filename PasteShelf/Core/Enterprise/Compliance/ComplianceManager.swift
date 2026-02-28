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
@MainActor
final class ComplianceManager: ObservableObject {

    // MARK: - Singleton

    /// The shared application-wide `ComplianceManager` instance.
    static let shared = ComplianceManager()

    // MARK: - Published State

    /// Whether the compliance subsystem has been configured and is active.
    @Published private(set) var isEnabled: Bool = false

    /// The most recent error encountered by the compliance subsystem, if any.
    @Published var lastError: ComplianceError?

    // MARK: - Dependencies

    private let logger = Logger.compliance

    // MARK: - Initialization

    private init() {}

    // MARK: - Configuration

    /// Configures the compliance manager. Call after LicenseManager is available.
    func configure() {
        guard LicenseManager.shared.isFeatureAvailable(.complianceTools) else {
            isEnabled = false
            logger.info("Compliance tools unavailable — enterprise license required")
            return
        }
        isEnabled = true
        logger.info("ComplianceManager configured and enabled")
    }
}
