//
//  DeviceRegistrationServiceTests.swift
//  PasteShelfTests
//
//  Tests for DeviceRegistrationService: enrollment, unenrollment, and Keychain store
//  interactions using mock API client and store implementations.
//

import Foundation
import Testing
@testable import PasteShelf

// MARK: - Mock API Client

/// A mock `AdminAPIProviding` implementation that records calls and returns
/// pre-configured results for testing service-level logic without network access.
final class MockAdminAPIClient: AdminAPIProviding, @unchecked Sendable {

    // MARK: - Call Tracking

    var registerDeviceCalls: [DeviceRegistration] = []
    var unregisterDeviceCalls: [String] = []
    var fetchPolicyCalls: [String] = []
    var submitHealthReportCalls: [DeviceHealthReport] = []
    var submitAnalyticsEventsCalls: [[AdminAnalyticsEvent]] = []
    var fetchDeviceStatusCalls: [String] = []
    var submitAuditEventsCalls: [[AuditEvent]] = []

    // MARK: - Stubbed Results

    var registerDeviceResult: Result<DeviceRegistration, Error> = .failure(AdminError.notConfigured)
    var unregisterDeviceResult: Result<Void, Error> = .success(())
    var fetchPolicyResult: Result<AdminPolicy, Error> = .failure(AdminError.notEnrolled)
    var submitHealthReportResult: Result<Void, Error> = .success(())
    var submitAnalyticsEventsResult: Result<Void, Error> = .success(())
    var fetchDeviceStatusResult: Result<DeviceEnrollmentStatus, Error> = .success(.enrolled)
    var submitAuditEventsResult: Result<Void, Error> = .success(())

    // MARK: - AdminAPIProviding

    func registerDevice(_ registration: DeviceRegistration) async throws -> DeviceRegistration {
        registerDeviceCalls.append(registration)
        return try registerDeviceResult.get()
    }

    func unregisterDevice(deviceId: String) async throws {
        unregisterDeviceCalls.append(deviceId)
        try unregisterDeviceResult.get()
    }

    func fetchPolicy(for deviceId: String) async throws -> AdminPolicy {
        fetchPolicyCalls.append(deviceId)
        return try fetchPolicyResult.get()
    }

    func submitHealthReport(_ report: DeviceHealthReport) async throws {
        submitHealthReportCalls.append(report)
        try submitHealthReportResult.get()
    }

    func submitAnalyticsEvents(_ events: [AdminAnalyticsEvent]) async throws {
        submitAnalyticsEventsCalls.append(events)
        try submitAnalyticsEventsResult.get()
    }

    func fetchDeviceStatus(deviceId: String) async throws -> DeviceEnrollmentStatus {
        fetchDeviceStatusCalls.append(deviceId)
        return try fetchDeviceStatusResult.get()
    }

    func submitAuditEvents(_ events: [AuditEvent]) async throws {
        submitAuditEventsCalls.append(events)
        try submitAuditEventsResult.get()
    }
}

// MARK: - Mock Registration Store

/// A mock `DeviceRegistrationStore` that stores data in memory for testing.
final class MockDeviceRegistrationStore: DeviceRegistrationStore, @unchecked Sendable {

    var savedRegistration: DeviceRegistration?
    var shouldFailOnSave = false
    var shouldFailOnDelete = false
    var deleteCalled = false

    func save(_ registration: DeviceRegistration) throws {
        if shouldFailOnSave {
            throw AdminError.enrollmentFailed("Mock save failure")
        }
        savedRegistration = registration
    }

    func load() -> DeviceRegistration? {
        savedRegistration
    }

    func delete() throws {
        if shouldFailOnDelete {
            throw AdminError.enrollmentFailed("Mock delete failure")
        }
        deleteCalled = true
        savedRegistration = nil
    }
}

// MARK: - Test Helpers

private func makeTestSession() -> SSOSession {
    SSOSession(
        providerId: UUID(),
        userId: "user-test-123",
        email: "test@example.com",
        displayName: "Test User",
        accessToken: "sso-access-token"
    )
}

private func makeTestConfig() -> AdminConsoleConfiguration {
    AdminConsoleConfiguration(
        serverURL: URL(string: "https://admin.example.com"),
        organizationID: "org-test-456"
    )
}

private func makeConfirmedRegistration() -> DeviceRegistration {
    DeviceRegistration(
        deviceId: "dev-server-assigned",
        organizationID: "org-test-456",
        userId: "user-test-123",
        enrollmentStatus: .enrolled,
        deviceName: "Test Mac",
        osVersion: "14.0",
        appVersion: "1.0.0"
    )
}

// MARK: - DeviceRegistrationServiceTests

struct DeviceRegistrationServiceTests {

    // MARK: - Enrollment

    @Test("enroll sends registration to API and persists server response")
    func enrollSuccess() async throws {
        let api = MockAdminAPIClient()
        let store = MockDeviceRegistrationStore()
        let confirmed = makeConfirmedRegistration()
        api.registerDeviceResult = .success(confirmed)

        let service = DeviceRegistrationService(apiClient: api, store: store)
        let result = try await service.enroll(with: makeTestSession(), config: makeTestConfig())

        #expect(result.deviceId == "dev-server-assigned")
        #expect(result.enrollmentStatus == .enrolled)
        #expect(api.registerDeviceCalls.count == 1)
        #expect(api.registerDeviceCalls.first?.userId == "user-test-123")
        #expect(api.registerDeviceCalls.first?.organizationID == "org-test-456")
        #expect(store.savedRegistration?.deviceId == "dev-server-assigned")
    }

    @Test("enroll throws notConfigured when config is incomplete")
    func enrollThrowsNotConfigured() async throws {
        let api = MockAdminAPIClient()
        let store = MockDeviceRegistrationStore()
        let service = DeviceRegistrationService(apiClient: api, store: store)
        let unconfigured = AdminConsoleConfiguration(serverURL: nil, organizationID: "")

        do {
            _ = try await service.enroll(with: makeTestSession(), config: unconfigured)
            #expect(Bool(false), "Expected AdminError.notConfigured")
        } catch let error as AdminError {
            if case .notConfigured = error {
                #expect(api.registerDeviceCalls.isEmpty)
            } else {
                #expect(Bool(false), "Expected notConfigured, got \(error)")
            }
        }
    }

    @Test("enroll propagates network error from API client")
    func enrollPropagatesNetworkError() async throws {
        let api = MockAdminAPIClient()
        let store = MockDeviceRegistrationStore()
        api.registerDeviceResult = .failure(AdminError.networkError("Connection refused"))

        let service = DeviceRegistrationService(apiClient: api, store: store)

        do {
            _ = try await service.enroll(with: makeTestSession(), config: makeTestConfig())
            #expect(Bool(false), "Expected AdminError.networkError")
        } catch let error as AdminError {
            if case .networkError(let msg) = error {
                #expect(msg == "Connection refused")
            } else {
                #expect(Bool(false), "Expected networkError, got \(error)")
            }
        }
        #expect(store.savedRegistration == nil)
    }

    @Test("enroll propagates store save failure")
    func enrollPropagatesStoreSaveFailure() async throws {
        let api = MockAdminAPIClient()
        let store = MockDeviceRegistrationStore()
        store.shouldFailOnSave = true
        api.registerDeviceResult = .success(makeConfirmedRegistration())

        let service = DeviceRegistrationService(apiClient: api, store: store)

        do {
            _ = try await service.enroll(with: makeTestSession(), config: makeTestConfig())
            #expect(Bool(false), "Expected enrollment to fail on store save")
        } catch let error as AdminError {
            if case .enrollmentFailed = error {
                // Expected
            } else {
                #expect(Bool(false), "Expected enrollmentFailed, got \(error)")
            }
        }
    }

    @Test("enroll sends device metadata in the registration payload")
    func enrollSendsDeviceMetadata() async throws {
        let api = MockAdminAPIClient()
        let store = MockDeviceRegistrationStore()
        api.registerDeviceResult = .success(makeConfirmedRegistration())

        let service = DeviceRegistrationService(apiClient: api, store: store)
        _ = try await service.enroll(with: makeTestSession(), config: makeTestConfig())

        let payload = api.registerDeviceCalls.first
        #expect(payload != nil)
        #expect(payload?.deviceName.isEmpty == false)
        #expect(payload?.osVersion.isEmpty == false)
        #expect(payload?.appVersion.isEmpty == false)
    }

    // MARK: - Unenrollment

    @Test("unenroll calls API and deletes local registration")
    func unenrollSuccess() async throws {
        let api = MockAdminAPIClient()
        let store = MockDeviceRegistrationStore()
        store.savedRegistration = makeConfirmedRegistration()
        api.unregisterDeviceResult = .success(())

        let service = DeviceRegistrationService(apiClient: api, store: store)
        try await service.unenroll()

        #expect(api.unregisterDeviceCalls.count == 1)
        #expect(api.unregisterDeviceCalls.first == "dev-server-assigned")
        #expect(store.deleteCalled == true)
        #expect(store.savedRegistration == nil)
    }

    @Test("unenroll throws notEnrolled when no local registration exists")
    func unenrollThrowsNotEnrolled() async throws {
        let api = MockAdminAPIClient()
        let store = MockDeviceRegistrationStore()

        let service = DeviceRegistrationService(apiClient: api, store: store)

        do {
            try await service.unenroll()
            #expect(Bool(false), "Expected AdminError.notEnrolled")
        } catch let error as AdminError {
            if case .notEnrolled = error {
                #expect(api.unregisterDeviceCalls.isEmpty)
            } else {
                #expect(Bool(false), "Expected notEnrolled, got \(error)")
            }
        }
    }

    @Test("unenroll propagates API error")
    func unenrollPropagatesAPIError() async throws {
        let api = MockAdminAPIClient()
        let store = MockDeviceRegistrationStore()
        store.savedRegistration = makeConfirmedRegistration()
        api.unregisterDeviceResult = .failure(AdminError.networkError("Timeout"))

        let service = DeviceRegistrationService(apiClient: api, store: store)

        do {
            try await service.unenroll()
            #expect(Bool(false), "Expected AdminError.networkError")
        } catch let error as AdminError {
            if case .networkError = error {
                // Expected - local registration should NOT be deleted
                #expect(store.savedRegistration != nil)
            } else {
                #expect(Bool(false), "Expected networkError, got \(error)")
            }
        }
    }

    @Test("unenroll propagates store delete failure")
    func unenrollPropagatesStoreDeleteFailure() async throws {
        let api = MockAdminAPIClient()
        let store = MockDeviceRegistrationStore()
        store.savedRegistration = makeConfirmedRegistration()
        store.shouldFailOnDelete = true
        api.unregisterDeviceResult = .success(())

        let service = DeviceRegistrationService(apiClient: api, store: store)

        do {
            try await service.unenroll()
            #expect(Bool(false), "Expected store delete failure")
        } catch let error as AdminError {
            if case .enrollmentFailed = error {
                // Expected
            } else {
                #expect(Bool(false), "Expected enrollmentFailed, got \(error)")
            }
        }
    }

    // MARK: - Current Registration

    @Test("currentRegistration returns stored registration")
    func currentRegistrationReturnsStored() {
        let api = MockAdminAPIClient()
        let store = MockDeviceRegistrationStore()
        let reg = makeConfirmedRegistration()
        store.savedRegistration = reg

        let service = DeviceRegistrationService(apiClient: api, store: store)

        #expect(service.currentRegistration()?.deviceId == "dev-server-assigned")
    }

    @Test("currentRegistration returns nil when not enrolled")
    func currentRegistrationReturnsNilWhenNotEnrolled() {
        let api = MockAdminAPIClient()
        let store = MockDeviceRegistrationStore()

        let service = DeviceRegistrationService(apiClient: api, store: store)

        #expect(service.currentRegistration() == nil)
    }

    // MARK: - isEnrolled

    @Test("isEnrolled returns true when registration is active")
    func isEnrolledTrueWhenActive() {
        let api = MockAdminAPIClient()
        let store = MockDeviceRegistrationStore()
        store.savedRegistration = makeConfirmedRegistration()

        let service = DeviceRegistrationService(apiClient: api, store: store)

        #expect(service.isEnrolled == true)
    }

    @Test("isEnrolled returns false when no registration stored")
    func isEnrolledFalseWhenNoRegistration() {
        let api = MockAdminAPIClient()
        let store = MockDeviceRegistrationStore()

        let service = DeviceRegistrationService(apiClient: api, store: store)

        #expect(service.isEnrolled == false)
    }

    @Test("isEnrolled returns false when registration status is suspended")
    func isEnrolledFalseWhenSuspended() {
        let api = MockAdminAPIClient()
        let store = MockDeviceRegistrationStore()
        store.savedRegistration = DeviceRegistration(
            deviceId: "dev-1",
            organizationID: "org-1",
            userId: "user-1",
            enrollmentStatus: .suspended,
            deviceName: "Mac",
            osVersion: "14.0",
            appVersion: "1.0"
        )

        let service = DeviceRegistrationService(apiClient: api, store: store)

        #expect(service.isEnrolled == false)
    }
}
