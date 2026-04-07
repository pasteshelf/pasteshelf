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
        guard !self.id.isEmpty,
              !self.issuer.isEmpty,
              let issueInstant,
              let subject,
              let conditions
        else {
            return nil
        }

        return SAMLAssertion(
            id: self.id,
            issuer: self.issuer,
            issueInstant: issueInstant,
            version: self.version,
            subject: subject,
            conditions: conditions,
            authnStatement: self.authnStatement,
            attributeStatements: self.attributeStatements
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
        guard !self.nameID.isEmpty else {
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
            nameID: self.nameID,
            nameIDFormat: self.nameIDFormat,
            nameQualifier: self.nameQualifier,
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
            audienceRestrictions: self.audiences.isEmpty ? [] : [audienceRestriction]
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
            sessionIndex: self.sessionIndex,
            sessionNotOnOrAfter: self.sessionNotOnOrAfter,
            authnContext: SAMLAuthnContext(classRef: self.authnContextClassRef)
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
        guard !self.name.isEmpty else {
            return nil
        }

        return SAMLAttribute(
            name: self.name,
            friendlyName: self.friendlyName,
            nameFormat: self.nameFormat,
            values: self.values
        )
    }
}
