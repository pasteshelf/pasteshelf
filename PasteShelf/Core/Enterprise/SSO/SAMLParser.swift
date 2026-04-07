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
        return try self.parseResponse(data)
    }

    /// Parses a SAML response from raw XML data
    /// - Parameter data: Raw XML data
    /// - Returns: Parsed SAML response
    func parseResponse(_ data: Data) throws -> SAMLResponse {
        self.resetState()

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = true

        guard parser.parse() else {
            let error = parser.parserError?.localizedDescription ?? "Unknown parsing error"
            self.logger.error("SAML XML parsing failed: \(error)")
            throw SAMLValidationError.xmlParsingFailed(error)
        }

        guard !self.responseId.isEmpty else {
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
            id: self.responseId,
            inResponseTo: self.responseInResponseTo,
            destination: self.responseDestination,
            issueInstant: issueInstant,
            issuer: self.responseIssuer,
            version: self.responseVersion,
            status: status,
            assertions: self.assertions
        )
    }

    /// Parses a standalone SAML assertion from XML data
    /// - Parameter data: Raw XML data containing just an assertion
    /// - Returns: Parsed SAML assertion
    func parseAssertion(_ data: Data) throws -> SAMLAssertion {
        self.resetState()

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
        self.currentElement = ""
        self.elementStack = []
        self.currentText = ""
        self.attributes = [:]

        self.responseId = ""
        self.responseInResponseTo = nil
        self.responseDestination = nil
        self.responseIssueInstant = nil
        self.responseIssuer = ""
        self.responseVersion = "2.0"
        self.statusCode = .unknown
        self.statusSubCode = nil
        self.statusMessage = nil

        self.assertions = []
        self.currentAssertion = nil
        self.currentAttributeStatement = []
        self.currentAttribute = nil
        self.currentSubject = nil
        self.currentConditions = nil
        self.currentAuthnStatement = nil
    }

    private func parseDate(_ string: String) -> Date? {
        self.dateFormatter.date(from: string) ?? self.fallbackDateFormatter.date(from: string)
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
        self.elementStack.append(elementName)
        self.currentElement = elementName
        self.currentText = ""
        self.attributes = attributeDict

        handleStartElement(elementName, attributes: attributeDict)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        self.currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let trimmedText = self.currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        handleEndElement(elementName, trimmedText: trimmedText)

        self.elementStack.removeLast()
        self.currentElement = self.elementStack.last ?? ""
        self.currentText = ""
    }
}

// MARK: - SAMLParser Element Handlers

private extension SAMLParser {
    func handleStartElement(_ elementName: String, attributes attributeDict: [String: String]) {
        switch elementName {
        case "Response",
             "samlp:Response":
            self.handleStartResponse(attributeDict)
        case "Assertion",
             "saml:Assertion":
            self.handleStartAssertion(attributeDict)
        case "Subject",
             "saml:Subject":
            self.currentSubject = SubjectBuilder()
        case "NameID",
             "saml:NameID":
            self.handleStartNameID(attributeDict)
        case "SubjectConfirmation",
             "saml:SubjectConfirmation":
            self.currentSubject?.confirmationMethod = SAMLConfirmationMethod(rawValue: attributeDict["Method"] ?? "")
        case "SubjectConfirmationData",
             "saml:SubjectConfirmationData":
            self.handleStartSubjectConfirmationData(attributeDict)
        case "Conditions",
             "saml:Conditions":
            self.handleStartConditions(attributeDict)
        case "AuthnStatement",
             "saml:AuthnStatement":
            self.handleStartAuthnStatement(attributeDict)
        case "AttributeStatement",
             "saml:AttributeStatement":
            self.currentAttributeStatement = []
        case "Attribute",
             "saml:Attribute":
            self.handleStartAttribute(attributeDict)
        case "StatusCode",
             "samlp:StatusCode":
            self.handleStartStatusCode(attributeDict)
        default:
            break
        }
    }

    func handleStartResponse(_ attrs: [String: String]) {
        self.responseId = attrs["ID"] ?? ""
        self.responseInResponseTo = attrs["InResponseTo"]
        self.responseDestination = attrs["Destination"]
        self.responseVersion = attrs["Version"] ?? "2.0"
        if let instant = attrs["IssueInstant"] {
            self.responseIssueInstant = self.parseDate(instant)
        }
    }

    func handleStartAssertion(_ attrs: [String: String]) {
        self.currentAssertion = AssertionBuilder()
        self.currentAssertion?.id = attrs["ID"] ?? ""
        self.currentAssertion?.version = attrs["Version"] ?? "2.0"
        if let instant = attrs["IssueInstant"] {
            self.currentAssertion?.issueInstant = self.parseDate(instant)
        }
    }

    func handleStartNameID(_ attrs: [String: String]) {
        self.currentSubject?.nameIDFormat = SAMLNameIDFormat(rawValue: attrs["Format"] ?? "")
        self.currentSubject?.nameQualifier = attrs["NameQualifier"]
    }

    func handleStartSubjectConfirmationData(_ attrs: [String: String]) {
        self.currentSubject?.confirmationRecipient = attrs["Recipient"]
        self.currentSubject?.confirmationInResponseTo = attrs["InResponseTo"]
        if let notOnOrAfter = attrs["NotOnOrAfter"] {
            self.currentSubject?.confirmationNotOnOrAfter = self.parseDate(notOnOrAfter)
        }
    }

    func handleStartConditions(_ attrs: [String: String]) {
        self.currentConditions = ConditionsBuilder()
        if let notBefore = attrs["NotBefore"] {
            self.currentConditions?.notBefore = self.parseDate(notBefore)
        }
        if let notOnOrAfter = attrs["NotOnOrAfter"] {
            self.currentConditions?.notOnOrAfter = self.parseDate(notOnOrAfter)
        }
    }

    func handleStartAuthnStatement(_ attrs: [String: String]) {
        self.currentAuthnStatement = AuthnStatementBuilder()
        if let instant = attrs["AuthnInstant"] {
            self.currentAuthnStatement?.authnInstant = self.parseDate(instant)
        }
        self.currentAuthnStatement?.sessionIndex = attrs["SessionIndex"]
        if let sessionNotOnOrAfter = attrs["SessionNotOnOrAfter"] {
            self.currentAuthnStatement?.sessionNotOnOrAfter = self.parseDate(sessionNotOnOrAfter)
        }
    }

    func handleStartAttribute(_ attrs: [String: String]) {
        self.currentAttribute = AttributeBuilder()
        self.currentAttribute?.name = attrs["Name"] ?? ""
        self.currentAttribute?.friendlyName = attrs["FriendlyName"]
        if let format = attrs["NameFormat"] {
            self.currentAttribute?.nameFormat = SAMLAttributeNameFormat(rawValue: format)
        }
    }

    func handleStartStatusCode(_ attrs: [String: String]) {
        let code = SAMLStatusCode(rawValue: attrs["Value"] ?? "")
        if self.statusCode == .unknown {
            self.statusCode = code
        } else {
            self.statusSubCode = code
        }
    }

    func handleEndElement(_ elementName: String, trimmedText: String) {
        switch elementName {
        case "Issuer",
             "saml:Issuer":
            if self.currentAssertion != nil {
                self.currentAssertion?.issuer = trimmedText
            } else {
                self.responseIssuer = trimmedText
            }
        case "NameID",
             "saml:NameID":
            self.currentSubject?.nameID = trimmedText
        case "Audience",
             "saml:Audience":
            self.currentConditions?.audiences.append(trimmedText)
        case "AuthnContextClassRef",
             "saml:AuthnContextClassRef":
            self.currentAuthnStatement?.authnContextClassRef = SAMLAuthnContextClass(rawValue: trimmedText)
        case "AttributeValue",
             "saml:AttributeValue":
            self.currentAttribute?.values.append(trimmedText)
        case "StatusMessage",
             "samlp:StatusMessage":
            self.statusMessage = trimmedText
        case "Attribute",
             "saml:Attribute":
            self.handleEndAttribute()
        case "AttributeStatement",
             "saml:AttributeStatement":
            self.handleEndAttributeStatement()
        case "Subject",
             "saml:Subject":
            self.handleEndSubject()
        case "Conditions",
             "saml:Conditions":
            self.handleEndConditions()
        case "AuthnStatement",
             "saml:AuthnStatement":
            self.handleEndAuthnStatement()
        case "Assertion",
             "saml:Assertion":
            self.handleEndAssertion()
        default:
            break
        }
    }

    func handleEndAttribute() {
        if let attr = currentAttribute?.build() {
            self.currentAttributeStatement.append(attr)
        }
        self.currentAttribute = nil
    }

    func handleEndAttributeStatement() {
        let statement = SAMLAttributeStatement(attributes: currentAttributeStatement)
        self.currentAssertion?.attributeStatements.append(statement)
        self.currentAttributeStatement = []
    }

    func handleEndSubject() {
        if let subject = currentSubject?.build() {
            self.currentAssertion?.subject = subject
        }
        self.currentSubject = nil
    }

    func handleEndConditions() {
        if let conditions = currentConditions?.build() {
            self.currentAssertion?.conditions = conditions
        }
        self.currentConditions = nil
    }

    func handleEndAuthnStatement() {
        if let authnStatement = currentAuthnStatement?.build() {
            self.currentAssertion?.authnStatement = authnStatement
        }
        self.currentAuthnStatement = nil
    }

    func handleEndAssertion() {
        if let assertion = currentAssertion?.build() {
            self.assertions.append(assertion)
        }
        self.currentAssertion = nil
    }
}

// Builder classes (AssertionBuilder, SubjectBuilder, ConditionsBuilder,
// AuthnStatementBuilder, AttributeBuilder) are in SAMLParserBuilders.swift
