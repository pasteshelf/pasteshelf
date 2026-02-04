//
//  LicenseViewModel.swift
//  PasteShelf
//
//  ViewModel for the license settings tab.
//  Manages license state and coordinates with LicenseManager.
//

import Combine
import Foundation
import os.log

/// ViewModel for license management UI
@MainActor
final class LicenseViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Current license tier
    @Published private(set) var currentTier: LicenseTier = .community

    /// Current license status
    @Published private(set) var status: LicenseStatus = .inactive

    /// License info (when active)
    @Published private(set) var licenseInfo: LicenseInfo?

    /// Whether a license operation is in progress
    @Published var isProcessing: Bool = false

    /// Whether to show activation dialog
    @Published var showActivationDialog: Bool = false

    /// License key input
    @Published var licenseKeyInput: String = ""

    /// Whether to show error alert
    @Published var showError: Bool = false

    /// Error message to display
    @Published private(set) var errorMessage: String = ""

    // MARK: - Computed Properties

    /// Whether a license is currently active (not community)
    var isLicenseActive: Bool {
        switch status {
        case .active, .trial, .offlineGrace:
            return true
        default:
            return false
        }
    }

    /// Status description for display
    var statusDescription: String {
        status.displayDescription
    }

    /// Status label (short form)
    var statusLabel: String {
        switch status {
        case .inactive:
            return "Free"
        case .active:
            return "Active"
        case .expired:
            return "Expired"
        case .trial:
            return "Trial"
        case .offlineGrace:
            return "Offline"
        case .invalid:
            return "Invalid"
        }
    }

    /// Current device name
    var deviceName: String {
        Host.current().localizedName ?? "This Mac"
    }

    // MARK: - Private Properties

    private let licenseManager: LicenseManager
    private var cancellables = Set<AnyCancellable>()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "license-vm"
    )

    // MARK: - Initialization

    init(licenseManager: LicenseManager = .shared) {
        self.licenseManager = licenseManager

        // Initialize from current state
        currentTier = licenseManager.currentTier
        status = licenseManager.status
        licenseInfo = licenseManager.licenseInfo

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Observe license manager changes
        licenseManager.$currentTier
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tier in
                self?.currentTier = tier
            }
            .store(in: &cancellables)

        licenseManager.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.status = status
            }
            .store(in: &cancellables)

        licenseManager.$licenseInfo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                self?.licenseInfo = info
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Check if a feature is available
    func isFeatureAvailable(_ feature: LicensedFeature) -> Bool {
        licenseManager.isFeatureAvailable(feature)
    }

    /// Activate license with entered key
    func activateLicense() async {
        let key = LicenseKeyFormat.normalize(licenseKeyInput)

        guard LicenseKeyFormat.isValid(key) else {
            showErrorMessage("Invalid license key format. Please use: PS-XXX-XXXX-XXXX-XXXX")
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        let result = await licenseManager.activate(licenseKey: key)

        switch result {
        case .success:
            logger.info("License activated successfully")
            licenseKeyInput = ""
            showActivationDialog = false

        case let .failure(error):
            logger.error("Activation failed: \(error.localizedDescription)")
            showErrorMessage(error.localizedDescription)
        }
    }

    /// Deactivate current license
    func deactivateLicense() async {
        isProcessing = true
        defer { isProcessing = false }

        let result = await licenseManager.deactivate()

        switch result {
        case .success:
            logger.info("License deactivated")

        case let .failure(error):
            logger.error("Deactivation failed: \(error.localizedDescription)")
            showErrorMessage(error.localizedDescription)
        }
    }

    /// Refresh license status
    func refreshLicense() async {
        isProcessing = true
        defer { isProcessing = false }

        _ = await licenseManager.validate()
    }

    /// Cancel activation dialog
    func cancelActivation() {
        licenseKeyInput = ""
        showActivationDialog = false
    }

    /// Dismiss error alert
    func dismissError() {
        showError = false
        errorMessage = ""
    }

    // MARK: - Private Methods

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}
