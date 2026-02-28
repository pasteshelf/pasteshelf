//
//  ManagedSettingModifier.swift
//  PasteShelf
//
//  SwiftUI ViewModifier that visually locks settings controlled by MDM policy.
//  Shows a lock icon and disables interaction when a preference key is forced by MDM.
//

import SwiftUI

// MARK: - ManagedSettingModifier

/// A ViewModifier that locks a settings control when the corresponding MDM
/// preference key is forced by the organization's MDM profile.
///
/// When the key is forced:
/// - The wrapped view is disabled.
/// - A `lock.fill` SF Symbol overlay is shown in the trailing position.
/// - The opacity is reduced to 0.7.
/// - A tooltip "Managed by your organization" is shown on hover.
///
/// When the key is not forced, the modifier is a no-op passthrough.
///
/// Usage:
/// ```swift
/// Picker("History limit", selection: $viewModel.historyLimit) { ... }
///     .managedSetting(.maxHistoryItems)
/// ```
struct ManagedSettingModifier: ViewModifier {

    // MARK: - Properties

    let key: ManagedPreferenceKey

    @ObservedObject private var settingsManager = SettingsManager.shared

    // MARK: - Body

    func body(content: Content) -> some View {
        if settingsManager.isLocked(key) {
            HStack(spacing: 6) {
                content
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Managed by your organization")
            }
            .disabled(true)
            .opacity(0.7)
            .help("Managed by your organization")
        } else {
            content
        }
    }
}

// MARK: - View Extension

extension View {
    /// Locks this view when the given MDM preference key is forced by policy.
    ///
    /// - Parameter key: The `ManagedPreferenceKey` to check against MDM policy.
    /// - Returns: A view that is disabled and annotated with a lock icon when the key is forced.
    func managedSetting(_ key: ManagedPreferenceKey) -> some View {
        modifier(ManagedSettingModifier(key: key))
    }
}
