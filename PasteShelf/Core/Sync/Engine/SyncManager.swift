// swiftlint:disable file_length
//
//  SyncManager.swift
//  PasteShelf
//
//  Main coordinator for sync operations.
//  Supports both CloudKit and self-hosted backends.
//

// swiftformat:disable organizeDeclarations

import CloudKit
import Combine
import CoreData
import Foundation
import Network
import os.log
import Security

// MARK: - SyncManager

/// Main sync coordinator implementing SyncManaging protocol.
///
/// Supports two sync backends:
/// - **CloudKit**: Apple iCloud via `CloudKitSyncBackend`
/// - **Self-Hosted**: Custom server via `SelfHostedSyncBackend`
///
/// The active backend is selected in `start()` based on user configuration.
@MainActor
public final class SyncManager: ObservableObject, SyncManaging { // swiftlint:disable:this type_body_length
    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        cloudKitProvider: CloudKitProvider = CloudKitProvider(),
        changeTracker: ChangeTracker = ChangeTracker(),
        conflictResolver: ConflictResolver = ConflictResolver(),
        encryptionManager: SyncEncryptionManager = SyncEncryptionManager(),
        persistenceController: PersistenceController = .shared
    ) {
        self.cloudKitProvider = cloudKitProvider
        self.changeTracker = changeTracker
        self.conflictResolver = conflictResolver
        self.encryptionManager = encryptionManager
        self.persistenceController = persistenceController

        // Load persisted state
        self.loadPersistedState()

        // Setup network monitoring
        self.setupNetworkMonitoring()

        // Setup CoreData change observation
        self.setupCoreDataObservation()
    }

    deinit {
        networkMonitor.cancel()
    }

    // MARK: Public

    // MARK: - Published Properties

    @Published public private(set) var status: SyncStatus = .disabled
    @Published public private(set) var lastSyncDate: Date?

    /// The type of sync backend currently in use.
    @Published public private(set) var activeBackendType: SyncBackendType?

    @Published public var isEnabled: Bool = false {
        didSet {
            if self.isEnabled != oldValue {
                self.handleEnabledStateChange()
            }
        }
    }

    // MARK: - Publishers

    public var statusPublisher: AnyPublisher<SyncStatus, Never> {
        self.$status.eraseToAnyPublisher()
    }

    /// Configuration for the self-hosted sync server.
    @Published public var selfHostedConfiguration: SelfHostedSyncConfiguration? {
        didSet { self.saveSelfHostedConfiguration() }
    }

    // MARK: - SyncManaging Protocol

    // swiftlint:disable:next function_body_length
    public func start() async throws {
        Self.logger.info("Starting sync engine")

        // Determine which backend to use based on configuration
        let backend = try resolveBackend()
        self.syncBackend = backend

        // Check network
        guard self.isNetworkAvailable else {
            self.status = .offline
            throw SyncError.networkUnavailable
        }

        // Check backend availability
        self.status = .syncing(progress: 0.1)
        let availability = try await backend.checkAvailability()
        switch availability {
        case .available:
            break
        case .authenticationRequired:
            let error: SyncError = self.activeBackendType == .selfHosted
                ? .authenticationTokenExpired
                : .noAccount
            self.status = .error(error)
            throw error
        case let .unavailable(reason):
            let error: SyncError = self.activeBackendType == .selfHosted
                ? .serverConnectionFailed(message: reason)
                : .accountTemporarilyUnavailable
            self.status = .error(error)
            throw error
        }

        // Setup backend (create zones, register device, etc.)
        do {
            try await backend.setup()
        } catch let error as SyncError {
            status = .error(error)
            throw error
        }

        // Perform initial sync
        try await performSync()

        // Start auto-sync timer
        self.startAutoSyncTimer()

        // Subscribe to real-time change notifications
        try? await backend.subscribeToChanges { [weak self] notification in
            Task { @MainActor in
                guard let self else {
                    return
                }
                Self.logger.info("Received sync notification: \(notification.type.rawValue)")
                switch notification.type {
                case .changesAvailable,
                     .forceSync:
                    try? await self.syncNow()
                case .authExpired:
                    self.status = .error(.authenticationTokenExpired)
                case .deviceRemoved:
                    self.stop()
                }
            }
        }

        Self.logger.info("Sync engine started with \(self.activeBackendType?.rawValue ?? "unknown") backend")
    }

    public func stop() {
        Self.logger.info("Stopping sync engine")

        self.syncTask?.cancel()
        self.syncTask = nil
        self.isCurrentlySyncing = false
        self.pendingSync = false

        // Tear down backend (close WebSocket, unregister device) before releasing
        let backend = self.syncBackend
        self.syncBackend = nil
        if let backend {
            Task { try? await backend.teardown() }
        }

        self.status = .disabled
    }

    /// Clears the saved backend selection so the user must pick a provider again.
    public func clearBackendSelection() {
        self.activeBackendType = nil
        UserDefaults.standard.removeObject(forKey: Self.backendTypeKey)
    }

    public func syncNow() async throws {
        Self.logger.info("Manual sync requested")

        guard self.isEnabled else {
            throw SyncError.unknown(message: "Sync is not enabled")
        }

        guard !self.isCurrentlySyncing else {
            self.pendingSync = true
            return
        }

        try await self.performSync()
    }

    public func reset() async throws {
        Self.logger.info("Resetting sync state")

        let backend = self.syncBackend
        self.stop()

        // Delete encryption keys
        try self.encryptionManager.deleteKeys()

        // Clear change tracker
        self.changeTracker.clearHistoryToken()

        // Clear stored tokens
        UserDefaults.standard.removeObject(forKey: Self.changeTokenKey)
        UserDefaults.standard.removeObject(forKey: Self.lastSyncKey)
        UserDefaults.standard.removeObject(forKey: Self.backendSyncTokenKey)
        UserDefaults.standard.removeObject(forKey: Self.backendTypeKey)
        self.backendSyncToken = nil
        self.activeBackendType = nil

        // Tear down the backend (delete zone / unregister device)
        if let backend {
            try await backend.teardown()
        } else {
            // Fallback: reset CloudKit directly
            try await self.cloudKitProvider.reset()
        }

        // Mark all local items as pending sync
        try await self.markAllItemsAsPending()

        Self.logger.info("Sync reset complete")
    }

    /// Deletes all remote sync data without re-uploading. Disables sync afterwards.
    public func deleteCloudData() async throws {
        Self.logger.info("Deleting cloud data")

        let backend = self.syncBackend
        self.stop()

        // Delete encryption keys
        try self.encryptionManager.deleteKeys()

        // Clear change tracker
        self.changeTracker.clearHistoryToken()

        // Clear stored tokens
        UserDefaults.standard.removeObject(forKey: Self.changeTokenKey)
        UserDefaults.standard.removeObject(forKey: Self.lastSyncKey)
        UserDefaults.standard.removeObject(forKey: Self.backendSyncTokenKey)
        UserDefaults.standard.removeObject(forKey: Self.backendTypeKey)
        self.backendSyncToken = nil
        self.activeBackendType = nil

        // Tear down the backend (delete zone only, do not recreate)
        if let backend {
            try await backend.teardown()
        } else {
            try await self.cloudKitProvider.teardownOnly()
        }

        // Disable sync so items are NOT re-uploaded
        self.isEnabled = false

        Self.logger.info("Cloud data deleted, sync disabled")
    }

    // MARK: Private

    // MARK: - Constants

    private static let syncDebounceInterval: TimeInterval = 2.0
    private static let autoSyncInterval: TimeInterval = 300.0 // 5 minutes

    // MARK: - UserDefaults Keys

    private static let enabledKey = "com.pasteshelf.sync.enabled"
    private static let lastSyncKey = "com.pasteshelf.sync.lastSyncDate"
    private static let changeTokenKey = "com.pasteshelf.sync.changeToken"
    private static let backendSyncTokenKey = "com.pasteshelf.sync.backendSyncToken"
    private static let backendTypeKey = "com.pasteshelf.sync.backendType"
    private static let selfHostedConfigKey = "com.pasteshelf.sync.selfHostedConfiguration"
    private static let selfHostedApiKeyService = "com.pasteshelf.sync.selfHostedApiKey"
    private static let selfHostedApiKeyAccount = "selfHostedSync"

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "sync-manager"
    )

    // MARK: - Dependencies

    private let cloudKitProvider: CloudKitProvider
    private let changeTracker: ChangeTracker
    private let conflictResolver: ConflictResolver
    private let encryptionManager: SyncEncryptionManager
    private let persistenceController: PersistenceController

    // MARK: - Backend

    /// The active sync backend (CloudKit or self-hosted). Set during `start()`.
    private var syncBackend: (any SyncBackend)?

    // MARK: - Network Monitoring

    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "com.pasteshelf.sync.network")
    private var isNetworkAvailable = true

    /// Wrapper that posts .networkRestored / .networkLost notifications and queues offline changes
    private let networkMonitorWrapper = NetworkMonitor()

    /// Handles iCloud account switches and posts .iCloudAccountSwitched
    private let accountChangeHandler = AccountChangeHandler()

    // MARK: - Sync State

    private var syncTask: Task<Void, Never>?
    private var isCurrentlySyncing = false
    private var pendingSync = false
    private var changeToken: CKServerChangeToken?

    /// Backend-agnostic sync token stored as opaque Data.
    private var backendSyncToken: Data?

    // MARK: - Self-Hosted API Key Keychain Helpers

    private static func saveSelfHostedApiKeyToKeychain(_ apiKey: String) {
        guard let data = apiKey.data(using: .utf8) else {
            return
        }
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.selfHostedApiKeyService,
            kSecAttrAccount as String: self.selfHostedApiKeyAccount,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.selfHostedApiKeyService,
            kSecAttrAccount as String: self.selfHostedApiKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private static func loadSelfHostedApiKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.selfHostedApiKeyService,
            kSecAttrAccount as String: self.selfHostedApiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteSelfHostedApiKeyFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.selfHostedApiKeyService,
            kSecAttrAccount as String: self.selfHostedApiKeyAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Determines the appropriate sync backend based on configuration.
    private func resolveBackend() throws -> any SyncBackend {
        #if !APP_STORE
            // Self-hosted sync takes precedence if configured
            if let config = selfHostedConfiguration, config.isConfigured, config.isEnabled {
                self.activeBackendType = .selfHosted
                Self.logger.info("Using self-hosted sync backend")
                return SelfHostedSyncBackend(configuration: config)
            }
        #endif

        // Fall back to CloudKit
        self.activeBackendType = .cloudKit
        Self.logger.info("Using CloudKit sync backend")
        return CloudKitSyncBackend(provider: self.cloudKitProvider)
    }

    // MARK: - Private Sync Operations

    private func performSync() async throws {
        guard !self.isCurrentlySyncing else {
            self.pendingSync = true
            return
        }

        self.isCurrentlySyncing = true
        defer {
            isCurrentlySyncing = false
            if pendingSync {
                pendingSync = false
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(Self.syncDebounceInterval * 1_000_000_000))
                    try? await performSync()
                }
            }
        }

        self.status = .syncing(progress: 0.2)
        Self.logger.info("Starting sync operation")

        do {
            // 1. Pull remote changes first
            self.status = .syncing(progress: 0.3)
            try await self.pullRemoteChanges()

            // 2. Push local changes
            self.status = .syncing(progress: 0.6)
            try await self.pushLocalChanges()

            // 3. Update sync state
            let now = Date()
            self.lastSyncDate = now
            UserDefaults.standard.set(now, forKey: Self.lastSyncKey)

            self.status = .synced(lastSync: now)
            Self.logger.info("Sync completed successfully")
        } catch let error as SyncError {
            status = .error(error)
            throw error
        } catch {
            let syncError = SyncError.unknown(message: error.localizedDescription)
            self.status = .error(syncError)
            throw syncError
        }
    }

    private func pullRemoteChanges() async throws {
        guard let backend = syncBackend else {
            return
        }

        Self.logger.debug("Pulling remote changes via \(self.activeBackendType?.rawValue ?? "unknown") backend")

        let result = try await backend.pullChanges(sinceToken: self.backendSyncToken)

        if !result.changes.isEmpty {
            try await self.applyRemoteChanges(result.changes)
        }

        // Save new token
        if let newToken = result.newToken {
            self.backendSyncToken = newToken
            self.saveBackendSyncToken(newToken)
        }

        // Continue pulling if more changes are available
        if result.hasMore {
            try await self.pullRemoteChanges()
        }

        Self.logger.debug("Pulled \(result.changes.count) remote changes")
    }

    private func pushLocalChanges() async throws {
        guard let backend = syncBackend else {
            return
        }

        Self.logger.debug("Pushing local changes via \(self.activeBackendType?.rawValue ?? "unknown") backend")

        // Get pending changes
        let pendingChanges = try await changeTracker.getPendingChanges()

        guard !pendingChanges.isEmpty else {
            Self.logger.debug("No local changes to push")
            return
        }

        // Prepare changes with encrypted data
        let preparedChanges = try await changeTracker.prepareChangesForSync(pendingChanges)

        // Push to backend
        let pushResult = try await backend.pushChanges(preparedChanges)

        // Handle conflicts if any
        if !pushResult.conflicts.isEmpty {
            Self.logger.info("Push returned \(pushResult.conflicts.count) conflicts")
            try await self.handlePushConflicts(pushResult.conflicts, originalChanges: preparedChanges)
        }

        // Update sync token from push result
        if let newToken = pushResult.newToken {
            self.backendSyncToken = newToken
            self.saveBackendSyncToken(newToken)
        }

        // Mark as synced
        try await self.changeTracker.markAsSynced(preparedChanges)

        Self.logger.debug("Pushed \(preparedChanges.count) local changes (\(pushResult.accepted) accepted)")
    }

    /// Handle conflicts returned from a push operation.
    private func handlePushConflicts(_ conflicts: [SyncConflict], originalChanges: [SyncChange]) async throws {
        for conflict in conflicts {
            // Find the local change for this entity
            guard let localChange = originalChanges.first(where: { $0.entityID == conflict.entityID }) else {
                continue
            }

            // Create a remote change from the server's version
            let remoteChange = SyncChange(
                changeType: .remoteUpdate,
                entityType: localChange.entityType,
                entityID: conflict.entityID,
                serverTimestamp: conflict.serverTimestamp,
                encryptedData: conflict.serverEncryptedData
            )

            // Use the existing conflict resolver
            let resolution = try await conflictResolver.resolve(local: localChange, remote: remoteChange)

            switch resolution {
            case .useLocal:
                // Retry pushing the local version (already pending)
                Self.logger.debug("Conflict resolved: using local version for \(conflict.entityID)")
            case let .useRemote(change):
                // Apply the server's version locally
                try await self.applyRemoteChanges([change])
            case let .merged(change):
                // Apply the merged version locally, then re-push
                try await self.applyRemoteChanges([change])
            }
        }
    }

    private func applyRemoteChanges(_ changes: [SyncChange]) async throws {
        Self.logger.debug("Applying \(changes.count) remote changes")

        let context = self.persistenceController.newBackgroundContext()

        // Pre-decrypt all payloads outside context.perform to avoid blocking
        // the context queue with async operations (no DispatchSemaphore needed)
        var decryptedPayloads: [UUID: Data] = [:]
        for change in changes {
            if change.changeType == .remoteInsert || change.changeType == .remoteUpdate,
               change.entityType == .clipboardItem,
               let encryptedData = change.encryptedData
            {
                decryptedPayloads[change.entityID] = try await self.encryptionManager.decrypt(encryptedData)
            }
        }

        try await context.perform {
            for change in changes {
                try self.applyChange(change, decryptedPayloads: decryptedPayloads, in: context)
            }

            if context.hasChanges {
                try context.save()
            }
        }
    }

    private func applyChange(
        _ change: SyncChange,
        decryptedPayloads: [UUID: Data],
        in context: NSManagedObjectContext
    ) throws {
        switch change.changeType {
        case .remoteInsert,
             .remoteUpdate:
            try self.applyInsertOrUpdate(change, decryptedPayloads: decryptedPayloads, in: context)
        case .remoteDelete:
            try self.applyDelete(change, in: context)
        default:
            break
        }
    }

    private func applyInsertOrUpdate(
        _ change: SyncChange,
        decryptedPayloads: [UUID: Data],
        in context: NSManagedObjectContext
    ) throws {
        guard change.entityType == .clipboardItem else {
            return
        }

        guard let data = decryptedPayloads[change.entityID] else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(ClipboardItemPayload.self, from: data)

        // Find or create item
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", payload.id as CVarArg)
        request.fetchLimit = 1

        let item = try context.fetch(request).first ?? ClipboardItem(context: context)

        // Update item from payload
        item.id = payload.id
        item.timestamp = payload.timestamp
        item.contentType = payload.contentType
        item.contentHash = payload.contentHash
        item.plainTextPreview = payload.plainTextPreview
        item.sourceAppBundleId = payload.sourceAppBundleId
        item.sourceAppName = payload.sourceAppName
        item.isFavorite = payload.isFavorite
        item.isSensitive = payload.isSensitive
        item.accessCount = Int32(payload.accessCount)
        item.syncState = ItemSyncState.synced.rawValue
        item.lastSyncedAt = Date()
        item.cloudKitRecordID = change.cloudKitRecordID
    }

    private func applyDelete(_ change: SyncChange, in context: NSManagedObjectContext) throws {
        guard change.entityType == .clipboardItem else {
            return
        }

        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", change.entityID as CVarArg)
        request.fetchLimit = 1

        if let item = try context.fetch(request).first {
            context.delete(item)
        }
    }

    // MARK: - Helper Methods

    private func loadPersistedState() {
        self.isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        self.lastSyncDate = UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date
        self.changeToken = self.loadChangeToken()
        self.backendSyncToken = UserDefaults.standard.data(forKey: Self.backendSyncTokenKey)
        self.selfHostedConfiguration = self.loadSelfHostedConfiguration()

        if let typeString = UserDefaults.standard.string(forKey: Self.backendTypeKey) {
            self.activeBackendType = SyncBackendType(rawValue: typeString)
        }

        if self.isEnabled {
            self.status = self.lastSyncDate.map { .synced(lastSync: $0) } ?? .idle
        }
    }

    private func saveChangeToken(_ token: CKServerChangeToken) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: Self.changeTokenKey)
        } catch {
            Self.logger.error("Failed to save change token: \(error.localizedDescription)")
        }
    }

    private func loadChangeToken() -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: Self.changeTokenKey) else {
            return nil
        }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    /// Persist the backend-agnostic sync token.
    private func saveBackendSyncToken(_ token: Data) {
        UserDefaults.standard.set(token, forKey: Self.backendSyncTokenKey)
    }

    /// Persist the active backend type so we can restore it on next launch.
    private func saveBackendType(_ type: SyncBackendType) {
        UserDefaults.standard.set(type.rawValue, forKey: Self.backendTypeKey)
    }

    /// Persist the self-hosted sync configuration to UserDefaults (API key stored in Keychain).
    private func saveSelfHostedConfiguration() {
        guard let config = selfHostedConfiguration else {
            UserDefaults.standard.removeObject(forKey: Self.selfHostedConfigKey)
            Self.deleteSelfHostedApiKeyFromKeychain()
            return
        }
        // Strip API key from UserDefaults — store it in Keychain instead
        var sanitized = config
        sanitized.apiKey = nil
        if let data = try? JSONEncoder().encode(sanitized) {
            UserDefaults.standard.set(data, forKey: Self.selfHostedConfigKey)
        }
        if let apiKey = config.apiKey {
            Self.saveSelfHostedApiKeyToKeychain(apiKey)
        } else {
            Self.deleteSelfHostedApiKeyFromKeychain()
        }
    }

    /// Load persisted self-hosted sync configuration from UserDefaults + Keychain.
    private func loadSelfHostedConfiguration() -> SelfHostedSyncConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: Self.selfHostedConfigKey) else {
            return nil
        }
        guard var config = try? JSONDecoder().decode(SelfHostedSyncConfiguration.self, from: data) else {
            return nil
        }
        config.apiKey = Self.loadSelfHostedApiKeyFromKeychain()
        return config
    }

    private func handleEnabledStateChange() {
        UserDefaults.standard.set(self.isEnabled, forKey: Self.enabledKey)

        if self.isEnabled {
            // Only auto-start if a backend was previously configured.
            // First-time enable waits for the user to pick a provider.
            if self.activeBackendType != nil || UserDefaults.standard.string(forKey: Self.backendTypeKey) != nil {
                Task {
                    try? await self.start()
                }
            }
        } else {
            self.stop()
        }
    }

    // swiftlint:disable:next function_body_length
    private func setupNetworkMonitoring() {
        self.networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasAvailable = self?.isNetworkAvailable ?? true
                self?.isNetworkAvailable = path.status == .satisfied

                if path.status == .satisfied, !wasAvailable {
                    // Network restored - trigger sync
                    Self.logger.info("Network restored, triggering sync")
                    try? await self?.syncNow()
                } else if path.status != .satisfied, wasAvailable {
                    Self.logger.info("Network lost")
                    self?.status = .offline
                }
            }
        }
        self.networkMonitor.start(queue: self.networkQueue)

        // Observe NetworkMonitor notifications as a secondary signal
        NotificationCenter.default.addObserver(
            forName: .networkRestored,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isEnabled else {
                    return
                }
                Self.logger.debug("NetworkMonitor reported network restored")
                try? await self.syncNow()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .networkLost,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else {
                    return
                }
                Self.logger.debug("NetworkMonitor reported network lost")
                self.status = .offline
            }
        }

        // Observe iCloud account switches to reset sync state
        NotificationCenter.default.addObserver(
            forName: .iCloudAccountSwitched,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self, self.isEnabled else {
                    return
                }
                let newUserId = notification.userInfo?["newUserID"] as? String
                Self.logger.info("iCloud account switched to: \(newUserId ?? "unknown")")
                self.stop()
                try? await self.start()
            }
        }
    }

    private func setupCoreDataObservation() {
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, isEnabled, !self.isCurrentlySyncing else {
                return
            }

            // Debounce sync on data changes
            Task {
                try? await Task.sleep(nanoseconds: UInt64(Self.syncDebounceInterval * 1_000_000_000))
                try? await self.syncNow()
            }
        }
    }

    private func startAutoSyncTimer() {
        self.syncTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.autoSyncInterval * 1_000_000_000))
                guard let self, !Task.isCancelled else {
                    break
                }
                try? await self.syncNow()
            }
        }
    }

    private func markAllItemsAsPending() async throws {
        let context = self.persistenceController.newBackgroundContext()

        try await context.perform {
            let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            let items = try context.fetch(request)

            for item in items {
                item.syncState = ItemSyncState.pending.rawValue
                item.cloudKitRecordID = nil
            }

            try context.save()
        }
    }
}

// MARK: - Shared Instance

extension SyncManager {
    /// Shared singleton instance
    @MainActor static let shared = SyncManager()
}
