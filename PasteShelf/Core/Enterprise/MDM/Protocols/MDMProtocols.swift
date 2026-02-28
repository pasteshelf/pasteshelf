//
//  MDMProtocols.swift
//  PasteShelf
//
//  Protocols defining the Enterprise MDM managed preferences reading and observation layer.
//

import Combine
import Foundation

// MARK: - ManagedPreferencesReading

/// Abstraction over a concrete managed preferences reader for MDM-enrolled devices.
///
/// Implementations read values from the managed preferences domain pushed by an MDM
/// server (e.g., via a configuration profile) and report which keys are forced.
protocol ManagedPreferencesReading: Sendable {
    /// Reads all current managed preferences and returns a structured configuration snapshot.
    ///
    /// - Returns: An `MDMConfiguration` value representing the full set of managed preferences
    ///   currently in effect. Keys not present in the managed domain use their default values.
    func readConfiguration() -> MDMConfiguration

    /// Checks whether a specific preference key is forced by the MDM profile.
    ///
    /// A forced key cannot be overridden by the user; its value is exclusively controlled
    /// by the MDM server.
    ///
    /// - Parameter key: The `ManagedPreferenceKey` to check.
    /// - Returns: `true` if the key is present in the forced managed domain, `false` otherwise.
    func isKeyForced(_ key: ManagedPreferenceKey) -> Bool

    /// Reads a specific typed value from the managed preferences domain.
    ///
    /// Returns `nil` if the key is absent from the managed domain or if the stored value
    /// cannot be cast to the requested type `T`.
    ///
    /// - Parameter key: The `ManagedPreferenceKey` identifying the preference to read.
    /// - Returns: The managed value cast to `T`, or `nil` if unavailable or type-mismatched.
    func value<T>(for key: ManagedPreferenceKey) -> T?
}

// MARK: - MDMConfigurationObserving

/// Observes changes to MDM managed preferences pushed by an MDM server.
///
/// Implementations should watch the managed preferences domain (e.g., via
/// `NSUserDefaults` distributed notifications or file-system observation) and
/// publish a new `MDMConfiguration` snapshot each time the profile changes.
protocol MDMConfigurationObserving {
    /// A publisher that emits a new `MDMConfiguration` snapshot whenever the managed
    /// preferences change on the device.
    ///
    /// Subscribers receive the full updated configuration on each emission; there is
    /// no partial-update model. The publisher never fails.
    var configurationDidChange: AnyPublisher<MDMConfiguration, Never> { get }

    /// Starts watching for MDM profile changes.
    ///
    /// Call this once before expecting emissions from `configurationDidChange`. Calling
    /// `startObserving()` when already observing is a no-op.
    func startObserving()

    /// Stops watching for MDM profile changes.
    ///
    /// After calling this method, `configurationDidChange` will no longer emit values
    /// until `startObserving()` is called again.
    func stopObserving()
}

// MARK: - MDMError

/// Errors that may be thrown during MDM managed-preferences operations.
enum MDMError: Error, LocalizedError, Sendable {
    /// The device is not enrolled in or managed by an MDM server.
    case notManaged

    /// The MDM configuration profile contains invalid or malformed values.
    case configurationInvalid(String)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .notManaged:
            return "This device is not under MDM management. Managed preferences are unavailable."
        case .configurationInvalid(let reason):
            return "The MDM configuration profile is invalid: \(reason)"
        }
    }

    var failureReason: String? {
        switch self {
        case .notManaged:
            return "No managed preferences domain was found on this device."
        case .configurationInvalid(let reason):
            return reason
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notManaged:
            return "Enroll the device with an MDM server and push a PasteShelf configuration profile."
        case .configurationInvalid:
            return "Contact your IT administrator to review and correct the PasteShelf configuration profile."
        }
    }
}
