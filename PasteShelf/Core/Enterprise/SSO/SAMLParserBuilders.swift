//
//  SAMLParserBuilders.swift
//  PasteShelf
//
//  Builder helpers used by SAMLParser to accumulate state during XML parsing.
//  Extracted from SAMLParser.swift to stay within file length limits.
//

import Foundation

// MARK: - AssertionBuilder

class AssertionBuilder {
    var id = ""
    var issuer = ""
    var issueInstant: Date?
    var version = "2.0"
    var subject: SAMLSubject?
    var conditions: SAMLConditions?
    var authnStatement: SAMLAuthnStatement?
    var attributeStatements: [SAMLAttributeStatement] = []

    func build() -> SAMLAssertion? {
        guard !id.isEmpty,
              !issuer.isEmpty,
              let issueInstant,
              let subject,
              let conditions
        else {
            return nil
        }

        return SAMLAssertion(
            id: id,
            issuer: issuer,
            issueInstant: issueInstant,
            version: version,
            subject: subject,
            conditions: conditions,
            authnStatement: authnStatement,
            attributeStatements: attributeStatements
        )
    }
}

// MARK: - SubjectBuilder

class SubjectBuilder {
    var nameID = ""
    var nameIDFormat: SAMLNameIDFormat = .unspecified
    var nameQualifier: String?
    var confirmationMethod: SAMLConfirmationMethod = .bearer
    var confirmationRecipient: String?
    var confirmationNotOnOrAfter: Date?
    var confirmationInResponseTo: String?

    func build() -> SAMLSubject? {
        guard !nameID.isEmpty else {
            return nil
        }

        let confirmationData = SAMLSubjectConfirmationData(
            recipient: confirmationRecipient,
            notOnOrAfter: confirmationNotOnOrAfter,
            inResponseTo: confirmationInResponseTo
        )

        let confirmation = SAMLSubjectConfirmation(
            method: confirmationMethod,
            confirmationData: confirmationData
        )

        return SAMLSubject(
            nameID: nameID,
            nameIDFormat: nameIDFormat,
            nameQualifier: nameQualifier,
            confirmations: [confirmation]
        )
    }
}

// MARK: - ConditionsBuilder

class ConditionsBuilder {
    var notBefore: Date?
    var notOnOrAfter: Date?
    var audiences: [String] = []

    func build() -> SAMLConditions? {
        guard let notBefore, let notOnOrAfter else {
            return nil
        }

        let audienceRestriction = SAMLAudienceRestriction(audiences: audiences)
        return SAMLConditions(
            notBefore: notBefore,
            notOnOrAfter: notOnOrAfter,
            audienceRestrictions: audiences.isEmpty ? [] : [audienceRestriction]
        )
    }
}

// MARK: - AuthnStatementBuilder

class AuthnStatementBuilder {
    var authnInstant: Date?
    var sessionIndex: String?
    var sessionNotOnOrAfter: Date?
    var authnContextClassRef: SAMLAuthnContextClass = .unspecified

    func build() -> SAMLAuthnStatement? {
        guard let authnInstant else {
            return nil
        }

        return SAMLAuthnStatement(
            authnInstant: authnInstant,
            sessionIndex: sessionIndex,
            sessionNotOnOrAfter: sessionNotOnOrAfter,
            authnContext: SAMLAuthnContext(classRef: authnContextClassRef)
        )
    }
}

// MARK: - AttributeBuilder

class AttributeBuilder {
    var name = ""
    var friendlyName: String?
    var nameFormat: SAMLAttributeNameFormat?
    var values: [String] = []

    func build() -> SAMLAttribute? {
        guard !name.isEmpty else {
            return nil
        }

        return SAMLAttribute(
            name: name,
            friendlyName: friendlyName,
            nameFormat: nameFormat,
            values: values
        )
    }
}
