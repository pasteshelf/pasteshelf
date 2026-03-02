//
//  SAMLLogoutHandler.swift
//  PasteShelf
//
//  Handles SAML 2.0 Single Logout (SLO) for Enterprise SSO.
//  Generates LogoutRequest XML, builds the SLO redirect URL, opens the IdP
//  in a browser session, and parses any LogoutResponse received on callback.
//

import AppKit
import AuthenticationServices
import Foundation
import os.log

/// Handles SAML 2.0 Single Logout for Enterprise SSO
final class SAMLLogoutHandler: NSObject, @unchecked Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.pasteshelf", category: "saml-logout")
    private let parser = SAMLParser()

    /// Callback URL scheme for receiving SLO responses
    private let callbackScheme = "pasteshelf"

    // MARK: - Public Interface

    /// Performs Single Logout with the IdP via the HTTP-Redirect binding.
    ///
    /// - Parameters:
    ///   - session: The current SSO session (provides sessionIndex and userId)
    ///   - config: The SAML provider configuration (provides sloURL and issuer)
    /// - Returns: `true` if the IdP acknowledged a full logout; `false` on partial logout.
    /// - Throws: `SSOError` if the logout flow cannot be initiated or the IdP reports failure.
    func performLogout(session: SSOSession, config: SAMLProviderConfig) async throws -> Bool {
        guard let sloURL = config.sloURL else {
            logger.info("No SLO endpoint configured for provider — skipping IdP logout")
            return true
        }

        logger.info("Starting SAML SLO flow for user: \(session.userId)")

        let requestId = "_\(UUID().uuidString)"
        let logoutRequestURL = try buildLogoutURL(
            sloURL: sloURL,
            logoutRequestXML: generateLogoutRequestXML(
                requestId: requestId,
                issuer: config.audienceRestriction,
                destination: sloURL.absoluteString,
                nameID: session.userId,
                nameIDFormat: config.nameIDFormat,
                sessionIndex: session.sessionIndex
            )
        )

        // Open browser session for logout
        let callbackURL = try await performBrowserLogout(url: logoutRequestURL)

        // Extract and parse the LogoutResponse if the IdP redirected back with one
        if let logoutResponse = extractLogoutResponse(from: callbackURL) {
            return try parseLogoutResponse(logoutResponse, requestId: requestId)
        }

        // If the callback URL had no SAMLResponse the IdP still accepted the logout
        logger.info("SAML SLO completed (no LogoutResponse in callback)")
        return true
    }

    /// Generates a SAML 2.0 LogoutRequest XML document.
    ///
    /// - Parameters:
    ///   - requestId:      Unique ID for this request (should start with "_")
    ///   - issuer:         SP entity ID / audience restriction value
    ///   - destination:    The IdP's SLO endpoint URL
    ///   - nameID:         The user identifier to log out
    ///   - nameIDFormat:   Format URI for the NameID element
    ///   - sessionIndex:   SAML SessionIndex from the original assertion (optional)
    /// - Returns: A well-formed SAML 2.0 LogoutRequest XML string
    func generateLogoutRequestXML(
        requestId: String,
        issuer: String,
        destination: String,
        nameID: String,
        nameIDFormat: SAMLNameIDFormat,
        sessionIndex: String?
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let issueInstant = formatter.string(from: Date())

        var sessionIndexElement = ""
        if let sessionIndex {
            sessionIndexElement = "\n    <samlp:SessionIndex>\(sessionIndex)</samlp:SessionIndex>"
        }

        return """
        <samlp:LogoutRequest xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
                             xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
                             ID="\(requestId)"
                             Version="2.0"
                             IssueInstant="\(issueInstant)"
                             Destination="\(destination)">
            <saml:Issuer>\(issuer)</saml:Issuer>
            <saml:NameID Format="\(nameIDFormat.rawValue)">\(nameID)</saml:NameID>\(sessionIndexElement)
        </samlp:LogoutRequest>
        """
    }

    /// Builds the SLO redirect URL by deflate-compressing and base64-encoding the
    /// LogoutRequest XML, then appending it as the `SAMLRequest` query parameter.
    ///
    /// - Parameters:
    ///   - sloURL:            The identity provider's Single Logout Service endpoint
    ///   - logoutRequestXML:  The raw LogoutRequest XML string
    /// - Returns: The complete URL to open in the browser to initiate SLO
    /// - Throws: `SSOError.configurationInvalid` if encoding or URL construction fails
    func buildLogoutURL(sloURL: URL, logoutRequestXML: String) throws -> URL {
        guard let xmlData = logoutRequestXML.data(using: .utf8) else {
            throw SSOError.configurationInvalid("Failed to encode LogoutRequest XML as UTF-8")
        }

        // Deflate the XML (raw deflate, no zlib header — required by SAML HTTP-Redirect binding)
        let deflatedData = try deflate(xmlData)

        // Base64 encode
        let base64 = deflatedData.base64EncodedString()

        // Append as SAMLRequest query parameter
        guard var components = URLComponents(url: sloURL, resolvingAgainstBaseURL: false) else {
            throw SSOError.configurationInvalid("Invalid SLO URL: \(sloURL)")
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "SAMLRequest", value: base64))
        components.queryItems = queryItems

        guard let finalURL = components.url else {
            throw SSOError.configurationInvalid("Failed to build SLO URL with LogoutRequest")
        }

        return finalURL
    }

    // MARK: - Browser Logout

    /// Opens the IdP SLO URL in a managed browser session and waits for the callback.
    @MainActor
    private func performBrowserLogout(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    // ASWebAuthenticationSession returns a cancellation error when the user
                    // dismisses the browser or the IdP closes the window without a redirect.
                    // Treat this as a successful logout rather than a hard failure.
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        // Build a synthetic callback URL so the caller can handle gracefully
                        continuation.resume(
                            returning: URL(string: "\(self.callbackScheme)://slo-complete")!
                        )
                        return
                    }
                    continuation.resume(
                        throwing: SSOError.logoutFailed(error.localizedDescription)
                    )
                    return
                }

                guard let callbackURL else {
                    // No redirect back from IdP — treat as success
                    continuation.resume(
                        returning: URL(string: "\(self.callbackScheme)://slo-complete")!
                    )
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

    /// Extracts the base64-encoded SAMLResponse from the callback URL query string,
    /// or returns `nil` if no LogoutResponse is present.
    private func extractLogoutResponse(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems
        else {
            return nil
        }

        // SAMLResponse is present when the IdP redirects back with a LogoutResponse
        if let samlResponse = queryItems.first(where: { $0.name == "SAMLResponse" })?.value {
            return samlResponse
        }

        // Some IdPs include the response in the URL fragment
        if let fragment = components.fragment {
            let fragmentComponents = URLComponents(string: "?\(fragment)")
            if let samlResponse = fragmentComponents?.queryItems?.first(
                where: { $0.name == "SAMLResponse" }
            )?.value {
                return samlResponse
            }
        }

        return nil
    }

    // MARK: - LogoutResponse Parsing

    /// Parses a base64-encoded SAML LogoutResponse and checks its status code.
    ///
    /// - Parameters:
    ///   - base64Response: The base64-encoded LogoutResponse from the IdP
    ///   - requestId:      The ID of the original LogoutRequest, for correlation
    /// - Returns: `true` on full success; `false` on partial logout
    /// - Throws: `SSOError.logoutFailed` if the IdP reports failure
    private func parseLogoutResponse(_ base64Response: String, requestId: String) throws -> Bool {
        let response: SAMLResponse
        do {
            response = try parser.parseBase64EncodedResponse(base64Response)
        } catch {
            logger.warning("Could not parse LogoutResponse — treating as successful: \(error.localizedDescription)")
            // If we cannot parse the response, assume the IdP accepted the logout
            return true
        }

        switch response.status.code {
        case .success:
            logger.info("SAML SLO succeeded (status: Success)")
            return true

        case .partialLogout:
            logger.warning("SAML SLO partially completed (status: PartialLogout)")
            // Partial logout is not an error — some sessions at the IdP may still be active
            return false

        default:
            let reason = response.status.message ?? response.status.code.displayName
            logger.error("SAML SLO failed with status: \(response.status.code.rawValue)")
            throw SSOError.logoutFailed("IdP rejected logout: \(reason)")
        }
    }

    // MARK: - Compression

    /// Deflates data using raw DEFLATE (RFC 1951) compression, stripping the zlib
    /// header and checksum so the result is compatible with the SAML HTTP-Redirect binding.
    private func deflate(_ data: Data) throws -> Data {
        let nsData = data as NSData
        do {
            let compressed = try nsData.compressed(using: .zlib)
            let compressedData = compressed as Data
            // Strip 2-byte zlib header and 4-byte Adler-32 checksum
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

extension SAMLLogoutHandler: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? NSWindow()
    }
}
