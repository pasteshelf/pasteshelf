//
//  AdminProtocols.swift
//  PasteShelf
//
//  Protocols defining the Enterprise admin console management layer.
//

import Combine
import Foundation

// MARK: - AdminAPIProviding

/// Abstraction over the admin console HTTP API client.
///
/// Implementations communicate with the centralized admin console server to register
/// devices, fetch policies, submit health reports, and relay analytics events.
/// All methods are asynchronous and throw `AdminError` on failure.
protocol AdminAPIProviding: Sendable {
    /// Registers or re-registers a device with the admin console server.
    ///
    /// The server assigns a `deviceId` and returns a fully-populated `DeviceRegistration`
    /// record that the client must persist locally for all subsequent API calls.
    ///
    /// - Parameter registration: The initial registration payload containing device metadata.
    /// - Returns: A server-confirmed `DeviceRegistration` with the assigned `deviceId`.
    /// - Throws: `AdminError.networkError` if the request fails, or `AdminError.enrollmentFailed`
    ///   if the server rejects the registration.
    func registerDevice(_ registration: DeviceRegistration) async throws -> DeviceRegistration

    /// Unregisters the device from the admin console, revoking its enrollment.
    ///
    /// After a successful call the device will no longer receive policy updates or be
    /// visible on the admin console dashboard.
    ///
    /// - Parameter deviceId: The server-assigned identifier of the device to unregister.
    /// - Throws: `AdminError.networkError` if the request fails, or `AdminError.notEnrolled`
    ///   if no matching device record is found on the server.
    func unregisterDevice(deviceId: String) async throws

    /// Fetches the current admin policy assigned to a device.
    ///
    /// - Parameter deviceId: The server-assigned identifier of the device whose policy is requested.
    /// - Returns: The `AdminPolicy` currently assigned to the device by the administrator.
    /// - Throws: `AdminError.policyFetchFailed` if the policy cannot be retrieved, or
    ///   `AdminError.networkError` on transport failure.
    func fetchPolicy(for deviceId: String) async throws -> AdminPolicy

    /// Submits a device health report to the admin console.
    ///
    /// Health reports are generated at each check-in interval and allow administrators
    /// to monitor the compliance and feature state of enrolled devices.
    ///
    /// - Parameter report: The `DeviceHealthReport` snapshot to upload.
    /// - Throws: `AdminError.networkError` on transport failure, or `AdminError.serverError`
    ///   if the server returns a non-success status code.
    func submitHealthReport(_ report: DeviceHealthReport) async throws

    /// Submits a batch of analytics events to the admin console.
    ///
    /// Events are batched locally and flushed during each check-in cycle to reduce
    /// network overhead and improve reliability on intermittent connections.
    ///
    /// - Parameter events: The array of `AdminAnalyticsEvent` values to upload.
    /// - Throws: `AdminError.networkError` on transport failure, or `AdminError.serverError`
    ///   if the server returns a non-success status code.
    func submitAnalyticsEvents(_ events: [AdminAnalyticsEvent]) async throws

    /// Fetches the current enrollment status of a device from the admin console.
    ///
    /// Use this to synchronize the local registration record with the server-side
    /// lifecycle state, for example to detect if an administrator has suspended or
    /// revoked the device's enrollment.
    ///
    /// - Parameter deviceId: The server-assigned identifier of the device to query.
    /// - Returns: The current `DeviceEnrollmentStatus` as reported by the server.
    /// - Throws: `AdminError.networkError` on transport failure, or `AdminError.notEnrolled`
    ///   if no matching device record exists.
    func fetchDeviceStatus(deviceId: String) async throws -> DeviceEnrollmentStatus

    /// Submits a batch of audit log events to the admin console.
    ///
    /// Audit events are persisted locally and flushed to the server periodically by the
    /// `AuditLogSyncService`. This method handles the network transport for a single batch.
    ///
    /// - Parameter events: The array of `AuditEvent` values to upload.
    /// - Throws: `AdminError.networkError` on transport failure, or `AdminError.serverError`
    ///   if the server returns a non-success status code.
    func submitAuditEvents(_ events: [AuditEvent]) async throws
}

// MARK: - DeviceRegistrationProviding

/// Manages the full enrollment lifecycle of a device with the admin console.
///
/// Implementations coordinate the enrollment handshake (using an active `SSOSession`
/// and admin console configuration), persist the resulting `DeviceRegistration`, and
/// expose the current enrollment state to the rest of the application.
protocol DeviceRegistrationProviding: Sendable {
    /// Enrolls the device with the admin console using an active SSO session.
    ///
    /// This method performs the complete enrollment handshake: it builds the initial
    /// registration payload from the SSO session and device metadata, submits it to
    /// the admin console, and persists the server-confirmed `DeviceRegistration` locally.
    ///
    /// - Parameters:
    ///   - session: The authenticated `SSOSession` that provides the user identity for enrollment.
    ///   - config: The `AdminConsoleConfiguration` specifying the server URL and organization ID.
    /// - Returns: The server-confirmed `DeviceRegistration` for the enrolled device.
    /// - Throws: `AdminError.enrollmentFailed` if the server rejects the request, or
    ///   `AdminError.networkError` on transport failure.
    func enroll(with session: SSOSession, config: AdminConsoleConfiguration) async throws -> DeviceRegistration

    /// Unenrolls the device from the admin console and removes local registration data.
    ///
    /// This method calls the API to revoke the device's enrollment and then deletes
    /// the locally persisted `DeviceRegistration` from the Keychain store.
    ///
    /// - Throws: `AdminError.notEnrolled` if no active registration exists, or
    ///   `AdminError.networkError` on transport failure.
    func unenroll() async throws

    /// Returns the current locally persisted `DeviceRegistration`, if one exists.
    ///
    /// - Returns: The cached `DeviceRegistration`, or `nil` if the device is not enrolled.
    func currentRegistration() -> DeviceRegistration?

    /// Whether the device currently has an active, locally persisted enrollment record.
    ///
    /// This is a synchronous, local check only. It does not contact the admin console server.
    var isEnrolled: Bool { get }
}

// MARK: - HealthReporting

/// Drives periodic submission of device health reports to the admin console.
///
/// Implementations schedule recurring background work to capture a `DeviceHealthReport`
/// snapshot and upload it to the admin console at the configured polling interval.
protocol HealthReporting {
    /// Starts the recurring health report submission timer.
    ///
    /// After calling this method, the implementation will automatically generate and
    /// submit a `DeviceHealthReport` at the given `interval`. Calling `startReporting`
    /// when already running replaces the existing timer with the new interval.
    ///
    /// - Parameter interval: The time interval in seconds between successive report submissions.
    func startReporting(interval: TimeInterval)

    /// Stops the recurring health report submission timer.
    ///
    /// After calling this method, no further reports are submitted automatically until
    /// `startReporting(interval:)` is called again.
    func stopReporting()

    /// Immediately generates and submits a device health report, outside the regular schedule.
    ///
    /// Use this to force an immediate check-in, for example after a significant state
    /// change such as a policy update or SSO session expiry.
    ///
    /// - Throws: `AdminError.notEnrolled` if no active registration exists, or
    ///   `AdminError.networkError` on transport failure.
    func reportNow() async throws
}

// MARK: - PolicySyncing

/// Fetches the latest admin policy from the server and applies it to application settings.
///
/// Implementations are responsible for retrieving the server-side `AdminPolicy` document
/// assigned to this device, caching it locally, and translating its sub-policies into
/// concrete mutations on the application's `AppSettings`.
protocol PolicySyncing {
    /// Fetches the latest admin policy from the admin console server.
    ///
    /// Implementations should compare the returned policy against `currentPolicy` to
    /// determine whether any settings need to be updated before calling `applyPolicy`.
    ///
    /// - Returns: The most recent `AdminPolicy` assigned to this device.
    /// - Throws: `AdminError.policyFetchFailed` if the server cannot return a policy, or
    ///   `AdminError.networkError` on transport failure.
    func fetchLatestPolicy() async throws -> AdminPolicy

    /// Applies the given policy to a mutable `AppSettings` instance.
    ///
    /// This method translates administrator-configured sub-policies (history limits,
    /// excluded apps, sync settings, encryption requirements) into concrete mutations
    /// on `settings`. Only the fields covered by enforced sub-policies are modified;
    /// unenforced or absent sub-policies leave the corresponding settings unchanged.
    ///
    /// - Parameters:
    ///   - policy: The `AdminPolicy` to apply.
    ///   - settings: A mutable `AppSettings` instance to update in-place.
    func applyPolicy(_ policy: AdminPolicy, to settings: inout AppSettings)

    /// The most recently fetched and applied `AdminPolicy`, or `nil` if no policy has
    /// been received from the server since the last launch.
    var currentPolicy: AdminPolicy? { get }
}

// MARK: - DeviceRegistrationStore

/// Provides Keychain-backed persistence for a device's `DeviceRegistration` record.
///
/// Implementations store the registration in the system Keychain so that it survives
/// application restarts, is excluded from iCloud backups, and benefits from the
/// operating system's sandboxed credential storage.
protocol DeviceRegistrationStore: Sendable {
    /// Persists the given `DeviceRegistration` in the Keychain, replacing any existing record.
    ///
    /// - Parameter registration: The `DeviceRegistration` to store.
    /// - Throws: `AdminError.enrollmentFailed` if the Keychain write operation fails.
    func save(_ registration: DeviceRegistration) throws

    /// Loads and returns the persisted `DeviceRegistration` from the Keychain, if one exists.
    ///
    /// - Returns: The stored `DeviceRegistration`, or `nil` if no record is present.
    func load() -> DeviceRegistration?

    /// Removes the persisted `DeviceRegistration` from the Keychain.
    ///
    /// This is called during unenrollment to ensure no stale registration data remains
    /// on the device after the device has been removed from the admin console.
    ///
    /// - Throws: `AdminError.enrollmentFailed` if the Keychain delete operation fails.
    func delete() throws
}

// MARK: - AdminError

/// Errors that may be thrown during admin console operations.
enum AdminError: Error, LocalizedError, Sendable {
    /// The admin console has not been configured with a server URL and organization ID.
    case notConfigured

    /// The device is not enrolled with the admin console.
    ///
    /// Operations that require an active enrollment — such as fetching policies,
    /// submitting health reports, or uploading analytics events — will throw this
    /// error when no `DeviceRegistration` is present.
    case notEnrolled

    /// The enrollment handshake with the admin console server failed.
    ///
    /// The associated `String` provides a human-readable reason returned by the server.
    case enrollmentFailed(String)

    /// A network-level error prevented communication with the admin console server.
    ///
    /// The associated `String` is the underlying error description from the transport layer.
    case networkError(String)

    /// The operation requires an authenticated SSO session that is not currently active.
    case authenticationRequired

    /// The admin console server could not return a policy for this device.
    ///
    /// The associated `String` provides a human-readable reason, such as "no policy assigned".
    case policyFetchFailed(String)

    /// The admin console server returned a non-success HTTP status code.
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status code returned by the server.
    ///   - message: The error message or body excerpt returned alongside the status code.
    case serverError(Int, String)

    /// The server returned a response that could not be decoded into the expected model.
    case invalidResponse

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "The admin console has not been configured. A server URL and organization ID are required."
        case .notEnrolled:
            return "This device is not enrolled with the admin console. Enrollment is required to use this feature."
        case .enrollmentFailed(let reason):
            return "Device enrollment with the admin console failed: \(reason)"
        case .networkError(let reason):
            return "A network error prevented communication with the admin console: \(reason)"
        case .authenticationRequired:
            return "An active SSO session is required to perform this operation. Please sign in and try again."
        case .policyFetchFailed(let reason):
            return "Failed to retrieve the admin policy from the server: \(reason)"
        case .serverError(let statusCode, let message):
            return "The admin console server returned an error (HTTP \(statusCode)): \(message)"
        case .invalidResponse:
            return "The admin console server returned a response that could not be understood."
        }
    }

    var failureReason: String? {
        switch self {
        case .notConfigured:
            return "No admin console server URL or organization ID has been provided."
        case .notEnrolled:
            return "No device registration record was found on this device."
        case .enrollmentFailed(let reason):
            return reason
        case .networkError(let reason):
            return reason
        case .authenticationRequired:
            return "No valid SSO session is currently active."
        case .policyFetchFailed(let reason):
            return reason
        case .serverError(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        case .invalidResponse:
            return "The server response could not be decoded into the expected data model."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notConfigured:
            return "Open Settings > Enterprise > Admin Console and enter the server URL and organization ID."
        case .notEnrolled:
            return "Enroll this device from Settings > Enterprise > Admin Console and sign in with your SSO credentials."
        case .enrollmentFailed:
            return "Contact your IT administrator to verify the admin console is reachable and your account has enrollment permission."
        case .networkError:
            return "Check your network connection and verify the admin console server URL is correct."
        case .authenticationRequired:
            return "Sign in via Settings > Enterprise > Single Sign-On and retry the operation."
        case .policyFetchFailed:
            return "Contact your IT administrator to ensure a policy has been assigned to this device in the admin console."
        case .serverError:
            return "Contact your IT administrator if the error persists, or check the admin console server status."
        case .invalidResponse:
            return "Ensure the PasteShelf app is up to date and that the admin console server is running a compatible version."
        }
    }
}
