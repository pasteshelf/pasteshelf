//
//  DeviceRegistrationService.swift
//  PasteShelf
//
//  Manages the full enrollment lifecycle of a device with the admin console.
//  Provides a Keychain-backed store for persisting DeviceRegistration records.
//

import Foundation
import os.log
import Security

// MARK: - DeviceRegistrationService

/// Manages the full enrollment lifecycle of a device with the admin console.
///
/// `DeviceRegistrationService` coordinates the enrollment handshake by building a
/// `DeviceRegistration` payload from the active `SSOSession` and local device metadata,
/// submitting it to the admin console via `AdminAPIProviding`, and persisting the
/// server-confirmed registration in a `DeviceRegistrationStore`.
///
/// Unenrollment revokes the device on the server and removes the locally stored record.
final class DeviceRegistrationService: DeviceRegistrationProviding, @unchecked Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates a device registration service with the given API client and local store.
    ///
    /// - Parameters:
    ///   - apiClient: The admin console API client used for network operations.
    ///   - store: The persistent store used to save and load the local registration record.
    init(apiClient: AdminAPIProviding, store: DeviceRegistrationStore) {
        self.apiClient = apiClient
        self.store = store
    }

    // MARK: Internal

    /// Whether the device currently has an active, locally persisted enrollment record.
    ///
    /// Returns `true` only when a stored registration exists and its `enrollmentStatus`
    /// is `.enrolled`. This check is synchronous and local only.
    var isEnrolled: Bool {
        store.load()?.isActive == true
    }

    // MARK: - DeviceRegistrationProviding

    /// Enrolls the device with the admin console using an active SSO session.
    ///
    /// Builds a `DeviceRegistration` from the SSO session user identity and local device
    /// metadata, submits it to the admin console, persists the server-confirmed record,
    /// and returns it to the caller.
    ///
    /// - Parameters:
    ///   - session: The authenticated `SSOSession` providing the user identity for enrollment.
    ///   - config: The `AdminConsoleConfiguration` specifying the organization ID.
    /// - Returns: The server-confirmed `DeviceRegistration` for the enrolled device.
    /// - Throws: `AdminError.notConfigured` if the configuration is incomplete,
    ///   `AdminError.enrollmentFailed` if the server rejects the request, or
    ///   `AdminError.networkError` on transport failure.
    func enroll(with session: SSOSession, config: AdminConsoleConfiguration) async throws -> DeviceRegistration {
        guard config.isConfigured else {
            logger.error("Enrollment failed: admin console is not configured")
            throw AdminError.notConfigured
        }

        let metadata = collectDeviceMetadata()

        // Build the initial registration payload with a placeholder deviceId.
        // The server assigns and returns the real deviceId in its response.
        let payload = DeviceRegistration(
            deviceId: "",
            organizationID: config.organizationID,
            userId: session.userId,
            enrollmentStatus: .enrolling,
            deviceName: metadata.deviceName,
            osVersion: metadata.osVersion,
            appVersion: metadata.appVersion,
            serialNumber: metadata.serialNumber
        )

        logger.info("Enrolling device for user '\(session.userId)' in org '\(config.organizationID)'")

        let confirmed: DeviceRegistration
        do {
            confirmed = try await apiClient.registerDevice(payload)
        } catch let error as AdminError {
            logger.error("Enrollment rejected by server: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("Enrollment network failure: \(error.localizedDescription)")
            throw AdminError.networkError(error.localizedDescription)
        }

        do {
            try store.save(confirmed)
        } catch {
            logger.error("Failed to persist registration after enrollment: \(error.localizedDescription)")
            throw error
        }

        logger.info("Device enrolled successfully with deviceId '\(confirmed.deviceId)'")
        return confirmed
    }

    /// Unenrolls the device from the admin console and removes the local registration record.
    ///
    /// Loads the current registration, calls the admin console API to revoke the device,
    /// and deletes the locally persisted record from the store.
    ///
    /// - Throws: `AdminError.notEnrolled` if no active registration exists, or
    ///   `AdminError.networkError` on transport failure.
    func unenroll() async throws {
        guard let registration = store.load() else {
            logger.warning("Unenroll called but no local registration record found")
            throw AdminError.notEnrolled
        }

        logger.info("Unenrolling device '\(registration.deviceId)'")

        do {
            try await apiClient.unregisterDevice(deviceId: registration.deviceId)
        } catch let error as AdminError {
            logger.error("Server rejected unenrollment: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("Unenrollment network failure: \(error.localizedDescription)")
            throw AdminError.networkError(error.localizedDescription)
        }

        do {
            try store.delete()
        } catch {
            logger.error("Failed to delete local registration after unenrollment: \(error.localizedDescription)")
            throw error
        }

        logger.info("Device unenrolled and local registration record removed")
    }

    /// Returns the current locally persisted `DeviceRegistration`, if one exists.
    ///
    /// This is a synchronous, local read from the store; it does not contact the server.
    ///
    /// - Returns: The stored `DeviceRegistration`, or `nil` if no record is present.
    func currentRegistration() -> DeviceRegistration? {
        store.load()
    }

    // MARK: Private

    private let apiClient: AdminAPIProviding
    private let store: DeviceRegistrationStore
    private let logger = Logger(subsystem: "com.pasteshelf", category: "device-registration")

    // MARK: - Device Metadata

    /// Collects metadata about the local device for inclusion in the enrollment payload.
    ///
    /// - Returns: A tuple containing the device name, OS version string, app version string,
    ///   and hardware serial number (always `nil` in a sandboxed environment).
    private func collectDeviceMetadata()
        -> (deviceName: String, osVersion: String, appVersion: String, serialNumber: String?)
    {
        let deviceName = Host.current().localizedName ?? "Unknown Mac"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        // Serial number is not accessible in the macOS app sandbox.
        return (deviceName, osVersion, appVersion, nil)
    }
}

// MARK: - KeychainDeviceRegistrationStore

/// A Keychain-backed implementation of `DeviceRegistrationStore`.
///
/// `KeychainDeviceRegistrationStore` encodes `DeviceRegistration` as JSON and stores
/// the data in the system Keychain using the Security framework. The item is scoped
/// to the `com.pasteshelf.admin.registration` service so that it survives application
/// restarts, is excluded from iCloud backups, and benefits from the OS sandbox.
final class KeychainDeviceRegistrationStore: DeviceRegistrationStore, @unchecked Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates a new Keychain-backed registration store.
    init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: Internal

    // MARK: - DeviceRegistrationStore

    /// Encodes `registration` as JSON and persists it in the Keychain.
    ///
    /// If an existing item is present it is updated in-place via `SecItemUpdate`;
    /// otherwise a new item is added via `SecItemAdd`.
    ///
    /// - Parameter registration: The `DeviceRegistration` to store.
    /// - Throws: `AdminError.enrollmentFailed` if encoding or the Keychain write fails.
    func save(_ registration: DeviceRegistration) throws {
        let data: Data
        do {
            data = try encoder.encode(registration)
        } catch {
            logger.error("Failed to encode registration for Keychain: \(error.localizedDescription)")
            throw AdminError.enrollmentFailed("Failed to encode registration data: \(error.localizedDescription)")
        }

        let query = keychainQuery()

        // Attempt to update an existing item first.
        let attributes: [CFString: Any] = [kSecValueData: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            logger.debug("Updated existing registration record in Keychain")
            return
        }

        if updateStatus == errSecItemNotFound {
            // No existing item — add a new one.
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                logger.error("SecItemAdd failed with status \(addStatus)")
                throw AdminError.enrollmentFailed("Keychain write failed (OSStatus \(addStatus))")
            }
            logger.debug("Saved new registration record to Keychain")
        } else {
            logger.error("SecItemUpdate failed with status \(updateStatus)")
            throw AdminError.enrollmentFailed("Keychain update failed (OSStatus \(updateStatus))")
        }
    }

    /// Loads and decodes the persisted `DeviceRegistration` from the Keychain.
    ///
    /// - Returns: The stored registration, or `nil` if no item is present or decoding fails.
    func load() -> DeviceRegistration? {
        var query = keychainQuery()
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound {
                logger.warning("SecItemCopyMatching returned status \(status)")
            }
            return nil
        }

        do {
            return try decoder.decode(DeviceRegistration.self, from: data)
        } catch {
            logger.error("Failed to decode registration from Keychain: \(error.localizedDescription)")
            return nil
        }
    }

    /// Removes the persisted `DeviceRegistration` from the Keychain.
    ///
    /// - Throws: `AdminError.enrollmentFailed` if the Keychain delete operation fails
    ///   for a reason other than the item not existing.
    func delete() throws {
        let query = keychainQuery()
        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("SecItemDelete failed with status \(status)")
            throw AdminError.enrollmentFailed("Keychain delete failed (OSStatus \(status))")
        }

        logger.debug("Deleted registration record from Keychain")
    }

    // MARK: Private

    private let service = "com.pasteshelf.admin.registration"
    private let account = "device-registration"
    private let logger = Logger(subsystem: "com.pasteshelf", category: "device-registration-store")

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Private Helpers

    /// Builds the base Keychain query dictionary scoped to this service and account.
    private func keychainQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
