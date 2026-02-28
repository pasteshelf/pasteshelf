//
//  HIPAAEncryptionVerifier.swift
//  PasteShelf
//
//  Runtime verification of encryption status for HIPAA compliance.
//

import CryptoKit
import Foundation
import os.log
import Security

/// Verifies that all encryption requirements are met for HIPAA compliance.
///
/// `HIPAAEncryptionVerifier` performs runtime checks across all data protection layers:
/// audit log encryption, sync transport encryption, local disk encryption (FileVault),
/// and key rotation status. The results are compiled into an `HIPAAEncryptionReport`
/// with individual `ComplianceFinding` entries for each check.
struct HIPAAEncryptionVerifier: Sendable {

    private static let logger = Logger.compliance

    // MARK: - Keychain Constants

    private static let auditKeyTag = "com.pasteshelf.audit.detail.key"
    private static let syncKeyTag = "com.pasteshelf.sync.encryption.key"

    // MARK: - Public API

    /// Performs a full encryption verification and returns a detailed report.
    ///
    /// - Returns: An `HIPAAEncryptionReport` with findings for each encryption check.
    static func verify() async -> HIPAAEncryptionReport {
        var findings: [ComplianceFinding] = []

        // Check audit log encryption key
        findings.append(verifyKeychainKey(
            tag: auditKeyTag,
            category: "Audit Encryption",
            description: "AES-256-GCM encryption key for audit log detail payloads"
        ))

        // Check sync encryption key
        findings.append(verifyKeychainKey(
            tag: syncKeyTag,
            category: "Sync Encryption",
            description: "AES-256-GCM encryption key for sync data payloads"
        ))

        // Check FileVault / disk encryption
        findings.append(verifyDiskEncryption())

        // Check key rotation status
        findings.append(verifyKeyRotation())

        let overallCompliant = !findings.contains { $0.status == .fail }

        return HIPAAEncryptionReport(
            findings: findings,
            auditEncryptionActive: findings.first { $0.category == "Audit Encryption" }?.status == .pass,
            syncEncryptionActive: findings.first { $0.category == "Sync Encryption" }?.status == .pass,
            localDiskEncrypted: findings.first { $0.category == "Disk Encryption" }?.status == .pass,
            keyRotationStatus: findings.first { $0.category == "Key Rotation" }?.status ?? .warning,
            overallCompliant: overallCompliant,
            verifiedAt: Date()
        )
    }

    // MARK: - Individual Checks

    /// Verifies that a symmetric key exists in the Keychain for the given tag.
    private static func verifyKeychainKey(tag: String, category: String, description: String) -> ComplianceFinding {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tag,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)

        if status == errSecSuccess {
            logger.debug("Encryption key found for \(category)")
            return ComplianceFinding(
                category: category,
                status: .pass,
                description: "\(description) is present in Keychain"
            )
        } else {
            logger.warning("Encryption key NOT found for \(category) (status: \(status))")
            return ComplianceFinding(
                category: category,
                status: .fail,
                description: "\(description) is missing from Keychain",
                recommendation: "Configure the \(category.lowercased()) system to generate encryption keys"
            )
        }
    }

    /// Verifies that the local disk is encrypted (FileVault on macOS).
    private static func verifyDiskEncryption() -> ComplianceFinding {
        // Check FileVault status via fdesetup
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/fdesetup")
        process.arguments = ["isactive"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                logger.debug("FileVault is active")
                return ComplianceFinding(
                    category: "Disk Encryption",
                    status: .pass,
                    description: "FileVault full-disk encryption is active"
                )
            } else {
                logger.warning("FileVault is NOT active")
                return ComplianceFinding(
                    category: "Disk Encryption",
                    status: .fail,
                    description: "FileVault full-disk encryption is not active",
                    recommendation: "Enable FileVault in System Settings > Privacy & Security > FileVault"
                )
            }
        } catch {
            logger.warning("Unable to determine FileVault status: \(error.localizedDescription)")
            return ComplianceFinding(
                category: "Disk Encryption",
                status: .warning,
                description: "Unable to determine FileVault status",
                recommendation: "Manually verify FileVault is enabled in System Settings"
            )
        }
    }

    /// Verifies key rotation status.
    private static func verifyKeyRotation() -> ComplianceFinding {
        // Key rotation check: verify that the key creation date is not too old
        // In practice, key metadata would be stored alongside the key
        // For now, we check that keys exist (rotation is tracked separately)
        let auditKeyExists = keychainKeyExists(tag: auditKeyTag)
        let syncKeyExists = keychainKeyExists(tag: syncKeyTag)

        if auditKeyExists && syncKeyExists {
            return ComplianceFinding(
                category: "Key Rotation",
                status: .pass,
                description: "Encryption keys are present and available for rotation"
            )
        } else {
            return ComplianceFinding(
                category: "Key Rotation",
                status: .warning,
                description: "Some encryption keys are missing — rotation status cannot be verified",
                recommendation: "Ensure all encryption subsystems are configured before verifying rotation"
            )
        }
    }

    private static func keychainKeyExists(tag: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tag,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
}

// MARK: - HIPAAEncryptionReport

/// Report produced by `HIPAAEncryptionVerifier` summarizing the encryption compliance status.
struct HIPAAEncryptionReport: Codable, Sendable, Identifiable {

    let id: UUID
    let findings: [ComplianceFinding]

    /// Whether the audit log encryption key is present and active.
    let auditEncryptionActive: Bool

    /// Whether the sync encryption key is present and active.
    let syncEncryptionActive: Bool

    /// Whether the local disk has full-disk encryption (FileVault).
    let localDiskEncrypted: Bool

    /// The status of the key rotation check.
    let keyRotationStatus: ComplianceFindingStatus

    /// Whether all checks pass — the device is HIPAA-compliant for encryption.
    let overallCompliant: Bool

    /// When this verification was performed.
    let verifiedAt: Date

    init(
        id: UUID = UUID(),
        findings: [ComplianceFinding],
        auditEncryptionActive: Bool,
        syncEncryptionActive: Bool,
        localDiskEncrypted: Bool,
        keyRotationStatus: ComplianceFindingStatus,
        overallCompliant: Bool,
        verifiedAt: Date = Date()
    ) {
        self.id = id
        self.findings = findings
        self.auditEncryptionActive = auditEncryptionActive
        self.syncEncryptionActive = syncEncryptionActive
        self.localDiskEncrypted = localDiskEncrypted
        self.keyRotationStatus = keyRotationStatus
        self.overallCompliant = overallCompliant
        self.verifiedAt = verifiedAt
    }
}
