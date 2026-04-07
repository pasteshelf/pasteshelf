//
//  AccountChangeHandler.swift
//  PasteShelf
//
//  Monitors iCloud account changes and handles sync state transitions.
//

import CloudKit
import Combine
import Foundation
import os.log

// MARK: - AccountChangeHandler

/// Handles iCloud account status changes and triggers appropriate sync actions
@MainActor
final class AccountChangeHandler: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        container: CKContainer = CKContainer(identifier: "iCloud.com.pasteshelf.PasteShelf"),
        syncManager: SyncManager? = nil
    ) {
        self.container = container
        self.syncManager = syncManager

        self.setupAccountChangeNotification()
        self.checkAccountStatus()
    }

    deinit {
        accountStatusTask?.cancel()
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: Internal

    // MARK: - Published Properties

    @Published private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published private(set) var currentUserID: String?

    // MARK: - Account Status

    /// Check current iCloud account status
    func checkAccountStatus() {
        self.accountStatusTask?.cancel()
        self.accountStatusTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let status = try await container.accountStatus()
                await MainActor.run {
                    self.updateAccountStatus(status)
                }
            } catch {
                Self.logger.error("Failed to check account status: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - First Sync Detection

    /// Check if this is the first time syncing on this device
    func isFirstSync() -> Bool {
        // No change token and no stored user ID indicates first sync
        let hasToken = UserDefaults.standard.data(forKey: "com.pasteshelf.sync.changeToken") != nil
        let hasUserID = UserDefaults.standard.string(forKey: Self.lastUserIDKey) != nil

        return !hasToken || !hasUserID
    }

    /// Check if this is a new device joining existing sync
    func isNewDeviceJoiningSync() async -> Bool {
        // New device if:
        // 1. No local change token
        // 2. But zone already exists in CloudKit

        let hasLocalToken = UserDefaults.standard.data(forKey: "com.pasteshelf.sync.changeToken") != nil

        if hasLocalToken {
            return false
        }

        // Check if zone exists
        let zoneManager = CloudKitZoneManager(container: container)
        do {
            // Try to fetch zone - if it exists, this is a new device
            _ = try await self.container.privateCloudDatabase.recordZone(for: zoneManager.zoneID)
            return true
        } catch {
            return false // Zone doesn't exist, this is first device
        }
    }

    // MARK: Private

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "account-handler"
    )

    // MARK: - UserDefaults Keys

    private static let lastUserIDKey = "com.pasteshelf.sync.lastUserID"

    private let container: CKContainer
    private weak var syncManager: SyncManager?

    private var accountStatusTask: Task<Void, Never>?
    private var notificationObserver: NSObjectProtocol?

    // MARK: - Setup

    private func setupAccountChangeNotification() {
        // Observe iCloud account changes
        self.notificationObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Self.logger.info("iCloud account change notification received")
            self?.handleAccountChange()
        }
    }

    /// Update account status and handle changes
    private func updateAccountStatus(_ status: CKAccountStatus) {
        let previousStatus = self.accountStatus
        self.accountStatus = status

        Self.logger.info("Account status updated: \(String(describing: status))")

        // Handle status changes
        if previousStatus != status {
            self.handleStatusChange(from: previousStatus, to: status)
        }

        // If available, fetch user ID
        if status == .available {
            self.fetchCurrentUserID()
        } else {
            self.currentUserID = nil
        }
    }

    /// Handle account change notification
    private func handleAccountChange() {
        Task {
            // Small delay to let CloudKit settle
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            self.checkAccountStatus()
        }
    }

    /// Handle status change transitions
    private func handleStatusChange(from previousStatus: CKAccountStatus, to newStatus: CKAccountStatus) {
        switch (previousStatus, newStatus) {
        case (_, .available):
            // Account became available
            Self.logger.info("iCloud account became available")
            self.handleAccountAvailable()

        case (.available, .noAccount):
            // User signed out
            Self.logger.info("User signed out of iCloud")
            self.handleAccountSignedOut()

        case (.available, .restricted):
            // Account became restricted
            Self.logger.warning("iCloud account became restricted")
            self.handleAccountRestricted()

        case (_, .temporarilyUnavailable):
            // Account temporarily unavailable
            Self.logger.info("iCloud account temporarily unavailable")
            self.handleAccountTemporarilyUnavailable()

        default:
            break
        }
    }

    // MARK: - User ID Management

    /// Fetch the current user's record ID
    private func fetchCurrentUserID() {
        Task {
            do {
                let recordID = try await container.userRecordID()
                let userID = recordID.recordName

                await MainActor.run {
                    self.handleUserIDChange(newUserID: userID)
                }
            } catch {
                Self.logger.warning("Failed to fetch user record ID: \(error.localizedDescription)")
            }
        }
    }

    /// Handle user ID change (account switch)
    private func handleUserIDChange(newUserID: String) {
        let previousUserID = UserDefaults.standard.string(forKey: Self.lastUserIDKey)

        if let previousUserID, previousUserID != newUserID {
            // Different user - account switch detected!
            Self.logger
                .warning("iCloud account switch detected: \(previousUserID.prefix(8))... -> \(newUserID.prefix(8))...")
            self.handleAccountSwitch(from: previousUserID, to: newUserID)
        }

        // Save current user ID
        self.currentUserID = newUserID
        UserDefaults.standard.set(newUserID, forKey: Self.lastUserIDKey)
    }

    // MARK: - Event Handlers

    /// Handle account becoming available
    private func handleAccountAvailable() {
        guard let syncManager, syncManager.isEnabled else {
            return
        }

        Task {
            do {
                try await syncManager.start()
            } catch {
                Self.logger.error("Failed to start sync after account became available: \(error.localizedDescription)")
            }
        }
    }

    /// Handle user signing out of iCloud
    private func handleAccountSignedOut() {
        self.syncManager?.stop()

        // Clear the stored user ID
        UserDefaults.standard.removeObject(forKey: Self.lastUserIDKey)
        self.currentUserID = nil
    }

    /// Handle account becoming restricted
    private func handleAccountRestricted() {
        self.syncManager?.stop()
    }

    /// Handle account temporarily unavailable
    private func handleAccountTemporarilyUnavailable() {
        // Don't stop sync, just update status
        // SyncManager will handle this via its status
    }

    /// Handle account switch (different user signed in)
    private func handleAccountSwitch(from _: String, to _: String) {
        guard let syncManager else {
            return
        }

        Self.logger.warning("Account switch requires sync reset")

        // Stop sync
        syncManager.stop()

        // The user should be prompted to reset sync
        // This will be handled by the UI layer observing this handler

        // Post notification for UI to handle
        NotificationCenter.default.post(
            name: .iCloudAccountSwitched,
            object: nil,
            userInfo: nil
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when iCloud account is switched to a different user
    static let iCloudAccountSwitched = Notification.Name("iCloudAccountSwitched")
}
