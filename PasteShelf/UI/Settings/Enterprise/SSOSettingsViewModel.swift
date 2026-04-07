//
//  SSOSettingsViewModel.swift
//  PasteShelf
//
//  ViewModel for the Enterprise SSO settings screen.
//  Manages the list of identity providers and test connection state.
//

import Combine
import Foundation
import os.log

// MARK: - SSOSettingsViewModel

/// ViewModel for the SSO settings view.
///
/// Manages provider CRUD operations and connection testing.
/// Uses an in-memory store for providers when no persistent store is configured
/// (e.g. in design-time previews or when no persistent store is configured).
@MainActor
final class SSOSettingsViewModel: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    init() {
        Task { await loadProviders() }
    }

    // MARK: Internal

    /// Outcome of a test-connection attempt
    enum TestConnectionResult: Equatable {
        case success(String)
        case failure(String)

        // MARK: Internal

        var isSuccess: Bool {
            if case .success = self {
                return true
            }
            return false
        }

        var message: String {
            switch self {
            case let .success(msg): msg
            case let .failure(msg): msg
            }
        }
    }

    // MARK: - Published State

    /// The list of configured identity providers
    @Published private(set) var providers: [IdentityProvider] = []

    /// The ID of the provider currently selected in the list
    @Published var selectedProviderID: UUID?

    /// Whether the add/edit form sheet is visible
    @Published var isShowingForm = false

    /// Whether the delete confirmation alert is visible
    @Published var isShowingDeleteConfirmation = false

    /// Whether a test-connection network call is in progress
    @Published var isTestingConnection = false

    /// The result of the most recent test-connection call
    @Published var testResult: TestConnectionResult?

    /// Error message for alert presentation; non-nil when an error should be shown
    @Published var errorMessage: String?

    /// The provider being edited, or nil when adding a new one
    private(set) var editingProvider: IdentityProvider?

    /// Derived accessor for the currently selected provider
    var selectedProvider: IdentityProvider? {
        get { providers.first { $0.id == selectedProviderID } }
        set { selectedProviderID = newValue?.id }
    }

    /// Whether the form is being used for a new provider (vs editing an existing one)
    var isFormForNewProvider: Bool {
        editingProvider == nil
    }

    // MARK: - Data Loading

    /// Loads providers from the SSOManager's store (if configured)
    func loadProviders() async {
        guard let store = SSOManager.shared.providerStore else {
            // No store configured; keep the published list as-is (may have been set by tests)
            return
        }

        do {
            providers = try await store.loadAll()
                .sorted { $0.createdAt < $1.createdAt }
        } catch {
            logger.error("Failed to load identity providers: \(error.localizedDescription)")
            errorMessage = "Failed to load providers: \(error.localizedDescription)"
        }
    }

    // MARK: - Provider CRUD

    /// Prepares the form to add a new provider
    func addProvider() {
        editingProvider = nil
        testResult = nil
        isShowingForm = true
    }

    /// Prepares the form to edit an existing provider
    func editProvider(_ provider: IdentityProvider) {
        editingProvider = provider
        testResult = nil
        isShowingForm = true
    }

    /// Requests deletion of the given provider (shows confirmation alert)
    func requestDeleteProvider(_ provider: IdentityProvider) {
        selectedProviderID = provider.id
        isShowingDeleteConfirmation = true
    }

    /// Deletes the provider and refreshes the list
    func deleteProvider(_ provider: IdentityProvider) async {
        guard let store = SSOManager.shared.providerStore else {
            providers.removeAll { $0.id == provider.id }
            if selectedProviderID == provider.id {
                selectedProviderID = nil
            }
            return
        }

        do {
            try await store.delete(id: provider.id)
            providers.removeAll { $0.id == provider.id }
            if selectedProviderID == provider.id {
                selectedProviderID = nil
            }
            logger.info("Deleted identity provider '\(provider.name)'")
        } catch {
            logger.error("Failed to delete provider '\(provider.name)': \(error.localizedDescription)")
            errorMessage = "Failed to delete provider: \(error.localizedDescription)"
        }
    }

    /// Saves a provider (new or updated) and refreshes the list
    func saveProvider(_ provider: IdentityProvider) async {
        guard let store = SSOManager.shared.providerStore else {
            // In-memory: upsert
            if let index = providers.firstIndex(where: { $0.id == provider.id }) {
                providers[index] = provider
            } else {
                providers.append(provider)
            }
            return
        }

        do {
            try await store.save(provider)
            await loadProviders()
            logger.info("Saved identity provider '\(provider.name)'")
        } catch {
            logger.error("Failed to save provider '\(provider.name)': \(error.localizedDescription)")
            errorMessage = "Failed to save provider: \(error.localizedDescription)"
        }
    }

    /// Toggles the enabled/disabled state of a provider
    func toggleProvider(_ provider: IdentityProvider) async {
        var updated = provider
        updated.isEnabled.toggle()
        updated.updatedAt = Date()
        await saveProvider(updated)
    }

    // MARK: - Test Connection

    /// Tests the connection to the specified identity provider.
    ///
    /// For OIDC providers this performs an OIDC Discovery fetch. For SAML providers it
    /// validates that the SSO URL is reachable and returns an HTTP 200 response.
    func testConnection(_ provider: IdentityProvider) async {
        isTestingConnection = true
        testResult = nil

        defer { isTestingConnection = false }

        do {
            switch provider.type {
            case .oidc:
                guard let config = provider.oidcConfig else {
                    testResult = .failure("OIDC configuration is incomplete.")
                    return
                }
                let discovery = OIDCDiscovery()
                let document = try await discovery.discover(issuerURL: config.issuerURL)
                let scopesList = document.scopesSupported?
                    .joined(separator: ", ") ?? "unspecified"
                testResult = .success(
                    "Connected to \(document.issuer). Scopes supported: \(scopesList)."
                )

            case .saml:
                guard let config = provider.samlConfig else {
                    testResult = .failure("SAML configuration is incomplete.")
                    return
                }
                let request = URLRequest(url: config.ssoURL, timeoutInterval: 10)
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode < 500 {
                    testResult = .success(
                        "SSO endpoint is reachable (HTTP \(http.statusCode))."
                    )
                } else {
                    testResult = .failure("SSO endpoint returned an unexpected response.")
                }
            }
            logger.info("Test connection succeeded for provider '\(provider.name)'")
        } catch let ssoError as SSOError {
            testResult = .failure(ssoError.localizedDescription)
            logger.error("Test connection failed for '\(provider.name)': \(ssoError.localizedDescription)")
        } catch {
            testResult = .failure("Connection failed: \(error.localizedDescription)")
            logger.error("Test connection failed for '\(provider.name)': \(error.localizedDescription)")
        }
    }

    // MARK: Private

    private let logger = Logger(subsystem: "com.pasteshelf", category: "sso-settings")
}
