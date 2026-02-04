//
//  KeychainStorage.swift
//  PasteShelf
//
//  Secure storage for license tokens using the macOS Keychain.
//  Implements LicenseTokenStoring protocol for the licensing system.
//

import Foundation
import os.log
import Security

/// Secure keychain storage for license tokens and device IDs
final class KeychainStorage: LicenseTokenStoring {
    // MARK: - Constants

    /// Keychain service identifier
    private let service = "com.pasteshelf.license"

    /// Keychain account for license token
    private let tokenAccount = "license_token"

    /// Keychain account for device ID
    private let deviceIdAccount = "device_id"

    /// Access group for shared keychain access (if needed)
    private let accessGroup: String? = nil

    // MARK: - Logger

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "keychain"
    )

    // MARK: - Initialization

    init() {}

    // MARK: - LicenseTokenStoring

    /// Save a license token to the keychain
    /// - Parameter token: The JWT token string
    /// - Throws: LicenseError.keychainError if operation fails
    func save(token: String) throws {
        try save(data: Data(token.utf8), account: tokenAccount)
        logger.info("License token saved to keychain")
    }

    /// Load the stored license token
    /// - Returns: The JWT token string, or nil if not found
    func load() -> String? {
        guard let data = loadData(account: tokenAccount) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Delete the stored license token
    /// - Throws: LicenseError.keychainError if operation fails
    func delete() throws {
        try deleteItem(account: tokenAccount)
        logger.info("License token deleted from keychain")
    }

    /// Save the device ID to the keychain
    /// - Parameter deviceId: The device identifier
    /// - Throws: LicenseError.keychainError if operation fails
    func saveDeviceId(_ deviceId: String) throws {
        try save(data: Data(deviceId.utf8), account: deviceIdAccount)
        logger.debug("Device ID saved to keychain")
    }

    /// Load the stored device ID
    /// - Returns: The device ID string, or nil if not found
    func loadDeviceId() -> String? {
        guard let data = loadData(account: deviceIdAccount) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Device ID Generation

    /// Get or create a unique device ID
    /// - Returns: The device identifier
    func getOrCreateDeviceId() throws -> String {
        // Try to load existing device ID
        if let existingId = loadDeviceId() {
            return existingId
        }

        // Generate new device ID based on hardware UUID + bundle ID
        let deviceId = generateDeviceId()
        try saveDeviceId(deviceId)
        return deviceId
    }

    /// Generate a unique device identifier
    private func generateDeviceId() -> String {
        // Get hardware UUID from IOKit
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )

        var hardwareUUID = ""
        if platformExpert != 0 {
            if let serialNumberAsCFString = IORegistryEntryCreateCFProperty(
                platformExpert,
                kIOPlatformUUIDKey as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() {
                hardwareUUID = serialNumberAsCFString as? String ?? ""
            }
            IOObjectRelease(platformExpert)
        }

        // Combine with bundle ID for uniqueness per app
        let bundleId = Bundle.main.bundleIdentifier ?? "com.pasteshelf"
        let combined = "\(hardwareUUID)-\(bundleId)"

        // Hash for privacy (don't expose raw hardware UUID)
        return combined.sha256Hash
    }

    // MARK: - Private Keychain Operations

    /// Save data to keychain
    private func save(data: Data, account: String) throws {
        // First try to delete existing item
        try? deleteItem(account: account)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            let message = securityErrorMessage(for: status)
            logger.error("Keychain save failed: \(message)")
            throw LicenseError.keychainError(message)
        }
    }

    /// Load data from keychain
    private func loadData(account: String) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                logger.warning("Keychain load failed: \(self.securityErrorMessage(for: status))")
            }
            return nil
        }

        return result as? Data
    }

    /// Delete item from keychain
    private func deleteItem(account: String) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            let message = securityErrorMessage(for: status)
            logger.error("Keychain delete failed: \(message)")
            throw LicenseError.keychainError(message)
        }
    }

    /// Check if an item exists in keychain
    func exists(account: String) -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false,
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Error Handling

    /// Get human-readable message for Security framework error
    private func securityErrorMessage(for status: OSStatus) -> String {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return message
        }

        switch status {
        case errSecItemNotFound:
            return "Item not found"
        case errSecDuplicateItem:
            return "Duplicate item"
        case errSecAuthFailed:
            return "Authentication failed"
        case errSecInteractionNotAllowed:
            return "User interaction required"
        case errSecDecode:
            return "Unable to decode data"
        case errSecParam:
            return "Invalid parameter"
        default:
            return "Unknown error (\(status))"
        }
    }
}

// MARK: - String Extension for Hashing

private extension String {
    /// Compute SHA256 hash of the string
    var sha256Hash: String {
        let data = Data(utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// Import CommonCrypto for SHA256
import CommonCrypto
