//
//  SyncManager.swift
//  PasteShelf
//
//  Main coordinator for iCloud sync operations.
//

import CloudKit
import Combine
import CoreData
import Foundation
import Network
import os.log

/// Main sync coordinator implementing SyncManaging protocol
@MainActor
public final class SyncManager: ObservableObject, SyncManaging {
    // MARK: - Published Properties

    @Published public private(set) var status: SyncStatus = .disabled
    @Published public var isEnabled: Bool = false {
        didSet {
            if isEnabled != oldValue {
                handleEnabledStateChange()
            }
        }
    }

    @Published public private(set) var lastSyncDate: Date?

    // MARK: - Publishers

    public var statusPublisher: AnyPublisher<SyncStatus, Never> {
        $status.eraseToAnyPublisher()
    }

    // MARK: - Dependencies

    private let cloudKitProvider: CloudKitProvider
    private let changeTracker: ChangeTracker
    private let conflictResolver: ConflictResolver
    private let encryptionManager: SyncEncryptionManager
    private let licenseManager: LicenseManager
    private let persistenceController: PersistenceController

    // MARK: - Network Monitoring

    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "com.pasteshelf.sync.network")
    private var isNetworkAvailable = true

    // MARK: - Sync State

    private var syncTask: Task<Void, Never>?
    private var isCurrentlySyncing = false
    private var pendingSync = false
    private var changeToken: CKServerChangeToken?

    // MARK: - Constants

    private static let syncDebounceInterval: TimeInterval = 2.0
    private static let autoSyncInterval: TimeInterval = 300.0 // 5 minutes

    // MARK: - UserDefaults Keys

    private static let enabledKey = "com.pasteshelf.sync.enabled"
    private static let lastSyncKey = "com.pasteshelf.sync.lastSyncDate"
    private static let changeTokenKey = "com.pasteshelf.sync.changeToken"

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "sync-manager"
    )

    // MARK: - Initialization

    init(
        cloudKitProvider: CloudKitProvider = CloudKitProvider(),
        changeTracker: ChangeTracker = ChangeTracker(),
        conflictResolver: ConflictResolver = ConflictResolver(),
        encryptionManager: SyncEncryptionManager = SyncEncryptionManager(),
        licenseManager: LicenseManager = .shared,
        persistenceController: PersistenceController = .shared
    ) {
        self.cloudKitProvider = cloudKitProvider
        self.changeTracker = changeTracker
        self.conflictResolver = conflictResolver
        self.encryptionManager = encryptionManager
        self.licenseManager = licenseManager
        self.persistenceController = persistenceController

        // Load persisted state
        loadPersistedState()

        // Setup network monitoring
        setupNetworkMonitoring()

        // Setup CoreData change observation
        setupCoreDataObservation()
    }

    deinit {
        networkMonitor.cancel()
    }

    // MARK: - SyncManaging Protocol

    public func start() async throws {
        Self.logger.info("Starting sync engine")

        // Check license
        guard licenseManager.isFeatureAvailable(.cloudSync) else {
            Self.logger.warning("Cloud sync requires Pro license")
            status = .error(.licenseRequired)
            throw SyncError.licenseRequired
        }

        // Check iCloud account
        do {
            _ = try await cloudKitProvider.checkAccountStatus()
        } catch let error as SyncError {
            status = .error(error)
            throw error
        }

        // Check network
        guard isNetworkAvailable else {
            status = .offline
            throw SyncError.networkUnavailable
        }

        // Setup CloudKit zone and subscription
        status = .syncing(progress: 0.1)

        do {
            try await cloudKitProvider.setupZone()
            try await cloudKitProvider.subscribeToChanges()
        } catch let error as SyncError {
            status = .error(error)
            throw error
        }

        // Perform initial sync
        try await performSync()

        // Start auto-sync timer
        startAutoSyncTimer()

        Self.logger.info("Sync engine started successfully")
    }

    public func stop() {
        Self.logger.info("Stopping sync engine")

        syncTask?.cancel()
        syncTask = nil
        isCurrentlySyncing = false
        pendingSync = false

        status = .disabled
    }

    public func syncNow() async throws {
        Self.logger.info("Manual sync requested")

        guard isEnabled else {
            throw SyncError.unknown(message: "Sync is not enabled")
        }

        guard !isCurrentlySyncing else {
            pendingSync = true
            return
        }

        try await performSync()
    }

    public func reset() async throws {
        Self.logger.info("Resetting sync state")

        stop()

        // Delete encryption keys
        try encryptionManager.deleteKeys()

        // Clear change tracker
        changeTracker.clearHistoryToken()

        // Clear stored tokens
        UserDefaults.standard.removeObject(forKey: Self.changeTokenKey)
        UserDefaults.standard.removeObject(forKey: Self.lastSyncKey)

        // Reset CloudKit zone (deletes all data)
        try await cloudKitProvider.reset()

        // Mark all local items as pending sync
        try await markAllItemsAsPending()

        Self.logger.info("Sync reset complete")
    }

    // MARK: - Private Sync Operations

    private func performSync() async throws {
        guard !isCurrentlySyncing else {
            pendingSync = true
            return
        }

        isCurrentlySyncing = true
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

        status = .syncing(progress: 0.2)
        Self.logger.info("Starting sync operation")

        do {
            // 1. Pull remote changes first
            status = .syncing(progress: 0.3)
            try await pullRemoteChanges()

            // 2. Push local changes
            status = .syncing(progress: 0.6)
            try await pushLocalChanges()

            // 3. Update sync state
            let now = Date()
            lastSyncDate = now
            UserDefaults.standard.set(now, forKey: Self.lastSyncKey)

            status = .synced(lastSync: now)
            Self.logger.info("Sync completed successfully")
        } catch let error as SyncError {
            status = .error(error)
            throw error
        } catch {
            let syncError = SyncError.unknown(message: error.localizedDescription)
            status = .error(syncError)
            throw syncError
        }
    }

    private func pullRemoteChanges() async throws {
        Self.logger.debug("Pulling remote changes")

        let result = try await cloudKitProvider.pullChanges(since: changeToken)

        if !result.changes.isEmpty {
            try await applyRemoteChanges(result.changes)
        }

        // Save new token
        if let newToken = result.newToken {
            changeToken = newToken
            saveChangeToken(newToken)
        }

        Self.logger.debug("Pulled \(result.changes.count) remote changes")
    }

    private func pushLocalChanges() async throws {
        Self.logger.debug("Pushing local changes")

        // Get pending changes
        let pendingChanges = try await changeTracker.getPendingChanges()

        guard !pendingChanges.isEmpty else {
            Self.logger.debug("No local changes to push")
            return
        }

        // Prepare changes with encrypted data
        let preparedChanges = try await changeTracker.prepareChangesForSync(pendingChanges)

        // Push to CloudKit
        try await cloudKitProvider.pushChanges(preparedChanges)

        // Mark as synced
        try await changeTracker.markAsSynced(preparedChanges)

        Self.logger.debug("Pushed \(preparedChanges.count) local changes")
    }

    private func applyRemoteChanges(_ changes: [SyncChange]) async throws {
        Self.logger.debug("Applying \(changes.count) remote changes")

        let context = persistenceController.newBackgroundContext()

        try await context.perform {
            for change in changes {
                try self.applyChange(change, in: context)
            }

            if context.hasChanges {
                try context.save()
            }
        }
    }

    private func applyChange(_ change: SyncChange, in context: NSManagedObjectContext) throws {
        switch change.changeType {
        case .remoteInsert, .remoteUpdate:
            try applyInsertOrUpdate(change, in: context)
        case .remoteDelete:
            try applyDelete(change, in: context)
        default:
            break
        }
    }

    private func applyInsertOrUpdate(_ change: SyncChange, in context: NSManagedObjectContext) throws {
        guard change.entityType == .clipboardItem,
              let encryptedData = change.encryptedData
        else { return }

        // Decrypt payload
        var decryptedData: Data?
        var decryptError: Error?

        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do {
                decryptedData = try await self.encryptionManager.decrypt(encryptedData)
            } catch {
                decryptError = error
            }
            semaphore.signal()
        }
        semaphore.wait()

        if let error = decryptError {
            throw error
        }

        guard let data = decryptedData else { return }

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
        guard change.entityType == .clipboardItem else { return }

        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", change.entityID as CVarArg)
        request.fetchLimit = 1

        if let item = try context.fetch(request).first {
            context.delete(item)
        }
    }

    // MARK: - Helper Methods

    private func loadPersistedState() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        lastSyncDate = UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date
        changeToken = loadChangeToken()

        if isEnabled {
            status = lastSyncDate.map { .synced(lastSync: $0) } ?? .idle
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
        guard let data = UserDefaults.standard.data(forKey: Self.changeTokenKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private func handleEnabledStateChange() {
        UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)

        if isEnabled {
            Task {
                try? await start()
            }
        } else {
            stop()
        }
    }

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
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
        networkMonitor.start(queue: networkQueue)
    }

    private func setupCoreDataObservation() {
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isEnabled, !self.isCurrentlySyncing else { return }

            // Debounce sync on data changes
            Task {
                try? await Task.sleep(nanoseconds: UInt64(Self.syncDebounceInterval * 1_000_000_000))
                try? await self.syncNow()
            }
        }
    }

    private func startAutoSyncTimer() {
        syncTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.autoSyncInterval * 1_000_000_000))
                guard let self, !Task.isCancelled else { break }
                try? await self.syncNow()
            }
        }
    }

    private func markAllItemsAsPending() async throws {
        let context = persistenceController.newBackgroundContext()

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
