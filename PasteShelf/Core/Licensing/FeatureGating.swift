//
//  FeatureGating.swift
//  PasteShelf
//
//  Property wrapper and utilities for feature gating.
//  Provides declarative feature access control based on license tier.
//

import Combine
import Foundation
import SwiftUI

// MARK: - Feature Flag Property Wrapper

/// Property wrapper for feature availability
///
/// Usage:
/// ```swift
/// struct SomeViewModel {
///     @FeatureFlag(.cloudSync) var isCloudSyncEnabled
///     @FeatureFlag(.semanticSearch) var isSemanticSearchEnabled
/// }
/// ```
@propertyWrapper
struct FeatureFlag: DynamicProperty {
    /// The feature being checked
    private let feature: LicensedFeature

    /// Observed license manager
    @ObservedObject private var licenseManager = LicenseManager.shared

    /// Initialize with a feature
    init(_ feature: LicensedFeature) {
        self.feature = feature
    }

    /// The wrapped value (whether feature is available)
    var wrappedValue: Bool {
        licenseManager.isFeatureAvailable(feature)
    }

    /// Projected value provides access to the feature itself
    var projectedValue: LicensedFeature {
        feature
    }
}

// MARK: - Feature Flags Manager

/// Observable manager for feature flag state
@MainActor
final class FeatureFlags: ObservableObject {
    // MARK: - Singleton

    /// Shared instance
    static let shared = FeatureFlags()

    // MARK: - Published Properties

    /// Current license tier
    @Published private(set) var currentTier: LicenseTier = .community

    // MARK: - Pro Feature Flags

    /// iCloud sync feature
    var isCloudSyncEnabled: Bool { checkFeature(.cloudSync) }

    /// Semantic search feature
    var isSemanticSearchEnabled: Bool { checkFeature(.semanticSearch) }

    /// OCR search feature
    var isOCREnabled: Bool { checkFeature(.ocrSearch) }

    /// Smart collections feature
    var isSmartCollectionsEnabled: Bool { checkFeature(.smartCollections) }

    /// Automation feature
    var isAutomationEnabled: Bool { checkFeature(.automation) }

    /// Plugins feature
    var isPluginsEnabled: Bool { checkFeature(.plugins) }

    // MARK: - Enterprise Feature Flags

    /// SSO integration feature
    var isSSOEnabled: Bool { checkFeature(.ssoIntegration) }

    /// MDM support feature
    var isMDMEnabled: Bool { checkFeature(.mdmSupport) }

    /// DLP policies feature
    var isDLPEnabled: Bool { checkFeature(.dlpPolicies) }

    /// Audit logging feature
    var isAuditLoggingEnabled: Bool { checkFeature(.auditLogs) }

    /// Self-hosted sync feature
    var isSelfHostedSyncEnabled: Bool { checkFeature(.selfHostedSync) }

    /// Admin console feature
    var isAdminConsoleEnabled: Bool { checkFeature(.adminConsole) }

    /// Team sharing feature
    var isTeamSharingEnabled: Bool { checkFeature(.teamSharing) }

    // MARK: - Private Properties

    private let licenseManager: LicenseManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        licenseManager = LicenseManager.shared
        setupBindings()
    }

    /// Initialize with custom license manager (for testing)
    init(licenseManager: LicenseManager) {
        self.licenseManager = licenseManager
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        licenseManager.$currentTier
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tier in
                self?.currentTier = tier
            }
            .store(in: &cancellables)
    }

    // MARK: - Feature Checking

    /// Check if a specific feature is available
    func checkFeature(_ feature: LicensedFeature) -> Bool {
        licenseManager.isFeatureAvailable(feature)
    }

    /// Check if tier meets minimum requirement
    func checkTier(_ minimumTier: LicenseTier) -> Bool {
        currentTier >= minimumTier
    }

    /// Get all available features
    func availableFeatures() -> [LicensedFeature] {
        LicensedFeature.allCases.filter { checkFeature($0) }
    }

    /// Get all locked features
    func lockedFeatures() -> [LicensedFeature] {
        LicensedFeature.allCases.filter { !checkFeature($0) }
    }
}

// MARK: - Feature Check Modifier

/// View modifier for conditionally showing content based on feature
struct FeatureCheckModifier: ViewModifier {
    let feature: LicensedFeature
    let showUpgradePrompt: Bool

    @ObservedObject private var licenseManager = LicenseManager.shared
    @State private var showingPrompt = false

    func body(content: Content) -> some View {
        if licenseManager.isFeatureAvailable(feature) {
            content
        } else if showUpgradePrompt {
            content
                .disabled(true)
                .opacity(0.5)
                .onTapGesture {
                    showingPrompt = true
                }
                .sheet(isPresented: $showingPrompt) {
                    UpgradePromptView(feature: feature)
                }
        } else {
            EmptyView()
        }
    }
}

extension View {
    /// Conditionally show view based on feature availability
    /// - Parameters:
    ///   - feature: The required feature
    ///   - showUpgradePrompt: Whether to show upgrade prompt when locked
    func requiresFeature(_ feature: LicensedFeature, showUpgradePrompt: Bool = false) -> some View {
        modifier(FeatureCheckModifier(feature: feature, showUpgradePrompt: showUpgradePrompt))
    }
}

// MARK: - Feature Guard

/// Execute code only if feature is available
struct FeatureGuard {
    private let licenseManager = LicenseManager.shared

    /// Check feature and execute closure if available
    @MainActor
    func ifAvailable(_ feature: LicensedFeature, execute: () -> Void) {
        guard licenseManager.isFeatureAvailable(feature) else { return }
        execute()
    }

    /// Check feature and return result, or nil if unavailable
    @MainActor
    func ifAvailable<T>(_ feature: LicensedFeature, execute: () -> T) -> T? {
        guard licenseManager.isFeatureAvailable(feature) else { return nil }
        return execute()
    }

    /// Check feature and execute async closure if available
    @MainActor
    func ifAvailable(_ feature: LicensedFeature, execute: () async -> Void) async {
        guard licenseManager.isFeatureAvailable(feature) else { return }
        await execute()
    }

    /// Check feature and throw error if unavailable
    @MainActor
    func require(_ feature: LicensedFeature) throws {
        guard licenseManager.isFeatureAvailable(feature) else {
            throw FeatureUnavailableError(feature: feature)
        }
    }
}

/// Error thrown when feature is unavailable
struct FeatureUnavailableError: Error, LocalizedError {
    let feature: LicensedFeature

    var errorDescription: String? {
        "\(feature.displayName) requires \(feature.requiredTier.displayName)"
    }
}

// MARK: - Global Instance

/// Global feature guard for convenience
@MainActor
let featureGuard = FeatureGuard()

// MARK: - Environment Key

/// Environment key for feature flags
private struct FeatureFlagsKey: EnvironmentKey {
    @MainActor
    static let defaultValue = FeatureFlags.shared
}

extension EnvironmentValues {
    /// Feature flags from environment
    var featureFlags: FeatureFlags {
        get { self[FeatureFlagsKey.self] }
        set { self[FeatureFlagsKey.self] = newValue }
    }
}
