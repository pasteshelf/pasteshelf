//
//  AuditRetentionService.swift
//  PasteShelf
//
//  Schedules and executes periodic pruning of expired audit log entries.
//

import Foundation
import os.log

// MARK: - AuditRetentionService

/// Drives scheduled pruning of audit log entries that exceed the configured retention window.
///
/// `AuditRetentionService` uses a daily `Timer` to check whether 24 hours have elapsed
/// since the last cleanup pass. When the threshold is met, it calls
/// `storage.pruneExpired(retentionDays:)` to delete stale entries and records the
/// completion timestamp in `UserDefaults` so that the schedule survives application
/// restarts.
///
/// A manual `runNow()` entry point is provided for immediate pruning on demand (e.g.
/// when the retention policy is changed by the administrator).
final class AuditRetentionService {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates an `AuditRetentionService` with the given storage backend and retention configuration.
    ///
    /// - Parameters:
    ///   - storage: The `AuditLogStoring` implementation used to prune expired entries.
    ///   - configuration: The retention policy specifying the number of days to keep entries.
    ///     Defaults to `AuditRetentionConfiguration.default` (90 days).
    init(
        storage: AuditLogStoring,
        configuration: AuditRetentionConfiguration = .default
    ) {
        self.storage = storage
        self.configuration = configuration
    }

    // MARK: Internal

    /// Starts the daily cleanup timer.
    ///
    /// The timer fires every 24 hours and triggers a pruning pass if at least 24 hours
    /// have elapsed since the last successful cleanup. If more than 24 hours have passed
    /// since the last cleanup (or if no cleanup has ever been recorded), a pass is
    /// triggered immediately on the first timer fire.
    func start() {
        self.stop()
        self.cleanupTimer = Timer.scheduledTimer(
            withTimeInterval: Self.cleanupInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self else {
                return
            }
            self.logger.debug("Audit retention timer fired — checking for expired entries")
            Task {
                _ = await self.runIfDue()
            }
        }
        self.logger.info("Audit retention service started (retentionDays: \(self.configuration.retentionDays))")

        // Run an initial check at startup without waiting for the first timer fire.
        Task {
            _ = await self.runIfDue()
        }
    }

    /// Stops the daily cleanup timer.
    ///
    /// After calling this method, no further automatic pruning passes are scheduled
    /// until `start()` is called again.
    func stop() {
        self.cleanupTimer?.invalidate()
        self.cleanupTimer = nil
        self.logger.debug("Audit retention service stopped")
    }

    /// Updates the retention configuration used for future pruning passes.
    ///
    /// The change takes effect on the next scheduled or manual pruning pass. Call `runNow()`
    /// after this method if an immediate pruning pass with the new window is required.
    ///
    /// - Parameter newConfiguration: The replacement retention policy.
    func updateConfiguration(_ newConfiguration: AuditRetentionConfiguration) {
        self.configuration = newConfiguration
        self.logger
            .info(
                // swiftlint:disable:next line_length
                "Audit retention configuration updated to \(newConfiguration.retentionDays) days (immutable: \(newConfiguration.isImmutable))"
            )
    }

    /// Immediately prunes expired audit log entries, regardless of the regular schedule.
    ///
    /// Updates the `UserDefaults` last-cleanup timestamp upon successful completion.
    ///
    /// - Returns: The number of entries that were pruned, or `0` if pruning failed.
    @discardableResult
    func runNow() async -> Int {
        guard !self.configuration.isImmutable else {
            self.logger.info("Audit retention: pruning skipped — immutable retention policy active (HIPAA)")
            return 0
        }
        self.logger
            .info("Audit retention: running manual pruning pass (retentionDays: \(self.configuration.retentionDays))")
        do {
            let count = try await storage.pruneExpired(retentionDays: self.configuration.retentionDays)
            UserDefaults.standard.set(Date(), forKey: Self.lastCleanupKey)
            self.logger.info("Audit retention: pruned \(count) expired entries")
            return count
        } catch {
            self.logger.error("Audit retention: pruning failed — \(error.localizedDescription)")
            return 0
        }
    }

    // MARK: Private

    // MARK: - Constants

    /// `UserDefaults` key used to persist the timestamp of the last successful cleanup pass.
    private static let lastCleanupKey = "com.pasteshelf.audit.lastRetentionCleanup"

    /// The minimum interval between successive cleanup passes (24 hours).
    private static let cleanupInterval: TimeInterval = 24 * 60 * 60

    // MARK: - Dependencies

    private let storage: AuditLogStoring
    private var configuration: AuditRetentionConfiguration

    // MARK: - Timer State

    private var cleanupTimer: Timer?

    // MARK: - Logger

    private let logger = Logger.audit

    // MARK: - Private Helpers

    /// Runs a pruning pass only if 24 hours have elapsed since the last cleanup.
    ///
    /// - Returns: The number of entries pruned, or `0` if the cleanup was skipped.
    @discardableResult
    private func runIfDue() async -> Int {
        let lastCleanup = UserDefaults.standard.object(forKey: Self.lastCleanupKey) as? Date
        let isDue: Bool = if let lastCleanup {
            Date().timeIntervalSince(lastCleanup) >= Self.cleanupInterval
        } else {
            true // Never cleaned up before
        }

        guard isDue else {
            self.logger.debug("Audit retention: cleanup not yet due — skipping")
            return 0
        }

        return await self.runNow()
    }
}
