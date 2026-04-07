//
//  KeychainSSOSessionStore.swift
//  PasteShelf
//
//  Keychain-backed implementation of SSOSessionStore.
//  Stores SSO session data securely in the system Keychain.
//

import Foundation
import os.log
import Security

// MARK: - KeychainSSOSessionStore

/// A Keychain-backed store for active SSO sessions.
///
/// Each session is stored as a JSON-encoded Keychain item keyed by the provider UUID.
/// This ensures session tokens (access tokens, refresh tokens) are protected by the
/// system's secure enclave and are not exposed in plain-text storage.
final class KeychainSSOSessionStore: SSOSessionStore, @unchecked Sendable {
    // MARK: Internal

    // MARK: - SSOSessionStore

    func save(_ session: SSOSession) async throws {
        let data = try JSONEncoder().encode(session)
        let account = session.providerId.uuidString

        // Delete existing item first (update = delete + add)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            self.logger.error("Failed to save SSO session to Keychain: \(status)")
            throw KeychainError.saveFailed(status)
        }
    }

    func load(for providerId: UUID) async throws -> SSOSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: providerId.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                return nil
            }
            self.logger.error("Failed to load SSO session from Keychain: \(status)")
            throw KeychainError.loadFailed(status)
        }

        return try JSONDecoder().decode(SSOSession.self, from: data)
    }

    func delete(for providerId: UUID) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: providerId.uuidString,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            self.logger.error("Failed to delete SSO session from Keychain: \(status)")
            throw KeychainError.deleteFailed(status)
        }
    }

    func deleteAll() async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            self.logger.error("Failed to delete all SSO sessions from Keychain: \(status)")
            throw KeychainError.deleteFailed(status)
        }
    }

    // MARK: Private

    private let service = "com.pasteshelf.sso.sessions"
    private let logger = Logger(subsystem: "com.pasteshelf", category: "sso-session-store")
}

// MARK: - KeychainError

/// Errors that can occur during Keychain operations.
enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case let .saveFailed(status):
            "Failed to save to Keychain (status: \(status))"
        case let .loadFailed(status):
            "Failed to load from Keychain (status: \(status))"
        case let .deleteFailed(status):
            "Failed to delete from Keychain (status: \(status))"
        }
    }
}
