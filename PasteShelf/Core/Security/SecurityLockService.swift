//
//  SecurityLockService.swift
//  PasteShelf
//
//  Enforces general security settings: biometric authentication gating and
//  auto-lock after inactivity. Driven by SecuritySettings (separate from HIPAA).
//

import Combine
import Foundation
import LocalAuthentication
import os.log

// MARK: - SecurityLockService

/// Enforces `SecuritySettings.requireBiometricAuth` and `SecuritySettings.autoLockTimeout`.
///
/// When biometric authentication is required, the service starts in a locked state and
/// the floating panel must call `unlock()` before displaying clipboard content. When an
/// auto-lock timeout is configured, the service locks the app after that many seconds of
/// inactivity.
///
/// This service is independent of `HIPAAAccessControlService`. If both are active, the
/// floating panel must satisfy **both** locks before showing content.
@MainActor
final class SecurityLockService: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    private init() {}

    // MARK: - Cleanup

    deinit {
        timeoutTimer?.invalidate()
    }

    // MARK: Internal

    // MARK: - Singleton

    static let shared = SecurityLockService()

    // MARK: - Published State

    /// Whether the application is currently locked and requires authentication.
    @Published private(set) var isLocked: Bool = false

    /// Whether an authentication attempt is in progress.
    @Published private(set) var isAuthenticating: Bool = false

    // MARK: - Configuration

    /// Activates security controls based on the current `SecuritySettings`.
    ///
    /// Call this at app launch and whenever settings change. If biometric auth is
    /// required, the app starts locked. If auto-lock timeout is set, the inactivity
    /// timer is started.
    func configure() {
        let settings = SettingsManager.shared.security

        if settings.requireBiometricAuth {
            if !isLocked {
                isLocked = true
            }
            logger.info("Security lock: biometric auth required")
        } else {
            isLocked = false
        }

        // Auto-lock timeout (0 = disabled)
        if settings.autoLockTimeout > 0 {
            startTimeoutTimer(timeoutSeconds: settings.autoLockTimeout)
            logger.info("Security lock: auto-lock timeout set to \(settings.autoLockTimeout)s")
        } else {
            stopTimeoutTimer()
        }
    }

    // MARK: - Authentication

    /// Attempts to unlock the application using biometric authentication.
    ///
    /// - Returns: `true` if authentication succeeded and the application was unlocked.
    @discardableResult
    func unlock() async -> Bool {
        let settings = SettingsManager.shared.security

        guard settings.requireBiometricAuth else {
            isLocked = false
            return true
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        let success = await performBiometricAuth()
        if success {
            isLocked = false
            lastActivityTimestamp = Date()
            logger.info("Security lock: unlocked via biometric auth")
        }
        return success
    }

    /// Locks the application, requiring re-authentication.
    func lock() {
        guard SettingsManager.shared.security.requireBiometricAuth else {
            return
        }
        isLocked = true
        logger.info("Security lock: application locked")
    }

    // MARK: - Activity Tracking

    /// Records user activity to reset the inactivity timeout.
    func recordActivity() {
        lastActivityTimestamp = Date()
    }

    // MARK: Private

    /// The interval at which the timeout timer checks for inactivity.
    private static let timeoutCheckInterval: TimeInterval = 15

    // MARK: - Private State

    /// Timestamp of the last user activity (used for inactivity timeout).
    private var lastActivityTimestamp: Date = .init()

    /// Timer that periodically checks for session inactivity.
    private var timeoutTimer: Timer?

    private let logger = Logger.security

    // MARK: - Timeout Timer

    private func startTimeoutTimer(timeoutSeconds: Int) {
        stopTimeoutTimer()

        let timeoutInterval = TimeInterval(timeoutSeconds)

        timeoutTimer = Timer.scheduledTimer(
            withTimeInterval: Self.timeoutCheckInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                guard SettingsManager.shared.security.requireBiometricAuth else {
                    return
                }
                guard !isLocked else {
                    return
                }

                let elapsed = Date().timeIntervalSince(lastActivityTimestamp)
                if elapsed >= timeoutInterval {
                    lock()
                    logger.info(
                        "Security lock: auto-locked after \(Int(elapsed))s of inactivity"
                    )
                }
            }
        }
    }

    private func stopTimeoutTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

    // MARK: - Biometric Authentication

    private func performBiometricAuth() async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            logger.warning("Biometric auth not available: \(error?.localizedDescription ?? "unknown")")
            // Fall back to device passcode if biometrics unavailable
            return await performDeviceOwnerAuth(context: context)
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to access PasteShelf clipboard data"
            )
        } catch {
            logger.warning("Biometric auth failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Falls back to device owner authentication (password/passcode) when biometrics
    /// are unavailable (e.g. no Touch ID hardware, biometrics locked out).
    private func performDeviceOwnerAuth(context: LAContext) async -> Bool {
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Authenticate to access PasteShelf clipboard data"
            )
        } catch {
            logger.warning("Device owner auth failed: \(error.localizedDescription)")
            return false
        }
    }
}
