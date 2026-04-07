//
//  SAMLResponse.swift
//  PasteShelf
//
//  Represents a complete SAML 2.0 Response for Enterprise SSO.
//  Contains status information and embedded assertion(s).
//

import Foundation

// MARK: - SAMLResponse

/// A complete SAML 2.0 Response message
struct SAMLResponse: Codable, Sendable, Equatable {
    /// Unique identifier for this response
    let id: String

    /// Reference to the original authentication request
    let inResponseTo: String?

    /// Destination URL for this response
    let destination: String?

    /// When the response was issued
    let issueInstant: Date

    /// Issuer of the response (Identity Provider entity ID)
    let issuer: String

    /// Version of the SAML response (typically "2.0")
    let version: String

    /// Status of the authentication
    let status: SAMLStatus

    /// The embedded SAML assertion(s)
    let assertions: [SAMLAssertion]

    // MARK: - Convenience Properties

    /// The primary (first) assertion in the response
    var primaryAssertion: SAMLAssertion? {
        assertions.first
    }

    /// Whether the authentication was successful
    var isSuccess: Bool {
        status.code == .success
    }

    /// Error message if authentication failed
    var errorMessage: String? {
        guard !isSuccess else {
            return nil
        }
        return status.message ?? status.code.displayName
    }

    // MARK: - Validation

    /// Validates the response structure (not cryptographic validation)
    /// - Parameters:
    ///   - expectedDestination: Expected ACS URL
    ///   - expectedRequestId: Original AuthnRequest ID (optional)
    ///   - audience: Expected audience (SP entity ID)
    /// - Returns: Validation result
    func validate(
        expectedDestination: String,
        expectedRequestId: String?,
        audience: String
    ) -> SAMLValidationResult {
        // Check status
        guard isSuccess else {
            return .failure(.authenticationFailed(status.code.displayName))
        }

        // Check destination
        if let dest = destination, dest != expectedDestination {
            return .failure(.invalidDestination(expected: expectedDestination, actual: dest))
        }

        // Check InResponseTo
        if let expectedId = expectedRequestId, inResponseTo != expectedId {
            return .failure(.invalidInResponseTo(expected: expectedId, actual: inResponseTo))
        }

        // Must have at least one assertion
        guard let assertion = primaryAssertion else {
            return .failure(.missingAssertion)
        }

        // Check assertion validity
        guard assertion.isValid() else {
            return .failure(.assertionExpired)
        }

        // Check audience restriction
        guard assertion.isIntendedFor(audience: audience) else {
            return .failure(.invalidAudience(expected: audience))
        }

        return .success
    }
}

// MARK: - SAMLStatus

/// Status of a SAML response
struct SAMLStatus: Codable, Sendable, Equatable {
    /// Top-level status code
    let code: SAMLStatusCode

    /// Sub-status code (optional, provides more detail)
    let subCode: SAMLStatusCode?

    /// Human-readable status message
    let message: String?
}

// MARK: - SAMLStatusCode

/// SAML status codes
enum SAMLStatusCode: String, Codable, Sendable {
    /// Success
    case success = "urn:oasis:names:tc:SAML:2.0:status:Success"

    // Top-level errors
    case requester = "urn:oasis:names:tc:SAML:2.0:status:Requester"
    case responder = "urn:oasis:names:tc:SAML:2.0:status:Responder"
    case versionMismatch = "urn:oasis:names:tc:SAML:2.0:status:VersionMismatch"

    // Second-level errors
    case authnFailed = "urn:oasis:names:tc:SAML:2.0:status:AuthnFailed"
    case invalidAttrNameOrValue = "urn:oasis:names:tc:SAML:2.0:status:InvalidAttrNameOrValue"
    case invalidNameIDPolicy = "urn:oasis:names:tc:SAML:2.0:status:InvalidNameIDPolicy"
    case noAuthnContext = "urn:oasis:names:tc:SAML:2.0:status:NoAuthnContext"
    case noAvailableIDP = "urn:oasis:names:tc:SAML:2.0:status:NoAvailableIDP"
    case noPassive = "urn:oasis:names:tc:SAML:2.0:status:NoPassive"
    case noSupportedIDP = "urn:oasis:names:tc:SAML:2.0:status:NoSupportedIDP"
    case partialLogout = "urn:oasis:names:tc:SAML:2.0:status:PartialLogout"
    case proxyCountExceeded = "urn:oasis:names:tc:SAML:2.0:status:ProxyCountExceeded"
    case requestDenied = "urn:oasis:names:tc:SAML:2.0:status:RequestDenied"
    case requestUnsupported = "urn:oasis:names:tc:SAML:2.0:status:RequestUnsupported"
    case requestVersionDeprecated = "urn:oasis:names:tc:SAML:2.0:status:RequestVersionDeprecated"
    case requestVersionTooHigh = "urn:oasis:names:tc:SAML:2.0:status:RequestVersionTooHigh"
    case requestVersionTooLow = "urn:oasis:names:tc:SAML:2.0:status:RequestVersionTooLow"
    case resourceNotRecognized = "urn:oasis:names:tc:SAML:2.0:status:ResourceNotRecognized"
    case tooManyResponses = "urn:oasis:names:tc:SAML:2.0:status:TooManyResponses"
    case unknownAttrProfile = "urn:oasis:names:tc:SAML:2.0:status:UnknownAttrProfile"
    case unknownPrincipal = "urn:oasis:names:tc:SAML:2.0:status:UnknownPrincipal"
    case unsupportedBinding = "urn:oasis:names:tc:SAML:2.0:status:UnsupportedBinding"

    /// Unknown
    case unknown

    // MARK: Lifecycle

    init(rawValue: String) {
        self = Self.rawValueLookup[rawValue] ?? .unknown
    }

    // MARK: Internal

    var displayName: String {
        switch self {
        case .success:
            "Success"
        case .requester:
            "Request error"
        case .responder:
            "Identity provider error"
        case .versionMismatch:
            "SAML version mismatch"
        case .authnFailed:
            "Authentication failed"
        case .invalidAttrNameOrValue:
            "Invalid attribute"
        case .invalidNameIDPolicy:
            "Invalid NameID policy"
        case .noAuthnContext:
            "No authentication context"
        case .noAvailableIDP:
            "No available identity provider"
        case .noPassive:
            "Cannot authenticate passively"
        case .noSupportedIDP:
            "No supported identity provider"
        case .partialLogout:
            "Partial logout"
        case .proxyCountExceeded:
            "Proxy count exceeded"
        case .requestDenied:
            "Request denied"
        case .requestUnsupported:
            "Request not supported"
        case .requestVersionDeprecated:
            "Request version deprecated"
        case .requestVersionTooHigh:
            "Request version too high"
        case .requestVersionTooLow:
            "Request version too low"
        case .resourceNotRecognized:
            "Resource not recognized"
        case .tooManyResponses:
            "Too many responses"
        case .unknownAttrProfile:
            "Unknown attribute profile"
        case .unknownPrincipal:
            "Unknown principal"
        case .unsupportedBinding:
            "Unsupported binding"
        case .unknown:
            "Unknown error"
        }
    }

    // MARK: Private

    /// Lookup table mapping SAML status URN strings to their enum cases.
    private static let rawValueLookup: [String: SAMLStatusCode] = {
        let allKnownCases: [SAMLStatusCode] = [
            .success, .requester, .responder, .versionMismatch,
            .authnFailed, .invalidAttrNameOrValue, .invalidNameIDPolicy,
            .noAuthnContext, .noAvailableIDP, .noPassive, .noSupportedIDP,
            .partialLogout, .proxyCountExceeded, .requestDenied,
            .requestUnsupported, .requestVersionDeprecated,
            .requestVersionTooHigh, .requestVersionTooLow,
            .resourceNotRecognized, .tooManyResponses,
            .unknownAttrProfile, .unknownPrincipal, .unsupportedBinding,
        ]
        var lookup: [String: SAMLStatusCode] = [:]
        for code in allKnownCases {
            lookup[code.rawValue] = code
        }
        return lookup
    }()
}

// MARK: - SAMLValidationResult

/// Result of SAML response validation
enum SAMLValidationResult: Equatable, Sendable {
    case success
    case failure(SAMLValidationError)

    // MARK: Internal

    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    var error: SAMLValidationError? {
        if case let .failure(error) = self {
            return error
        }
        return nil
    }
}

// MARK: - SAMLValidationError

/// Errors that can occur during SAML validation
enum SAMLValidationError: Error, LocalizedError, Equatable, Sendable {
    case authenticationFailed(String)
    case invalidDestination(expected: String, actual: String)
    case invalidInResponseTo(expected: String, actual: String?)
    case missingAssertion
    case assertionExpired
    case invalidAudience(expected: String)
    case signatureInvalid
    case signatureMissing
    case certificateInvalid
    case certificateMismatch
    case xmlParsingFailed(String)
    case invalidStructure(String)
    case issuerMismatch(expected: String, actual: String)

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case let .authenticationFailed(reason):
            "Authentication failed: \(reason)"
        case let .invalidDestination(expected, actual):
            "Invalid destination: expected \(expected), got \(actual)"
        case let .invalidInResponseTo(expected, actual):
            "Invalid InResponseTo: expected \(expected), got \(actual ?? "nil")"
        case .missingAssertion:
            "SAML response contains no assertion"
        case .assertionExpired:
            "SAML assertion has expired"
        case let .invalidAudience(expected):
            "SAML assertion not intended for audience: \(expected)"
        case .signatureInvalid:
            "SAML signature is invalid"
        case .signatureMissing:
            "SAML signature is missing"
        case .certificateInvalid:
            "IdP certificate is invalid"
        case .certificateMismatch:
            "IdP certificate does not match configured certificate"
        case let .xmlParsingFailed(reason):
            "Failed to parse SAML XML: \(reason)"
        case let .invalidStructure(reason):
            "Invalid SAML structure: \(reason)"
        case let .issuerMismatch(expected, actual):
            "Issuer mismatch: expected \(expected), got \(actual)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .authenticationFailed:
            "Try logging in again or contact your administrator."
        case .invalidDestination,
             .invalidInResponseTo:
            "This may indicate a replay attack or misconfiguration. Contact your administrator."
        case .missingAssertion:
            "The identity provider did not include user information. Contact your administrator."
        case .assertionExpired:
            "Your session has expired. Please log in again."
        case .invalidAudience:
            "The identity provider is not configured correctly. Contact your administrator."
        case .signatureInvalid,
             .signatureMissing:
            "The SAML response could not be verified. This may indicate tampering."
        case .certificateInvalid,
             .certificateMismatch:
            "The identity provider certificate has changed. Contact your administrator to update SSO configuration."
        case .xmlParsingFailed,
             .invalidStructure:
            "The identity provider sent an invalid response. Contact your administrator."
        case .issuerMismatch:
            "The response came from an unexpected identity provider. Verify SSO configuration."
        }
    }
}
