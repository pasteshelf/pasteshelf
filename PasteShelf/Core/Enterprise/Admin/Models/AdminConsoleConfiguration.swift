//
//  AdminConsoleConfiguration.swift
//  PasteShelf
//
//  Model representing the server connection configuration for the centralized admin console.
//

import Foundation

// MARK: - AdminConsoleConfiguration

/// The configuration required to connect a device to the centralized admin console.
///
/// The admin console is an optional Enterprise feature that allows IT administrators
/// to manage enrolled devices, push policies, and collect health reports from a
/// central server.  `AdminConsoleConfiguration` stores the connection parameters
/// needed to reach that server and authenticate API requests.
///
/// Use `isConfigured` to determine whether all required fields are present before
/// attempting a connection.  Use `.empty` as a safe default value when no
/// configuration has been provided.
struct AdminConsoleConfiguration: Codable, Equatable, Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates an admin console configuration with the given connection parameters.
    ///
    /// - Parameters:
    ///   - serverURL: The base URL of the admin console server.
    ///   - organizationID: The tenant organization identifier.
    ///   - apiKey: An optional API key for request authentication.
    ///   - isEnabled: Whether the integration is active. Defaults to `false`.
    ///   - pollingInterval: How often to poll for policy updates, in seconds. Defaults to `300`.
    init(
        serverURL: URL? = nil,
        organizationID: String = "",
        apiKey: String? = nil,
        isEnabled: Bool = false,
        pollingInterval: TimeInterval = 300
    ) {
        self.serverURL = serverURL
        self.organizationID = organizationID
        self.apiKey = apiKey
        self.isEnabled = isEnabled
        self.pollingInterval = pollingInterval
    }

    // MARK: Internal

    // MARK: - Empty Sentinel

    /// An `AdminConsoleConfiguration` with no server, no organization, and the integration disabled.
    ///
    /// Use this as a safe zero-value before any admin console configuration has been applied.
    static let empty = AdminConsoleConfiguration(
        serverURL: nil,
        organizationID: "",
        apiKey: nil,
        isEnabled: false,
        pollingInterval: 300
    )

    // MARK: - Connection

    /// The base URL of the admin console server.
    ///
    /// `nil` means no server has been configured; in that case `isConfigured` returns `false`.
    let serverURL: URL?

    /// The organization identifier used to scope all API requests to the correct tenant.
    let organizationID: String

    /// An optional API key for authenticating requests to the admin console server.
    ///
    /// When present this key is included in the `Authorization` header of every outbound
    /// request.  It may be `nil` for deployments that rely solely on certificate-based
    /// mutual TLS or another authentication mechanism.
    var apiKey: String?

    // MARK: - State

    /// Whether the admin console integration is currently active.
    ///
    /// When `false` the device will not attempt to contact the server regardless of
    /// whether `serverURL` and `organizationID` are set.
    var isEnabled: Bool

    // MARK: - Sync

    /// How frequently (in seconds) the client polls the admin console for policy updates.
    ///
    /// The default value is 300 seconds (5 minutes).  Administrators should set this to a
    /// value appropriate for their organization's network constraints and policy cadence.
    var pollingInterval: TimeInterval

    /// `true` when both a server URL and a non-empty organization ID have been supplied.
    ///
    /// Use this to guard connection attempts and to show configuration-required prompts in the UI.
    var isConfigured: Bool {
        serverURL != nil && !organizationID.isEmpty
    }
}
