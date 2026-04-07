//
//  MDMSettingsViewModel.swift
//  PasteShelf
//
//  ViewModel for the MDM settings dashboard in the Enterprise preferences tab.
//  Reads MDM configuration state and exposes it for display in MDMSettingsView.
//

import Combine
import Foundation

// MARK: - MDMSettingsViewModel

/// ViewModel for the MDM settings view.
///
/// Exposes the current MDM management state, organization ID, forced (locked)
/// settings, and default (suggestive) settings pushed by the MDM profile.
/// All properties are read-only; this view is a status dashboard, not an
/// interactive settings panel.
@MainActor
final class MDMSettingsViewModel: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    init() {
        loadState()
        observeChanges()
    }

    // MARK: Internal

    // MARK: - Published State

    /// Whether the device is under MDM management.
    @Published private(set) var isManaged: Bool = false

    /// The organization ID from the MDM configuration, if set.
    @Published private(set) var organizationID: String?

    /// Admin-locked settings that the user cannot change, sorted by display name.
    @Published private(set) var forcedSettings: [(key: ManagedPreferenceKey, value: PreferenceValue)] = []

    /// Admin-supplied default settings that the user may override, sorted by display name.
    @Published private(set) var defaultSettings: [(key: ManagedPreferenceKey, value: PreferenceValue)] = []

    // MARK: - State Loading

    /// Reads the current MDM configuration and updates all published properties.
    func loadState() {
        let mdm = MDMManager.shared
        isManaged = mdm.isManaged
        organizationID = mdm.organizationID

        forcedSettings = mdm.configuration.forcedPreferences
            .sorted { $0.key.displayName < $1.key.displayName }
            .map { (key: $0.key, value: $0.value) }

        defaultSettings = mdm.configuration.defaultPreferences
            .sorted { $0.key.displayName < $1.key.displayName }
            .map { (key: $0.key, value: $0.value) }
    }

    // MARK: Private

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Private Helpers

    /// Subscribes to MDM configuration changes and reloads state on each update.
    private func observeChanges() {
        MDMManager.shared.$configuration
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadState() }
            .store(in: &cancellables)
    }
}
