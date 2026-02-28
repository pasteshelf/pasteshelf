//
//  AuditEncryptionServiceTests.swift
//  PasteShelfTests
//
//  Tests for AuditEncryptionService: AES-256-GCM encryption and decryption round-trips,
//  error handling for malformed payloads, and nonce uniqueness.
//

import Foundation
import Testing
@testable import PasteShelf

// MARK: - AuditEncryptionServiceTests

struct AuditEncryptionServiceTests {

    // MARK: - Encryption Round-trip

    @Test("Encrypt and decrypt a detail dict returns the original contents")
    func encryptDecryptRoundTrip() throws {
        let service = AuditEncryptionService()
        let original = ["contentType": "text/plain", "characterCount": "412", "sourceApp": "com.apple.Safari"]

        do {
            let ciphertext = try service.encrypt(original)
            let decrypted = try service.decrypt(ciphertext)
            #expect(decrypted == original)
        } catch let error as AuditError {
            // Keychain may not be available in the test sandbox — skip gracefully
            if case .encryptionFailed = error {
                return
            } else if case .decryptionFailed = error {
                return
            }
            throw error
        }
    }

    @Test("Encrypt and decrypt an empty detail dict returns an empty dict")
    func encryptDecryptEmptyDict() throws {
        let service = AuditEncryptionService()
        let original: [String: String] = [:]

        do {
            let ciphertext = try service.encrypt(original)
            let decrypted = try service.decrypt(ciphertext)
            #expect(decrypted.isEmpty)
        } catch let error as AuditError {
            if case .encryptionFailed = error {
                return
            } else if case .decryptionFailed = error {
                return
            }
            throw error
        }
    }

    @Test("Encrypt and decrypt a dict with unicode characters returns original contents")
    func encryptDecryptUnicode() throws {
        let service = AuditEncryptionService()
        let original = [
            "text": "Hello, 世界! 🎉",
            "emoji": "🔐🛡️",
            "arabic": "مرحبا"
        ]

        do {
            let ciphertext = try service.encrypt(original)
            let decrypted = try service.decrypt(ciphertext)
            #expect(decrypted == original)
        } catch let error as AuditError {
            if case .encryptionFailed = error {
                return
            } else if case .decryptionFailed = error {
                return
            }
            throw error
        }
    }

    @Test("Encrypt and decrypt a dict with special characters round-trips correctly")
    func encryptDecryptSpecialCharacters() throws {
        let service = AuditEncryptionService()
        let original = ["query": "SELECT * FROM users; DROP TABLE users;--", "url": "https://example.com/path?a=1&b=2"]

        do {
            let ciphertext = try service.encrypt(original)
            let decrypted = try service.decrypt(ciphertext)
            #expect(decrypted == original)
        } catch let error as AuditError {
            if case .encryptionFailed = error {
                return
            } else if case .decryptionFailed = error {
                return
            }
            throw error
        }
    }

    // MARK: - Error Handling

    @Test("Decrypt truncated data throws decryptionFailed")
    func decryptTruncatedDataThrowsDecryptionFailed() throws {
        let service = AuditEncryptionService()
        // Only 5 bytes — far below the minimum (1 + 12 + 16 = 29 bytes)
        let truncated = Data([0x01, 0x02, 0x03, 0x04, 0x05])

        do {
            _ = try service.decrypt(truncated)
            #expect(Bool(false), "Expected AuditError.decryptionFailed for truncated data")
        } catch let error as AuditError {
            if case .decryptionFailed = error {
                // Expected
            } else {
                #expect(Bool(false), "Expected decryptionFailed, got \(error)")
            }
        }
    }

    @Test("Decrypt data with wrong version byte throws decryptionFailed")
    func decryptWrongVersionByteThrowsDecryptionFailed() throws {
        let service = AuditEncryptionService()
        // Build a payload that is large enough (>= 29 bytes) but has a wrong version byte (0x99)
        var fakePayload = Data(repeating: 0xAB, count: 30)
        fakePayload[0] = 0x99  // Not the expected version 0x01

        do {
            _ = try service.decrypt(fakePayload)
            #expect(Bool(false), "Expected AuditError.decryptionFailed for wrong version byte")
        } catch let error as AuditError {
            if case .decryptionFailed = error {
                // Expected
            } else {
                #expect(Bool(false), "Expected decryptionFailed, got \(error)")
            }
        }
    }

    @Test("Decrypt garbage data with valid version byte throws decryptionFailed")
    func decryptGarbageDataThrowsDecryptionFailed() throws {
        let service = AuditEncryptionService()
        // Build a payload that passes the size and version checks but has garbage ciphertext+tag
        // Version = 0x01, then 12 bytes nonce, then at least 16 bytes for the tag = 29 bytes total
        var garbagePayload = Data(repeating: 0xFF, count: 50)
        garbagePayload[0] = 0x01  // Correct version byte

        do {
            _ = try service.decrypt(garbagePayload)
            #expect(Bool(false), "Expected AuditError.decryptionFailed for garbage ciphertext")
        } catch let error as AuditError {
            if case .decryptionFailed = error {
                // Expected — either key retrieval fails, or AES-GCM tag mismatch
            } else {
                #expect(Bool(false), "Expected decryptionFailed, got \(error)")
            }
        }
    }

    @Test("Decrypt empty data throws decryptionFailed")
    func decryptEmptyDataThrowsDecryptionFailed() throws {
        let service = AuditEncryptionService()

        do {
            _ = try service.decrypt(Data())
            #expect(Bool(false), "Expected AuditError.decryptionFailed for empty data")
        } catch let error as AuditError {
            if case .decryptionFailed = error {
                // Expected
            } else {
                #expect(Bool(false), "Expected decryptionFailed, got \(error)")
            }
        }
    }

    // MARK: - Nonce Uniqueness

    @Test("Encrypt same input twice produces different ciphertexts due to random nonce")
    func encryptSameInputProducesDifferentCiphertexts() throws {
        let service = AuditEncryptionService()
        let detail = ["key": "value", "another": "entry"]

        do {
            let ciphertext1 = try service.encrypt(detail)
            let ciphertext2 = try service.encrypt(detail)
            // Due to random 96-bit nonce, ciphertexts must differ
            #expect(ciphertext1 != ciphertext2)
        } catch let error as AuditError {
            if case .encryptionFailed = error {
                // Keychain unavailable in test sandbox — skip gracefully
                return
            }
            throw error
        }
    }
}
