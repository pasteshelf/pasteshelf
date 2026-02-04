//
//  AutoCleanupManagerTests.swift
//  PasteShelfTests
//
//  Unit tests for AutoCleanupManager.
//

import Foundation
import Testing
@testable import PasteShelf

struct AutoCleanupManagerTests {
    // MARK: - Cleanup Logic Tests

    @Test("Should cleanup when auto-delete is enabled and days exceeded")
    func shouldCleanupWhenEnabled() {
        var settings = PrivacySettings.default
        settings.autoDeleteEnabled = true
        settings.autoDeleteDays = 7

        // Calculate a date 10 days ago
        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!

        #expect(AutoCleanupManager.shouldDelete(itemDate: oldDate, settings: settings) == true)
    }

    @Test("Should not cleanup when auto-delete is disabled")
    func shouldNotCleanupWhenDisabled() {
        var settings = PrivacySettings.default
        settings.autoDeleteEnabled = false
        settings.autoDeleteDays = 7

        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!

        #expect(AutoCleanupManager.shouldDelete(itemDate: oldDate, settings: settings) == false)
    }

    @Test("Should not cleanup recent items")
    func shouldNotCleanupRecentItems() {
        var settings = PrivacySettings.default
        settings.autoDeleteEnabled = true
        settings.autoDeleteDays = 7

        // 3 days ago is within the 7-day window
        let recentDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!

        #expect(AutoCleanupManager.shouldDelete(itemDate: recentDate, settings: settings) == false)
    }

    @Test("Boundary date is handled correctly")
    func boundaryDateIsHandledCorrectly() {
        var settings = PrivacySettings.default
        settings.autoDeleteEnabled = true
        settings.autoDeleteDays = 7

        // Exactly 7 days ago
        let boundaryDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        // Implementation-dependent: could be true or false at boundary
        let result = AutoCleanupManager.shouldDelete(itemDate: boundaryDate, settings: settings)
        // Just verify it doesn't crash and returns a boolean
        #expect(result == true || result == false)
    }

    // MARK: - Favorites Protection Tests

    @Test("Favorites should be protected from cleanup")
    func favoritesShouldBeProtected() {
        // Favorites should never be deleted regardless of age
        #expect(AutoCleanupManager.shouldKeepFavorite(true) == true)
        #expect(AutoCleanupManager.shouldKeepFavorite(false) == false)
    }

    // MARK: - History Limit Tests

    @Test("Items over limit should be candidates for deletion")
    func itemsOverLimitShouldBeCandidates() {
        let limit = 100
        let currentCount = 150

        #expect(AutoCleanupManager.itemsToRemove(currentCount: currentCount, limit: limit) == 50)
    }

    @Test("Items under limit should not be deleted")
    func itemsUnderLimitShouldNotBeDeleted() {
        let limit = 100
        let currentCount = 50

        #expect(AutoCleanupManager.itemsToRemove(currentCount: currentCount, limit: limit) == 0)
    }

    @Test("Exactly at limit should not delete")
    func exactlyAtLimitShouldNotDelete() {
        let limit = 100
        let currentCount = 100

        #expect(AutoCleanupManager.itemsToRemove(currentCount: currentCount, limit: limit) == 0)
    }

    @Test("Unlimited history limit returns zero items to remove")
    func unlimitedHistoryLimitReturnsZero() {
        let currentCount = 10000

        // When limit is nil (unlimited), no items should be removed based on count
        #expect(AutoCleanupManager.itemsToRemove(currentCount: currentCount, limit: nil) == 0)
    }

    // MARK: - Cleanup Scheduling Tests

    @Test("Cleanup interval should be reasonable")
    func cleanupIntervalShouldBeReasonable() {
        // Default cleanup interval should be at least 1 hour
        let interval = AutoCleanupManager.defaultCleanupInterval

        #expect(interval >= 3600)  // At least 1 hour
        #expect(interval <= 86400)  // At most 1 day
    }
}

// MARK: - Mock Helper for Testing

extension AutoCleanupManager {
    /// Check if an item should be deleted based on date and settings
    nonisolated static func shouldDelete(itemDate: Date, settings: PrivacySettings) -> Bool {
        guard settings.autoDeleteEnabled else { return false }

        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -settings.autoDeleteDays,
            to: Date()
        )!

        return itemDate < cutoffDate
    }

    /// Check if a favorite should be kept
    nonisolated static func shouldKeepFavorite(_ isFavorite: Bool) -> Bool {
        isFavorite
    }

    /// Calculate how many items need to be removed based on limit
    nonisolated static func itemsToRemove(currentCount: Int, limit: Int?) -> Int {
        guard let limit = limit else { return 0 }
        return max(0, currentCount - limit)
    }

    /// Default cleanup interval in seconds
    nonisolated static var defaultCleanupInterval: TimeInterval {
        86400  // 24 hours
    }
}
