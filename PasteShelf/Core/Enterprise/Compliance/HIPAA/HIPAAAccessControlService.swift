//
//  HIPAAAccessControlService.swift
//  PasteShelf
//
//  Enforces HIPAA access controls: biometric authentication, SSO enforcement,
//  and session inactivity timeout.
//

import Combine
import Foundation
import LocalAuthentication
import os.log

// MARK: - HIPAAAccessControlService

/// Enforces HIPAA-mandated access controls for the application.
///
/// When HIPAA compliance mode is active, `HIPAAAccessControlService` requires users to
/// authenticate before accessing clipboard data. It supports:
///
/// - **Biometric authentication** via Touch ID (`LAContext`)
/// - **SSO enforcement** via `SSOManager` (requires an active SSO session)
/// - **Session inactivity timeout** that automatically locks the application
///
/// The service publishes `isLocked` so that views can gate access to sensitive content.
/// Access attempts are logged via `AuditManager.logComplianceEvent()`.
@MainActor
final class HIPAAAccessControlService: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    private init() {}

    /// Designated initializer for dependency injection in tests.
    init(initialLockState: Bool) {
        isLocked = initialLockState
    }

    // MARK: - Cleanup

    deinit {
        timeoutTimer?.invalidate()
    }

    // MARK: Internal

    // MARK: - Singleton

    static let shared = HIPAAAccessControlService()

    // MARK: - Published State

    /// Whether the application is currently locked and requires authentication.
    @Published private(set) var isLocked: Bool = true

    /// Whether an authentication attempt is in progress.
    @Published private(set) var isAuthenticating: Bool = false

    /// The most recent access control error, if any.
    @Published var lastError: ComplianceError?

    // MARK: - Configuration

    /// Activates access controls based on the current HIPAA configuration.
    ///
    /// If HIPAA mode is enabled, the application is locked immediately and the
    /// inactivity timeout timer is started. If HIPAA mode is disabled, the
    /// application is unlocked and timers are stopped.
    func configure() {
        let config = HIPAAComplianceMode.load()

        if config.isEnabled {
            isLocked = true
            startTimeoutTimer(timeoutMinutes: config.sessionTimeoutMinutes)
            logger.info("HIPAA access controls activated (timeout: \(config.sessionTimeoutMinutes)min)")
        } else {
            isLocked = false
            stopTimeoutTimer()
            logger.info("HIPAA access controls deactivated")
        }
    }

    // MARK: - Authentication

    /// Attempts to unlock the application using the configured authentication methods.
    ///
    /// The authentication flow respects the HIPAA configuration:
    /// 1. If `requireSSO` is enabled, verifies that an active SSO session exists.
    /// 2. If `requireBiometric` is enabled, prompts for Touch ID authentication.
    /// 3. If both are required, both must succeed.
    ///
    /// - Returns: `true` if authentication succeeded and the application was unlocked.
    @discardableResult
    func unlock() async -> Bool {
        let config = HIPAAComplianceMode.load()

        guard config.isEnabled else {
            isLocked = false
            return true
        }

        isAuthenticating = true
        lastError = nil

        defer { isAuthenticating = false }

        // Step 1: SSO verification
        if config.requireSSO {
            let ssoValid = await verifySSOSession()
            if !ssoValid {
                await logAccessAttempt(success: false, method: "sso", reason: "No active SSO session")
                lastError = .featureUnavailable
                return false
            }
        }

        // Step 2: Biometric authentication
        if config.requireBiometric {
            let biometricResult = await performBiometricAuth()
            if !biometricResult {
                await logAccessAttempt(success: false, method: "biometric", reason: "Biometric authentication failed")
                return false
            }
        }

        // Both checks passed (or were not required)
        isLocked = false
        lastActivityTimestamp = Date()
        await logAccessAttempt(success: true, method: authMethod(for: config), reason: nil)

        logger.info("HIPAA access controls: application unlocked")
        return true
    }

    /// Locks the application, requiring re-authentication.
    func lock() {
        isLocked = true
        logger.info("HIPAA access controls: application locked")
    }

    // MARK: - Activity Tracking

    /// Records user activity to reset the inactivity timeout.
    ///
    /// Call this whenever the user interacts with the application (e.g., copies,
    /// pastes, navigates, searches). The timeout timer resets based on this timestamp.
    func recordActivity() {
        lastActivityTimestamp = Date()
    }

    // MARK: Private

    /// The interval at which the timeout timer checks for inactivity.
    private static let timeoutCheckInterval: TimeInterval = 30

    // MARK: - Private State

    /// Timestamp of the last user activity (used for inactivity timeout).
    private var lastActivityTimestamp: Date = .init()

    /// Timer that periodically checks for session inactivity.
    private var timeoutTimer: Timer?

    private let logger = Logger.compliance

    // MARK: - Timeout Timer

    /// Starts the session inactivity timer.
    ///
    /// - Parameter timeoutMinutes: The number of minutes of inactivity before locking.
    private func startTimeoutTimer(timeoutMinutes: Int) {
        stopTimeoutTimer()

        let timeoutInterval = TimeInterval(timeoutMinutes * 60)

        timeoutTimer = Timer.scheduledTimer(
            withTimeInterval: Self.timeoutCheckInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isLocked else {
                    return
                }

                let elapsed = Date().timeIntervalSince(lastActivityTimestamp)
                if elapsed >= timeoutInterval {
                    lock()
                    logger.info(
                        "HIPAA session timeout after \(Int(elapsed / 60)) minutes of inactivity"
                    )
                }
            }
        }
    }

    /// Stops the session inactivity timer.
    private func stopTimeoutTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

    // MARK: - SSO Verification

    /// Verifies that an active SSO session exists.
    ///
    /// - Returns: `true` if `SSOManager` has a valid current session.
    private func verifySSOSession() async -> Bool {
        guard let isValid = try? await SSOManager.shared.validateCurrentSession() else {
            return false
        }
        return isValid
    }

    // MARK: - Biometric Authentication

    /// Prompts for biometric authentication via Touch ID.
    ///
    /// - Returns: `true` if biometric authentication succeeded.
    private func performBiometricAuth() async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            logger.warning("Biometric auth not available: \(error?.localizedDescription ?? "unknown")")
            lastError = .invalidConfiguration("Biometric authentication is not available on this device")
            return false
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to access HIPAA-protected clipboard data"
            )
        } catch {
            logger.warning("Biometric auth failed: \(error.localizedDescription)")
            lastError = .invalidConfiguration("Biometric authentication failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Audit Logging

    /// Logs an access attempt to the audit trail.
    private func logAccessAttempt(success: Bool, method: String, reason: String?) async {
        var detail: [String: String] = [
            "success": success ? "true" : "false",
            "method": method,
            "hipaa.accessReason": "hipaa_access_control",
        ]
        if let reason {
            detail["failureReason"] = reason
        }

        await AuditManager.shared.logComplianceEvent(
            action: .hipaaAccessAttempt,
            severity: success ? .info : .warning,
            detail: detail
        )
    }

    // MARK: - Helpers

    /// Returns a description of the authentication method used.
    private func authMethod(for config: HIPAAComplianceMode) -> String {
        var methods: [String] = []
        if config.requireSSO {
            methods.append("sso")
        }
        if config.requireBiometric {
            methods.append("biometric")
        }
        return methods.isEmpty ? "none" : methods.joined(separator: "+")
    }
}
