//
//  AutoCleanupManager.swift
//  PasteShelf
//
//  Manages automatic cleanup of old clipboard items based on user preferences.
//  Runs periodic cleanup tasks in the background.
//

import Combine
import Foundation
import os.log

/// Manages automatic cleanup of old clipboard items
@MainActor
final class AutoCleanupManager: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    private init(
        storageManager: StorageManager = .shared,
        settingsManager: SettingsManager = .shared
    ) {
        self.storageManager = storageManager
        self.settingsManager = settingsManager

        self.loadLastCleanupDate()
        self.setupSettingsObserver()
    }

    // MARK: Internal

    // MARK: - Singleton

    /// Shared instance
    static let shared = AutoCleanupManager()

    /// Whether cleanup is currently running
    @Published private(set) var isRunning = false

    /// Last cleanup date
    @Published private(set) var lastCleanupDate: Date?

    /// Number of items deleted in last cleanup
    @Published private(set) var lastCleanupCount: Int = 0

    // MARK: - Public Methods

    /// Starts the auto-cleanup scheduler
    func start() {
        guard self.settingsManager.privacy.autoDeleteEnabled else {
            self.logger.debug("Auto-cleanup disabled, not starting")
            return
        }

        self.scheduleCleanup()
        self.logger.info("Auto-cleanup manager started")
    }

    /// Stops the auto-cleanup scheduler
    func stop() {
        self.stopScheduledCleanup()
        self.logger.info("Auto-cleanup manager stopped")
    }

    /// Triggers an immediate cleanup
    func runCleanupNow() async {
        await self.performCleanup()
    }

    // MARK: Private

    // MARK: - Private Properties

    private let storageManager: StorageManager
    private let settingsManager: SettingsManager
    private var cleanupTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "auto-cleanup"
    )

    // MARK: - Configuration

    /// Cleanup interval (daily)
    private let cleanupInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    /// Key for storing last cleanup date
    private let lastCleanupKey = "com.pasteshelf.lastAutoCleanup"

    // MARK: - Setup

    private func setupSettingsObserver() {
        // Observe settings changes
        self.settingsManager.$settings
            .dropFirst()
            .sink { [weak self] settings in
                if settings.privacy.autoDeleteEnabled {
                    self?.scheduleCleanup()
                } else {
                    self?.stopScheduledCleanup()
                }
            }
            .store(in: &self.cancellables)
    }

    // MARK: - Scheduling

    private func scheduleCleanup() {
        self.stopScheduledCleanup()

        // Check if cleanup is needed immediately
        if self.shouldRunCleanup() {
            Task {
                await self.performCleanup()
            }
        }

        // Schedule periodic cleanup
        self.cleanupTimer = Timer.scheduledTimer(
            withTimeInterval: self.cleanupInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.performCleanup()
            }
        }

        // Ensure timer runs in common run loop mode
        if let timer = cleanupTimer {
            RunLoop.main.add(timer, forMode: .common)
        }

        self.logger.debug("Cleanup scheduled (interval: \(self.cleanupInterval)s)")
    }

    private func stopScheduledCleanup() {
        self.cleanupTimer?.invalidate()
        self.cleanupTimer = nil
    }

    private func shouldRunCleanup() -> Bool {
        guard let lastDate = lastCleanupDate else {
            return true
        }

        let timeSinceLastCleanup = Date().timeIntervalSince(lastDate)
        return timeSinceLastCleanup >= self.cleanupInterval
    }

    // MARK: - Cleanup

    private func performCleanup() async {
        guard !self.isRunning else {
            self.logger.debug("Cleanup already in progress, skipping")
            return
        }

        guard self.settingsManager.privacy.autoDeleteEnabled else {
            self.logger.debug("Auto-cleanup disabled, skipping")
            return
        }

        self.isRunning = true
        defer { isRunning = false }

        self.logger.info("Starting auto-cleanup")

        var totalDeleted = 0

        // Delete items older than the configured number of days
        let daysToKeep = self.settingsManager.privacy.autoDeleteDays
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -daysToKeep,
            to: Date()
        ) ?? Date()

        let dateDeletedCount = await storageManager.deleteItems(
            olderThan: cutoffDate,
            keepFavorites: true
        )
        totalDeleted += dateDeletedCount

        // Also enforce history limit
        if let limit = settingsManager.general.historyLimit.limit {
            let limitDeletedCount = await storageManager.deleteItemsExceedingLimit(
                limit,
                keepFavorites: true
            )
            totalDeleted += limitDeletedCount
        }

        // Update state
        self.lastCleanupDate = Date()
        self.lastCleanupCount = totalDeleted
        self.saveLastCleanupDate()

        if totalDeleted > 0 {
            NotificationCenter.default.post(name: .clipboardHistoryChanged, object: nil)
        }

        self.logger.info("Auto-cleanup completed: \(totalDeleted) items deleted")
    }

    // MARK: - Persistence

    private func loadLastCleanupDate() {
        if let timestamp = UserDefaults.standard.object(forKey: lastCleanupKey) as? Date {
            self.lastCleanupDate = timestamp
        }
    }

    private func saveLastCleanupDate() {
        UserDefaults.standard.set(self.lastCleanupDate, forKey: self.lastCleanupKey)
    }
}
