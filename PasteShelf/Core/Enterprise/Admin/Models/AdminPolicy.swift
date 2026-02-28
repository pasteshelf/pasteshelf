//
//  AdminPolicy.swift
//  PasteShelf
//
//  Model representing a server-side admin policy pushed to enrolled devices.
//

import Foundation

// MARK: - HistoryLimitPolicy

/// Policy governing clipboard history retention limits.
///
/// An administrator can cap the maximum number of stored items, the maximum age of
/// stored items, or both.  When `enforced` is `true` the application must apply
/// whichever limits are set and must not allow the user to exceed them.
struct HistoryLimitPolicy: Codable, Sendable, Equatable {

    /// The maximum number of clipboard items to retain.
    ///
    /// `nil` means no item-count limit is imposed by this policy.
    var maxItems: Int?

    /// The maximum number of days for which clipboard items are retained.
    ///
    /// `nil` means no age-based limit is imposed by this policy.
    var maxDays: Int?

    /// When `true` the limits must be enforced and the user cannot override them.
    var enforced: Bool

    /// Creates a history limit policy.
    ///
    /// - Parameters:
    ///   - maxItems: Optional upper bound on the number of retained items.
    ///   - maxDays: Optional upper bound on retention age in days.
    ///   - enforced: Whether the limits are administrator-locked. Defaults to `false`.
    init(maxItems: Int? = nil, maxDays: Int? = nil, enforced: Bool = false) {
        self.maxItems = maxItems
        self.maxDays = maxDays
        self.enforced = enforced
    }
}

// MARK: - ExcludedAppsPolicy

/// Policy governing which applications are excluded from clipboard monitoring.
///
/// Bundle identifiers listed here will not have their clipboard content captured.
/// When `enforced` is `true` the user cannot remove entries from this list, though
/// they may still add their own exclusions.
struct ExcludedAppsPolicy: Codable, Sendable, Equatable {

    /// The bundle identifiers of applications whose clipboard content must not be captured.
    var bundleIds: [String]

    /// When `true` the listed exclusions are administrator-locked and cannot be removed by the user.
    var enforced: Bool

    /// Creates an excluded apps policy.
    ///
    /// - Parameters:
    ///   - bundleIds: Bundle identifiers to exclude. Defaults to an empty array.
    ///   - enforced: Whether the exclusions are administrator-locked. Defaults to `false`.
    init(bundleIds: [String] = [], enforced: Bool = false) {
        self.bundleIds = bundleIds
        self.enforced = enforced
    }
}

// MARK: - SyncSettingsPolicy

/// Policy governing iCloud sync behaviour.
///
/// An administrator can mandate that sync is disabled (local storage only) or
/// conversely require it to be enabled.  When `enforced` is `true` the user cannot
/// change the sync-related settings covered by this policy.
struct SyncSettingsPolicy: Codable, Sendable, Equatable {

    /// When non-`nil`, overrides whether iCloud sync is active.
    var syncEnabled: Bool?

    /// When `true` (and enforced), the device must store clipboard data locally only.
    var localStorageOnly: Bool?

    /// When `true` these sync settings are administrator-locked and cannot be changed by the user.
    var enforced: Bool

    /// Creates a sync settings policy.
    ///
    /// - Parameters:
    ///   - syncEnabled: Optional override for the sync-enabled state.
    ///   - localStorageOnly: Optional flag requiring local-only storage.
    ///   - enforced: Whether the settings are administrator-locked. Defaults to `false`.
    init(syncEnabled: Bool? = nil, localStorageOnly: Bool? = nil, enforced: Bool = false) {
        self.syncEnabled = syncEnabled
        self.localStorageOnly = localStorageOnly
        self.enforced = enforced
    }
}

// MARK: - EncryptionPolicy

/// Policy governing local data encryption requirements.
///
/// Administrators can mandate that all locally stored clipboard data must be encrypted,
/// specify a minimum encryption key length, and optionally require biometric
/// authentication before decrypting data.
struct EncryptionPolicy: Codable, Sendable, Equatable {

    /// When `true` all locally stored clipboard data must be encrypted.
    var requireEncryption: Bool

    /// The minimum acceptable encryption key length in bits.
    ///
    /// `nil` means no specific key-length requirement is imposed.
    var minimumKeyLength: Int?

    /// When `true` the user must authenticate with biometrics (Touch ID / Apple Watch)
    /// before clipboard data can be decrypted.
    ///
    /// `nil` means no biometric requirement is imposed.
    var requireBiometricAuth: Bool?

    /// When `true` these encryption requirements are administrator-locked.
    var enforced: Bool

    /// Creates an encryption policy.
    ///
    /// - Parameters:
    ///   - requireEncryption: Whether local data encryption is mandatory.
    ///   - minimumKeyLength: Optional minimum key length in bits.
    ///   - requireBiometricAuth: Optional biometric authentication requirement.
    ///   - enforced: Whether the requirements are administrator-locked. Defaults to `false`.
    init(
        requireEncryption: Bool,
        minimumKeyLength: Int? = nil,
        requireBiometricAuth: Bool? = nil,
        enforced: Bool = false
    ) {
        self.requireEncryption = requireEncryption
        self.minimumKeyLength = minimumKeyLength
        self.requireBiometricAuth = requireBiometricAuth
        self.enforced = enforced
    }
}

// MARK: - AdminPolicy

/// A versioned, server-side policy document pushed to enrolled devices by the admin console.
///
/// `AdminPolicy` is the top-level container for all administrator-configurable settings
/// that can be pushed to enrolled devices.  Individual sub-policies (`historyLimits`,
/// `excludedApps`, `syncSettings`, `encryptionRequirements`) are optional; a `nil`
/// sub-policy means the administrator has not configured that area and the application
/// should apply its own defaults.
///
/// Use `.empty` as a safe default before any policy has been received from the server.
struct AdminPolicy: Codable, Sendable, Identifiable, Equatable {

    // MARK: - Identity

    /// The server-assigned unique identifier for this policy document.
    let id: String

    /// A monotonically increasing version string used to detect stale cached policies.
    let version: String

    /// A human-readable name for this policy, shown in the admin console UI.
    let name: String

    /// When this policy was last modified on the server.
    let updatedAt: Date

    // MARK: - Sub-Policies

    /// Clipboard history retention limits, or `nil` if not configured.
    var historyLimits: HistoryLimitPolicy?

    /// Application exclusion rules, or `nil` if not configured.
    var excludedApps: ExcludedAppsPolicy?

    /// iCloud sync settings, or `nil` if not configured.
    var syncSettings: SyncSettingsPolicy?

    /// Local data encryption requirements, or `nil` if not configured.
    var encryptionRequirements: EncryptionPolicy?

    // MARK: - Initialization

    /// Creates an admin policy with the given server-assigned fields and optional sub-policies.
    ///
    /// - Parameters:
    ///   - id: The server-assigned policy identifier.
    ///   - version: The policy version string.
    ///   - name: A human-readable name for the policy.
    ///   - updatedAt: When the policy was last modified.
    ///   - historyLimits: Optional history retention limits.
    ///   - excludedApps: Optional application exclusion rules.
    ///   - syncSettings: Optional iCloud sync settings.
    ///   - encryptionRequirements: Optional encryption requirements.
    init(
        id: String,
        version: String,
        name: String,
        updatedAt: Date,
        historyLimits: HistoryLimitPolicy? = nil,
        excludedApps: ExcludedAppsPolicy? = nil,
        syncSettings: SyncSettingsPolicy? = nil,
        encryptionRequirements: EncryptionPolicy? = nil
    ) {
        self.id = id
        self.version = version
        self.name = name
        self.updatedAt = updatedAt
        self.historyLimits = historyLimits
        self.excludedApps = excludedApps
        self.syncSettings = syncSettings
        self.encryptionRequirements = encryptionRequirements
    }

    // MARK: - Empty Sentinel

    /// An `AdminPolicy` with no sub-policies — represents a device with no active policy.
    ///
    /// Use this as a safe zero-value before any policy has been received from the server.
    static let empty = AdminPolicy(
        id: "",
        version: "0",
        name: "None",
        updatedAt: .distantPast,
        historyLimits: nil,
        excludedApps: nil,
        syncSettings: nil,
        encryptionRequirements: nil
    )
}
