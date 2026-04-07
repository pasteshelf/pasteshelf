//
//  NetworkMonitor.swift
//  PasteShelf
//
//  Monitors network connectivity and queues sync operations when offline.
//

import Combine
import Foundation
import Network
import os.log

// MARK: - NetworkMonitor

/// Monitors network connectivity for sync operations
@MainActor
final class NetworkMonitor: ObservableObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    init() {
        self.monitor = NWPathMonitor()
        self.loadQueuedChanges()
        self.startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    // MARK: Internal

    // MARK: - Published Properties

    /// Whether network is currently available
    @Published private(set) var isConnected: Bool = true

    /// Current network interface type
    @Published private(set) var interfaceType: NWInterface.InterfaceType?

    /// Whether the device is on an expensive network (cellular)
    @Published private(set) var isExpensive: Bool = false

    /// Whether the device is on a constrained network (low data mode)
    @Published private(set) var isConstrained: Bool = false

    // MARK: - Queued Changes

    /// Changes queued while offline
    @Published private(set) var queuedChanges: [SyncChange] = []

    // MARK: - Change Queue Management

    /// Queue a change to be synced when network is restored
    func queueChange(_ change: SyncChange) {
        guard self.queuedChanges.count < Self.maxQueueSize else {
            Self.logger.warning("Queue full, dropping change for \(change.entityID)")
            return
        }

        // Avoid duplicates
        if !self.queuedChanges.contains(where: { $0.entityID == change.entityID }) {
            self.queuedChanges.append(change)
            self.saveQueuedChanges()
            Self.logger.debug("Queued change for \(change.entityID), queue size: \(self.queuedChanges.count)")
        }
    }

    /// Get and clear queued changes
    func dequeueChanges() -> [SyncChange] {
        let changes = self.queuedChanges
        self.queuedChanges.removeAll()
        self.saveQueuedChanges()
        return changes
    }

    /// Clear all queued changes
    func clearQueue() {
        self.queuedChanges.removeAll()
        self.saveQueuedChanges()
    }

    // MARK: Private

    /// Maximum number of changes to queue
    private static let maxQueueSize = 1000

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pasteshelf",
        category: "network-monitor"
    )

    // MARK: - UserDefaults Keys

    private static let queuedChangesKey = "com.pasteshelf.sync.queuedChanges"

    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.pasteshelf.network-monitor")

    // MARK: - Monitoring

    private func startMonitoring() {
        self.monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        self.monitor.start(queue: self.monitorQueue)
    }

    private func handlePathUpdate(_ path: NWPath) {
        let wasConnected = self.isConnected
        let newConnected = path.status == .satisfied

        self.isConnected = newConnected
        self.isExpensive = path.isExpensive
        self.isConstrained = path.isConstrained

        // Determine interface type
        if path.usesInterfaceType(.wifi) {
            self.interfaceType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            self.interfaceType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            self.interfaceType = .wiredEthernet
        } else {
            self.interfaceType = nil
        }

        Self.logger
            .debug(
                // swiftlint:disable:next line_length
                "Network status: connected=\(newConnected), expensive=\(path.isExpensive), constrained=\(path.isConstrained)"
            )

        // Handle connectivity change
        if !wasConnected, newConnected {
            self.handleNetworkRestored()
        } else if wasConnected, !newConnected {
            self.handleNetworkLost()
        }
    }

    // MARK: - Event Handlers

    private func handleNetworkRestored() {
        Self.logger.info("Network restored")

        // Post notification for SyncManager
        NotificationCenter.default.post(name: .networkRestored, object: nil)

        // Process queued changes will be handled by SyncManager
    }

    private func handleNetworkLost() {
        Self.logger.info("Network lost")

        // Post notification for SyncManager
        NotificationCenter.default.post(name: .networkLost, object: nil)
    }

    // MARK: - Persistence

    private func loadQueuedChanges() {
        guard let data = UserDefaults.standard.data(forKey: Self.queuedChangesKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.queuedChanges = try decoder.decode([SyncChange].self, from: data)
            Self.logger.debug("Loaded \(self.queuedChanges.count) queued changes")
        } catch {
            Self.logger.error("Failed to load queued changes: \(error.localizedDescription)")
        }
    }

    private func saveQueuedChanges() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(self.queuedChanges)
            UserDefaults.standard.set(data, forKey: Self.queuedChangesKey)
        } catch {
            Self.logger.error("Failed to save queued changes: \(error.localizedDescription)")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when network connectivity is restored
    static let networkRestored = Notification.Name("networkRestored")

    /// Posted when network connectivity is lost
    static let networkLost = Notification.Name("networkLost")
}

// MARK: - Network Status Extension

extension NetworkMonitor {
    /// Human-readable description of current network status
    var statusDescription: String {
        guard self.isConnected else {
            return "Offline"
        }

        var description = "Online"

        if let type = interfaceType {
            switch type {
            case .wifi:
                description += " (Wi-Fi)"
            case .cellular:
                description += " (Cellular)"
            case .wiredEthernet:
                description += " (Ethernet)"
            default:
                break
            }
        }

        if self.isConstrained {
            description += " - Low Data Mode"
        }

        return description
    }

    /// Whether sync should proceed based on network conditions
    var shouldSync: Bool {
        // Always sync if connected
        // In the future, we could add settings to skip sync on expensive/constrained networks
        self.isConnected
    }
}
