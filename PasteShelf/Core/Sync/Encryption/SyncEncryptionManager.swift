//
//  SyncEncryptionManager.swift
//  PasteShelf
//
//  End-to-end encryption for iCloud sync using AES-256-GCM.
//  Data format: [1 byte version][12 bytes nonce][ciphertext][16 bytes auth tag]
//

import CryptoKit
import Foundation
import os.log

/// Handles end-to-end encryption for sync data using AES-256-GCM
final class SyncEncryptionManager: SyncEncrypting, Sendable {
    // MARK: - Constants

    /// Current encryption format version
    private static let currentVersion: UInt8 = 1

    /// Size of the nonce in bytes (96 bits for GCM)
    private static let nonceSize = 12

    /// Size of the authentication tag in bytes (128 bits)
    private static let tagSize = 16

    /// Minimum size of encrypted data (version + nonce + tag)
    private static let minEncryptedSize = 1 + nonceSize + tagSize

    // MARK: - Dependencies

    private let keyManager: SyncKeyManager

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "sync-encryption"
    )

    // MARK: - Initialization

    init(keyManager: SyncKeyManager = SyncKeyManager()) {
        self.keyManager = keyManager
    }

    // MARK: - SyncEncrypting Protocol

    var hasEncryptionKey: Bool {
        get async {
            keyManager.hasKey
        }
    }

    func getOrCreateKey() async throws -> Data {
        try keyManager.getOrCreateRawKey()
    }

    func encrypt(_ data: Data) async throws -> Data {
        let key = try keyManager.getOrCreateSyncKey()
        return try encrypt(data, with: key)
    }

    func decrypt(_ data: Data) async throws -> Data {
        let key = try keyManager.getOrCreateSyncKey()
        return try decrypt(data, with: key)
    }

    func rotateKey() async throws {
        _ = try keyManager.rotateKey()
        Self.logger.info("Encryption key rotated - all data needs re-encryption")
    }

    // MARK: - Encryption Implementation

    /// Encrypt data using AES-256-GCM
    /// - Parameters:
    ///   - plaintext: Data to encrypt
    ///   - key: 256-bit symmetric key
    /// - Returns: Encrypted data in format [version][nonce][ciphertext][tag]
    private func encrypt(_ plaintext: Data, with key: SymmetricKey) throws -> Data {
        // Generate random nonce
        let nonce = try AES.GCM.Nonce()

        // Encrypt using AES-256-GCM
        let sealedBox = try AES.GCM.seal(plaintext, using: key, nonce: nonce)

        // Build encrypted data format: [version][nonce][ciphertext + tag]
        var encryptedData = Data()

        // 1 byte: version
        encryptedData.append(Self.currentVersion)

        // 12 bytes: nonce
        encryptedData.append(contentsOf: nonce)

        // Variable: ciphertext + 16 byte tag
        encryptedData.append(sealedBox.ciphertext)
        encryptedData.append(sealedBox.tag)

        Self.logger.debug("Encrypted \(plaintext.count) bytes -> \(encryptedData.count) bytes")

        return encryptedData
    }

    /// Decrypt data using AES-256-GCM
    /// - Parameters:
    ///   - encryptedData: Encrypted data in format [version][nonce][ciphertext][tag]
    ///   - key: 256-bit symmetric key
    /// - Returns: Decrypted plaintext
    private func decrypt(_ encryptedData: Data, with key: SymmetricKey) throws -> Data {
        // Validate minimum size
        guard encryptedData.count >= Self.minEncryptedSize else {
            Self.logger.error("Encrypted data too small: \(encryptedData.count) bytes")
            throw SyncError.decryptionFailed
        }

        // Parse version
        let version = encryptedData[0]
        guard version == Self.currentVersion else {
            Self.logger.error("Unsupported encryption version: \(version)")
            throw SyncError.decryptionFailed
        }

        // Parse nonce (12 bytes after version)
        let nonceData = encryptedData[1 ..< (1 + Self.nonceSize)]
        guard let nonce = try? AES.GCM.Nonce(data: nonceData) else {
            Self.logger.error("Invalid nonce data")
            throw SyncError.decryptionFailed
        }

        // Parse ciphertext + tag (rest of data)
        let ciphertextAndTag = encryptedData[(1 + Self.nonceSize)...]

        // Separate ciphertext and tag
        let ciphertextSize = ciphertextAndTag.count - Self.tagSize
        guard ciphertextSize >= 0 else {
            Self.logger.error("Invalid ciphertext size")
            throw SyncError.decryptionFailed
        }

        let ciphertext = ciphertextAndTag.prefix(ciphertextSize)
        let tag = ciphertextAndTag.suffix(Self.tagSize)

        // Reconstruct sealed box
        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: ciphertext,
                tag: tag
            )
        } catch {
            Self.logger.error("Failed to create sealed box: \(error.localizedDescription)")
            throw SyncError.decryptionFailed
        }

        // Decrypt
        do {
            let plaintext = try AES.GCM.open(sealedBox, using: key)
            Self.logger.debug("Decrypted \(encryptedData.count) bytes -> \(plaintext.count) bytes")
            return plaintext
        } catch {
            Self.logger.error("Decryption failed: \(error.localizedDescription)")
            throw SyncError.decryptionFailed
        }
    }

    // MARK: - Convenience Methods

    /// Encrypt a string
    func encrypt(_ string: String) async throws -> Data {
        guard let data = string.data(using: .utf8) else {
            throw SyncError.invalidData(reason: "String encoding failed")
        }
        return try await encrypt(data)
    }

    /// Decrypt to string
    func decryptString(_ encryptedData: Data) async throws -> String {
        let data = try await decrypt(encryptedData)
        guard let string = String(data: data, encoding: .utf8) else {
            throw SyncError.invalidData(reason: "String decoding failed")
        }
        return string
    }

    /// Encrypt a Codable object
    func encrypt<T: Encodable>(_ object: T) async throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(object)
        return try await encrypt(data)
    }

    /// Decrypt to Codable object
    func decrypt<T: Decodable>(_ encryptedData: Data, as type: T.Type) async throws -> T {
        let data = try await decrypt(encryptedData)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    // MARK: - Key Management

    /// Delete encryption keys (for sync reset)
    func deleteKeys() throws {
        try keyManager.deleteKeys()
    }

    /// Check if encryption is available
    var isAvailable: Bool {
        keyManager.hasKey
    }
}

// MARK: - Encrypted Payload

/// Wrapper for encrypted sync data with metadata
struct EncryptedPayload: Codable, Sendable {
    /// Encrypted data (version + nonce + ciphertext + tag)
    let data: Data

    /// Entity type for routing
    let entityType: String

    /// Entity UUID
    let entityID: UUID

    /// Timestamp of encryption (for ordering)
    let encryptedAt: Date

    init(
        data: Data,
        entityType: SyncChange.EntityType,
        entityID: UUID,
        encryptedAt: Date = Date()
    ) {
        self.data = data
        self.entityType = entityType.rawValue
        self.entityID = entityID
        self.encryptedAt = encryptedAt
    }
}
