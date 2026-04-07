//
//  HIPAAComplianceMode.swift
//  PasteShelf
//
//  Configuration for HIPAA compliance mode, controlling enhanced audit, access controls, and retention.
//

import Foundation

/// Configuration that governs HIPAA compliance behavior across the application.
///
/// When `isEnabled` is `true`, the application enforces HIPAA-specific requirements
/// including enhanced audit logging with PHI indicators, mandatory session timeouts,
/// and biometric/SSO authentication before accessing clipboard data.
///
/// Persisted to `UserDefaults` under `com.pasteshelf.hipaa.config`.
struct HIPAAComplianceMode: Codable, Equatable {
    // MARK: Internal

    /// Default configuration with HIPAA mode disabled.
    static let `default` = HIPAAComplianceMode(
        isEnabled: false,
        sessionTimeoutMinutes: 15,
        requireBiometric: false,
        requireSSO: false
    )

    /// Whether HIPAA compliance mode is active.
    var isEnabled: Bool

    /// Session inactivity timeout in minutes before the application locks.
    var sessionTimeoutMinutes: Int

    /// Whether biometric authentication (Touch ID) is required to unlock.
    var requireBiometric: Bool

    /// Whether SSO authentication is required before granting access.
    var requireSSO: Bool

    /// Loads the current HIPAA configuration from UserDefaults.
    static func load() -> HIPAAComplianceMode {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let config = try? JSONDecoder().decode(HIPAAComplianceMode.self, from: data)
        else {
            return .default
        }
        return config
    }

    /// Persists the current HIPAA configuration to UserDefaults.
    func save() {
        guard let data = try? JSONEncoder().encode(self) else {
            return
        }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }

    // MARK: Private

    // MARK: - Persistence

    private static let userDefaultsKey = "com.pasteshelf.hipaa.config"
}
