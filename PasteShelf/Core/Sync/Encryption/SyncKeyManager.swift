//
//  SyncKeyManager.swift
//  PasteShelf
//
//  Manages encryption keys for iCloud sync.
//  Keys are stored in iCloud Keychain for cross-device availability.
//

import CryptoKit
import Foundation
import os.log
import Security

/// Manages encryption keys for end-to-end encrypted sync
final class SyncKeyManager: Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    nonisolated init() {}

    // MARK: Internal

    // MARK: - Public API

    /// Check if the primary encryption key exists
    var hasKey: Bool {
        loadPrimaryKey() != nil
    }

    /// Get or create the sync encryption key
    /// - Returns: 256-bit symmetric key for AES-256-GCM
    /// - Throws: SyncError if key generation or retrieval fails
    func getOrCreateSyncKey() throws -> SymmetricKey {
        let primaryKey: Data

        if let existingKey = loadPrimaryKey() {
            primaryKey = existingKey
            Self.logger.debug("Loaded existing primary key from keychain")
        } else {
            primaryKey = try generateAndStorePrimaryKey()
            Self.logger.info("Generated and stored new primary key")
        }

        return deriveSyncKey(from: primaryKey)
    }

    /// Get the raw sync key data (for protocol conformance)
    func getOrCreateRawKey() throws -> Data {
        let symmetricKey = try getOrCreateSyncKey()
        return symmetricKey.withUnsafeBytes { Data($0) }
    }

    /// Delete all sync keys (for reset functionality)
    func deleteKeys() throws {
        try deleteKeyFromKeychain(account: primaryKeyAccount)
        Self.logger.info("Deleted sync encryption keys")
    }

    /// Rotate the primary key
    /// - Returns: The new sync key (caller must re-encrypt data)
    func rotateKey() throws -> SymmetricKey {
        // Delete existing key
        try? deleteKeys()

        // Generate new key
        let newPrimaryKey = try generateAndStorePrimaryKey()
        Self.logger.info("Rotated primary encryption key")

        return deriveSyncKey(from: newPrimaryKey)
    }

    // MARK: Private

    /// Size of the primary key in bytes (256 bits)
    private static let primaryKeySize = 32

    /// Salt for HKDF key derivation
    private static let derivationSalt = Data("com.pasteshelf.sync".utf8)

    /// Info string for deriving the sync encryption key
    private static let syncKeyInfo = Data("encryption-key-v1".utf8)

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "sync-keys"
    )

    // MARK: - Constants

    /// Keychain service identifier for sync keys
    private let service = "com.pasteshelf.sync"

    /// Keychain account for the primary encryption key
    private let primaryKeyAccount = "master_encryption_key"

    // MARK: - Private Key Operations

    /// Generate a new primary key and store it in keychain
    private func generateAndStorePrimaryKey() throws -> Data {
        // Generate cryptographically secure random bytes
        var keyData = Data(count: Self.primaryKeySize)
        let result = keyData.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return errSecParam
            }
            return SecRandomCopyBytes(kSecRandomDefault, Self.primaryKeySize, baseAddress)
        }

        guard result == errSecSuccess else {
            Self.logger.error("Failed to generate random key: \(result)")
            throw SyncError.encryptionKeyMissing
        }

        // Store in iCloud Keychain
        try storeInKeychain(data: keyData, account: primaryKeyAccount)

        return keyData
    }

    /// Derive the sync encryption key from primary key using HKDF
    private func deriveSyncKey(from primaryKey: Data) -> SymmetricKey {
        let primarySymmetricKey = SymmetricKey(data: primaryKey)

        // Use HKDF to derive the actual encryption key
        // This provides key separation and allows for multiple derived keys if needed
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: primarySymmetricKey,
            salt: Self.derivationSalt,
            info: Self.syncKeyInfo,
            outputByteCount: Self.primaryKeySize
        )
    }

    /// Load primary key from keychain
    private func loadPrimaryKey() -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: primaryKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            // Enable iCloud Keychain sync
            kSecAttrSynchronizable as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                Self.logger.warning("Keychain load failed: \(securityErrorMessage(for: status))")
            }
            return nil
        }

        return result as? Data
    }

    /// Store key data in keychain with iCloud sync
    private func storeInKeychain(data: Data, account: String) throws {
        // First try to delete any existing item
        try? deleteKeyFromKeychain(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // Store in iCloud Keychain for cross-device access
            kSecAttrSynchronizable as String: true,
            // Accessible when device is unlocked
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            let message = securityErrorMessage(for: status)
            Self.logger.error("Failed to store key in keychain: \(message)")
            throw SyncError.encryptionKeyMissing
        }
    }

    /// Delete key from keychain
    private func deleteKeyFromKeychain(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: true,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            let message = securityErrorMessage(for: status)
            Self.logger.error("Failed to delete key from keychain: \(message)")
            throw SyncError.encryptionKeyMissing
        }
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
