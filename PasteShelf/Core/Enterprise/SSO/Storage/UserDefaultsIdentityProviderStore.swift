//
//  UserDefaultsIdentityProviderStore.swift
//  PasteShelf
//
//  UserDefaults-backed implementation of IdentityProviderStore.
//  Stores identity provider configurations as JSON in UserDefaults.
//

import Foundation
import os.log

// MARK: - UserDefaultsIdentityProviderStore

/// A UserDefaults-backed store for identity provider configurations.
///
/// Provider configurations (SAML/OIDC metadata URLs, client IDs, entity IDs) do not
/// contain secrets, so UserDefaults is an appropriate storage backend. Secrets like
/// client secrets should be stored in Keychain by the authenticator, not here.
final class UserDefaultsIdentityProviderStore: IdentityProviderStore, Sendable {

    // MARK: - Properties

    private let defaults: UserDefaults
    private let storageKey = "com.pasteshelf.sso.identityProviders"
    private let logger = Logger(subsystem: "com.pasteshelf", category: "idp-store")

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - IdentityProviderStore

    func save(_ provider: IdentityProvider) async throws {
        var providers = loadAllSync()

        // Replace existing or append
        if let index = providers.firstIndex(where: { $0.id == provider.id }) {
            providers[index] = provider
        } else {
            providers.append(provider)
        }

        try persistAll(providers)
        logger.debug("Saved identity provider: \(provider.name)")
    }

    func load(id: UUID) async throws -> IdentityProvider? {
        loadAllSync().first { $0.id == id }
    }

    func loadAll() async throws -> [IdentityProvider] {
        loadAllSync()
    }

    func delete(id: UUID) async throws {
        var providers = loadAllSync()
        providers.removeAll { $0.id == id }
        try persistAll(providers)
        logger.debug("Deleted identity provider: \(id)")
    }

    // MARK: - Private Helpers

    private func loadAllSync() -> [IdentityProvider] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        do {
            return try JSONDecoder().decode([IdentityProvider].self, from: data)
        } catch {
            logger.error("Failed to decode identity providers: \(error.localizedDescription)")
            return []
        }
    }

    private func persistAll(_ providers: [IdentityProvider]) throws {
        let data = try JSONEncoder().encode(providers)
        defaults.set(data, forKey: storageKey)
    }
}
