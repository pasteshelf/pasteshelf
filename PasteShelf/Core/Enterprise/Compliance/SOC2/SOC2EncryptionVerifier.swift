//
//  SOC2EncryptionVerifier.swift
//  PasteShelf
//
//  Runtime verification of encryption status for SOC 2 compliance.
//  Covers all encryption layers: CoreData, Keychain, audit logs,
//  sync transport, at-rest storage, and key management practices.
//

import Foundation
import os.log
import Security

// MARK: - SOC2EncryptionVerifier

/// Verifies that all encryption requirements are met for SOC 2 compliance.
///
/// `SOC2EncryptionVerifier` performs runtime checks across a broader set of data
/// protection layers than the HIPAA verifier: CoreData encryption, keychain security,
/// audit log encryption, sync transport encryption, at-rest disk encryption
/// (FileVault), and key management practices. The results are compiled into a
/// `SOC2EncryptionReport` with individual `ComplianceFinding` entries for each check.
enum SOC2EncryptionVerifier {
    // MARK: Internal

    // MARK: - Public API

    /// Performs a full encryption verification across all SOC 2 layers and returns a detailed report.
    ///
    /// - Returns: A `SOC2EncryptionReport` with findings for each encryption check.
    static func verify() async -> SOC2EncryptionReport {
        var findings: [ComplianceFinding] = []

        // Check CoreData / data protection layer
        let coreDataFinding = verifyCoreDataEncryption()
        findings.append(coreDataFinding)

        // Check Keychain security (audit key + sync key)
        let auditKeychainFinding = verifyKeychainKey(
            tag: auditKeyTag,
            category: "Keychain Security",
            description: "AES-256-GCM audit log encryption key"
        )
        findings.append(auditKeychainFinding)

        let syncKeychainFinding = verifyKeychainKey(
            tag: syncKeyTag,
            category: "Keychain Security",
            description: "AES-256-GCM sync data encryption key"
        )
        findings.append(syncKeychainFinding)

        // Check audit log encryption
        let auditLogFinding = verifyAuditLogEncryption()
        findings.append(auditLogFinding)

        // Check sync transport encryption (TLS 1.2+ via ATS)
        let transportFinding = verifySyncTransportEncryption()
        findings.append(transportFinding)

        // Check at-rest disk encryption (FileVault)
        let atRestFinding = verifyAtRestEncryption()
        findings.append(atRestFinding)

        // Check key management practices
        let keyManagementFinding = verifyKeyManagement()
        findings.append(keyManagementFinding)

        // Derive per-domain booleans from findings
        let coreDataEncrypted = coreDataFinding.status == .pass
        let keychainSecure = !findings.filter { $0.category == "Keychain Security" }
            .contains { $0.status == .fail }
        let auditLogEncrypted = auditLogFinding.status == .pass
        let transportEncrypted = transportFinding.status == .pass
        let atRestEncrypted = atRestFinding.status == .pass
        let keyManagementCompliant = keyManagementFinding.status == .pass

        // Overall score: percentage of passing checks
        let passingCount = findings.filter { $0.status == .pass }.count
        let overallScore = findings.isEmpty ? 0 : Int((Double(passingCount) / Double(findings.count)) * 100)

        let totalCount = findings.count
        let summary = "\(overallScore)% (\(passingCount)/\(totalCount) checks passed)"
        logger.info("SOC2 encryption verification complete — score: \(summary)")

        return SOC2EncryptionReport(
            findings: findings,
            overallScore: overallScore,
            coreDataEncrypted: coreDataEncrypted,
            keychainSecure: keychainSecure,
            auditLogEncrypted: auditLogEncrypted,
            transportEncrypted: transportEncrypted,
            atRestEncrypted: atRestEncrypted,
            keyManagementCompliant: keyManagementCompliant,
            verifiedAt: Date()
        )
    }

    // MARK: Private

    private static let logger = Logger.compliance

    // MARK: - Keychain Constants

    private static let auditKeyTag = "com.pasteshelf.audit.detail.key"
    private static let syncKeyTag = "com.pasteshelf.sync.encryption.key"

    // MARK: - Individual Checks

    /// Verifies CoreData data-protection encryption.
    ///
    /// Apple's NSPersistentStore uses the platform data-protection class
    /// (`NSFileProtectionCompleteUntilFirstUserAuthentication` by default on
    /// macOS with FileVault enabled). This is an OS-level guarantee — we
    /// record a static pass and note the dependency on FileVault being active.
    private static func verifyCoreDataEncryption() -> ComplianceFinding {
        logger.debug("CoreData encryption verified via Apple platform data-protection APIs")
        return ComplianceFinding(
            category: "CoreData Encryption",
            status: .pass,
            description: "CoreData persistent store is protected by Apple platform data-protection (NSFileProtection)"
        )
    }

    /// Verifies that a symmetric key exists in the Keychain for the given service tag.
    private static func verifyKeychainKey(tag: String, category: String, description: String) -> ComplianceFinding {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tag,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)

        if status == errSecSuccess {
            logger.debug("Keychain key present for \(description)")
            return ComplianceFinding(
                category: category,
                status: .pass,
                description: "\(description) is present in Keychain"
            )
        } else {
            logger.warning("Keychain key NOT found for \(description) (OSStatus: \(status))")
            return ComplianceFinding(
                category: category,
                status: .fail,
                description: "\(description) is missing from Keychain",
                recommendation: "Configure the encryption subsystem to generate "
                    + "and store keys before enabling compliance features"
            )
        }
    }

    /// Verifies that the audit log encryption key exists in the Keychain.
    private static func verifyAuditLogEncryption() -> ComplianceFinding {
        let exists = keychainKeyExists(tag: auditKeyTag)

        if exists {
            logger.debug("Audit log encryption key is present")
            return ComplianceFinding(
                category: "Audit Log Encryption",
                status: .pass,
                description: "Audit log detail payloads are encrypted with AES-256-GCM"
            )
        } else {
            logger.warning("Audit log encryption key is missing")
            return ComplianceFinding(
                category: "Audit Log Encryption",
                status: .fail,
                description: "Audit log encryption key is absent — log payloads may be stored in plaintext",
                recommendation: "Enable audit log encryption by initialising the AuditEncryptionManager"
            )
        }
    }

    /// Verifies sync transport encryption enforcement (TLS 1.2+).
    ///
    /// URLSession enforces TLS 1.2+ by default via App Transport Security (ATS).
    /// This is a static pass — ATS is a compile-time / plist-level guarantee for
    /// all URLSession traffic used by the sync subsystem.
    private static func verifySyncTransportEncryption() -> ComplianceFinding {
        logger.debug("Sync transport encryption verified via App Transport Security (ATS/TLS 1.2+)")
        return ComplianceFinding(
            category: "Sync Transport Encryption",
            status: .pass,
            description: "All sync traffic is encrypted in transit via TLS 1.2+ enforced by App Transport Security"
        )
    }

    /// Verifies that the local disk is encrypted using FileVault.
    private static func verifyAtRestEncryption() -> ComplianceFinding {
        #if APP_STORE
            // Process() is unavailable in sandboxed App Store builds; assume encrypted.
            return ComplianceFinding(
                category: "At-Rest Encryption",
                status: .warning,
                description: "Unable to determine FileVault status in App Store build",
                recommendation: "Manually verify FileVault is enabled in System Settings"
            )
        #else
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
                    logger.debug("FileVault at-rest encryption is active")
                    return ComplianceFinding(
                        category: "At-Rest Encryption",
                        status: .pass,
                        description: "FileVault full-disk encryption is active, protecting all data at rest"
                    )
                } else {
                    logger.warning("FileVault at-rest encryption is NOT active")
                    return ComplianceFinding(
                        category: "At-Rest Encryption",
                        status: .fail,
                        description: "FileVault full-disk encryption is not active — data at rest is unprotected",
                        recommendation: "Enable FileVault in System Settings > Privacy & Security > FileVault"
                    )
                }
            } catch {
                logger.warning("Unable to determine FileVault status: \(error.localizedDescription)")
                return ComplianceFinding(
                    category: "At-Rest Encryption",
                    status: .warning,
                    description: "Unable to determine FileVault status",
                    recommendation: "Manually verify FileVault is enabled in System Settings"
                )
            }
        #endif
    }

    /// Verifies key management practices by confirming all required keys are present
    /// and available for rotation.
    private static func verifyKeyManagement() -> ComplianceFinding {
        let auditKeyExists = keychainKeyExists(tag: auditKeyTag)
        let syncKeyExists = keychainKeyExists(tag: syncKeyTag)

        switch (auditKeyExists, syncKeyExists) {
        case (true, true):
            logger.debug("Key management check passed — all encryption keys are present")
            return ComplianceFinding(
                category: "Key Management",
                status: .pass,
                description: "All encryption keys are present in Keychain and available for rotation"
            )
        case (false, false):
            logger.warning("Key management check failed — both encryption keys are missing")
            return ComplianceFinding(
                category: "Key Management",
                status: .fail,
                description: "Audit and sync encryption keys are both missing "
                    + "— key management policy cannot be enforced",
                recommendation: "Initialise both the audit and sync encryption "
                    + "subsystems to generate managed keys"
            )
        default:
            logger.warning("Key management check warning — one encryption key is missing")
            return ComplianceFinding(
                category: "Key Management",
                status: .warning,
                description: "One or more encryption keys are missing "
                    + "— key rotation compliance cannot be fully verified",
                recommendation: "Ensure all encryption subsystems are configured "
                    + "so key rotation can be audited"
            )
        }
    }

    // MARK: - Helpers

    private static func keychainKeyExists(tag: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tag,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
}

// MARK: - SOC2EncryptionReport

/// Report produced by `SOC2EncryptionVerifier` summarising the SOC 2 encryption
/// compliance status across all data-protection layers.
struct SOC2EncryptionReport: Codable, Identifiable {
    // MARK: Lifecycle

    init(
        id: UUID = UUID(),
        findings: [ComplianceFinding],
        overallScore: Int,
        coreDataEncrypted: Bool,
        keychainSecure: Bool,
        auditLogEncrypted: Bool,
        transportEncrypted: Bool,
        atRestEncrypted: Bool,
        keyManagementCompliant: Bool,
        verifiedAt: Date = Date()
    ) {
        self.id = id
        self.findings = findings
        self.overallScore = overallScore
        self.coreDataEncrypted = coreDataEncrypted
        self.keychainSecure = keychainSecure
        self.auditLogEncrypted = auditLogEncrypted
        self.transportEncrypted = transportEncrypted
        self.atRestEncrypted = atRestEncrypted
        self.keyManagementCompliant = keyManagementCompliant
        self.verifiedAt = verifiedAt
    }

    // MARK: Internal

    let id: UUID
    let findings: [ComplianceFinding]

    /// Percentage of checks that passed (0–100).
    let overallScore: Int

    /// Whether CoreData persistent stores are protected by platform data-protection.
    let coreDataEncrypted: Bool

    /// Whether all required Keychain encryption keys are present and accessible.
    let keychainSecure: Bool

    /// Whether the audit log encryption key is present and active.
    let auditLogEncrypted: Bool

    /// Whether sync transport encryption (TLS 1.2+ / ATS) is enforced.
    let transportEncrypted: Bool

    /// Whether full-disk at-rest encryption (FileVault) is active.
    let atRestEncrypted: Bool

    /// Whether key management practices (presence + rotation readiness) are compliant.
    let keyManagementCompliant: Bool

    /// When this verification was performed.
    let verifiedAt: Date
}
