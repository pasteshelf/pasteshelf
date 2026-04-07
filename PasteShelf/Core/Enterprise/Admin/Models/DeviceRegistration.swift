//
//  DeviceRegistration.swift
//  PasteShelf
//
//  Model representing a device's enrollment state with the admin console.
//

import Foundation

// MARK: - DeviceEnrollmentStatus

/// The lifecycle state of a device's enrollment with the admin console.
enum DeviceEnrollmentStatus: String, Codable, Sendable {
    /// The device has not been enrolled and has no record on the admin console.
    case notEnrolled

    /// An enrollment request has been sent and is awaiting approval or completion.
    case enrolling

    /// The device is fully enrolled and actively managed by the admin console.
    case enrolled

    /// Enrollment has been temporarily suspended by an administrator.
    ///
    /// A suspended device cannot receive policy updates or submit health reports
    /// until an administrator reinstates it.
    case suspended

    /// The device's enrollment has been permanently revoked by an administrator.
    ///
    /// Revoked devices must re-enroll to participate in admin console management.
    case revoked
}

// MARK: - DeviceRegistration

/// A record of a single device's enrollment with the admin console.
///
/// `DeviceRegistration` captures the server-assigned identity, enrollment timestamps,
/// and device metadata that the admin console uses to identify and manage a device.
/// It also surfaces the current `enrollmentStatus` so the application can adapt its
/// behaviour accordingly (e.g., blocking features when `suspended` or `revoked`).
struct DeviceRegistration: Codable, Sendable, Identifiable, Equatable {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates a device registration record with the given enrollment details.
    ///
    /// - Parameters:
    ///   - id: A locally generated UUID for this record. Defaults to a new `UUID()`.
    ///   - deviceId: The server-assigned device identifier.
    ///   - organizationID: The organization this device belongs to.
    ///   - userId: The SSO user ID of the enrolling user.
    ///   - enrollmentStatus: The initial enrollment lifecycle state. Defaults to `.notEnrolled`.
    ///   - enrolledAt: The enrollment timestamp. Defaults to the current date.
    ///   - lastCheckIn: The last check-in timestamp. Defaults to the current date.
    ///   - deviceName: The human-readable device name.
    ///   - osVersion: The macOS version string.
    ///   - appVersion: The PasteShelf version string.
    ///   - serialNumber: The hardware serial number, if available.
    init(
        id: UUID = UUID(),
        deviceId: String,
        organizationID: String,
        userId: String,
        enrollmentStatus: DeviceEnrollmentStatus = .notEnrolled,
        enrolledAt: Date = Date(),
        lastCheckIn: Date = Date(),
        deviceName: String,
        osVersion: String,
        appVersion: String,
        serialNumber: String? = nil
    ) {
        self.id = id
        self.deviceId = deviceId
        self.organizationID = organizationID
        self.userId = userId
        self.enrollmentStatus = enrollmentStatus
        self.enrolledAt = enrolledAt
        self.lastCheckIn = lastCheckIn
        self.deviceName = deviceName
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.serialNumber = serialNumber
    }

    // MARK: Internal

    // MARK: - Identity

    /// Unique local identifier for this registration record.
    let id: UUID

    /// The identifier assigned to this device by the admin console server.
    ///
    /// This value is returned by the server during the enrollment handshake and must
    /// be included in all subsequent API requests to identify the device.
    let deviceId: String

    /// The organization this device is enrolled under.
    let organizationID: String

    /// The identifier of the user who enrolled the device, sourced from `SSOSession.userId`.
    let userId: String

    // MARK: - Enrollment State

    /// The current lifecycle state of this device's enrollment.
    var enrollmentStatus: DeviceEnrollmentStatus

    // MARK: - Timestamps

    /// When the device was first successfully enrolled.
    let enrolledAt: Date

    /// The most recent time this device successfully checked in with the admin console.
    var lastCheckIn: Date

    // MARK: - Device Metadata

    /// The human-readable name of the device (e.g., "Jane's MacBook Pro").
    let deviceName: String

    /// The macOS version string at the time of last check-in (e.g., "14.4.1").
    let osVersion: String

    /// The PasteShelf application version string at the time of last check-in.
    let appVersion: String

    /// The hardware serial number of the device, if available.
    ///
    /// May be `nil` on virtual machines or in sandboxed environments where the
    /// serial number is not accessible.
    let serialNumber: String?

    /// `true` when the device is fully enrolled and not suspended or revoked.
    ///
    /// Use this to gate admin-console-dependent features such as policy enforcement
    /// and health report submission.
    var isActive: Bool {
        enrollmentStatus == .enrolled
    }
}
