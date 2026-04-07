//
//  AdminManager.swift
//  PasteShelf
//
//  Central orchestrator for Enterprise centralized management.
//  Coordinates device registration, policy sync, health reporting, and analytics.
//

import Combine
import Foundation
import os.log

// MARK: - AdminManager

/// Central manager for the Enterprise admin console subsystem.
///
/// `AdminManager` orchestrates all admin console services — device registration,
/// policy enforcement, health reporting, and analytics — behind a single entry
/// point.  It follows the same `@MainActor` singleton pattern as `SSOManager`
/// and `MDMManager`.
///
/// **Policy priority**: MDM forced preferences always take precedence over admin
/// console policies.  When applying policy overrides, this manager skips any
/// setting already locked by MDM (`MDMManager.shared.isSettingLocked`).
@MainActor
final class AdminManager: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    private init() {}

    /// Creates a manager with injected dependencies (for testing).
    ///
    /// - Parameters:
    ///   - apiClient: The API client for server communication.
    ///   - registrationService: The device registration service.
    ///   - healthService: The health reporting service.
    ///   - policyService: The policy sync service.
    ///   - analyticsReporter: The analytics event reporter.
    init(
        apiClient: AdminAPIClient,
        registrationService: DeviceRegistrationService,
        healthService: HealthReportingService,
        policyService: PolicySyncService,
        analyticsReporter: AnalyticsReporter
    ) {
        self.apiClient = apiClient
        self.registrationService = registrationService
        self.healthService = healthService
        self.policyService = policyService
        self.analyticsReporter = analyticsReporter
    }

    // MARK: Internal

    // MARK: - Singleton

    static let shared = AdminManager()

    // MARK: - Published State

    /// The current admin console connection configuration.
    @Published private(set) var configuration: AdminConsoleConfiguration = .empty

    /// The locally persisted device registration, if enrolled.
    @Published private(set) var deviceRegistration: DeviceRegistration?

    /// The current device enrollment status.
    @Published private(set) var enrollmentStatus: DeviceEnrollmentStatus = .notEnrolled

    /// The most recently fetched admin policy, if any.
    @Published private(set) var currentPolicy: AdminPolicy?

    /// Whether the device is successfully connected to the admin console.
    @Published private(set) var isConnected: Bool = false

    /// The most recent admin error, if any.
    @Published var lastError: AdminError?

    // MARK: - Enterprise Key Access

    /// Returns the admin console server URL, either from direct configuration
    /// or from the MDM-pushed `adminConsoleURL` key.
    var adminConsoleURL: String? {
        if let url = configuration.serverURL?.absoluteString {
            return url
        }
        if case let .string(url) = MDMManager.shared.configuration.effectiveValue(for: .adminConsoleURL) {
            return url
        }
        return nil
    }

    // MARK: - Configuration

    /// Configures the manager with admin console connection parameters.
    ///
    /// This initializes all internal services and prepares the manager for
    /// enrollment and monitoring.  If the configuration is not valid
    /// (`isConfigured` is `false`), services are not created.
    ///
    /// - Parameter config: The admin console configuration to apply.
    func configure(with config: AdminConsoleConfiguration) {
        configuration = config

        guard config.isConfigured else {
            logger.info("Admin console not configured — services disabled")
            tearDownServices()
            return
        }

        let client = AdminAPIClient(configuration: config)
        apiClient = client

        let store = KeychainDeviceRegistrationStore()
        let registration = DeviceRegistrationService(apiClient: client, store: store)
        registrationService = registration

        healthService = HealthReportingService(
            apiClient: client,
            registrationProvider: registration
        )

        policyService = PolicySyncService(
            apiClient: client,
            deviceId: { [weak self] in self?.deviceRegistration?.deviceId }
        )

        analyticsReporter = AnalyticsReporter(apiClient: client)

        // Configure audit logging
        AuditManager.shared.configure(with: client)

        // Load existing registration if present
        if let existing = registration.currentRegistration() {
            deviceRegistration = existing
            enrollmentStatus = existing.enrollmentStatus
            isConnected = existing.isActive
            currentPolicy = policyService?.currentPolicy
        }

        logger.info("Admin console configured: \(config.serverURL?.absoluteString ?? "nil")")
    }

    // MARK: - Enrollment

    /// Enrolls this device with the admin console using the current SSO session.
    ///
    /// The enrollment flow:
    /// 1. Validates that an active SSO session exists.
    /// 2. Registers the device via the admin API.
    /// 3. Starts health reporting.
    /// 4. Fetches and applies the initial policy.
    /// 5. Starts policy polling.
    /// 6. Tracks the enrollment analytics event.
    ///
    /// - Throws: `AdminError` if enrollment fails.
    func enrollDevice() async throws {
        guard let registrationService else {
            throw AdminError.notConfigured
        }

        let session = SSOManager.shared.currentSession
        guard let session, session.isValid else {
            throw AdminError.authenticationRequired
        }

        // Inject SSO token for API auth
        apiClient?.bearerToken = session.accessToken

        do {
            let registration = try await registrationService.enroll(
                with: session,
                config: configuration
            )
            deviceRegistration = registration
            enrollmentStatus = registration.enrollmentStatus
            isConnected = registration.isActive
            lastError = nil

            // Start monitoring services
            startMonitoring()

            // Fetch initial policy
            await refreshPolicySilently()

            // Track enrollment event
            trackEvent(.deviceEnrolled)

            logger.info("Device enrolled: \(registration.deviceId)")
        } catch let error as AdminError {
            lastError = error
            throw error
        } catch {
            let adminError = AdminError.enrollmentFailed(error.localizedDescription)
            lastError = adminError
            throw adminError
        }
    }

    /// Unenrolls this device from the admin console.
    ///
    /// Stops all monitoring, removes the local registration, and notifies
    /// the server.
    ///
    /// - Throws: `AdminError` if unenrollment fails.
    func unenrollDevice() async throws {
        guard let registrationService else {
            throw AdminError.notConfigured
        }

        stopMonitoring()

        do {
            trackEvent(.deviceUnenrolled)
            try await registrationService.unenroll()
            deviceRegistration = nil
            enrollmentStatus = .notEnrolled
            currentPolicy = nil
            isConnected = false
            lastError = nil

            logger.info("Device unenrolled")
        } catch let error as AdminError {
            lastError = error
            throw error
        }
    }

    // MARK: - Policy

    /// Fetches and applies the latest admin policy from the server.
    ///
    /// - Throws: `AdminError` if the policy cannot be fetched.
    func refreshPolicy() async throws {
        guard let policyService else {
            throw AdminError.notConfigured
        }

        let policy = try await policyService.fetchLatestPolicy()
        currentPolicy = policy
        trackEvent(.policyApplied, metadata: [
            "policyId": policy.id,
            "policyVersion": policy.version,
        ])
    }

    /// Applies admin console policy overrides to the given settings.
    ///
    /// **Policy priority**: MDM forced preferences take precedence over admin
    /// console policies.  Settings already locked by `MDMManager` are skipped.
    ///
    /// - Parameter settings: The application settings to apply overrides to.
    func applyPolicyOverrides(to settings: inout AppSettings) {
        guard let policy = currentPolicy, let policyService else {
            return
        }
        policyService.applyPolicy(policy, to: &settings)
    }

    // MARK: - Monitoring

    /// Starts health reporting and policy polling services.
    func startMonitoring() {
        healthService?.startReporting(interval: configuration.pollingInterval)
        policyService?.startPolling(interval: configuration.pollingInterval)
        analyticsReporter?.startAutoFlush()
        AuditManager.shared.startMonitoring()
        logger.info("Admin monitoring started")
    }

    /// Stops all monitoring services.
    func stopMonitoring() {
        healthService?.stopReporting()
        policyService?.stopPolling()
        analyticsReporter?.stopAutoFlush()
        AuditManager.shared.stopMonitoring()
        logger.info("Admin monitoring stopped")
    }

    // MARK: - Analytics

    /// Tracks an analytics event with the admin console.
    ///
    /// - Parameters:
    ///   - type: The event type to track.
    ///   - metadata: Optional key/value metadata for the event.
    func trackEvent(
        _ type: AdminAnalyticsEventType,
        metadata: [String: String] = [:]
    ) {
        guard let deviceId = deviceRegistration?.deviceId else {
            return
        }
        analyticsReporter?.track(
            type,
            deviceId: deviceId,
            userId: SSOManager.shared.currentSession?.userId,
            metadata: metadata
        )
    }

    // MARK: Private

    // MARK: - Dependencies

    private var apiClient: AdminAPIClient?
    private var registrationService: DeviceRegistrationService?
    private var healthService: HealthReportingService?
    private var policyService: PolicySyncService?
    private var analyticsReporter: AnalyticsReporter?
    private let logger = Logger(subsystem: "com.pasteshelf", category: "admin-manager")
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Private Helpers

    /// Fetches policy silently, logging errors without throwing.
    private func refreshPolicySilently() async {
        do {
            let policy = try await policyService?.fetchLatestPolicy()
            currentPolicy = policy
        } catch {
            logger.warning("Initial policy fetch failed: \(error.localizedDescription)")
        }
    }

    /// Tears down all services when configuration is cleared.
    private func tearDownServices() {
        stopMonitoring()
        apiClient = nil
        registrationService = nil
        healthService = nil
        policyService = nil
        analyticsReporter = nil
        isConnected = false
    }
}
