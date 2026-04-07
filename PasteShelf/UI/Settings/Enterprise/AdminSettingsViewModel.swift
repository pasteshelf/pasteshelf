//
//  AdminSettingsViewModel.swift
//  PasteShelf
//
//  ViewModel for the Admin Console settings dashboard in the Enterprise preferences tab.
//  Reads admin console connection and enrollment state and exposes it for display in AdminSettingsView.
//

import Combine
import Foundation

// MARK: - DeviceEnrollmentStatus Display Extension

extension DeviceEnrollmentStatus {
    var displayName: String {
        switch self {
        case .notEnrolled: "Not Enrolled"
        case .enrolling: "Enrolling..."
        case .enrolled: "Enrolled"
        case .suspended: "Suspended"
        case .revoked: "Revoked"
        }
    }
}

// MARK: - AdminSettingsViewModel

/// ViewModel for the Admin Console settings view.
///
/// Exposes the current admin console connection state, enrollment status, active policy,
/// and last error for display in `AdminSettingsView`. Provides action methods to enroll
/// and unenroll the device with the admin console.
@MainActor
final class AdminSettingsViewModel: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    init() {
        loadState()
        observeChanges()
    }

    // MARK: Internal

    // MARK: - Published State

    /// Whether the device is connected to the admin console server.
    @Published private(set) var isConnected: Bool = false

    /// The current device enrollment lifecycle state.
    @Published private(set) var enrollmentStatus: DeviceEnrollmentStatus = .notEnrolled

    /// The admin console server URL string, if configured.
    @Published private(set) var serverURL: String?

    /// The organization identifier from the admin console configuration, if set.
    @Published private(set) var organizationID: String?

    /// The name of the currently active admin policy, if any.
    @Published private(set) var policyName: String?

    /// The version string of the currently active admin policy, if any.
    @Published private(set) var policyVersion: String?

    /// The most recent admin error, if any.
    @Published private(set) var lastError: AdminError?

    /// Whether an enrollment or unenrollment operation is in progress.
    @Published private(set) var isProcessing: Bool = false

    /// Whether the device is fully enrolled with the admin console.
    var isEnrolled: Bool {
        enrollmentStatus == .enrolled
    }

    // MARK: - State Loading

    /// Reads the current admin console state and updates all published properties.
    func loadState() {
        let admin = AdminManager.shared
        isConnected = admin.isConnected
        enrollmentStatus = admin.enrollmentStatus
        serverURL = admin.configuration.serverURL?.absoluteString
        organizationID = admin.configuration.organizationID.isEmpty ? nil : admin.configuration.organizationID
        policyName = admin.currentPolicy?.name
        policyVersion = admin.currentPolicy?.version
        lastError = admin.lastError
    }

    /// Enrolls this device with the admin console.
    ///
    /// On failure, sets `lastError` with the caught `AdminError`.
    func enrollDevice() async {
        guard !isProcessing else {
            return
        }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await AdminManager.shared.enrollDevice()
            loadState()
        } catch let error as AdminError {
            lastError = error
        } catch {
            lastError = AdminError.enrollmentFailed(error.localizedDescription)
        }
    }

    /// Unenrolls this device from the admin console.
    ///
    /// On failure, sets `lastError` with the caught `AdminError`.
    func unenrollDevice() async {
        guard !isProcessing else {
            return
        }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await AdminManager.shared.unenrollDevice()
            loadState()
        } catch let error as AdminError {
            lastError = error
        } catch {
            lastError = AdminError.enrollmentFailed(error.localizedDescription)
        }
    }

    // MARK: Private

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Private Helpers

    /// Subscribes to admin console state changes and reloads state on each update.
    private func observeChanges() {
        AdminManager.shared.$enrollmentStatus
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadState() }
            .store(in: &cancellables)

        AdminManager.shared.$isConnected
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadState() }
            .store(in: &cancellables)

        AdminManager.shared.$currentPolicy
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadState() }
            .store(in: &cancellables)

        AdminManager.shared.$configuration
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadState() }
            .store(in: &cancellables)

        AdminManager.shared.$lastError
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadState() }
            .store(in: &cancellables)
    }
}
