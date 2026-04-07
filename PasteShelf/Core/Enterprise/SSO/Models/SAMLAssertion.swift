//
//  SAMLAssertion.swift
//  PasteShelf
//
//  Represents a parsed SAML 2.0 assertion for Enterprise SSO.
//  Contains subject, conditions, and attribute statements.
//

import Foundation

// MARK: - SAMLAssertion

/// A parsed SAML 2.0 Assertion containing user identity information
struct SAMLAssertion: Codable, Sendable, Equatable {
    // MARK: Internal

    /// Unique identifier for this assertion
    let id: String

    /// Issuer of the assertion (Identity Provider entity ID)
    let issuer: String

    /// When the assertion was issued
    let issueInstant: Date

    /// Version of the SAML assertion (typically "2.0")
    let version: String

    /// Subject information (the authenticated user)
    let subject: SAMLSubject

    /// Conditions for assertion validity
    let conditions: SAMLConditions

    /// Authentication statement with session details
    let authnStatement: SAMLAuthnStatement?

    /// Attribute statements containing user attributes
    let attributeStatements: [SAMLAttributeStatement]

    // MARK: - Convenience Properties

    /// The user's email from attribute statements
    var email: String? {
        findAttribute(
            named: "email",
            "mail",
            "emailAddress",
            "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
        )
    }

    /// The user's first name from attribute statements
    var firstName: String? {
        findAttribute(
            named: "firstName",
            "givenName",
            "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname"
        )
    }

    /// The user's last name from attribute statements
    var lastName: String? {
        findAttribute(
            named: "lastName",
            "surname",
            "sn",
            "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname"
        )
    }

    /// The user's display name
    var displayName: String? {
        findAttribute(named: "displayName", "name", "cn", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name")
    }

    /// User's group memberships
    var groups: [String] {
        findAttributes(named: "groups", "memberOf", "http://schemas.xmlsoap.org/claims/Group")
    }

    /// User's unique identifier (usually email or UPN)
    var userId: String {
        subject.nameID
    }

    // MARK: - Validation

    /// Checks if the assertion is currently valid (within time bounds)
    func isValid(clockSkewTolerance: TimeInterval = 300) -> Bool {
        let now = Date()
        let adjustedNotBefore = conditions.notBefore.addingTimeInterval(-clockSkewTolerance)
        let adjustedNotOnOrAfter = conditions.notOnOrAfter.addingTimeInterval(clockSkewTolerance)

        return now >= adjustedNotBefore && now < adjustedNotOnOrAfter
    }

    /// Checks if the assertion is intended for the given audience
    func isIntendedFor(audience: String) -> Bool {
        conditions.audienceRestrictions.contains { $0.audiences.contains(audience) }
    }

    // MARK: Private

    // MARK: - Private Helpers

    private func findAttribute(named names: String...) -> String? {
        for statement in attributeStatements {
            for attribute in statement.attributes {
                if names.contains(attribute.name) || names.contains(attribute.friendlyName ?? "") {
                    return attribute.values.first
                }
            }
        }
        return nil
    }

    private func findAttributes(named names: String...) -> [String] {
        var result: [String] = []
        for statement in attributeStatements {
            for attribute in statement.attributes {
                if names.contains(attribute.name) || names.contains(attribute.friendlyName ?? "") {
                    result.append(contentsOf: attribute.values)
                }
            }
        }
        return result
    }
}

// MARK: - SAMLSubject

/// The subject (authenticated user) of a SAML assertion
struct SAMLSubject: Codable, Sendable, Equatable {
    /// The unique identifier for the subject (usually email or UPN)
    let nameID: String

    /// Format of the NameID (e.g., email, persistent, transient)
    let nameIDFormat: SAMLNameIDFormat

    /// Service Provider's name qualifier
    let nameQualifier: String?

    /// Confirmation data for the subject
    let confirmations: [SAMLSubjectConfirmation]
}

// MARK: - SAMLSubjectConfirmation

/// Confirmation method for the subject
struct SAMLSubjectConfirmation: Codable, Sendable, Equatable {
    /// Confirmation method URI (e.g., bearer)
    let method: SAMLConfirmationMethod

    /// Additional confirmation data
    let confirmationData: SAMLSubjectConfirmationData?
}

// MARK: - SAMLSubjectConfirmationData

/// Data confirming the subject
struct SAMLSubjectConfirmationData: Codable, Sendable, Equatable {
    /// Response must be delivered to this URL
    let recipient: String?

    /// The assertion must not be used after this time
    let notOnOrAfter: Date?

    /// Reference to the authentication request
    let inResponseTo: String?
}

// MARK: - SAMLConditions

/// Time and audience conditions for assertion validity
struct SAMLConditions: Codable, Sendable, Equatable {
    /// Assertion must not be used before this time
    let notBefore: Date

    /// Assertion must not be used on or after this time
    let notOnOrAfter: Date

    /// Restricted audiences for this assertion
    let audienceRestrictions: [SAMLAudienceRestriction]
}

// MARK: - SAMLAudienceRestriction

/// Audience restriction for the assertion
struct SAMLAudienceRestriction: Codable, Sendable, Equatable {
    /// Entity IDs of allowed audiences
    let audiences: [String]
}

// MARK: - SAMLAuthnStatement

/// Statement about how the user authenticated
struct SAMLAuthnStatement: Codable, Sendable, Equatable {
    /// When the authentication occurred
    let authnInstant: Date

    /// Unique identifier for this session
    let sessionIndex: String?

    /// When the session should expire
    let sessionNotOnOrAfter: Date?

    /// How the user authenticated
    let authnContext: SAMLAuthnContext
}

// MARK: - SAMLAuthnContext

/// Context about the authentication method
struct SAMLAuthnContext: Codable, Sendable, Equatable {
    /// Authentication context class reference (method used)
    let classRef: SAMLAuthnContextClass
}

// MARK: - SAMLAttributeStatement

/// Statement containing user attributes
struct SAMLAttributeStatement: Codable, Sendable, Equatable {
    /// Attributes in this statement
    let attributes: [SAMLAttribute]
}

// MARK: - SAMLAttribute

/// A single SAML attribute (name-value pair)
struct SAMLAttribute: Codable, Sendable, Equatable {
    /// Attribute name (URI or simple name)
    let name: String

    /// Human-readable name
    let friendlyName: String?

    /// Name format URI
    let nameFormat: SAMLAttributeNameFormat?

    /// Attribute values (can be multi-valued)
    let values: [String]
}

// MARK: - SAMLNameIDFormat

/// SAML NameID format types
enum SAMLNameIDFormat: String, Codable, Sendable {
    case unspecified = "urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified"
    case emailAddress = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
    case persistent = "urn:oasis:names:tc:SAML:2.0:nameid-format:persistent"
    case transient = "urn:oasis:names:tc:SAML:2.0:nameid-format:transient"
    case entity = "urn:oasis:names:tc:SAML:2.0:nameid-format:entity"
    case kerberos = "urn:oasis:names:tc:SAML:2.0:nameid-format:kerberos"
    case windowsDomainQualifiedName = "urn:oasis:names:tc:SAML:1.1:nameid-format:WindowsDomainQualifiedName"
    case x509SubjectName = "urn:oasis:names:tc:SAML:1.1:nameid-format:X509SubjectName"

    // MARK: Lifecycle

    /// Creates a NameIDFormat from any string, defaulting to unspecified
    init(rawValue: String) {
        switch rawValue {
        case SAMLNameIDFormat.emailAddress.rawValue:
            self = .emailAddress
        case SAMLNameIDFormat.persistent.rawValue:
            self = .persistent
        case SAMLNameIDFormat.transient.rawValue:
            self = .transient
        case SAMLNameIDFormat.entity.rawValue:
            self = .entity
        case SAMLNameIDFormat.kerberos.rawValue:
            self = .kerberos
        case SAMLNameIDFormat.windowsDomainQualifiedName.rawValue:
            self = .windowsDomainQualifiedName
        case SAMLNameIDFormat.x509SubjectName.rawValue:
            self = .x509SubjectName
        default:
            self = .unspecified
        }
    }
}

// MARK: - SAMLConfirmationMethod

/// SAML subject confirmation methods
enum SAMLConfirmationMethod: String, Codable, Sendable {
    case bearer = "urn:oasis:names:tc:SAML:2.0:cm:bearer"
    case holderOfKey = "urn:oasis:names:tc:SAML:2.0:cm:holder-of-key"
    case senderVouches = "urn:oasis:names:tc:SAML:2.0:cm:sender-vouches"

    // MARK: Lifecycle

    init(rawValue: String) {
        switch rawValue {
        case SAMLConfirmationMethod.bearer.rawValue:
            self = .bearer
        case SAMLConfirmationMethod.holderOfKey.rawValue:
            self = .holderOfKey
        case SAMLConfirmationMethod.senderVouches.rawValue:
            self = .senderVouches
        default:
            self = .bearer
        }
    }
}

// MARK: - SAMLAuthnContextClass

/// SAML authentication context classes (how the user authenticated)
enum SAMLAuthnContextClass: String, Codable, Sendable {
    case password = "urn:oasis:names:tc:SAML:2.0:ac:classes:Password"
    case passwordProtectedTransport = "urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport"
    case tlsClient = "urn:oasis:names:tc:SAML:2.0:ac:classes:TLSClient"
    case x509 = "urn:oasis:names:tc:SAML:2.0:ac:classes:X509"
    case kerberos = "urn:oasis:names:tc:SAML:2.0:ac:classes:Kerberos"
    case smartcard = "urn:oasis:names:tc:SAML:2.0:ac:classes:Smartcard"
    case smartcardPKI = "urn:oasis:names:tc:SAML:2.0:ac:classes:SmartcardPKI"
    case mobileTwoFactorContract = "urn:oasis:names:tc:SAML:2.0:ac:classes:MobileTwoFactorContract"
    case unspecified = "urn:oasis:names:tc:SAML:2.0:ac:classes:unspecified"

    // MARK: Lifecycle

    init(rawValue: String) {
        switch rawValue {
        case SAMLAuthnContextClass.password.rawValue:
            self = .password
        case SAMLAuthnContextClass.passwordProtectedTransport.rawValue:
            self = .passwordProtectedTransport
        case SAMLAuthnContextClass.tlsClient.rawValue:
            self = .tlsClient
        case SAMLAuthnContextClass.x509.rawValue:
            self = .x509
        case SAMLAuthnContextClass.kerberos.rawValue:
            self = .kerberos
        case SAMLAuthnContextClass.smartcard.rawValue:
            self = .smartcard
        case SAMLAuthnContextClass.smartcardPKI.rawValue:
            self = .smartcardPKI
        case SAMLAuthnContextClass.mobileTwoFactorContract.rawValue:
            self = .mobileTwoFactorContract
        default:
            self = .unspecified
        }
    }
}

// MARK: - SAMLAttributeNameFormat

/// SAML attribute name format
enum SAMLAttributeNameFormat: String, Codable, Sendable {
    case unspecified = "urn:oasis:names:tc:SAML:2.0:attrname-format:unspecified"
    case uri = "urn:oasis:names:tc:SAML:2.0:attrname-format:uri"
    case basic = "urn:oasis:names:tc:SAML:2.0:attrname-format:basic"

    // MARK: Lifecycle

    init(rawValue: String) {
        switch rawValue {
        case SAMLAttributeNameFormat.uri.rawValue:
            self = .uri
        case SAMLAttributeNameFormat.basic.rawValue:
            self = .basic
        default:
            self = .unspecified
        }
    }
}
