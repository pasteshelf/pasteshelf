//
//  ExclusionManagerTests.swift
//  PasteShelfTests
//
//  Tests for app exclusion management functionality.
//

import Foundation
import Testing
@testable import PasteShelf

@MainActor
struct ExclusionManagerTests {
    // MARK: - Default Exclusions Tests

    @Test("Password managers are excluded by default")
    func passwordManagersAreExcludedByDefault() {
        let manager = ExclusionManager.shared

        #expect(manager.isExcluded(bundleId: "com.1password.1Password"))
        #expect(manager.isExcluded(bundleId: "com.bitwarden.desktop"))
        #expect(manager.isExcluded(bundleId: "com.lastpass.LastPass"))
    }

    @Test("Normal apps are not excluded by default")
    func normalAppsAreNotExcludedByDefault() {
        let manager = ExclusionManager.shared

        #expect(!manager.isExcluded(bundleId: "com.apple.Notes"))
        #expect(!manager.isExcluded(bundleId: "com.google.Chrome"))
        #expect(!manager.isExcluded(bundleId: "com.microsoft.Word"))
    }

    @Test("Default exclusions list contains password managers")
    func defaultExclusionsContainsPasswordManagers() {
        let manager = ExclusionManager.shared
        let defaults = manager.defaultExcludedBundleIds

        #expect(defaults.contains("com.1password.1Password"))
        #expect(defaults.contains("com.bitwarden.desktop"))
    }

    // MARK: - User Exclusion Tests

    @Test("Can add user exclusion")
    func canAddUserExclusion() {
        let manager = ExclusionManager.forTesting(
            defaultExclusions: [],
            userExclusions: [],
            excludeOwnApp: false
        )

        manager.exclude(bundleId: "com.example.app")

        #expect(manager.isExcluded(bundleId: "com.example.app"))
    }

    @Test("Can remove user exclusion")
    func canRemoveUserExclusion() {
        let manager = ExclusionManager.forTesting(
            defaultExclusions: [],
            userExclusions: ["com.example.app"],
            excludeOwnApp: false
        )

        manager.include(bundleId: "com.example.app")

        #expect(!manager.isExcluded(bundleId: "com.example.app"))
    }

    @Test("Cannot remove default exclusion")
    func cannotRemoveDefaultExclusion() {
        let manager = ExclusionManager.shared

        // Try to remove a default exclusion
        manager.include(bundleId: "com.1password.1Password")

        // Should still be excluded
        #expect(manager.isExcluded(bundleId: "com.1password.1Password"))
    }

    // MARK: - Exclusion List Tests

    @Test("Excluded bundle IDs includes all sources")
    func excludedBundleIdsIncludesAllSources() {
        let manager = ExclusionManager.shared
        let excluded = manager.excludedBundleIds

        // Should include defaults
        #expect(excluded.contains("com.1password.1Password"))
        // Should be sorted
        #expect(excluded == excluded.sorted())
    }

    // MARK: - Exclusion Info Tests

    @Test("Exclusion info for default app")
    func exclusionInfoForDefaultApp() {
        let manager = ExclusionManager.shared
        let info = manager.exclusionInfo(for: "com.1password.1Password")

        #expect(info != nil)
        #expect(info?.isDefault == true)
        #expect(info?.isRemovable == false)
    }

    @Test("Exclusion info for non-excluded app is nil")
    func exclusionInfoForNonExcludedAppIsNil() {
        let manager = ExclusionManager.shared
        let info = manager.exclusionInfo(for: "com.apple.Notes")

        #expect(info == nil)
    }
}

// MARK: - Exclusion Reason Tests

struct ExclusionReasonTests {
    @Test("Exclusion reasons are sendable")
    func exclusionReasonsAreSendable() {
        let reason: ExclusionReason = .excludedApp(bundleId: "test")

        // This test verifies the type is Sendable at compile time
        Task {
            _ = reason
        }
    }

    @Test("Exclusion reason cases exist")
    func exclusionReasonCasesExist() {
        let reasons: [ExclusionReason] = [
            .excludedApp(bundleId: "test"),
            .privateBrowsing,
            .ownPasteOperation,
            .emptyContent,
            .duplicate,
            .userPaused
        ]

        #expect(reasons.count == 6)
    }
}
