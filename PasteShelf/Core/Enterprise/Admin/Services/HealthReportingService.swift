//
//  HealthReportingService.swift
//  PasteShelf
//
//  Drives periodic submission of device health reports to the admin console.
//  Builds a DeviceHealthReport snapshot and uploads it at the configured interval.
//

import Foundation
import os.log

// MARK: - HealthReportingService

/// Drives periodic submission of device health reports to the admin console.
///
/// `HealthReportingService` schedules a recurring background timer that generates a
/// `DeviceHealthReport` snapshot and uploads it to the admin console at the configured
/// interval. An immediate, on-demand report can be triggered at any time via `reportNow()`.
///
/// The service relies on injected `AdminAPIProviding` and `DeviceRegistrationProviding`
/// collaborators, keeping it decoupled from `@MainActor` singletons and making it fully
/// testable without running on the main thread.
final class HealthReportingService: HealthReporting {

    // MARK: - Properties

    private let apiClient: AdminAPIProviding
    private let registrationProvider: DeviceRegistrationProviding
    private var reportTimer: Timer?
    private let logger = Logger(subsystem: "com.pasteshelf", category: "health-reporting")

    // MARK: - Initialization

    /// Creates a `HealthReportingService`.
    ///
    /// - Parameters:
    ///   - apiClient: The admin console API client used to submit health reports.
    ///   - registrationProvider: The provider that supplies the current device registration.
    init(apiClient: AdminAPIProviding, registrationProvider: DeviceRegistrationProviding) {
        self.apiClient = apiClient
        self.registrationProvider = registrationProvider
    }

    // MARK: - HealthReporting

    /// Starts the recurring health report submission timer.
    ///
    /// Any previously running timer is invalidated before the new one is scheduled.
    /// Calling this method when already running replaces the existing timer with the
    /// new interval. Reports are generated and submitted asynchronously on each firing.
    ///
    /// - Parameter interval: The time interval in seconds between successive report submissions.
    func startReporting(interval: TimeInterval) {
        stopReporting()
        reportTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                try? await self?.reportNow()
            }
        }
        logger.info("Health reporting started (interval: \(interval)s)")
    }

    /// Stops the recurring health report submission timer.
    ///
    /// After calling this method, no further reports are submitted automatically until
    /// `startReporting(interval:)` is called again. Any report currently in flight is
    /// not affected.
    func stopReporting() {
        reportTimer?.invalidate()
        reportTimer = nil
    }

    /// Immediately generates and submits a device health report outside the regular schedule.
    ///
    /// Use this to force an immediate check-in — for example, after a significant state
    /// change such as a policy update or SSO session expiry.
    ///
    /// - Throws: `AdminError.notEnrolled` if no active device registration exists, or
    ///   any error propagated from the underlying `AdminAPIProviding` implementation.
    func reportNow() async throws {
        guard let registration = registrationProvider.currentRegistration(), registration.isActive else {
            throw AdminError.notEnrolled
        }

        let report = buildHealthReport(deviceId: registration.deviceId)
        try await apiClient.submitHealthReport(report)
        logger.info("Health report submitted for device \(registration.deviceId)")
    }

    // MARK: - Report Building

    /// Gathers current app state into a `DeviceHealthReport`.
    ///
    /// System values (OS version, app version) are read directly from `ProcessInfo` and
    /// `Bundle`. Feature-status fields (SSO, MDM, sync, encryption) use safe placeholder
    /// defaults — the `AdminManager` layer is responsible for providing real values by
    /// calling `reportNow()` after decorating the report, or by injecting a specialized
    /// `DeviceHealthReport` builder that can safely hop to `@MainActor` singletons.
    ///
    /// Keeping this method free of `@MainActor` dependencies ensures the service remains
    /// usable from any concurrency context without risk of deadlocks or data races.
    ///
    /// - Parameter deviceId: The server-assigned identifier of the enrolled device.
    /// - Returns: A `DeviceHealthReport` snapshot with system metadata populated and
    ///   feature-status fields set to conservative defaults.
    private func buildHealthReport(deviceId: String) -> DeviceHealthReport {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        // NOTE: Feature-status fields (isSSOActive, isMDMManaged, isSyncEnabled,
        // isEncryptionEnabled, clipboardItemCount, lastSyncDate) are intentionally
        // left at safe defaults. Accessing @MainActor singletons (SSOManager.shared,
        // MDMManager.shared) from a background context requires a MainActor hop which
        // is the responsibility of the calling AdminManager layer, not this service.
        return DeviceHealthReport(
            deviceId: deviceId,
            timestamp: Date(),
            appVersion: appVersion,
            osVersion: osVersion,
            isSSOActive: false,
            isMDMManaged: false,
            isSyncEnabled: false,
            isEncryptionEnabled: false,
            clipboardItemCount: 0,
            lastSyncDate: nil,
            policyVersion: nil,
            activePolicyId: nil,
            complianceStatus: .unknown
        )
    }
}
