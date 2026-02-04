//
//  SAMLParser.swift
//  PasteShelf
//
//  Parses SAML 2.0 XML responses and assertions for Enterprise SSO.
//  Uses XMLParser for secure, efficient XML parsing.
//

import Foundation
import os.log

/// Parses SAML 2.0 XML documents into Swift models
final class SAMLParser: NSObject, @unchecked Sendable {
    // MARK: - SAML XML Namespaces

    private enum Namespace {
        static let saml = "urn:oasis:names:tc:SAML:2.0:assertion"
        static let samlp = "urn:oasis:names:tc:SAML:2.0:protocol"
        static let ds = "http://www.w3.org/2000/09/xmldsig#"
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.pasteshelf", category: "saml")

    /// Date formatter for SAML timestamps (ISO 8601)
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Fallback date formatter without fractional seconds
    private let fallbackDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - Parsing State

    private var currentElement = ""
    private var elementStack: [String] = []
    private var currentText = ""
    private var attributes: [String: String] = [:]

    // Response state
    private var responseId = ""
    private var responseInResponseTo: String?
    private var responseDestination: String?
    private var responseIssueInstant: Date?
    private var responseIssuer = ""
    private var responseVersion = "2.0"
    private var statusCode: SAMLStatusCode = .unknown
    private var statusSubCode: SAMLStatusCode?
    private var statusMessage: String?

    // Assertion state
    private var assertions: [SAMLAssertion] = []
    private var currentAssertion: AssertionBuilder?
    private var currentAttributeStatement: [SAMLAttribute] = []
    private var currentAttribute: AttributeBuilder?
    private var currentSubject: SubjectBuilder?
    private var currentConditions: ConditionsBuilder?
    private var currentAuthnStatement: AuthnStatementBuilder?

    // MARK: - Parsing

    /// Parses a base64-encoded SAML response
    /// - Parameter base64String: Base64-encoded SAML response XML
    /// - Returns: Parsed SAML response
    func parseBase64EncodedResponse(_ base64String: String) throws -> SAMLResponse {
        guard let data = Data(base64Encoded: base64String) else {
            throw SAMLValidationError.xmlParsingFailed("Invalid base64 encoding")
        }
        return try parseResponse(data)
    }

    /// Parses a SAML response from raw XML data
    /// - Parameter data: Raw XML data
    /// - Returns: Parsed SAML response
    func parseResponse(_ data: Data) throws -> SAMLResponse {
        resetState()

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = true

        guard parser.parse() else {
            let error = parser.parserError?.localizedDescription ?? "Unknown parsing error"
            logger.error("SAML XML parsing failed: \(error)")
            throw SAMLValidationError.xmlParsingFailed(error)
        }

        guard !responseId.isEmpty else {
            throw SAMLValidationError.invalidStructure("Missing Response ID")
        }

        guard let issueInstant = responseIssueInstant else {
            throw SAMLValidationError.invalidStructure("Missing Response IssueInstant")
        }

        let status = SAMLStatus(
            code: statusCode,
            subCode: statusSubCode,
            message: statusMessage
        )

        return SAMLResponse(
            id: responseId,
            inResponseTo: responseInResponseTo,
            destination: responseDestination,
            issueInstant: issueInstant,
            issuer: responseIssuer,
            version: responseVersion,
            status: status,
            assertions: assertions
        )
    }

    /// Parses a standalone SAML assertion from XML data
    /// - Parameter data: Raw XML data containing just an assertion
    /// - Returns: Parsed SAML assertion
    func parseAssertion(_ data: Data) throws -> SAMLAssertion {
        resetState()

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = true

        guard parser.parse() else {
            let error = parser.parserError?.localizedDescription ?? "Unknown parsing error"
            throw SAMLValidationError.xmlParsingFailed(error)
        }

        guard let assertion = assertions.first else {
            throw SAMLValidationError.invalidStructure("No assertion found in XML")
        }

        return assertion
    }

    // MARK: - State Management

    private func resetState() {
        currentElement = ""
        elementStack = []
        currentText = ""
        attributes = [:]

        responseId = ""
        responseInResponseTo = nil
        responseDestination = nil
        responseIssueInstant = nil
        responseIssuer = ""
        responseVersion = "2.0"
        statusCode = .unknown
        statusSubCode = nil
        statusMessage = nil

        assertions = []
        currentAssertion = nil
        currentAttributeStatement = []
        currentAttribute = nil
        currentSubject = nil
        currentConditions = nil
        currentAuthnStatement = nil
    }

    private func parseDate(_ string: String) -> Date? {
        dateFormatter.date(from: string) ?? fallbackDateFormatter.date(from: string)
    }
}

// MARK: - XMLParserDelegate

extension SAMLParser: XMLParserDelegate {
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        elementStack.append(elementName)
        currentElement = elementName
        currentText = ""
        attributes = attributeDict

        switch elementName {
        case "Response", "samlp:Response":
            responseId = attributeDict["ID"] ?? ""
            responseInResponseTo = attributeDict["InResponseTo"]
            responseDestination = attributeDict["Destination"]
            responseVersion = attributeDict["Version"] ?? "2.0"
            if let instant = attributeDict["IssueInstant"] {
                responseIssueInstant = parseDate(instant)
            }

        case "Assertion", "saml:Assertion":
            currentAssertion = AssertionBuilder()
            currentAssertion?.id = attributeDict["ID"] ?? ""
            currentAssertion?.version = attributeDict["Version"] ?? "2.0"
            if let instant = attributeDict["IssueInstant"] {
                currentAssertion?.issueInstant = parseDate(instant)
            }

        case "Subject", "saml:Subject":
            currentSubject = SubjectBuilder()

        case "NameID", "saml:NameID":
            currentSubject?.nameIDFormat = SAMLNameIDFormat(rawValue: attributeDict["Format"] ?? "")
            currentSubject?.nameQualifier = attributeDict["NameQualifier"]

        case "SubjectConfirmation", "saml:SubjectConfirmation":
            currentSubject?.confirmationMethod = SAMLConfirmationMethod(rawValue: attributeDict["Method"] ?? "")

        case "SubjectConfirmationData", "saml:SubjectConfirmationData":
            currentSubject?.confirmationRecipient = attributeDict["Recipient"]
            currentSubject?.confirmationInResponseTo = attributeDict["InResponseTo"]
            if let notOnOrAfter = attributeDict["NotOnOrAfter"] {
                currentSubject?.confirmationNotOnOrAfter = parseDate(notOnOrAfter)
            }

        case "Conditions", "saml:Conditions":
            currentConditions = ConditionsBuilder()
            if let notBefore = attributeDict["NotBefore"] {
                currentConditions?.notBefore = parseDate(notBefore)
            }
            if let notOnOrAfter = attributeDict["NotOnOrAfter"] {
                currentConditions?.notOnOrAfter = parseDate(notOnOrAfter)
            }

        case "AuthnStatement", "saml:AuthnStatement":
            currentAuthnStatement = AuthnStatementBuilder()
            if let instant = attributeDict["AuthnInstant"] {
                currentAuthnStatement?.authnInstant = parseDate(instant)
            }
            currentAuthnStatement?.sessionIndex = attributeDict["SessionIndex"]
            if let sessionNotOnOrAfter = attributeDict["SessionNotOnOrAfter"] {
                currentAuthnStatement?.sessionNotOnOrAfter = parseDate(sessionNotOnOrAfter)
            }

        case "AttributeStatement", "saml:AttributeStatement":
            currentAttributeStatement = []

        case "Attribute", "saml:Attribute":
            currentAttribute = AttributeBuilder()
            currentAttribute?.name = attributeDict["Name"] ?? ""
            currentAttribute?.friendlyName = attributeDict["FriendlyName"]
            if let format = attributeDict["NameFormat"] {
                currentAttribute?.nameFormat = SAMLAttributeNameFormat(rawValue: format)
            }

        case "StatusCode", "samlp:StatusCode":
            let code = SAMLStatusCode(rawValue: attributeDict["Value"] ?? "")
            if statusCode == .unknown {
                statusCode = code
            } else {
                statusSubCode = code
            }

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "Issuer", "saml:Issuer":
            if currentAssertion != nil {
                currentAssertion?.issuer = trimmedText
            } else {
                responseIssuer = trimmedText
            }

        case "NameID", "saml:NameID":
            currentSubject?.nameID = trimmedText

        case "Audience", "saml:Audience":
            currentConditions?.audiences.append(trimmedText)

        case "AuthnContextClassRef", "saml:AuthnContextClassRef":
            currentAuthnStatement?.authnContextClassRef = SAMLAuthnContextClass(rawValue: trimmedText)

        case "AttributeValue", "saml:AttributeValue":
            currentAttribute?.values.append(trimmedText)

        case "StatusMessage", "samlp:StatusMessage":
            statusMessage = trimmedText

        case "Attribute", "saml:Attribute":
            if let attr = currentAttribute?.build() {
                currentAttributeStatement.append(attr)
            }
            currentAttribute = nil

        case "AttributeStatement", "saml:AttributeStatement":
            let statement = SAMLAttributeStatement(attributes: currentAttributeStatement)
            currentAssertion?.attributeStatements.append(statement)
            currentAttributeStatement = []

        case "Subject", "saml:Subject":
            if let subject = currentSubject?.build() {
                currentAssertion?.subject = subject
            }
            currentSubject = nil

        case "Conditions", "saml:Conditions":
            if let conditions = currentConditions?.build() {
                currentAssertion?.conditions = conditions
            }
            currentConditions = nil

        case "AuthnStatement", "saml:AuthnStatement":
            if let authnStatement = currentAuthnStatement?.build() {
                currentAssertion?.authnStatement = authnStatement
            }
            currentAuthnStatement = nil

        case "Assertion", "saml:Assertion":
            if let assertion = currentAssertion?.build() {
                assertions.append(assertion)
            }
            currentAssertion = nil

        default:
            break
        }

        elementStack.removeLast()
        currentElement = elementStack.last ?? ""
        currentText = ""
    }
}

// MARK: - Builder Classes

private class AssertionBuilder {
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

private class SubjectBuilder {
    var nameID = ""
    var nameIDFormat: SAMLNameIDFormat = .unspecified
    var nameQualifier: String?
    var confirmationMethod: SAMLConfirmationMethod = .bearer
    var confirmationRecipient: String?
    var confirmationNotOnOrAfter: Date?
    var confirmationInResponseTo: String?

    func build() -> SAMLSubject? {
        guard !nameID.isEmpty else { return nil }

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

private class ConditionsBuilder {
    var notBefore: Date?
    var notOnOrAfter: Date?
    var audiences: [String] = []

    func build() -> SAMLConditions? {
        guard let notBefore, let notOnOrAfter else { return nil }

        let audienceRestriction = SAMLAudienceRestriction(audiences: audiences)
        return SAMLConditions(
            notBefore: notBefore,
            notOnOrAfter: notOnOrAfter,
            audienceRestrictions: audiences.isEmpty ? [] : [audienceRestriction]
        )
    }
}

private class AuthnStatementBuilder {
    var authnInstant: Date?
    var sessionIndex: String?
    var sessionNotOnOrAfter: Date?
    var authnContextClassRef: SAMLAuthnContextClass = .unspecified

    func build() -> SAMLAuthnStatement? {
        guard let authnInstant else { return nil }

        return SAMLAuthnStatement(
            authnInstant: authnInstant,
            sessionIndex: sessionIndex,
            sessionNotOnOrAfter: sessionNotOnOrAfter,
            authnContext: SAMLAuthnContext(classRef: authnContextClassRef)
        )
    }
}

private class AttributeBuilder {
    var name = ""
    var friendlyName: String?
    var nameFormat: SAMLAttributeNameFormat?
    var values: [String] = []

    func build() -> SAMLAttribute? {
        guard !name.isEmpty else { return nil }

        return SAMLAttribute(
            name: name,
            friendlyName: friendlyName,
            nameFormat: nameFormat,
            values: values
        )
    }
}
