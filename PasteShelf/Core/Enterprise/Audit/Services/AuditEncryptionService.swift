//
//  AuditEncryptionService.swift
//  PasteShelf
//
//  AES-256-GCM encryption and decryption for audit log detail payloads.
//  Keys are generated and stored in the system Keychain under a dedicated service identifier.
//

import CryptoKit
import Foundation
import os.log
import Security

// MARK: - AuditEncryptionService

/// Encrypts and decrypts audit event detail dictionaries using AES-256-GCM.
///
/// `AuditEncryptionService` produces a compact binary wire format that mirrors the
/// one used by `SyncEncryptionManager`:
/// `[1 byte version][12 bytes nonce][ciphertext][16 bytes auth tag]`
///
/// The AES-256 symmetric key is generated on first use and persisted in the system
/// Keychain under the `com.pasteshelf.audit.detail.key` service so that it survives
/// application restarts without requiring re-encryption of existing records.
struct AuditEncryptionService {
    // MARK: Internal

    // MARK: - Encryption

    /// Encrypts a `[String: String]` detail dictionary into an opaque binary payload.
    ///
    /// The dictionary is JSON-encoded with ISO 8601 date formatting before encryption.
    /// The resulting binary follows the wire format:
    /// `[1 byte version][12 bytes nonce][ciphertext][16 bytes auth tag]`
    ///
    /// - Parameter detail: The key/value detail dictionary to encrypt.
    /// - Returns: The encrypted binary payload.
    /// - Throws: `AuditError.encryptionFailed` if JSON encoding or AES-GCM sealing fails,
    ///   or if the Keychain key cannot be retrieved or generated.
    func encrypt(_ detail: [String: String]) throws -> Data {
        let key: SymmetricKey
        do {
            key = try getOrCreateKey()
        } catch {
            Self.logger.error("Failed to retrieve audit encryption key: \(error.localizedDescription)")
            throw AuditError.encryptionFailed("Key retrieval failed: \(error.localizedDescription)")
        }

        let plaintext: Data
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            plaintext = try encoder.encode(detail)
        } catch {
            Self.logger.error("Failed to JSON-encode audit detail: \(error.localizedDescription)")
            throw AuditError.encryptionFailed("JSON encoding failed: \(error.localizedDescription)")
        }

        let nonce: AES.GCM.Nonce
        let sealedBox: AES.GCM.SealedBox
        do {
            nonce = try AES.GCM.Nonce()
            sealedBox = try AES.GCM.seal(plaintext, using: key, nonce: nonce)
        } catch {
            Self.logger.error("AES-GCM seal failed: \(error.localizedDescription)")
            throw AuditError.encryptionFailed("AES-GCM seal failed: \(error.localizedDescription)")
        }

        // Build wire format: [version][nonce][ciphertext][tag]
        var result = Data()
        result.append(Self.currentVersion)
        result.append(contentsOf: nonce)
        result.append(sealedBox.ciphertext)
        result.append(sealedBox.tag)

        Self.logger.debug("Encrypted audit detail: \(plaintext.count) bytes -> \(result.count) bytes")
        return result
    }

    // MARK: - Decryption

    /// Decrypts an encrypted audit detail payload back into a `[String: String]` dictionary.
    ///
    /// Parses the wire format `[version][nonce][ciphertext][tag]`, opens the AES-GCM
    /// sealed box, and JSON-decodes the resulting plaintext.
    ///
    /// - Parameter data: The encrypted binary payload produced by `encrypt(_:)`.
    /// - Returns: The plaintext key/value detail dictionary.
    /// - Throws: `AuditError.decryptionFailed` if the payload is malformed, the
    ///   authentication tag does not verify, or JSON decoding fails.
    func decrypt(_ data: Data) throws -> [String: String] { // swiftlint:disable:this function_body_length
        guard data.count >= Self.minEncryptedSize else {
            Self.logger.error("Encrypted audit detail too small: \(data.count) bytes")
            throw AuditError.decryptionFailed("Payload too small (\(data.count) bytes)")
        }

        // Parse version byte
        let version = data[data.startIndex]
        guard version == Self.currentVersion else {
            Self.logger.error("Unsupported audit encryption version: \(version)")
            throw AuditError.decryptionFailed("Unsupported format version \(version)")
        }

        let key: SymmetricKey
        do {
            key = try getOrCreateKey()
        } catch {
            Self.logger.error("Failed to retrieve audit decryption key: \(error.localizedDescription)")
            throw AuditError.decryptionFailed("Key retrieval failed: \(error.localizedDescription)")
        }

        // Parse nonce (bytes 1 ..< 13)
        let nonceStart = data.index(data.startIndex, offsetBy: 1)
        let nonceEnd = data.index(nonceStart, offsetBy: Self.nonceSize)
        let nonceData = data[nonceStart ..< nonceEnd]

        guard let nonce = try? AES.GCM.Nonce(data: nonceData) else {
            Self.logger.error("Invalid nonce data in audit detail payload")
            throw AuditError.decryptionFailed("Invalid nonce data")
        }

        // Parse ciphertext + tag (everything after the nonce)
        let ciphertextAndTag = data[nonceEnd...]
        let ciphertextSize = ciphertextAndTag.count - Self.tagSize
        guard ciphertextSize >= 0 else {
            Self.logger.error("Invalid ciphertext size in audit detail payload")
            throw AuditError.decryptionFailed("Invalid ciphertext size")
        }

        let ciphertext = ciphertextAndTag.prefix(ciphertextSize)
        let tag = ciphertextAndTag.suffix(Self.tagSize)

        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        } catch {
            Self.logger.error("Failed to reconstruct AES-GCM sealed box: \(error.localizedDescription)")
            throw AuditError.decryptionFailed("Sealed box reconstruction failed: \(error.localizedDescription)")
        }

        let plaintext: Data
        do {
            plaintext = try AES.GCM.open(sealedBox, using: key)
        } catch {
            Self.logger.error("AES-GCM open failed (authentication tag mismatch?): \(error.localizedDescription)")
            throw AuditError.decryptionFailed("AES-GCM open failed: \(error.localizedDescription)")
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let detail = try decoder.decode([String: String].self, from: plaintext)
            Self.logger.debug("Decrypted audit detail: \(data.count) bytes -> \(plaintext.count) bytes")
            return detail
        } catch {
            Self.logger.error("Failed to JSON-decode decrypted audit detail: \(error.localizedDescription)")
            throw AuditError.decryptionFailed("JSON decoding failed: \(error.localizedDescription)")
        }
    }

    // MARK: Private

    // MARK: - Constants

    /// Keychain service identifier for the audit encryption key.
    private static let keychainService = "com.pasteshelf.audit.detail.key"

    /// Keychain account name for the audit encryption key.
    private static let keychainAccount = "audit-encryption-key"

    /// Current wire-format version byte prepended to every encrypted payload.
    private static let currentVersion: UInt8 = 1

    /// Size of the AES-GCM nonce in bytes (96-bit).
    private static let nonceSize = 12

    /// Size of the AES-GCM authentication tag in bytes (128-bit).
    private static let tagSize = 16

    /// Minimum valid size of an encrypted payload: version + nonce + tag.
    private static let minEncryptedSize = 1 + nonceSize + tagSize

    // MARK: - Logger

    private static let logger = Logger.audit

    // MARK: - Key Management

    /// Loads the existing key from the Keychain, or generates and saves a new one.
    ///
    /// - Returns: The 256-bit `SymmetricKey` for AES-GCM operations.
    /// - Throws: Any error from `saveKey(_:)` if a new key cannot be persisted.
    private func getOrCreateKey() throws -> SymmetricKey {
        if let existing = loadKey() {
            return existing
        }

        let newKey = SymmetricKey(size: .bits256)
        try saveKey(newKey)
        Self.logger.info("Generated new audit encryption key and persisted to Keychain")
        return newKey
    }

    /// Attempts to load the audit encryption key from the Keychain.
    ///
    /// - Returns: The stored `SymmetricKey`, or `nil` if no item is present.
    private func loadKey() -> SymmetricKey? {
        var query: [String: Any] = keychainQuery()
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let keyData = result as? Data else {
            if status != errSecItemNotFound {
                Self.logger.warning("SecItemCopyMatching returned unexpected status \(status) for audit key")
            }
            return nil
        }

        return SymmetricKey(data: keyData)
    }

    /// Persists the given symmetric key to the Keychain.
    ///
    /// If an existing item is present it is replaced via `SecItemDelete` + `SecItemAdd`.
    ///
    /// - Parameter key: The `SymmetricKey` to persist.
    /// - Throws: `AuditError.encryptionFailed` if the Keychain write fails.
    private func saveKey(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }

        // Delete any existing item first (ignore errSecItemNotFound)
        let deleteQuery = keychainQuery()
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        if deleteStatus != errSecSuccess, deleteStatus != errSecItemNotFound {
            Self.logger.warning("SecItemDelete for audit key returned status \(deleteStatus)")
        }

        // Add the new key
        var addQuery = keychainQuery()
        addQuery[kSecValueData as String] = keyData
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            Self.logger.error("SecItemAdd for audit key failed with status \(addStatus)")
            throw AuditError.encryptionFailed("Keychain write failed (OSStatus \(addStatus))")
        }
    }

    /// Builds the base Keychain query dictionary scoped to the audit encryption service and account.
    private func keychainQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
        ]
    }
}
