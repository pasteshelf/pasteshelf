// swiftlint:disable file_length
//
//  AdminPolicySyncTests.swift
//  PasteShelfTests
//
//  Tests for PolicySyncService: policy mapping to AppSettings, caching, and fetch behavior.
//  Mirrors MDMPolicyEnforcerTests for the admin console policy layer.
//

import Foundation
@testable import PasteShelf
import Testing

// MARK: - AdminPolicySyncTests

// swiftlint:disable:next type_body_length
struct AdminPolicySyncTests {
    // MARK: Internal

    // MARK: - History Limits Mapping

    @Test("applyPolicy maps maxItems <= 100 to HistoryLimit.small")
    func historyLimitSmall() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            historyLimits: HistoryLimitPolicy(maxItems: 100, enforced: true)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.general.historyLimit == .small)
    }

    @Test("applyPolicy maps maxItems of 1 to HistoryLimit.small")
    func historyLimit1MapsToSmall() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            historyLimits: HistoryLimitPolicy(maxItems: 1, enforced: true)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.general.historyLimit == .small)
    }

    @Test("applyPolicy maps maxItems <= 500 to HistoryLimit.medium")
    func historyLimitMedium() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            historyLimits: HistoryLimitPolicy(maxItems: 500, enforced: true)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.general.historyLimit == .medium)
    }

    @Test("applyPolicy maps maxItems of 101 to HistoryLimit.medium")
    func historyLimit101MapsToMedium() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            historyLimits: HistoryLimitPolicy(maxItems: 101, enforced: true)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.general.historyLimit == .medium)
    }

    @Test("applyPolicy maps maxItems <= 1000 to HistoryLimit.large")
    func historyLimitLarge() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            historyLimits: HistoryLimitPolicy(maxItems: 1000, enforced: true)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.general.historyLimit == .large)
    }

    @Test("applyPolicy maps maxItems of 501 to HistoryLimit.large")
    func historyLimit501MapsToLarge() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            historyLimits: HistoryLimitPolicy(maxItems: 501, enforced: true)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.general.historyLimit == .large)
    }

    @Test("applyPolicy maps maxItems > 1000 to HistoryLimit.unlimited")
    func historyLimitUnlimited() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            historyLimits: HistoryLimitPolicy(maxItems: 5000, enforced: true)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.general.historyLimit == .unlimited)
    }

    @Test("applyPolicy maps maxItems of 0 to HistoryLimit.unlimited")
    func historyLimit0MapsToUnlimited() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            historyLimits: HistoryLimitPolicy(maxItems: 0, enforced: true)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.general.historyLimit == .unlimited)
    }

    @Test("applyPolicy maps negative maxItems to HistoryLimit.unlimited")
    func historyLimitNegativeMapsToUnlimited() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            historyLimits: HistoryLimitPolicy(maxItems: -10, enforced: true)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.general.historyLimit == .unlimited)
    }

    // MARK: - History Max Days

    @Test("applyPolicy enables auto-delete and sets days for maxDays")
    func historyMaxDaysEnablesAutoDelete() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        settings.privacy.autoDeleteEnabled = false
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            historyLimits: HistoryLimitPolicy(maxDays: 30, enforced: true)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.privacy.autoDeleteEnabled == true)
        #expect(settings.privacy.autoDeleteDays == 30)
    }

    @Test("applyPolicy with maxDays of 90 sets correct days")
    func historyMaxDays90() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            historyLimits: HistoryLimitPolicy(maxDays: 90, enforced: true)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.privacy.autoDeleteEnabled == true)
        #expect(settings.privacy.autoDeleteDays == 90)
    }

    @Test("applyPolicy does not enable auto-delete for maxDays of 0")
    func historyMaxDays0DoesNotEnableAutoDelete() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        settings.privacy.autoDeleteEnabled = false
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            historyLimits: HistoryLimitPolicy(maxDays: 0, enforced: true)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.privacy.autoDeleteEnabled == false)
    }

    @Test("applyPolicy does not enable auto-delete for negative maxDays")
    func historyMaxDaysNegativeDoesNotEnableAutoDelete() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        settings.privacy.autoDeleteEnabled = false
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            historyLimits: HistoryLimitPolicy(maxDays: -5, enforced: true)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.privacy.autoDeleteEnabled == false)
    }

    @Test("applyPolicy applies both maxItems and maxDays together")
    func historyBothItemsAndDays() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            historyLimits: HistoryLimitPolicy(maxItems: 200, maxDays: 60, enforced: true)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.general.historyLimit == .medium)
        #expect(settings.privacy.autoDeleteEnabled == true)
        #expect(settings.privacy.autoDeleteDays == 60)
    }

    // MARK: - Excluded Apps

    @Test("applyPolicy merges enforced excluded apps with existing list")
    func excludedAppsMerge() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        settings.privacy.excludedAppBundleIds = ["com.user.app"]
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            excludedApps: ExcludedAppsPolicy(
                bundleIds: ["com.enterprise.secure", "com.enterprise.vpn"],
                enforced: true
            )
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.privacy.excludedAppBundleIds.contains("com.user.app"))
        #expect(settings.privacy.excludedAppBundleIds.contains("com.enterprise.secure"))
        #expect(settings.privacy.excludedAppBundleIds.contains("com.enterprise.vpn"))
        #expect(settings.privacy.excludedAppBundleIds.count == 3)
    }

    @Test("applyPolicy excluded apps are sorted")
    func excludedAppsAreSorted() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        settings.privacy.excludedAppBundleIds = ["com.zzz"]
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            excludedApps: ExcludedAppsPolicy(bundleIds: ["com.aaa"], enforced: true)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.privacy.excludedAppBundleIds == ["com.aaa", "com.zzz"])
    }

    @Test("applyPolicy does not duplicate existing excluded apps")
    func excludedAppsNoDuplicates() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        settings.privacy.excludedAppBundleIds = ["com.shared.app"]
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            excludedApps: ExcludedAppsPolicy(bundleIds: ["com.shared.app", "com.new.app"], enforced: true)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.privacy.excludedAppBundleIds.count == 2)
        #expect(settings.privacy.excludedAppBundleIds.contains("com.shared.app"))
        #expect(settings.privacy.excludedAppBundleIds.contains("com.new.app"))
    }

    @Test("applyPolicy with empty excluded apps policy preserves existing list")
    func excludedAppsEmptyPolicyPreservesExisting() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        settings.privacy.excludedAppBundleIds = ["com.user.app"]
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            excludedApps: ExcludedAppsPolicy(bundleIds: [], enforced: true)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.privacy.excludedAppBundleIds == ["com.user.app"])
    }

    // MARK: - Non-Enforced Policies

    @Test("applyPolicy skips non-enforced history limits")
    func nonEnforcedHistoryLimitsSkipped() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        let original = settings
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            historyLimits: HistoryLimitPolicy(maxItems: 100, maxDays: 7, enforced: false)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.general.historyLimit == original.general.historyLimit)
        #expect(settings.privacy.autoDeleteEnabled == original.privacy.autoDeleteEnabled)
    }

    @Test("applyPolicy skips non-enforced excluded apps")
    func nonEnforcedExcludedAppsSkipped() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        settings.privacy.excludedAppBundleIds = ["com.user.app"]
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            excludedApps: ExcludedAppsPolicy(bundleIds: ["com.blocked.app"], enforced: false)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings.privacy.excludedAppBundleIds == ["com.user.app"])
    }

    @Test("applyPolicy skips non-enforced sync settings")
    func nonEnforcedSyncSettingsSkipped() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        let original = settings
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            syncSettings: SyncSettingsPolicy(syncEnabled: false, localStorageOnly: true, enforced: false)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings == original)
    }

    @Test("applyPolicy skips non-enforced encryption policy")
    func nonEnforcedEncryptionSkipped() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        let original = settings
        let policy = AdminPolicy(
            id: "p1",
            version: "1",
            name: "Test",
            updatedAt: Date(),
            encryptionRequirements: EncryptionPolicy(requireEncryption: true, enforced: false)
        )

        service.applyPolicy(policy, to: &settings)

        #expect(settings == original)
    }

    // MARK: - Nil Sub-policies

    @Test("applyPolicy with all nil sub-policies changes nothing")
    func nilSubPoliciesChangeNothing() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        let original = settings
        let policy = AdminPolicy(id: "p1", version: "1", name: "Test", updatedAt: Date())

        service.applyPolicy(policy, to: &settings)

        #expect(settings == original)
    }

    @Test("applyPolicy with AdminPolicy.empty changes nothing")
    func emptyPolicyChangesNothing() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        let original = settings

        service.applyPolicy(.empty, to: &settings)

        #expect(settings == original)
    }

    // MARK: - Full Policy Application

    @Test("applyPolicy applies multiple enforced sub-policies simultaneously")
    func fullPolicyApplication() {
        let (service, _) = makeService()
        var settings = AppSettings.default
        settings.privacy.excludedAppBundleIds = ["com.user.kept"]
        let policy = AdminPolicy(
            id: "full",
            version: "3",
            name: "Enterprise Strict",
            updatedAt: Date(),
            historyLimits: HistoryLimitPolicy(maxItems: 500, maxDays: 30, enforced: true),
            excludedApps: ExcludedAppsPolicy(bundleIds: ["com.secure.browser"], enforced: true),
            syncSettings: SyncSettingsPolicy(syncEnabled: false, localStorageOnly: true, enforced: true),
            encryptionRequirements: EncryptionPolicy(requireEncryption: true, enforced: true)
        )

        service.applyPolicy(policy, to: &settings)

        // History limits
        #expect(settings.general.historyLimit == .medium)
        #expect(settings.privacy.autoDeleteEnabled == true)
        #expect(settings.privacy.autoDeleteDays == 30)

        // Excluded apps (merged and sorted)
        #expect(settings.privacy.excludedAppBundleIds.contains("com.user.kept"))
        #expect(settings.privacy.excludedAppBundleIds.contains("com.secure.browser"))

        // Sync and encryption are logged but not yet mapped to AppSettings
        // (future-proofed in the service implementation)
    }

    // MARK: - Fetch Policy

    @Test("fetchLatestPolicy calls API with correct device ID")
    func fetchLatestPolicyCallsAPI() async throws {
        let api = MockAdminAPIClient()
        let expectedPolicy = AdminPolicy(id: "pol-new", version: "5", name: "Updated", updatedAt: Date())
        api.fetchPolicyResult = .success(expectedPolicy)

        let (service, _) = makeService(api: api, deviceId: "dev-123")
        let result = try await service.fetchLatestPolicy()

        #expect(result.id == "pol-new")
        #expect(result.version == "5")
        #expect(api.fetchPolicyCalls == ["dev-123"])
    }

    @Test("fetchLatestPolicy caches the fetched policy")
    func fetchLatestPolicyCachesResult() async throws {
        let api = MockAdminAPIClient()
        let policy = AdminPolicy(id: "pol-cached", version: "1", name: "Cached", updatedAt: Date())
        api.fetchPolicyResult = .success(policy)

        let (service, _) = makeService(api: api, deviceId: "dev-1")
        _ = try await service.fetchLatestPolicy()

        #expect(service.currentPolicy?.id == "pol-cached")
    }

    @Test("fetchLatestPolicy throws notEnrolled when deviceId is nil")
    func fetchLatestPolicyThrowsWhenNoDevice() async throws {
        let api = MockAdminAPIClient()
        let (service, _) = makeService(api: api, deviceId: nil)

        do {
            _ = try await service.fetchLatestPolicy()
            #expect(Bool(false), "Expected AdminError.notEnrolled")
        } catch let error as AdminError {
            if case .notEnrolled = error {
                #expect(api.fetchPolicyCalls.isEmpty)
            } else {
                #expect(Bool(false), "Expected notEnrolled, got \(error)")
            }
        }
    }

    @Test("fetchLatestPolicy propagates API errors")
    func fetchLatestPolicyPropagatesErrors() async throws {
        let api = MockAdminAPIClient()
        api.fetchPolicyResult = .failure(AdminError.networkError("DNS failure"))

        let (service, _) = makeService(api: api, deviceId: "dev-1")

        do {
            _ = try await service.fetchLatestPolicy()
            #expect(Bool(false), "Expected AdminError.networkError")
        } catch let error as AdminError {
            if case let .networkError(msg) = error {
                #expect(msg == "DNS failure")
            } else {
                #expect(Bool(false), "Expected networkError, got \(error)")
            }
        }
    }

    @Test("currentPolicy is nil before any fetch")
    func currentPolicyNilBeforeFetch() {
        let (service, _) = makeService()
        #expect(service.currentPolicy == nil)
    }

    // MARK: Private

    // MARK: - Test Helpers

    /// Creates a `PolicySyncService` wired to a mock API client.
    private func makeService(
        api: MockAdminAPIClient = MockAdminAPIClient(),
        deviceId: String? = "dev-test"
    ) -> (PolicySyncService, MockAdminAPIClient) {
        let service = PolicySyncService(
            apiClient: api
        ) { deviceId }
        return (service, api)
    }
}
