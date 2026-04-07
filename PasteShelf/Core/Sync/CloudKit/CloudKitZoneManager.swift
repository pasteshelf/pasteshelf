//
//  CloudKitZoneManager.swift
//  PasteShelf
//
//  Manages custom CloudKit zone and subscriptions for sync.
//

import CloudKit
import Foundation
import os.log

/// Manages CloudKit zone and subscription setup
final class CloudKitZoneManager: Sendable {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(container: CKContainer = CKContainer(identifier: "iCloud.com.pasteshelf.PasteShelf")) {
        self.database = container.privateCloudDatabase
        self.zone = CKRecordZone(zoneName: Self.zoneName)
    }

    // MARK: Internal

    // MARK: - Constants

    /// Custom zone name for PasteShelf data
    static let zoneName = "com.pasteshelf.clipboardHistory"

    /// Subscription ID for remote change notifications
    static let subscriptionID = "com.pasteshelf.sync-subscription"

    /// The custom record zone
    let zone: CKRecordZone

    /// Zone ID for convenience
    var zoneID: CKRecordZone.ID {
        self.zone.zoneID
    }

    // MARK: - Zone Management

    /// Create the custom zone if it doesn't exist
    func createZoneIfNeeded() async throws {
        Self.logger.info("Checking if zone exists: \(Self.zoneName)")

        do {
            // Try to fetch the zone
            _ = try await self.database.recordZone(for: self.zoneID)
            Self.logger.info("Zone already exists")
        } catch let error as CKError where error.code == .zoneNotFound {
            // Zone doesn't exist, create it
            Self.logger.info("Creating new zone: \(Self.zoneName)")
            try await self.createZone()
        } catch {
            Self.logger.error("Failed to check zone: \(error.localizedDescription)")
            throw SyncError.from(error as? CKError ?? CKError(.serverRejectedRequest))
        }
    }

    /// Delete the custom zone (for reset functionality)
    func deleteZone() async throws {
        Self.logger.info("Deleting zone: \(Self.zoneName)")

        let operation = CKModifyRecordZonesOperation(
            recordZonesToSave: nil,
            recordZoneIDsToDelete: [zoneID]
        )

        operation.qualityOfService = .userInitiated

        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordZonesResultBlock = { result in
                switch result {
                case .success:
                    Self.logger.info("Zone deleted successfully")
                    continuation.resume()
                case let .failure(error):
                    Self.logger.error("Failed to delete zone: \(error.localizedDescription)")
                    let syncError = SyncError.from(error as? CKError ?? CKError(.serverRejectedRequest))
                    continuation.resume(throwing: syncError)
                }
            }

            self.database.add(operation)
        }
    }

    // MARK: - Subscription Management

    /// Create subscription for remote change notifications
    func createSubscriptionIfNeeded() async throws {
        Self.logger.info("Setting up subscription for zone changes")

        // Check if subscription already exists
        do {
            _ = try await self.database.subscription(for: Self.subscriptionID)
            Self.logger.info("Subscription already exists")
            return
        } catch let error as CKError where error.code == .unknownItem {
            // Subscription doesn't exist, create it
            Self.logger.info("Creating new subscription")
        } catch {
            Self.logger.warning("Failed to check subscription: \(error.localizedDescription)")
            // Try to create anyway
        }

        // Create subscription for all record changes in our zone
        let subscription = CKRecordZoneSubscription(
            zoneID: zoneID,
            subscriptionID: Self.subscriptionID
        )

        // Configure notification
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // Silent push

        subscription.notificationInfo = notificationInfo

        try await self.saveSubscription(subscription)
    }

    /// Delete the subscription
    func deleteSubscription() async throws {
        Self.logger.info("Deleting subscription")

        let operation = CKModifySubscriptionsOperation(
            subscriptionsToSave: nil,
            subscriptionIDsToDelete: [Self.subscriptionID]
        )

        operation.qualityOfService = .userInitiated

        return try await withCheckedThrowingContinuation { continuation in
            operation.modifySubscriptionsResultBlock = { result in
                switch result {
                case .success:
                    Self.logger.info("Subscription deleted successfully")
                    continuation.resume()
                case let .failure(error):
                    // Ignore if subscription doesn't exist
                    if let ckError = error as? CKError, ckError.code == .unknownItem {
                        Self.logger.info("Subscription didn't exist")
                        continuation.resume()
                    } else {
                        Self.logger.error("Failed to delete subscription: \(error.localizedDescription)")
                        let syncError = SyncError.from(error as? CKError ?? CKError(.serverRejectedRequest))
                        continuation.resume(throwing: syncError)
                    }
                }
            }

            self.database.add(operation)
        }
    }

    // MARK: - Setup

    /// Complete zone and subscription setup
    func setup() async throws {
        try await self.createZoneIfNeeded()
        try await self.createSubscriptionIfNeeded()
        Self.logger.info("CloudKit zone setup complete")
    }

    /// Complete teardown (for reset)
    func teardown() async throws {
        try await self.deleteSubscription()
        try await self.deleteZone()
        Self.logger.info("CloudKit zone teardown complete")
    }

    // MARK: Private

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "cloudkit-zone"
    )

    /// Private database reference
    private let database: CKDatabase

    /// Create the custom zone
    private func createZone() async throws {
        let operation = CKModifyRecordZonesOperation(
            recordZonesToSave: [zone],
            recordZoneIDsToDelete: nil
        )

        operation.qualityOfService = .userInitiated

        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordZonesResultBlock = { result in
                switch result {
                case .success:
                    Self.logger.info("Zone created successfully")
                    continuation.resume()
                case let .failure(error):
                    Self.logger.error("Failed to create zone: \(error.localizedDescription)")
                    let syncError = SyncError.from(error as? CKError ?? CKError(.serverRejectedRequest))
                    continuation.resume(throwing: syncError)
                }
            }

            self.database.add(operation)
        }
    }

    /// Save a subscription to CloudKit
    private func saveSubscription(_ subscription: CKSubscription) async throws {
        let operation = CKModifySubscriptionsOperation(
            subscriptionsToSave: [subscription],
            subscriptionIDsToDelete: nil
        )

        operation.qualityOfService = .userInitiated

        return try await withCheckedThrowingContinuation { continuation in
            operation.modifySubscriptionsResultBlock = { result in
                switch result {
                case .success:
                    Self.logger.info("Subscription created successfully")
                    continuation.resume()
                case let .failure(error):
                    Self.logger.error("Failed to create subscription: \(error.localizedDescription)")
                    let syncError = SyncError.from(error as? CKError ?? CKError(.serverRejectedRequest))
                    continuation.resume(throwing: syncError)
                }
            }

            self.database.add(operation)
        }
    }
}
