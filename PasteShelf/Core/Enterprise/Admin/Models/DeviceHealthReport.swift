//
//  DeviceHealthReport.swift
//  PasteShelf
//
//  Model representing a health and compliance snapshot submitted to the admin console.
//

import Foundation

// MARK: - ComplianceStatus

/// The overall compliance state of a device relative to its assigned admin policy.
enum ComplianceStatus: String, Codable, Sendable {
    /// The device satisfies all requirements imposed by its assigned policy.
    case compliant

    /// The device violates one or more requirements imposed by its assigned policy.
    ///
    /// Non-compliant devices may have certain features restricted by the policy enforcer
    /// until the violation is resolved.
    case nonCompliant

    /// Compliance could not be determined, typically because no policy has been assigned
    /// or because a required check could not be completed.
    case unknown
}

// MARK: - DeviceHealthReport

/// A point-in-time snapshot of a device's application state, feature status, and
/// policy compliance, submitted to the admin console during each check-in.
///
/// Health reports allow administrators to monitor the state of enrolled devices from
/// the admin console dashboard.  A new report is generated and uploaded whenever the
/// device checks in with the server.
struct DeviceHealthReport: Codable, Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates a device health report with the given snapshot data.
    ///
    /// - Parameters:
    ///   - deviceId: The server-assigned device identifier.
    ///   - timestamp: When the snapshot was captured. Defaults to the current date.
    ///   - appVersion: The PasteShelf version string.
    ///   - osVersion: The macOS version string.
    ///   - isSSOActive: Whether an active SSO session exists.
    ///   - isMDMManaged: Whether the device is MDM-managed.
    ///   - isSyncEnabled: Whether iCloud sync is active.
    ///   - isEncryptionEnabled: Whether local encryption is enabled.
    ///   - clipboardItemCount: The number of stored clipboard items.
    ///   - lastSyncDate: The most recent successful sync date, if any.
    ///   - policyVersion: The version string of the active policy, if any.
    ///   - activePolicyId: The server-assigned ID of the active policy, if any.
    ///   - complianceStatus: The overall compliance verdict. Defaults to `.unknown`.
    init(
        deviceId: String,
        timestamp: Date = Date(),
        appVersion: String,
        osVersion: String,
        isSSOActive: Bool,
        isMDMManaged: Bool,
        isSyncEnabled: Bool,
        isEncryptionEnabled: Bool,
        clipboardItemCount: Int,
        lastSyncDate: Date? = nil,
        policyVersion: String? = nil,
        activePolicyId: String? = nil,
        complianceStatus: ComplianceStatus = .unknown
    ) {
        self.deviceId = deviceId
        self.timestamp = timestamp
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.isSSOActive = isSSOActive
        self.isMDMManaged = isMDMManaged
        self.isSyncEnabled = isSyncEnabled
        self.isEncryptionEnabled = isEncryptionEnabled
        self.clipboardItemCount = clipboardItemCount
        self.lastSyncDate = lastSyncDate
        self.policyVersion = policyVersion
        self.activePolicyId = activePolicyId
        self.complianceStatus = complianceStatus
    }

    // MARK: Internal

    // MARK: - Identity

    /// The server-assigned identifier of the device submitting this report.
    let deviceId: String

    /// When this health snapshot was captured.
    let timestamp: Date

    // MARK: - Software Versions

    /// The PasteShelf application version at the time the report was generated.
    let appVersion: String

    /// The macOS version at the time the report was generated.
    let osVersion: String

    // MARK: - Feature Status

    /// `true` when the device has an active Enterprise SSO session.
    let isSSOActive: Bool

    /// `true` when the device is currently under MDM management.
    let isMDMManaged: Bool

    /// `true` when iCloud sync is enabled for the current user.
    let isSyncEnabled: Bool

    /// `true` when local clipboard data encryption is enabled.
    let isEncryptionEnabled: Bool

    // MARK: - Usage Statistics

    /// The total number of clipboard items currently stored on the device.
    let clipboardItemCount: Int

    /// The timestamp of the most recent successful iCloud sync, or `nil` if sync has
    /// never completed or is disabled.
    let lastSyncDate: Date?

    /// The version string of the policy that was active at report time, or `nil` if no
    /// policy has been assigned.
    let policyVersion: String?

    // MARK: - Compliance

    /// The server-assigned identifier of the admin policy currently applied to this device,
    /// or `nil` if no policy is active.
    let activePolicyId: String?

    /// The overall compliance verdict for this device at report time.
    let complianceStatus: ComplianceStatus
}
