//
//  SAMLParserTests.swift
//  PasteShelfTests
//
//  Comprehensive tests for SAMLParser, SAMLAssertion, and SAMLResponse.
//

import Foundation
@testable import PasteShelf
import Testing

// MARK: - Test Fixtures

/// Generates valid SAML 2.0 XML for testing.
private func makeValidSAMLResponseXML(
    responseId: String = "_response123",
    assertionId: String = "_assertion456",
    issuer: String = "https://idp.example.com",
    destination: String = "https://sp.example.com/acs",
    inResponseTo: String = "_request789",
    notBefore: Date? = nil,
    notOnOrAfter: Date? = nil,
    audience: String = "https://sp.example.com",
    nameID: String = "user@example.com",
    email: String = "user@example.com",
    statusCode: String = "urn:oasis:names:tc:SAML:2.0:status:Success",
    includeAssertion: Bool = true
) -> Data {
    let now = Date()
    let effectiveNotBefore = notBefore ?? now.addingTimeInterval(-60)
    let effectiveNotOnOrAfter = notOnOrAfter ?? now.addingTimeInterval(3600)

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]

    let assertionXML = includeAssertion ? """
        <saml:Assertion ID="\(assertionId)" Version="2.0" IssueInstant="\(formatter.string(from: now))">
            <saml:Issuer>\(issuer)</saml:Issuer>
            <saml:Subject>
                <saml:NameID Format="urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress">\(nameID)</saml:NameID>
                <saml:SubjectConfirmation Method="urn:oasis:names:tc:SAML:2.0:cm:bearer">
                    <saml:SubjectConfirmationData Recipient="\(destination)"
                                                   NotOnOrAfter="\(formatter.string(from: effectiveNotOnOrAfter))"
                                                   InResponseTo="\(inResponseTo)"/>
                </saml:SubjectConfirmation>
            </saml:Subject>
            <saml:Conditions NotBefore="\(formatter.string(from: effectiveNotBefore))"
                             NotOnOrAfter="\(formatter.string(from: effectiveNotOnOrAfter))">
                <saml:AudienceRestriction>
                    <saml:Audience>\(audience)</saml:Audience>
                </saml:AudienceRestriction>
            </saml:Conditions>
            <saml:AuthnStatement AuthnInstant="\(formatter.string(from: now))" SessionIndex="_session123">
                <saml:AuthnContext>
                    <saml:AuthnContextClassRef>urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport</saml:AuthnContextClassRef>
                </saml:AuthnContext>
            </saml:AuthnStatement>
            <saml:AttributeStatement>
                <saml:Attribute Name="email" FriendlyName="email">
                    <saml:AttributeValue>\(email)</saml:AttributeValue>
                </saml:Attribute>
                <saml:Attribute Name="firstName" FriendlyName="firstName">
                    <saml:AttributeValue>Test</saml:AttributeValue>
                </saml:Attribute>
                <saml:Attribute Name="lastName" FriendlyName="lastName">
                    <saml:AttributeValue>User</saml:AttributeValue>
                </saml:Attribute>
                <saml:Attribute Name="groups">
                    <saml:AttributeValue>admin</saml:AttributeValue>
                    <saml:AttributeValue>users</saml:AttributeValue>
                </saml:Attribute>
            </saml:AttributeStatement>
        </saml:Assertion>
    """ : ""

    let xml = """
    <samlp:Response xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
                    xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
                    ID="\(responseId)"
                    Version="2.0"
                    IssueInstant="\(formatter.string(from: now))"
                    Destination="\(destination)"
                    InResponseTo="\(inResponseTo)">
        <saml:Issuer>\(issuer)</saml:Issuer>
        <samlp:Status>
            <samlp:StatusCode Value="\(statusCode)"/>
        </samlp:Status>
        \(assertionXML)
    </samlp:Response>
    """
    return xml.data(using: .utf8)!
}

/// Generates a standalone SAML assertion XML for testing.
private func makeStandaloneAssertionXML(
    assertionId: String = "_assertion456",
    issuer: String = "https://idp.example.com",
    recipient: String = "https://sp.example.com/acs",
    notBefore: Date? = nil,
    notOnOrAfter: Date? = nil,
    audience: String = "https://sp.example.com",
    nameID: String = "user@example.com"
) -> Data {
    let now = Date()
    let effectiveNotBefore = notBefore ?? now.addingTimeInterval(-60)
    let effectiveNotOnOrAfter = notOnOrAfter ?? now.addingTimeInterval(3600)

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]

    let xml = """
    <saml:Assertion xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
                    ID="\(assertionId)" Version="2.0" IssueInstant="\(formatter.string(from: now))">
        <saml:Issuer>\(issuer)</saml:Issuer>
        <saml:Subject>
            <saml:NameID Format="urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress">\(nameID)</saml:NameID>
            <saml:SubjectConfirmation Method="urn:oasis:names:tc:SAML:2.0:cm:bearer">
                <saml:SubjectConfirmationData Recipient="\(recipient)"
                                               NotOnOrAfter="\(formatter.string(from: effectiveNotOnOrAfter))"
                                               InResponseTo="_request789"/>
            </saml:SubjectConfirmation>
        </saml:Subject>
        <saml:Conditions NotBefore="\(formatter.string(from: effectiveNotBefore))"
                         NotOnOrAfter="\(formatter.string(from: effectiveNotOnOrAfter))">
            <saml:AudienceRestriction>
                <saml:Audience>\(audience)</saml:Audience>
            </saml:AudienceRestriction>
        </saml:Conditions>
        <saml:AuthnStatement AuthnInstant="\(formatter.string(from: now))" SessionIndex="_session123">
            <saml:AuthnContext>
                <saml:AuthnContextClassRef>urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport</saml:AuthnContextClassRef>
            </saml:AuthnContext>
        </saml:AuthnStatement>
        <saml:AttributeStatement>
            <saml:Attribute Name="email" FriendlyName="email">
                <saml:AttributeValue>\(nameID)</saml:AttributeValue>
            </saml:Attribute>
            <saml:Attribute Name="firstName">
                <saml:AttributeValue>Test</saml:AttributeValue>
            </saml:Attribute>
            <saml:Attribute Name="lastName">
                <saml:AttributeValue>User</saml:AttributeValue>
            </saml:Attribute>
        </saml:AttributeStatement>
    </saml:Assertion>
    """
    return xml.data(using: .utf8)!
}

// MARK: - SAMLParserTests

struct SAMLParserTests {
    let parser = SAMLParser()

    // MARK: - parseResponse: Valid XML

    @Test("parseResponse parses valid SAML XML and extracts response fields")
    func parseResponse_validXML_parsesResponseFields() throws {
        let data = makeValidSAMLResponseXML()
        let response = try parser.parseResponse(data)

        #expect(response.id == "_response123")
        #expect(response.inResponseTo == "_request789")
        #expect(response.destination == "https://sp.example.com/acs")
        #expect(response.version == "2.0")
        #expect(response.issuer == "https://idp.example.com")
    }

    @Test("parseResponse parses valid SAML XML and extracts assertion fields")
    func parseResponse_validXML_parsesAssertionFields() throws {
        let data = makeValidSAMLResponseXML()
        let response = try parser.parseResponse(data)

        let assertion = try #require(response.primaryAssertion)
        #expect(assertion.id == "_assertion456")
        #expect(assertion.issuer == "https://idp.example.com")
        #expect(assertion.version == "2.0")
        #expect(assertion.subject.nameID == "user@example.com")
        #expect(assertion.subject.nameIDFormat == .emailAddress)
    }

    @Test("parseResponse parses success status code correctly")
    func parseResponse_successStatus_statusIsSuccess() throws {
        let data = makeValidSAMLResponseXML(
            statusCode: "urn:oasis:names:tc:SAML:2.0:status:Success"
        )
        let response = try parser.parseResponse(data)

        #expect(response.status.code == .success)
        #expect(response.isSuccess)
    }

    @Test("parseResponse parses AuthnFailed status code correctly")
    func parseResponse_authnFailedStatus_statusIsAuthnFailed() throws {
        let data = makeValidSAMLResponseXML(
            statusCode: "urn:oasis:names:tc:SAML:2.0:status:AuthnFailed",
            includeAssertion: false
        )
        let response = try parser.parseResponse(data)

        #expect(response.status.code == .authnFailed)
        #expect(!response.isSuccess)
    }

    @Test("parseResponse parses Requester status code correctly")
    func parseResponse_requesterStatus_statusIsRequester() throws {
        let data = makeValidSAMLResponseXML(
            statusCode: "urn:oasis:names:tc:SAML:2.0:status:Requester",
            includeAssertion: false
        )
        let response = try parser.parseResponse(data)

        #expect(response.status.code == .requester)
        #expect(!response.isSuccess)
    }

    @Test("parseResponse parses assertion attribute statements")
    func parseResponse_validXML_parsesAttributeStatements() throws {
        let data = makeValidSAMLResponseXML(
            email: "testuser@example.com"
        )
        let response = try parser.parseResponse(data)

        let assertion = try #require(response.primaryAssertion)
        #expect(!assertion.attributeStatements.isEmpty)
        #expect(assertion.email == "testuser@example.com")
        #expect(assertion.firstName == "Test")
        #expect(assertion.lastName == "User")
    }

    @Test("parseResponse parses multi-value group attribute")
    func parseResponse_multiValueAttribute_parsesAllValues() throws {
        let data = makeValidSAMLResponseXML()
        let response = try parser.parseResponse(data)

        let assertion = try #require(response.primaryAssertion)
        let groups = assertion.groups
        #expect(groups.count == 2)
        #expect(groups.contains("admin"))
        #expect(groups.contains("users"))
    }

    @Test("parseResponse parses authn statement fields")
    func parseResponse_validXML_parsesAuthnStatement() throws {
        let data = makeValidSAMLResponseXML()
        let response = try parser.parseResponse(data)

        let assertion = try #require(response.primaryAssertion)
        let authnStatement = try #require(assertion.authnStatement)
        #expect(authnStatement.sessionIndex == "_session123")
        #expect(authnStatement.authnContext.classRef == .passwordProtectedTransport)
    }

    @Test("parseResponse with missing assertion returns empty assertions array")
    func parseResponse_missingAssertion_hasNoAssertions() throws {
        let data = makeValidSAMLResponseXML(includeAssertion: false)
        let response = try parser.parseResponse(data)

        #expect(response.assertions.isEmpty)
        #expect(response.primaryAssertion == nil)
    }

    @Test("parseResponse with invalid XML throws xmlParsingFailed error")
    func parseResponse_invalidXML_throwsParsingError() throws {
        let invalidData = "not xml at all <<<>>>".data(using: .utf8)!

        #expect(throws: (any Error).self) {
            try parser.parseResponse(invalidData)
        }
    }

    @Test("parseResponse with empty data throws error")
    func parseResponse_emptyData_throwsError() throws {
        let emptyData = Data()

        #expect(throws: (any Error).self) {
            try parser.parseResponse(emptyData)
        }
    }

    // MARK: - parseBase64EncodedResponse Tests

    @Test("parseBase64EncodedResponse decodes valid base64 and parses successfully")
    func parseBase64EncodedResponse_validBase64_parsesSuccessfully() throws {
        let data = makeValidSAMLResponseXML()
        let base64String = data.base64EncodedString()

        let response = try parser.parseBase64EncodedResponse(base64String)

        #expect(response.id == "_response123")
        #expect(response.isSuccess)
    }

    @Test("parseBase64EncodedResponse with invalid base64 throws xmlParsingFailed error")
    func parseBase64EncodedResponse_invalidBase64_throwsError() {
        let invalidBase64 = "this is not valid base64 !!!"

        #expect(throws: (any Error).self) {
            try parser.parseBase64EncodedResponse(invalidBase64)
        }
    }

    @Test("parseBase64EncodedResponse with empty string throws error")
    func parseBase64EncodedResponse_emptyString_throwsError() {
        #expect(throws: (any Error).self) {
            try parser.parseBase64EncodedResponse("")
        }
    }

    @Test("parseBase64EncodedResponse preserves all response fields")
    func parseBase64EncodedResponse_validBase64_preservesAllFields() throws {
        let data = makeValidSAMLResponseXML(
            responseId: "_resp_b64",
            assertionId: "_assert_b64",
            issuer: "https://b64-idp.example.com"
        )
        let base64String = data.base64EncodedString()

        let response = try parser.parseBase64EncodedResponse(base64String)

        #expect(response.id == "_resp_b64")
        #expect(response.issuer == "https://b64-idp.example.com")

        let assertion = try #require(response.primaryAssertion)
        #expect(assertion.id == "_assert_b64")
        #expect(assertion.issuer == "https://b64-idp.example.com")
    }

    // MARK: - parseAssertion: Standalone Tests

    @Test("parseAssertion parses standalone assertion XML")
    func parseAssertion_standaloneXML_parsesSuccessfully() throws {
        let data = makeStandaloneAssertionXML()
        let assertion = try parser.parseAssertion(data)

        #expect(assertion.id == "_assertion456")
        #expect(assertion.issuer == "https://idp.example.com")
        #expect(assertion.subject.nameID == "user@example.com")
    }

    @Test("parseAssertion extracts conditions from standalone assertion")
    func parseAssertion_standaloneXML_parsesConditions() throws {
        let data = makeStandaloneAssertionXML(audience: "https://sp.example.com")
        let assertion = try parser.parseAssertion(data)

        #expect(assertion.isIntendedFor(audience: "https://sp.example.com"))
        #expect(!assertion.isIntendedFor(audience: "https://other.example.com"))
    }

    @Test("parseAssertion with invalid XML throws error")
    func parseAssertion_invalidXML_throwsError() {
        let badData = "<not-an-assertion/>".data(using: .utf8)!

        #expect(throws: (any Error).self) {
            try parser.parseAssertion(badData)
        }
    }

    // MARK: - Multiple Attribute Statements

    @Test("parseResponse handles multiple attribute statements in assertion")
    func parseResponse_multipleAttributeStatements_parsesAll() throws {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let notBefore = formatter.string(from: now.addingTimeInterval(-60))
        let notOnOrAfter = formatter.string(from: now.addingTimeInterval(3600))
        let issueInstant = formatter.string(from: now)

        let xml = """
        <samlp:Response xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
                        xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
                        ID="_multi_attr_resp"
                        Version="2.0"
                        IssueInstant="\(issueInstant)"
                        Destination="https://sp.example.com/acs"
                        InResponseTo="_req1">
            <saml:Issuer>https://idp.example.com</saml:Issuer>
            <samlp:Status>
                <samlp:StatusCode Value="urn:oasis:names:tc:SAML:2.0:status:Success"/>
            </samlp:Status>
            <saml:Assertion ID="_assert_multi" Version="2.0" IssueInstant="\(issueInstant)">
                <saml:Issuer>https://idp.example.com</saml:Issuer>
                <saml:Subject>
                    <saml:NameID Format="urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress">user@example.com</saml:NameID>
                    <saml:SubjectConfirmation Method="urn:oasis:names:tc:SAML:2.0:cm:bearer">
                        <saml:SubjectConfirmationData Recipient="https://sp.example.com/acs"
                                                       NotOnOrAfter="\(notOnOrAfter)"
                                                       InResponseTo="_req1"/>
                    </saml:SubjectConfirmation>
                </saml:Subject>
                <saml:Conditions NotBefore="\(notBefore)" NotOnOrAfter="\(notOnOrAfter)">
                    <saml:AudienceRestriction>
                        <saml:Audience>https://sp.example.com</saml:Audience>
                    </saml:AudienceRestriction>
                </saml:Conditions>
                <saml:AuthnStatement AuthnInstant="\(issueInstant)">
                    <saml:AuthnContext>
                        <saml:AuthnContextClassRef>urn:oasis:names:tc:SAML:2.0:ac:classes:Password</saml:AuthnContextClassRef>
                    </saml:AuthnContext>
                </saml:AuthnStatement>
                <saml:AttributeStatement>
                    <saml:Attribute Name="email">
                        <saml:AttributeValue>user@example.com</saml:AttributeValue>
                    </saml:Attribute>
                </saml:AttributeStatement>
                <saml:AttributeStatement>
                    <saml:Attribute Name="groups">
                        <saml:AttributeValue>engineering</saml:AttributeValue>
                    </saml:Attribute>
                </saml:AttributeStatement>
            </saml:Assertion>
        </samlp:Response>
        """
        let data = try #require(xml.data(using: .utf8))

        let response = try parser.parseResponse(data)
        let assertion = try #require(response.primaryAssertion)

        // Both attribute statements should be captured
        #expect(assertion.attributeStatements.count == 2)
        #expect(assertion.email == "user@example.com")
        #expect(assertion.groups.contains("engineering"))
    }
}

// MARK: - SAMLAssertionTests

struct SAMLAssertionTests {
    // MARK: Internal

    // MARK: - isValid Tests

    @Test("isValid returns true when current time is within assertion time bounds")
    func isValid_currentTimeWithinBounds_returnsTrue() {
        let now = Date()
        let assertion = makeAssertion(
            notBefore: now.addingTimeInterval(-300),
            notOnOrAfter: now.addingTimeInterval(3600)
        )
        #expect(assertion.isValid())
    }

    @Test("isValid returns false when assertion has expired")
    func isValid_expiredAssertion_returnsFalse() {
        let now = Date()
        let assertion = makeAssertion(
            notBefore: now.addingTimeInterval(-7200),
            notOnOrAfter: now.addingTimeInterval(-3600)
        )
        #expect(!assertion.isValid())
    }

    @Test("isValid returns false when assertion is not yet valid")
    func isValid_notYetValid_returnsFalse() {
        let now = Date()
        // notBefore is far in the future; even with default 300s clock skew
        // the assertion should still be invalid if notBefore > now + tolerance
        let assertion = makeAssertion(
            notBefore: now.addingTimeInterval(600),
            notOnOrAfter: now.addingTimeInterval(7200)
        )
        // Default clockSkewTolerance is 300s, so notBefore - 300 = now + 300, which is > now
        #expect(!assertion.isValid())
    }

    @Test("isValid with clock skew tolerance allows assertion slightly before notBefore")
    func isValid_clockSkewTolerance_allowsSlightlyEarlyAssertion() {
        let now = Date()
        // notBefore is 200 seconds in the future — within default 300s tolerance
        let assertion = makeAssertion(
            notBefore: now.addingTimeInterval(200),
            notOnOrAfter: now.addingTimeInterval(7200)
        )
        #expect(assertion.isValid(clockSkewTolerance: 300))
    }

    @Test("isValid with clock skew tolerance allows assertion slightly after notOnOrAfter")
    func isValid_clockSkewTolerance_allowsSlightlyExpiredAssertion() {
        let now = Date()
        // notOnOrAfter was 200 seconds ago — within default 300s tolerance
        let assertion = makeAssertion(
            notBefore: now.addingTimeInterval(-3600),
            notOnOrAfter: now.addingTimeInterval(-200)
        )
        #expect(assertion.isValid(clockSkewTolerance: 300))
    }

    @Test("isValid returns false when expired beyond clock skew tolerance")
    func isValid_expiredBeyondTolerance_returnsFalse() {
        let now = Date()
        let assertion = makeAssertion(
            notBefore: now.addingTimeInterval(-7200),
            notOnOrAfter: now.addingTimeInterval(-400)
        )
        #expect(!assertion.isValid(clockSkewTolerance: 300))
    }

    // MARK: - isIntendedFor Tests

    @Test("isIntendedFor returns true when audience matches")
    func isIntendedFor_matchingAudience_returnsTrue() {
        let now = Date()
        let assertion = makeAssertion(
            notBefore: now.addingTimeInterval(-60),
            notOnOrAfter: now.addingTimeInterval(3600),
            audience: "https://sp.example.com"
        )
        #expect(assertion.isIntendedFor(audience: "https://sp.example.com"))
    }

    @Test("isIntendedFor returns false when audience does not match")
    func isIntendedFor_nonMatchingAudience_returnsFalse() {
        let now = Date()
        let assertion = makeAssertion(
            notBefore: now.addingTimeInterval(-60),
            notOnOrAfter: now.addingTimeInterval(3600),
            audience: "https://sp.example.com"
        )
        #expect(!assertion.isIntendedFor(audience: "https://other.example.com"))
    }

    @Test("isIntendedFor is case sensitive")
    func isIntendedFor_casesDiffer_returnsFalse() {
        let now = Date()
        let assertion = makeAssertion(
            notBefore: now.addingTimeInterval(-60),
            notOnOrAfter: now.addingTimeInterval(3600),
            audience: "https://sp.example.com"
        )
        // Audience comparison should be case-sensitive
        #expect(!assertion.isIntendedFor(audience: "HTTPS://SP.EXAMPLE.COM"))
    }

    // MARK: - Convenience Properties Tests

    @Test("email convenience property returns email from attribute statements")
    func email_withEmailAttribute_returnsEmail() {
        let now = Date()
        let assertion = makeAssertion(
            notBefore: now.addingTimeInterval(-60),
            notOnOrAfter: now.addingTimeInterval(3600),
            email: "john.doe@example.com"
        )
        #expect(assertion.email == "john.doe@example.com")
    }

    @Test("firstName convenience property returns first name from attribute statements")
    func firstName_withFirstNameAttribute_returnsFirstName() {
        let now = Date()
        let assertion = makeAssertion(
            notBefore: now.addingTimeInterval(-60),
            notOnOrAfter: now.addingTimeInterval(3600),
            firstName: "John"
        )
        #expect(assertion.firstName == "John")
    }

    @Test("lastName convenience property returns last name from attribute statements")
    func lastName_withLastNameAttribute_returnsLastName() {
        let now = Date()
        let assertion = makeAssertion(
            notBefore: now.addingTimeInterval(-60),
            notOnOrAfter: now.addingTimeInterval(3600),
            lastName: "Doe"
        )
        #expect(assertion.lastName == "Doe")
    }

    @Test("groups convenience property returns all group values")
    func groups_withGroupsAttribute_returnsAllGroups() {
        let now = Date()
        let assertion = makeAssertion(
            notBefore: now.addingTimeInterval(-60),
            notOnOrAfter: now.addingTimeInterval(3600),
            groups: ["admin", "engineers", "users"]
        )
        let groups = assertion.groups
        #expect(groups.count == 3)
        #expect(groups.contains("admin"))
        #expect(groups.contains("engineers"))
        #expect(groups.contains("users"))
    }

    @Test("userId returns subject nameID")
    func userId_returnsNameID() {
        let now = Date()
        let assertion = makeAssertion(
            notBefore: now.addingTimeInterval(-60),
            notOnOrAfter: now.addingTimeInterval(3600),
            email: "specific-user@example.com"
        )
        #expect(assertion.userId == "specific-user@example.com")
    }

    @Test("displayName returns nil when no displayName attribute exists")
    func displayName_noDisplayNameAttribute_returnsNil() {
        let now = Date()
        let assertion = makeAssertion(
            notBefore: now.addingTimeInterval(-60),
            notOnOrAfter: now.addingTimeInterval(3600)
        )
        // makeAssertion does not include a displayName attribute
        #expect(assertion.displayName == nil)
    }

    @Test("email returns nil when no email attribute exists")
    func email_noEmailAttribute_returnsNil() {
        let conditions = SAMLConditions(
            notBefore: Date().addingTimeInterval(-60),
            notOnOrAfter: Date().addingTimeInterval(3600),
            audienceRestrictions: []
        )
        let subject = SAMLSubject(
            nameID: "user@example.com",
            nameIDFormat: .emailAddress,
            nameQualifier: nil,
            confirmations: []
        )
        let assertion = SAMLAssertion(
            id: "_test",
            issuer: "https://idp.example.com",
            issueInstant: Date(),
            version: "2.0",
            subject: subject,
            conditions: conditions,
            authnStatement: nil,
            attributeStatements: []
        )
        #expect(assertion.email == nil)
    }

    // MARK: Private

    private func makeAssertion(
        notBefore: Date,
        notOnOrAfter: Date,
        audience: String = "https://sp.example.com",
        email: String = "user@example.com",
        firstName: String = "Test",
        lastName: String = "User",
        groups: [String] = ["admin"]
    ) -> SAMLAssertion {
        let conditions = SAMLConditions(
            notBefore: notBefore,
            notOnOrAfter: notOnOrAfter,
            audienceRestrictions: [SAMLAudienceRestriction(audiences: [audience])]
        )
        let subject = SAMLSubject(
            nameID: email,
            nameIDFormat: .emailAddress,
            nameQualifier: nil,
            confirmations: [
                SAMLSubjectConfirmation(
                    method: .bearer,
                    confirmationData: SAMLSubjectConfirmationData(
                        recipient: "https://sp.example.com/acs",
                        notOnOrAfter: notOnOrAfter,
                        inResponseTo: "_req1"
                    )
                ),
            ]
        )
        let attributes: [SAMLAttribute] = [
            SAMLAttribute(name: "email", friendlyName: "email", nameFormat: nil, values: [email]),
            SAMLAttribute(name: "firstName", friendlyName: "firstName", nameFormat: nil, values: [firstName]),
            SAMLAttribute(name: "lastName", friendlyName: "lastName", nameFormat: nil, values: [lastName]),
            SAMLAttribute(name: "groups", friendlyName: nil, nameFormat: nil, values: groups),
        ]
        return SAMLAssertion(
            id: "_test_assertion",
            issuer: "https://idp.example.com",
            issueInstant: Date(),
            version: "2.0",
            subject: subject,
            conditions: conditions,
            authnStatement: nil,
            attributeStatements: [SAMLAttributeStatement(attributes: attributes)]
        )
    }
}

// MARK: - SAMLResponseTests

struct SAMLResponseTests {
    // MARK: Internal

    // MARK: - validate Tests

    @Test("validate returns success for valid response")
    func validate_validResponse_returnsSuccess() {
        let response = makeValidResponse()
        let result = response.validate(
            expectedDestination: "https://sp.example.com/acs",
            expectedRequestId: "_request789",
            audience: "https://sp.example.com"
        )
        #expect(result.isSuccess)
        #expect(result.error == nil)
    }

    @Test("validate returns failure when status is not success")
    func validate_failedStatus_returnsAuthenticationFailed() {
        let response = makeValidResponse(statusCode: .authnFailed)
        let result = response.validate(
            expectedDestination: "https://sp.example.com/acs",
            expectedRequestId: nil,
            audience: "https://sp.example.com"
        )
        #expect(!result.isSuccess)
        if case let .failure(error) = result {
            if case .authenticationFailed = error {
                // Expected
            } else {
                Issue.record("Expected authenticationFailed error, got \(error)")
            }
        } else {
            Issue.record("Expected failure result")
        }
    }

    @Test("validate returns failure when destination does not match")
    func validate_wrongDestination_returnsInvalidDestination() {
        let response = makeValidResponse(destination: "https://sp.example.com/acs")
        let result = response.validate(
            expectedDestination: "https://other.example.com/acs",
            expectedRequestId: nil,
            audience: "https://sp.example.com"
        )
        #expect(!result.isSuccess)
        if case let .failure(error) = result {
            if case .invalidDestination = error {
                // Expected
            } else {
                Issue.record("Expected invalidDestination error, got \(error)")
            }
        } else {
            Issue.record("Expected failure result")
        }
    }

    @Test("validate returns failure when InResponseTo does not match")
    func validate_wrongInResponseTo_returnsInvalidInResponseTo() {
        let response = makeValidResponse(inResponseTo: "_actual_request_id")
        let result = response.validate(
            expectedDestination: "https://sp.example.com/acs",
            expectedRequestId: "_different_request_id",
            audience: "https://sp.example.com"
        )
        #expect(!result.isSuccess)
        if case let .failure(error) = result {
            if case .invalidInResponseTo = error {
                // Expected
            } else {
                Issue.record("Expected invalidInResponseTo error, got \(error)")
            }
        } else {
            Issue.record("Expected failure result")
        }
    }

    @Test("validate returns failure when assertion has expired")
    func validate_expiredAssertion_returnsAssertionExpired() {
        let now = Date()
        let response = makeValidResponse(
            notBefore: now.addingTimeInterval(-7200),
            notOnOrAfter: now.addingTimeInterval(-3600)
        )
        let result = response.validate(
            expectedDestination: "https://sp.example.com/acs",
            expectedRequestId: nil,
            audience: "https://sp.example.com"
        )
        #expect(!result.isSuccess)
        if case let .failure(error) = result {
            #expect(error == .assertionExpired)
        } else {
            Issue.record("Expected failure result")
        }
    }

    @Test("validate returns failure when audience does not match")
    func validate_wrongAudience_returnsInvalidAudience() {
        let response = makeValidResponse(audience: "https://sp.example.com")
        let result = response.validate(
            expectedDestination: "https://sp.example.com/acs",
            expectedRequestId: nil,
            audience: "https://different-sp.example.com"
        )
        #expect(!result.isSuccess)
        if case let .failure(error) = result {
            if case .invalidAudience = error {
                // Expected
            } else {
                Issue.record("Expected invalidAudience error, got \(error)")
            }
        } else {
            Issue.record("Expected failure result")
        }
    }

    @Test("validate returns failure when no assertion is present")
    func validate_noAssertion_returnsMissingAssertion() {
        let response = SAMLResponse(
            id: "_response",
            inResponseTo: nil,
            destination: "https://sp.example.com/acs",
            issueInstant: Date(),
            issuer: "https://idp.example.com",
            version: "2.0",
            status: SAMLStatus(code: .success, subCode: nil, message: nil),
            assertions: []
        )
        let result = response.validate(
            expectedDestination: "https://sp.example.com/acs",
            expectedRequestId: nil,
            audience: "https://sp.example.com"
        )
        #expect(!result.isSuccess)
        if case let .failure(error) = result {
            #expect(error == .missingAssertion)
        } else {
            Issue.record("Expected failure result")
        }
    }

    @Test("validate passes when expectedRequestId is nil (not checking InResponseTo)")
    func validate_nilExpectedRequestId_doesNotCheckInResponseTo() {
        let response = makeValidResponse(inResponseTo: "_some_request")
        let result = response.validate(
            expectedDestination: "https://sp.example.com/acs",
            expectedRequestId: nil,
            audience: "https://sp.example.com"
        )
        #expect(result.isSuccess)
    }

    // MARK: - Convenience Properties Tests

    @Test("isSuccess returns true when status code is success")
    func isSuccess_successStatus_returnsTrue() {
        let response = makeValidResponse(statusCode: .success)
        #expect(response.isSuccess)
    }

    @Test("isSuccess returns false when status code is not success")
    func isSuccess_nonSuccessStatus_returnsFalse() {
        let response = makeValidResponse(statusCode: .authnFailed)
        #expect(!response.isSuccess)
    }

    @Test("errorMessage returns nil on successful response")
    func errorMessage_successStatus_returnsNil() {
        let response = makeValidResponse(statusCode: .success)
        #expect(response.errorMessage == nil)
    }

    @Test("errorMessage returns display name on failed response")
    func errorMessage_failedStatus_returnsDisplayName() {
        let response = makeValidResponse(statusCode: .authnFailed)
        #expect(response.errorMessage != nil)
        #expect(response.errorMessage == SAMLStatusCode.authnFailed.displayName)
    }

    @Test("primaryAssertion returns first assertion")
    func primaryAssertion_withAssertions_returnsFirstAssertion() {
        let response = makeValidResponse()
        #expect(response.primaryAssertion != nil)
        #expect(response.primaryAssertion?.id == "_assertion")
    }

    // MARK: Private

    private func makeValidResponse(
        destination: String = "https://sp.example.com/acs",
        inResponseTo: String? = "_request789",
        statusCode: SAMLStatusCode = .success,
        audience: String = "https://sp.example.com",
        notBefore: Date? = nil,
        notOnOrAfter: Date? = nil
    ) -> SAMLResponse {
        let now = Date()
        let effectiveNotBefore = notBefore ?? now.addingTimeInterval(-60)
        let effectiveNotOnOrAfter = notOnOrAfter ?? now.addingTimeInterval(3600)

        let conditions = SAMLConditions(
            notBefore: effectiveNotBefore,
            notOnOrAfter: effectiveNotOnOrAfter,
            audienceRestrictions: [SAMLAudienceRestriction(audiences: [audience])]
        )
        let subject = SAMLSubject(
            nameID: "user@example.com",
            nameIDFormat: .emailAddress,
            nameQualifier: nil,
            confirmations: []
        )
        let assertion = SAMLAssertion(
            id: "_assertion",
            issuer: "https://idp.example.com",
            issueInstant: now,
            version: "2.0",
            subject: subject,
            conditions: conditions,
            authnStatement: nil,
            attributeStatements: []
        )

        return SAMLResponse(
            id: "_response",
            inResponseTo: inResponseTo,
            destination: destination,
            issueInstant: now,
            issuer: "https://idp.example.com",
            version: "2.0",
            status: SAMLStatus(code: statusCode, subCode: nil, message: nil),
            assertions: [assertion]
        )
    }
}

// MARK: - SAMLValidationErrorTests

struct SAMLValidationErrorTests {
    // MARK: - Error Description Tests

    @Test("errorDescription is not empty for authenticationFailed")
    func errorDescription_authenticationFailed_isNotEmpty() {
        let error = SAMLValidationError.authenticationFailed("Bad credentials")
        #expect((error.errorDescription ?? "").isEmpty == false)
        #expect(error.errorDescription?.contains("Bad credentials") == true)
    }

    @Test("errorDescription is not empty for invalidDestination")
    func errorDescription_invalidDestination_isNotEmpty() {
        let error = SAMLValidationError.invalidDestination(
            expected: "https://expected.com",
            actual: "https://actual.com"
        )
        #expect((error.errorDescription ?? "").isEmpty == false)
        #expect(error.errorDescription?.contains("https://expected.com") == true)
    }

    @Test("errorDescription is not empty for invalidInResponseTo")
    func errorDescription_invalidInResponseTo_isNotEmpty() {
        let error = SAMLValidationError.invalidInResponseTo(
            expected: "_req1",
            actual: "_req2"
        )
        #expect((error.errorDescription ?? "").isEmpty == false)
        #expect(error.errorDescription?.contains("_req1") == true)
    }

    @Test("errorDescription is not empty for missingAssertion")
    func errorDescription_missingAssertion_isNotEmpty() {
        let error = SAMLValidationError.missingAssertion
        #expect((error.errorDescription ?? "").isEmpty == false)
    }

    @Test("errorDescription is not empty for assertionExpired")
    func errorDescription_assertionExpired_isNotEmpty() {
        let error = SAMLValidationError.assertionExpired
        #expect((error.errorDescription ?? "").isEmpty == false)
    }

    @Test("errorDescription is not empty for invalidAudience")
    func errorDescription_invalidAudience_isNotEmpty() {
        let error = SAMLValidationError.invalidAudience(expected: "https://sp.example.com")
        #expect((error.errorDescription ?? "").isEmpty == false)
        #expect(error.errorDescription?.contains("https://sp.example.com") == true)
    }

    @Test("errorDescription is not empty for signatureInvalid")
    func errorDescription_signatureInvalid_isNotEmpty() {
        let error = SAMLValidationError.signatureInvalid
        #expect((error.errorDescription ?? "").isEmpty == false)
    }

    @Test("errorDescription is not empty for xmlParsingFailed")
    func errorDescription_xmlParsingFailed_isNotEmpty() {
        let error = SAMLValidationError.xmlParsingFailed("Unexpected token")
        #expect((error.errorDescription ?? "").isEmpty == false)
        #expect(error.errorDescription?.contains("Unexpected token") == true)
    }

    @Test("errorDescription is not empty for invalidStructure")
    func errorDescription_invalidStructure_isNotEmpty() {
        let error = SAMLValidationError.invalidStructure("Missing Response ID")
        #expect((error.errorDescription ?? "").isEmpty == false)
        #expect(error.errorDescription?.contains("Missing Response ID") == true)
    }

    // MARK: - Recovery Suggestion Tests

    @Test("recoverySuggestion is not nil for all error cases")
    func recoverySuggestion_allCases_isNotNil() {
        let errors: [SAMLValidationError] = [
            .authenticationFailed("reason"),
            .invalidDestination(expected: "a", actual: "b"),
            .invalidInResponseTo(expected: "a", actual: "b"),
            .missingAssertion,
            .assertionExpired,
            .invalidAudience(expected: "a"),
            .signatureInvalid,
            .signatureMissing,
            .certificateInvalid,
            .certificateMismatch,
            .xmlParsingFailed("reason"),
            .invalidStructure("reason"),
            .issuerMismatch(expected: "a", actual: "b"),
        ]

        for error in errors {
            #expect(error.recoverySuggestion != nil, "recoverySuggestion should not be nil for \(error)")
        }
    }

    @Test("recoverySuggestion is not empty for authenticationFailed")
    func recoverySuggestion_authenticationFailed_isNotEmpty() {
        let error = SAMLValidationError.authenticationFailed("reason")
        #expect((error.recoverySuggestion ?? "").isEmpty == false)
    }

    @Test("recoverySuggestion is not empty for assertionExpired")
    func recoverySuggestion_assertionExpired_isNotEmpty() {
        let error = SAMLValidationError.assertionExpired
        #expect((error.recoverySuggestion ?? "").isEmpty == false)
    }

    // MARK: - Equatable Tests

    @Test("SAMLValidationError equality holds for same cases")
    func equality_sameCases_areEqual() {
        #expect(SAMLValidationError.missingAssertion == SAMLValidationError.missingAssertion)
        #expect(SAMLValidationError.assertionExpired == SAMLValidationError.assertionExpired)
        #expect(SAMLValidationError.signatureInvalid == SAMLValidationError.signatureInvalid)
    }

    @Test("SAMLValidationError inequality holds for different cases")
    func equality_differentCases_areNotEqual() {
        #expect(SAMLValidationError.missingAssertion != SAMLValidationError.assertionExpired)
    }
}

// MARK: - SAMLStatusCodeTests

struct SAMLStatusCodeTests {
    @Test("SAMLStatusCode displayName is non-empty for all cases")
    func displayName_allCases_isNotEmpty() {
        let codes: [SAMLStatusCode] = [
            .success, .requester, .responder, .versionMismatch,
            .authnFailed, .invalidAttrNameOrValue, .invalidNameIDPolicy,
            .noAuthnContext, .noAvailableIDP, .noPassive, .noSupportedIDP,
            .partialLogout, .proxyCountExceeded, .requestDenied, .requestUnsupported,
            .requestVersionDeprecated, .requestVersionTooHigh, .requestVersionTooLow,
            .resourceNotRecognized, .tooManyResponses, .unknownAttrProfile,
            .unknownPrincipal, .unsupportedBinding, .unknown,
        ]
        for code in codes {
            #expect(!code.displayName.isEmpty, "displayName should not be empty for \(code)")
        }
    }

    @Test("SAMLStatusCode rawValue initializer maps success correctly")
    func rawValueInit_success_mapsToSuccess() {
        let code = SAMLStatusCode(rawValue: "urn:oasis:names:tc:SAML:2.0:status:Success")
        #expect(code == .success)
    }

    @Test("SAMLStatusCode rawValue initializer maps authnFailed correctly")
    func rawValueInit_authnFailed_mapsToAuthnFailed() {
        let code = SAMLStatusCode(rawValue: "urn:oasis:names:tc:SAML:2.0:status:AuthnFailed")
        #expect(code == .authnFailed)
    }

    @Test("SAMLStatusCode rawValue initializer defaults to unknown for unrecognized value")
    func rawValueInit_unknownString_mapsToUnknown() {
        let code = SAMLStatusCode(rawValue: "urn:oasis:names:tc:SAML:2.0:status:SomethingUnknown")
        #expect(code == .unknown)
    }
}
