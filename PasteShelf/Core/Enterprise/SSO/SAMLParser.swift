//
//  SAMLParser.swift
//  PasteShelf
//
//  Parses SAML 2.0 XML responses and assertions for Enterprise SSO.
//  Uses XMLParser for secure, efficient XML parsing.
//

import Foundation
import os.log

// MARK: - SAMLParser

/// Parses SAML 2.0 XML documents into Swift models
final class SAMLParser: NSObject, @unchecked Sendable {
    // MARK: Internal

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

    // MARK: Private

    // MARK: - SAML XML Namespaces

    private enum Namespace {
        static let saml = "urn:oasis:names:tc:SAML:2.0:assertion"
        static let samlp = "urn:oasis:names:tc:SAML:2.0:protocol"
        static let ds = "http://www.w3.org/2000/09/xmldsig#"
    }

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

// MARK: XMLParserDelegate

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

        handleStartElement(elementName, attributes: attributeDict)
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

        handleEndElement(elementName, trimmedText: trimmedText)

        elementStack.removeLast()
        currentElement = elementStack.last ?? ""
        currentText = ""
    }
}

// MARK: - SAMLParser Element Handlers

private extension SAMLParser {
    func handleStartElement(_ elementName: String, attributes attributeDict: [String: String]) {
        switch elementName {
        case "Response",
             "samlp:Response":
            handleStartResponse(attributeDict)
        case "Assertion",
             "saml:Assertion":
            handleStartAssertion(attributeDict)
        case "Subject",
             "saml:Subject":
            currentSubject = SubjectBuilder()
        case "NameID",
             "saml:NameID":
            handleStartNameID(attributeDict)
        case "SubjectConfirmation",
             "saml:SubjectConfirmation":
            currentSubject?.confirmationMethod = SAMLConfirmationMethod(rawValue: attributeDict["Method"] ?? "")
        case "SubjectConfirmationData",
             "saml:SubjectConfirmationData":
            handleStartSubjectConfirmationData(attributeDict)
        case "Conditions",
             "saml:Conditions":
            handleStartConditions(attributeDict)
        case "AuthnStatement",
             "saml:AuthnStatement":
            handleStartAuthnStatement(attributeDict)
        case "AttributeStatement",
             "saml:AttributeStatement":
            currentAttributeStatement = []
        case "Attribute",
             "saml:Attribute":
            handleStartAttribute(attributeDict)
        case "StatusCode",
             "samlp:StatusCode":
            handleStartStatusCode(attributeDict)
        default:
            break
        }
    }

    func handleStartResponse(_ attrs: [String: String]) {
        responseId = attrs["ID"] ?? ""
        responseInResponseTo = attrs["InResponseTo"]
        responseDestination = attrs["Destination"]
        responseVersion = attrs["Version"] ?? "2.0"
        if let instant = attrs["IssueInstant"] {
            responseIssueInstant = parseDate(instant)
        }
    }

    func handleStartAssertion(_ attrs: [String: String]) {
        currentAssertion = AssertionBuilder()
        currentAssertion?.id = attrs["ID"] ?? ""
        currentAssertion?.version = attrs["Version"] ?? "2.0"
        if let instant = attrs["IssueInstant"] {
            currentAssertion?.issueInstant = parseDate(instant)
        }
    }

    func handleStartNameID(_ attrs: [String: String]) {
        currentSubject?.nameIDFormat = SAMLNameIDFormat(rawValue: attrs["Format"] ?? "")
        currentSubject?.nameQualifier = attrs["NameQualifier"]
    }

    func handleStartSubjectConfirmationData(_ attrs: [String: String]) {
        currentSubject?.confirmationRecipient = attrs["Recipient"]
        currentSubject?.confirmationInResponseTo = attrs["InResponseTo"]
        if let notOnOrAfter = attrs["NotOnOrAfter"] {
            currentSubject?.confirmationNotOnOrAfter = parseDate(notOnOrAfter)
        }
    }

    func handleStartConditions(_ attrs: [String: String]) {
        currentConditions = ConditionsBuilder()
        if let notBefore = attrs["NotBefore"] {
            currentConditions?.notBefore = parseDate(notBefore)
        }
        if let notOnOrAfter = attrs["NotOnOrAfter"] {
            currentConditions?.notOnOrAfter = parseDate(notOnOrAfter)
        }
    }

    func handleStartAuthnStatement(_ attrs: [String: String]) {
        currentAuthnStatement = AuthnStatementBuilder()
        if let instant = attrs["AuthnInstant"] {
            currentAuthnStatement?.authnInstant = parseDate(instant)
        }
        currentAuthnStatement?.sessionIndex = attrs["SessionIndex"]
        if let sessionNotOnOrAfter = attrs["SessionNotOnOrAfter"] {
            currentAuthnStatement?.sessionNotOnOrAfter = parseDate(sessionNotOnOrAfter)
        }
    }

    func handleStartAttribute(_ attrs: [String: String]) {
        currentAttribute = AttributeBuilder()
        currentAttribute?.name = attrs["Name"] ?? ""
        currentAttribute?.friendlyName = attrs["FriendlyName"]
        if let format = attrs["NameFormat"] {
            currentAttribute?.nameFormat = SAMLAttributeNameFormat(rawValue: format)
        }
    }

    func handleStartStatusCode(_ attrs: [String: String]) {
        let code = SAMLStatusCode(rawValue: attrs["Value"] ?? "")
        if statusCode == .unknown {
            statusCode = code
        } else {
            statusSubCode = code
        }
    }

    func handleEndElement(_ elementName: String, trimmedText: String) {
        switch elementName {
        case "Issuer",
             "saml:Issuer":
            if currentAssertion != nil {
                currentAssertion?.issuer = trimmedText
            } else {
                responseIssuer = trimmedText
            }
        case "NameID",
             "saml:NameID":
            currentSubject?.nameID = trimmedText
        case "Audience",
             "saml:Audience":
            currentConditions?.audiences.append(trimmedText)
        case "AuthnContextClassRef",
             "saml:AuthnContextClassRef":
            currentAuthnStatement?.authnContextClassRef = SAMLAuthnContextClass(rawValue: trimmedText)
        case "AttributeValue",
             "saml:AttributeValue":
            currentAttribute?.values.append(trimmedText)
        case "StatusMessage",
             "samlp:StatusMessage":
            statusMessage = trimmedText
        case "Attribute",
             "saml:Attribute":
            handleEndAttribute()
        case "AttributeStatement",
             "saml:AttributeStatement":
            handleEndAttributeStatement()
        case "Subject",
             "saml:Subject":
            handleEndSubject()
        case "Conditions",
             "saml:Conditions":
            handleEndConditions()
        case "AuthnStatement",
             "saml:AuthnStatement":
            handleEndAuthnStatement()
        case "Assertion",
             "saml:Assertion":
            handleEndAssertion()
        default:
            break
        }
    }

    func handleEndAttribute() {
        if let attr = currentAttribute?.build() {
            currentAttributeStatement.append(attr)
        }
        currentAttribute = nil
    }

    func handleEndAttributeStatement() {
        let statement = SAMLAttributeStatement(attributes: currentAttributeStatement)
        currentAssertion?.attributeStatements.append(statement)
        currentAttributeStatement = []
    }

    func handleEndSubject() {
        if let subject = currentSubject?.build() {
            currentAssertion?.subject = subject
        }
        currentSubject = nil
    }

    func handleEndConditions() {
        if let conditions = currentConditions?.build() {
            currentAssertion?.conditions = conditions
        }
        currentConditions = nil
    }

    func handleEndAuthnStatement() {
        if let authnStatement = currentAuthnStatement?.build() {
            currentAssertion?.authnStatement = authnStatement
        }
        currentAuthnStatement = nil
    }

    func handleEndAssertion() {
        if let assertion = currentAssertion?.build() {
            assertions.append(assertion)
        }
        currentAssertion = nil
    }
}

// Builder classes (AssertionBuilder, SubjectBuilder, ConditionsBuilder,
// AuthnStatementBuilder, AttributeBuilder) are in SAMLParserBuilders.swift
