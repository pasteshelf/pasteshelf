//
//  SAMLResponse.swift
//  PasteShelf
//
//  Represents a complete SAML 2.0 Response for Enterprise SSO.
//  Contains status information and embedded assertion(s).
//

import Foundation

/// A complete SAML 2.0 Response message
struct SAMLResponse: Codable, Sendable, Equatable {
    // MARK: - Properties

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
        guard !isSuccess else { return nil }
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

// MARK: - Status

/// Status of a SAML response
struct SAMLStatus: Codable, Sendable, Equatable {
    /// Top-level status code
    let code: SAMLStatusCode

    /// Sub-status code (optional, provides more detail)
    let subCode: SAMLStatusCode?

    /// Human-readable status message
    let message: String?
}

/// SAML status codes
enum SAMLStatusCode: String, Codable, Sendable {
    // Success
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

    // Unknown
    case unknown = "unknown"

    init(rawValue: String) {
        switch rawValue {
        case SAMLStatusCode.success.rawValue:
            self = .success
        case SAMLStatusCode.requester.rawValue:
            self = .requester
        case SAMLStatusCode.responder.rawValue:
            self = .responder
        case SAMLStatusCode.versionMismatch.rawValue:
            self = .versionMismatch
        case SAMLStatusCode.authnFailed.rawValue:
            self = .authnFailed
        case SAMLStatusCode.invalidAttrNameOrValue.rawValue:
            self = .invalidAttrNameOrValue
        case SAMLStatusCode.invalidNameIDPolicy.rawValue:
            self = .invalidNameIDPolicy
        case SAMLStatusCode.noAuthnContext.rawValue:
            self = .noAuthnContext
        case SAMLStatusCode.noAvailableIDP.rawValue:
            self = .noAvailableIDP
        case SAMLStatusCode.noPassive.rawValue:
            self = .noPassive
        case SAMLStatusCode.noSupportedIDP.rawValue:
            self = .noSupportedIDP
        case SAMLStatusCode.partialLogout.rawValue:
            self = .partialLogout
        case SAMLStatusCode.proxyCountExceeded.rawValue:
            self = .proxyCountExceeded
        case SAMLStatusCode.requestDenied.rawValue:
            self = .requestDenied
        case SAMLStatusCode.requestUnsupported.rawValue:
            self = .requestUnsupported
        case SAMLStatusCode.requestVersionDeprecated.rawValue:
            self = .requestVersionDeprecated
        case SAMLStatusCode.requestVersionTooHigh.rawValue:
            self = .requestVersionTooHigh
        case SAMLStatusCode.requestVersionTooLow.rawValue:
            self = .requestVersionTooLow
        case SAMLStatusCode.resourceNotRecognized.rawValue:
            self = .resourceNotRecognized
        case SAMLStatusCode.tooManyResponses.rawValue:
            self = .tooManyResponses
        case SAMLStatusCode.unknownAttrProfile.rawValue:
            self = .unknownAttrProfile
        case SAMLStatusCode.unknownPrincipal.rawValue:
            self = .unknownPrincipal
        case SAMLStatusCode.unsupportedBinding.rawValue:
            self = .unsupportedBinding
        default:
            self = .unknown
        }
    }

    var displayName: String {
        switch self {
        case .success:
            return String(localized: "Success")
        case .requester:
            return String(localized: "Request error")
        case .responder:
            return String(localized: "Identity provider error")
        case .versionMismatch:
            return String(localized: "SAML version mismatch")
        case .authnFailed:
            return String(localized: "Authentication failed")
        case .invalidAttrNameOrValue:
            return String(localized: "Invalid attribute")
        case .invalidNameIDPolicy:
            return String(localized: "Invalid NameID policy")
        case .noAuthnContext:
            return String(localized: "No authentication context")
        case .noAvailableIDP:
            return String(localized: "No available identity provider")
        case .noPassive:
            return String(localized: "Cannot authenticate passively")
        case .noSupportedIDP:
            return String(localized: "No supported identity provider")
        case .partialLogout:
            return String(localized: "Partial logout")
        case .proxyCountExceeded:
            return String(localized: "Proxy count exceeded")
        case .requestDenied:
            return String(localized: "Request denied")
        case .requestUnsupported:
            return String(localized: "Request not supported")
        case .requestVersionDeprecated:
            return String(localized: "Request version deprecated")
        case .requestVersionTooHigh:
            return String(localized: "Request version too high")
        case .requestVersionTooLow:
            return String(localized: "Request version too low")
        case .resourceNotRecognized:
            return String(localized: "Resource not recognized")
        case .tooManyResponses:
            return String(localized: "Too many responses")
        case .unknownAttrProfile:
            return String(localized: "Unknown attribute profile")
        case .unknownPrincipal:
            return String(localized: "Unknown principal")
        case .unsupportedBinding:
            return String(localized: "Unsupported binding")
        case .unknown:
            return String(localized: "Unknown error")
        }
    }
}

// MARK: - Validation Result

/// Result of SAML response validation
enum SAMLValidationResult: Equatable, Sendable {
    case success
    case failure(SAMLValidationError)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var error: SAMLValidationError? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

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

    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let reason):
            return String(localized: "Authentication failed: \(reason)")
        case .invalidDestination(let expected, let actual):
            return String(localized: "Invalid destination: expected \(expected), got \(actual)")
        case .invalidInResponseTo(let expected, let actual):
            return String(localized: "Invalid InResponseTo: expected \(expected), got \(actual ?? "nil")")
        case .missingAssertion:
            return String(localized: "SAML response contains no assertion")
        case .assertionExpired:
            return String(localized: "SAML assertion has expired")
        case .invalidAudience(let expected):
            return String(localized: "SAML assertion not intended for audience: \(expected)")
        case .signatureInvalid:
            return String(localized: "SAML signature is invalid")
        case .signatureMissing:
            return String(localized: "SAML signature is missing")
        case .certificateInvalid:
            return String(localized: "IdP certificate is invalid")
        case .certificateMismatch:
            return String(localized: "IdP certificate does not match configured certificate")
        case .xmlParsingFailed(let reason):
            return String(localized: "Failed to parse SAML XML: \(reason)")
        case .invalidStructure(let reason):
            return String(localized: "Invalid SAML structure: \(reason)")
        case .issuerMismatch(let expected, let actual):
            return String(localized: "Issuer mismatch: expected \(expected), got \(actual)")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .authenticationFailed:
            return String(localized: "Try logging in again or contact your administrator.")
        case .invalidDestination, .invalidInResponseTo:
            return String(localized: "This may indicate a replay attack or misconfiguration. Contact your administrator.")
        case .missingAssertion:
            return String(localized: "The identity provider did not include user information. Contact your administrator.")
        case .assertionExpired:
            return String(localized: "Your session has expired. Please log in again.")
        case .invalidAudience:
            return String(localized: "The identity provider is not configured correctly. Contact your administrator.")
        case .signatureInvalid, .signatureMissing:
            return String(localized: "The SAML response could not be verified. This may indicate tampering.")
        case .certificateInvalid, .certificateMismatch:
            return String(localized: "The identity provider certificate has changed. Contact your administrator to update SSO configuration.")
        case .xmlParsingFailed, .invalidStructure:
            return String(localized: "The identity provider sent an invalid response. Contact your administrator.")
        case .issuerMismatch:
            return String(localized: "The response came from an unexpected identity provider. Verify SSO configuration.")
        }
    }
}
