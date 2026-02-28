//
//  CertificatePinningDelegate.swift
//  PasteShelf
//
//  URLSessionDelegate that enforces certificate pinning for self-hosted sync.
//  Validates the server's TLS certificate against pinned certificates.
//

import CryptoKit
import Foundation
import os.log
import Security

// MARK: - CertificatePinningDelegate

/// URLSessionDelegate that performs certificate pinning for self-hosted sync connections.
///
/// When certificate pinning is enabled in the configuration, this delegate
/// validates the server's TLS certificate against stored pinned certificates.
/// If the certificate doesn't match, the connection is rejected.
final class CertificatePinningDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {

    // MARK: - Properties

    private let configuration: SelfHostedSyncConfiguration
    private let logger = Logger(subsystem: "com.pasteshelf", category: "cert-pinning")

    // MARK: - Initialization

    init(configuration: SelfHostedSyncConfiguration) {
        self.configuration = configuration
        super.init()
    }

    // MARK: - URLSessionDelegate

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard configuration.certificatePinningEnabled else {
            // Pinning disabled — use default handling
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Evaluate the server trust
        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)

        guard isValid else {
            logger.error("Server trust evaluation failed: \(error?.localizedDescription ?? "unknown")")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // If we have pinned certificate data, verify against it
        if let pinnedData = configuration.pinnedCertificateData {
            guard validatePinnedCertificate(serverTrust: serverTrust, pinnedData: pinnedData) else {
                logger.error("Certificate pinning validation failed for \(challenge.protectionSpace.host)")
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            logger.debug("Certificate pinning validated for \(challenge.protectionSpace.host)")
        }

        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }

    // MARK: - Certificate Validation

    /// Validate the server's certificate chain against the pinned certificate data.
    ///
    /// Compares the SHA-256 hash of the server's leaf certificate's public key
    /// against the hash of the pinned certificate's public key.
    private func validatePinnedCertificate(serverTrust: SecTrust, pinnedData: Data) -> Bool {
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        guard certificateCount > 0 else { return false }

        // Get the leaf certificate (index 0)
        guard let certificates = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let serverCertificate = certificates.first
        else { return false }

        // Extract public key hash from server certificate
        guard let serverPublicKeyHash = publicKeyHash(for: serverCertificate) else {
            logger.error("Failed to extract public key from server certificate")
            return false
        }

        // Extract public key hash from pinned certificate data
        guard let pinnedCertificate = SecCertificateCreateWithData(nil, pinnedData as CFData),
              let pinnedPublicKeyHash = publicKeyHash(for: pinnedCertificate)
        else {
            logger.error("Failed to extract public key from pinned certificate")
            return false
        }

        return serverPublicKeyHash == pinnedPublicKeyHash
    }

    /// Compute the SHA-256 hash of a certificate's public key.
    private func publicKeyHash(for certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate) else { return nil }

        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }

        let hash = SHA256.hash(data: publicKeyData)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Certificate Utilities

extension CertificatePinningDelegate {
    /// Load a certificate from a DER-encoded file in the app bundle.
    static func loadCertificate(named name: String, extension ext: String = "der") -> Data? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    /// Load a certificate from Base64-encoded string (e.g., from MDM profile).
    static func loadCertificate(fromBase64 string: String) -> Data? {
        Data(base64Encoded: string)
    }
}
