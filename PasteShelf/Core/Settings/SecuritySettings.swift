//
//  SecuritySettings.swift
//  PasteShelf
//
//  Security-related settings for biometric auth, auto-lock, and clear-on-quit.
//  These are typically enforced via MDM policies.
//

import Foundation

/// Security settings for authentication and data protection.
struct SecuritySettings: Codable, Equatable {
    /// Whether biometric authentication (Touch ID) is required to access the app.
    var requireBiometricAuth: Bool

    /// Idle timeout in seconds before the app auto-locks. 0 means disabled.
    var autoLockTimeout: Int

    /// Whether clipboard history is cleared when the app quits.
    var clearOnQuit: Bool

    // MARK: - Defaults

    static let `default` = SecuritySettings(
        requireBiometricAuth: false,
        autoLockTimeout: 0,
        clearOnQuit: false
    )
}
