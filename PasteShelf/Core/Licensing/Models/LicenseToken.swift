//
//  LicenseToken.swift
//  PasteShelf
//
//  JWT-based license token structure for PasteShelf licensing.
//  Contains token parsing, base64URL encoding/decoding, and header structures.
//

import Foundation

// MARK: - JWT Token Structure

/// Represents a parsed JWT license token
struct LicenseToken: Sendable {
    /// JWT header
    let header: JWTHeader

    /// JWT claims (payload)
    let claims: LicenseClaims

    /// Original signature data
    let signature: Data

    /// Raw token string
    let rawToken: String

    /// The signed data portion (header.payload)
    var signedData: Data {
        guard let dotIndex = rawToken.lastIndex(of: ".") else {
            return Data()
        }
        let signedPortion = String(rawToken[..<dotIndex])
        return Data(signedPortion.utf8)
    }
}

// MARK: - JWT Header

/// JWT header structure
struct JWTHeader: Codable, Sendable {
    /// Algorithm (should be RS256)
    let alg: String

    /// Token type (should be JWT)
    let typ: String

    /// Key ID for key rotation
    let kid: String?

    /// Validate header values
    func validate() throws {
        guard alg == "RS256" else {
            throw LicenseError.invalidSignature
        }
        guard typ == "JWT" else {
            throw LicenseError.malformedToken
        }
    }
}

// MARK: - License Server Configuration

/// Expected values for license validation
enum LicenseServerConfig {
    /// Expected token issuer
    static let issuer = "https://license.pasteshelf.app"

    /// Expected token audience
    static let audience = "pasteshelf-client"

    /// Public key resource name (in bundle)
    static let publicKeyResource = "license-public"

    /// Public key file extension
    static let publicKeyExtension = "pem"
}

// MARK: - Base64URL Encoding/Decoding

extension Data {
    /// Initialize from Base64URL encoded string
    /// - Parameter base64URLEncoded: Base64URL encoded string
    init?(base64URLEncoded: String) {
        // Convert Base64URL to standard Base64
        var base64 = base64URLEncoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let paddingLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: paddingLength)

        self.init(base64Encoded: base64)
    }

    /// Convert to Base64URL encoded string
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Token Parser

/// Parser for JWT license tokens
enum LicenseTokenParser {
    /// Parse a JWT token string into components
    /// - Parameter tokenString: The raw JWT token
    /// - Returns: Parsed LicenseToken
    /// - Throws: LicenseError if parsing fails
    static func parse(_ tokenString: String) throws -> LicenseToken {
        // Split into parts
        let parts = tokenString.split(separator: ".")
        guard parts.count == 3 else {
            throw LicenseError.malformedToken
        }

        // Decode header
        guard let headerData = Data(base64URLEncoded: String(parts[0])) else {
            throw LicenseError.malformedToken
        }

        let header: JWTHeader
        do {
            header = try JSONDecoder().decode(JWTHeader.self, from: headerData)
            try header.validate()
        } catch let error as LicenseError {
            throw error
        } catch {
            throw LicenseError.malformedToken
        }

        // Decode payload
        guard let payloadData = Data(base64URLEncoded: String(parts[1])) else {
            throw LicenseError.malformedToken
        }

        let claims: LicenseClaims
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            claims = try decoder.decode(LicenseClaims.self, from: payloadData)
        } catch {
            throw LicenseError.malformedToken
        }

        // Decode signature
        guard let signature = Data(base64URLEncoded: String(parts[2])) else {
            throw LicenseError.malformedToken
        }

        return LicenseToken(
            header: header,
            claims: claims,
            signature: signature,
            rawToken: tokenString
        )
    }
}

// MARK: - License Key Format

/// Utilities for license key handling
enum LicenseKeyFormat {
    /// License key regex pattern: PS-XXX-XXXX-XXXX-XXXX
    static let pattern = #"^PS-(?:PRO|ENT)-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$"#

    /// Validate license key format
    /// - Parameter key: The license key to validate
    /// - Returns: True if format is valid
    static func isValid(_ key: String) -> Bool {
        let normalized = key.uppercased().trimmingCharacters(in: .whitespaces)
        return normalized.range(of: pattern, options: .regularExpression) != nil
    }

    /// Normalize a license key (uppercase, trim whitespace)
    /// - Parameter key: The license key to normalize
    /// - Returns: Normalized key
    static func normalize(_ key: String) -> String {
        key.uppercased().trimmingCharacters(in: .whitespaces)
    }

    /// Extract edition from license key
    /// - Parameter key: The license key
    /// - Returns: The tier indicated by the key
    static func tier(from key: String) -> LicenseTier? {
        let normalized = normalize(key)
        if normalized.hasPrefix("PS-PRO-") {
            return .pro
        } else if normalized.hasPrefix("PS-ENT-") {
            return .enterprise
        }
        return nil
    }
}
