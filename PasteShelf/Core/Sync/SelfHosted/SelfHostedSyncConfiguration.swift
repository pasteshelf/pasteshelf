//
//  SelfHostedSyncConfiguration.swift
//  PasteShelf
//
//  Configuration for connecting to a self-hosted sync server.
//

import Foundation

// MARK: - SelfHostedSyncConfiguration

/// The configuration required to connect to a self-hosted PasteShelf sync server.
///
/// Enterprise customers deploy their own sync server for data sovereignty. This
/// model stores the connection parameters: server URL, organization, authentication,
/// and optional certificate pinning settings.
///
/// Use `isConfigured` to guard connection attempts. Use `.empty` as a safe default.
public struct SelfHostedSyncConfiguration: Codable, Equatable, Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    public init(
        serverURL: URL? = nil,
        organizationID: String = "",
        apiKey: String? = nil,
        isEnabled: Bool = false,
        certificatePinningEnabled: Bool = false,
        pinnedCertificateData: Data? = nil
    ) {
        self.serverURL = serverURL
        self.organizationID = organizationID
        self.apiKey = apiKey
        self.isEnabled = isEnabled
        self.certificatePinningEnabled = certificatePinningEnabled
        self.pinnedCertificateData = pinnedCertificateData
    }

    // MARK: Public

    // MARK: - Empty Sentinel

    /// A zero-value configuration with no server and sync disabled.
    public static let empty = SelfHostedSyncConfiguration(
        serverURL: nil,
        organizationID: "",
        apiKey: nil,
        isEnabled: false,
        certificatePinningEnabled: false,
        pinnedCertificateData: nil
    )

    // MARK: - Connection

    /// The base URL of the self-hosted sync server (e.g., `https://sync.company.internal`).
    public let serverURL: URL?

    /// The organization identifier for multi-tenant deployments.
    public let organizationID: String

    /// An optional API key for persistent device authentication.
    ///
    /// When set, the client includes this in the `Authorization: Api-Key <key>` header.
    /// `nil` when the device uses JWT-based authentication from SSO.
    public var apiKey: String?

    // MARK: - State

    /// Whether self-hosted sync is currently active.
    public var isEnabled: Bool

    // MARK: - Certificate Pinning

    /// Whether to enforce certificate pinning for the server connection.
    ///
    /// When `true`, the client validates the server's TLS certificate against
    /// pinned certificates stored in the app bundle or Keychain.
    public var certificatePinningEnabled: Bool

    /// Base64-encoded pinned certificate data.
    ///
    /// Populated from the app bundle, MDM managed preferences, or manual import.
    /// When `nil` and `certificatePinningEnabled` is `true`, the client uses
    /// system-trusted CA validation only.
    public var pinnedCertificateData: Data?

    /// `true` when both a server URL and a non-empty organization ID are present.
    public var isConfigured: Bool {
        serverURL != nil && !organizationID.isEmpty
    }
}
