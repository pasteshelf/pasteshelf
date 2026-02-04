//
//  LicenseValidator.swift
//  PasteShelf
//
//  JWT license token validator using RS256 signature verification.
//  Implements LicenseValidating protocol for the licensing system.
//

import Foundation
import os.log
import Security

/// Validates JWT license tokens using RS256 signature verification
final class LicenseValidator: LicenseValidating {
    // MARK: - Properties

    /// RSA public key for signature verification
    private let publicKey: SecKey

    /// Logger for validation operations
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "license-validator"
    )

    // MARK: - Initialization

    /// Initialize with embedded public key from bundle
    init() throws {
        guard let keyURL = Bundle.main.url(
            forResource: LicenseServerConfig.publicKeyResource,
            withExtension: LicenseServerConfig.publicKeyExtension
        ) else {
            throw LicenseError.invalidPublicKey
        }

        let key = try Self.loadPublicKey(from: keyURL)
        publicKey = key
    }

    /// Initialize with a specific public key (for testing)
    init(publicKey: SecKey) {
        self.publicKey = publicKey
    }

    /// Initialize with PEM key data (for testing)
    init(pemData: Data) throws {
        publicKey = try Self.createPublicKey(from: pemData)
    }

    // MARK: - LicenseValidating Implementation

    /// Verify and decode a JWT license token
    /// - Parameter token: The JWT token string
    /// - Returns: Decoded license claims
    /// - Throws: LicenseError if validation fails
    func verify(_ token: String) throws -> LicenseClaims {
        // Parse token
        let licenseToken = try LicenseTokenParser.parse(token)

        // Verify signature
        guard verifySignature(licenseToken) else {
            logger.error("Signature verification failed")
            throw LicenseError.invalidSignature
        }

        // Verify claims
        try verifyClaims(licenseToken.claims)

        logger.debug("Token verified successfully")
        return licenseToken.claims
    }

    /// Verify token signature only (for quick checks)
    /// - Parameter token: The JWT token string
    /// - Returns: True if signature is valid
    func verifySignature(_ token: String) -> Bool {
        do {
            let licenseToken = try LicenseTokenParser.parse(token)
            return verifySignature(licenseToken)
        } catch {
            return false
        }
    }

    // MARK: - Signature Verification

    /// Verify RS256 signature on license token
    private func verifySignature(_ token: LicenseToken) -> Bool {
        let signedData = token.signedData

        var error: Unmanaged<CFError>?
        let isValid = SecKeyVerifySignature(
            publicKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            signedData as CFData,
            token.signature as CFData,
            &error
        )

        if let error = error?.takeRetainedValue() {
            logger.warning("Signature verification error: \(error.localizedDescription)")
        }

        return isValid
    }

    // MARK: - Claims Verification

    /// Verify JWT claims
    private func verifyClaims(_ claims: LicenseClaims) throws {
        let now = Date()

        // Check expiration
        if claims.exp < now {
            logger.warning("Token expired at \(claims.exp)")
            throw LicenseError.expired
        }

        // Check not before
        if claims.nbf > now {
            logger.warning("Token not yet valid until \(claims.nbf)")
            throw LicenseError.notYetValid
        }

        // Check issuer
        if claims.iss != LicenseServerConfig.issuer {
            logger.warning("Invalid issuer: \(claims.iss)")
            throw LicenseError.invalidIssuer
        }

        // Check audience
        if claims.aud != LicenseServerConfig.audience {
            logger.warning("Invalid audience: \(claims.aud)")
            throw LicenseError.invalidAudience
        }

        logger.debug("All claims verified")
    }

    // MARK: - Public Key Loading

    /// Load RSA public key from file URL
    private static func loadPublicKey(from url: URL) throws -> SecKey {
        let pemData = try Data(contentsOf: url)
        return try createPublicKey(from: pemData)
    }

    /// Create SecKey from PEM data
    private static func createPublicKey(from pemData: Data) throws -> SecKey {
        // Convert PEM to DER
        guard let pemString = String(data: pemData, encoding: .utf8) else {
            throw LicenseError.invalidPublicKey
        }

        let derData = try extractDERFromPEM(pemString)

        // Create SecKey from DER
        let keyDict: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 2048,
        ]

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(derData as CFData, keyDict as CFDictionary, &error) else {
            if let error = error?.takeRetainedValue() {
                throw LicenseError.unknown("Failed to create key: \(error.localizedDescription)")
            }
            throw LicenseError.invalidPublicKey
        }

        return key
    }

    /// Extract DER data from PEM string
    private static func extractDERFromPEM(_ pem: String) throws -> Data {
        // Remove PEM headers and whitespace
        var base64String = pem
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----BEGIN RSA PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END RSA PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let derData = Data(base64Encoded: base64String) else {
            throw LicenseError.invalidPublicKey
        }

        return derData
    }
}

// MARK: - Embedded Public Key (Development)

extension LicenseValidator {
    /// Create validator with embedded development key
    /// NOTE: In production, the public key should be in the app bundle
    static func withEmbeddedKey() throws -> LicenseValidator {
        // This is a placeholder - in production, use Bundle resource
        // For development/testing, you can embed a test key here
        let testPEM = """
        -----BEGIN PUBLIC KEY-----
        MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAu1SU1LfVLPHCozMxH2Mo
        4lgOEePzNm0tRgeLezV6ffAt0gunVTLw7onLRnrq0/IzW7yWR7QkrmBL7jTKEn5u
        +qKhbwKfBstIs+bMY2Zkp18gnTxKLxoS2tFczGkPLPgizskuemMghRniWaoLcyeh
        kd3qqGElvW/VDL5AaWTg0nLVkjRo9z+40RQzuVaE8AkAFmxZzow3x+VJYKdjykkJ
        0iT9wCS0DRTXu269V264Vf/3jvredZiKRkgwlL9xNAwxXFg0x/XFw005UWVRIkdg
        cKWTjpBP2dPwVZ4WWC+9aGVd+Gyn1o0CLelf4rEjGoXbAAEgAqeGUxrcIlbjXfbc
        mwIDAQAB
        -----END PUBLIC KEY-----
        """
        return try LicenseValidator(pemData: Data(testPEM.utf8))
    }
}

// MARK: - Device Verification

extension LicenseValidator {
    /// Verify device ID matches current device
    /// - Parameters:
    ///   - claims: License claims containing device ID
    ///   - currentDeviceId: Current device's ID
    /// - Throws: LicenseError.deviceMismatch if IDs don't match
    func verifyDevice(claims: LicenseClaims, currentDeviceId: String) throws {
        if claims.deviceId != currentDeviceId {
            throw LicenseError.deviceMismatch
        }
    }
}
