//
//  GDPRConsentManagerTests.swift
//  PasteShelfTests
//
//  Tests for GDPRConsentCategory enum and GDPRConsentManager consent flows.
//

import CoreData
import Foundation
@testable import PasteShelf
import Testing

// MARK: - GDPRConsentCategoryTests

struct GDPRConsentCategoryTests {
    // MARK: Raw Values

    @Test("clipboardMonitoring raw value is 'clipboard_monitoring'")
    func clipboardMonitoringRawValue() {
        #expect(GDPRConsentCategory.clipboardMonitoring.rawValue == "clipboard_monitoring")
    }

    @Test("analytics raw value is 'analytics'")
    func analyticsRawValue() {
        #expect(GDPRConsentCategory.analytics.rawValue == "analytics")
    }

    @Test("cloudSync raw value is 'cloud_sync'")
    func cloudSyncRawValue() {
        #expect(GDPRConsentCategory.cloudSync.rawValue == "cloud_sync")
    }

    @Test("auditLogging raw value is 'audit_logging'")
    func auditLoggingRawValue() {
        #expect(GDPRConsentCategory.auditLogging.rawValue == "audit_logging")
    }

    @Test("thirdPartyPlugins raw value is 'third_party_plugins'")
    func thirdPartyPluginsRawValue() {
        #expect(GDPRConsentCategory.thirdPartyPlugins.rawValue == "third_party_plugins")
    }

    // MARK: CaseIterable

    @Test("allCases contains exactly 5 categories")
    func allCasesCount() {
        #expect(GDPRConsentCategory.allCases.count == 5)
    }

    @Test("allCases contains all expected categories")
    func allCasesContainsAll() {
        let cases = GDPRConsentCategory.allCases
        #expect(cases.contains(.clipboardMonitoring))
        #expect(cases.contains(.analytics))
        #expect(cases.contains(.cloudSync))
        #expect(cases.contains(.auditLogging))
        #expect(cases.contains(.thirdPartyPlugins))
    }

    // MARK: Display Names

    @Test("displayName is non-empty for all categories")
    func displayNamesNonEmpty() {
        for category in GDPRConsentCategory.allCases {
            #expect(!category.displayName.isEmpty)
        }
    }

    // MARK: Purpose Descriptions

    @Test("purposeDescription is non-empty for all categories")
    func purposeDescriptionsNonEmpty() {
        for category in GDPRConsentCategory.allCases {
            #expect(!category.purposeDescription.isEmpty)
        }
    }

    // MARK: Icon Names

    @Test("iconName is non-empty for all categories")
    func iconNamesNonEmpty() {
        for category in GDPRConsentCategory.allCases {
            #expect(!category.iconName.isEmpty)
        }
    }

    @Test("clipboardMonitoring icon is 'doc.on.clipboard'")
    func clipboardIcon() {
        #expect(GDPRConsentCategory.clipboardMonitoring.iconName == "doc.on.clipboard")
    }

    @Test("analytics icon is 'chart.bar.fill'")
    func analyticsIcon() {
        #expect(GDPRConsentCategory.analytics.iconName == "chart.bar.fill")
    }

    @Test("cloudSync icon is 'icloud.fill'")
    func cloudSyncIcon() {
        #expect(GDPRConsentCategory.cloudSync.iconName == "icloud.fill")
    }

    // MARK: Codable Round-trip

    @Test("GDPRConsentCategory survives Codable round-trip for all cases")
    func codableRoundTrip() throws {
        for category in GDPRConsentCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(GDPRConsentCategory.self, from: data)
            #expect(decoded == category)
        }
    }

    // MARK: Init from raw value

    @Test("Init from valid raw value succeeds")
    func initFromValidRawValue() {
        let category = GDPRConsentCategory(rawValue: "clipboard_monitoring")
        #expect(category == .clipboardMonitoring)
    }

    @Test("Init from invalid raw value returns nil")
    func initFromInvalidRawValue() {
        let category = GDPRConsentCategory(rawValue: "nonexistent")
        #expect(category == nil)
    }
}

// MARK: - GDPRConsentManagerTests

struct GDPRConsentManagerTests {
    // MARK: Internal

    // MARK: Initial State

    @Test("isConsentGranted returns false for unconfigured category")
    @MainActor
    func initialConsentFalse() {
        let context = makeInMemoryContext()
        let manager = GDPRConsentManager(context: context)
        #expect(!manager.isConsentGranted(for: .clipboardMonitoring))
    }

    @Test("consentStatuses is empty for fresh manager")
    @MainActor
    func initialStatusesEmpty() {
        let context = makeInMemoryContext()
        let manager = GDPRConsentManager(context: context)
        #expect(manager.consentStatuses.isEmpty)
    }

    // MARK: Loading existing consent records

    @Test("Manager loads existing consent records from CoreData on init")
    @MainActor
    func loadsExistingRecords() {
        let context = makeInMemoryContext()

        // Pre-populate a consent record
        let record = ConsentRecord(context: context)
        record.id = UUID()
        record.category = GDPRConsentCategory.analytics.rawValue
        record.isGranted = true
        record.updatedAt = Date()
        try? context.save()

        let manager = GDPRConsentManager(context: context)
        #expect(manager.isConsentGranted(for: .analytics) == true)
    }

    @Test("Manager ignores records with invalid category raw values")
    @MainActor
    func ignoresInvalidCategories() {
        let context = makeInMemoryContext()

        let record = ConsentRecord(context: context)
        record.id = UUID()
        record.category = "nonexistent_category"
        record.isGranted = true
        record.updatedAt = Date()
        try? context.save()

        let manager = GDPRConsentManager(context: context)
        #expect(manager.consentStatuses.isEmpty)
    }

    // MARK: Private

    // MARK: Helpers

    private func makeInMemoryContext() -> NSManagedObjectContext {
        let controller = PersistenceController(inMemory: true)
        return controller.container.viewContext
    }
}
