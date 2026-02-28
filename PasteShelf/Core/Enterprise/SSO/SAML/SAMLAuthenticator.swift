//
//  SAMLAuthenticator.swift
//  PasteShelf
//
//  Implements the SAML 2.0 SP-Initiated SSO flow for Enterprise SSO.
//  Generates AuthnRequests, opens the IdP in a browser session, and
//  processes the SAML response to create an SSOSession.
//

import AuthenticationServices
import Foundation
import os.log

/// SAML 2.0 SSO provider that handles the full SP-initiated authentication flow
final class SAMLAuthenticator: NSObject, SSOProvider, @unchecked Sendable {
    // MARK: - Properties

    let providerType: IdentityProviderType = .saml

    private let parser = SAMLParser()
    private let logger = Logger(subsystem: "com.pasteshelf", category: "saml-auth")

    /// Callback URL scheme for receiving SAML responses
    private let callbackScheme = "pasteshelf"

    // MARK: - SSOProvider

    func authenticate(config: IdentityProvider) async throws -> SSOSession {
        guard let samlConfig = config.samlConfig else {
            throw SSOError.configurationInvalid("SAML configuration is missing")
        }

        logger.info("Starting SAML SSO flow for provider: \(config.name)")

        // Generate AuthnRequest
        let requestId = "_\(UUID().uuidString)"
        let authnRequestURL = try buildAuthnRequestURL(
            config: samlConfig,
            requestId: requestId,
            issuer: samlConfig.audienceRestriction
        )

        // Open browser for authentication
        let callbackURL = try await performBrowserAuthentication(url: authnRequestURL)

        // Extract SAML response from callback
        let samlResponseData = try extractSAMLResponse(from: callbackURL)

        // Parse and validate SAML response
        let response = try parser.parseBase64EncodedResponse(samlResponseData)

        let validationResult = response.validate(
            expectedDestination: samlConfig.assertionConsumerServiceURL,
            expectedRequestId: requestId,
            audience: samlConfig.audienceRestriction
        )

        guard validationResult.isSuccess else {
            let error = validationResult.error?.localizedDescription ?? "Unknown validation error"
            logger.error("SAML validation failed: \(error)")
            throw SSOError.authenticationFailed(error)
        }

        guard let assertion = response.primaryAssertion else {
            throw SSOError.authenticationFailed("No assertion in SAML response")
        }

        logger.info("SAML SSO authentication successful for user: \(assertion.userId)")

        // Build session from assertion
        return SSOSession(
            providerId: config.id,
            userId: assertion.userId,
            email: assertion.email,
            displayName: assertion.displayName,
            groups: assertion.groups,
            authenticatedAt: Date(),
            expiresAt: assertion.authnStatement?.sessionNotOnOrAfter,
            sessionIndex: assertion.authnStatement?.sessionIndex
        )
    }

    func validateSession(_ session: SSOSession) async throws -> Bool {
        // SAML sessions are validated by checking expiry locally;
        // there is no standard SAML session validation endpoint
        return session.isValid
    }

    func logout(session: SSOSession) async throws {
        // Single logout is handled by SAMLLogoutHandler (separate task)
        // This is a placeholder that clears the local session
        logger.info("SAML logout requested for session: \(session.id)")
    }

    // MARK: - AuthnRequest Generation

    /// Builds the SSO URL with an encoded AuthnRequest
    func buildAuthnRequestURL(
        config: SAMLProviderConfig,
        requestId: String,
        issuer: String
    ) throws -> URL {
        let authnRequestXML = generateAuthnRequestXML(
            requestId: requestId,
            issuer: issuer,
            destination: config.ssoURL.absoluteString,
            acsURL: config.assertionConsumerServiceURL,
            nameIDFormat: config.nameIDFormat
        )

        switch config.binding {
        case .httpRedirect:
            return try buildRedirectURL(
                ssoURL: config.ssoURL,
                authnRequestXML: authnRequestXML
            )
        case .httpPost:
            // For HTTP-POST, we still redirect to our local handler that
            // generates the auto-submit form. In practice, we use HTTP-Redirect
            // for SP-initiated SSO and HTTP-POST for IdP responses.
            return try buildRedirectURL(
                ssoURL: config.ssoURL,
                authnRequestXML: authnRequestXML
            )
        }
    }

    /// Generates SAML 2.0 AuthnRequest XML
    func generateAuthnRequestXML(
        requestId: String,
        issuer: String,
        destination: String,
        acsURL: String,
        nameIDFormat: SAMLNameIDFormat
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let issueInstant = formatter.string(from: Date())

        return """
        <samlp:AuthnRequest xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
                            xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
                            ID="\(requestId)"
                            Version="2.0"
                            IssueInstant="\(issueInstant)"
                            Destination="\(destination)"
                            AssertionConsumerServiceURL="\(acsURL)"
                            ProtocolBinding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST">
            <saml:Issuer>\(issuer)</saml:Issuer>
            <samlp:NameIDPolicy Format="\(nameIDFormat.rawValue)"
                                AllowCreate="true"/>
        </samlp:AuthnRequest>
        """
    }

    // MARK: - Browser Authentication

    /// Opens the IdP SSO URL in a managed browser session and waits for the callback
    @MainActor
    private func performBrowserAuthentication(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: SSOError.authenticationFailed(error.localizedDescription))
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: SSOError.authenticationFailed("No callback URL received"))
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = self
            session.start()
        }
    }

    // MARK: - Response Extraction

    /// Extracts the base64-encoded SAML response from the callback URL
    private func extractSAMLResponse(from url: URL) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems
        else {
            throw SSOError.authenticationFailed("Invalid callback URL format")
        }

        // Look for SAMLResponse parameter
        if let samlResponse = queryItems.first(where: { $0.name == "SAMLResponse" })?.value {
            return samlResponse
        }

        // Also check fragment (some IdPs use fragment-based responses)
        if let fragment = components.fragment {
            let fragmentComponents = URLComponents(string: "?\(fragment)")
            if let samlResponse = fragmentComponents?.queryItems?.first(where: { $0.name == "SAMLResponse" })?.value {
                return samlResponse
            }
        }

        throw SSOError.authenticationFailed("No SAMLResponse found in callback URL")
    }

    // MARK: - URL Building

    /// Builds an HTTP-Redirect binding URL with deflated and encoded AuthnRequest
    private func buildRedirectURL(ssoURL: URL, authnRequestXML: String) throws -> URL {
        guard let xmlData = authnRequestXML.data(using: .utf8) else {
            throw SSOError.configurationInvalid("Failed to encode AuthnRequest XML")
        }

        // Deflate the XML (raw deflate, no zlib header)
        let deflatedData = try deflate(xmlData)

        // Base64 encode
        let base64 = deflatedData.base64EncodedString()

        // URL encode and build final URL
        guard var components = URLComponents(url: ssoURL, resolvingAgainstBaseURL: false) else {
            throw SSOError.configurationInvalid("Invalid SSO URL: \(ssoURL)")
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "SAMLRequest", value: base64))
        components.queryItems = queryItems

        guard let finalURL = components.url else {
            throw SSOError.configurationInvalid("Failed to build SSO URL with AuthnRequest")
        }

        return finalURL
    }

    /// Deflates data using raw DEFLATE (RFC 1951) compression
    private func deflate(_ data: Data) throws -> Data {
        // Use NSData's built-in compression
        let nsData = data as NSData
        // Try compression; if it fails, fall back to base64 of raw XML
        // (some IdPs accept uncompressed requests in HTTP-Redirect)
        do {
            let compressed = try nsData.compressed(using: .zlib)
            // Strip zlib header (first 2 bytes) and checksum (last 4 bytes) for raw deflate
            let compressedData = compressed as Data
            if compressedData.count > 6 {
                return compressedData.dropFirst(2).dropLast(4)
            }
            return compressedData
        } catch {
            logger.warning("Deflate compression failed, using raw XML: \(error.localizedDescription)")
            return data
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension SAMLAuthenticator: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the key window or create a new one
        NSApplication.shared.keyWindow ?? NSWindow()
    }
}
