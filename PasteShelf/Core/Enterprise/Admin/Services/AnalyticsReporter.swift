//
//  AnalyticsReporter.swift
//  PasteShelf
//
//  Batches and submits analytics events to the admin console.
//  Events are flushed when the batch size threshold is reached or the auto-flush timer fires.
//

import Foundation
import os.log

// MARK: - AnalyticsReporter

/// Batches and submits analytics events to the admin console.
///
/// Events are accumulated in memory and flushed to the server either when the
/// batch size threshold is reached or when the auto-flush timer fires. This
/// reduces network overhead and improves reliability on intermittent connections.
final class AnalyticsReporter {

    // MARK: - Properties

    private let apiClient: AdminAPIProviding
    private var pendingEvents: [AdminAnalyticsEvent] = []
    private var flushTimer: Timer?
    private let batchSize: Int
    private let flushInterval: TimeInterval
    private let logger = Logger(subsystem: "com.pasteshelf", category: "analytics")
    private let lock = NSLock()

    // MARK: - Initialization

    /// Creates an `AnalyticsReporter`.
    ///
    /// - Parameters:
    ///   - apiClient: The admin console API client used to submit event batches.
    ///   - batchSize: The maximum number of events to accumulate before triggering an
    ///     automatic flush. Defaults to `50`.
    ///   - flushInterval: The number of seconds between successive auto-flush timer
    ///     firings. Defaults to `60`.
    init(
        apiClient: AdminAPIProviding,
        batchSize: Int = 50,
        flushInterval: TimeInterval = 60
    ) {
        self.apiClient = apiClient
        self.batchSize = batchSize
        self.flushInterval = flushInterval
    }

    // MARK: - Tracking

    /// Enqueues an analytics event.
    ///
    /// The event is appended to the in-memory pending queue in a thread-safe manner.
    /// When the queue reaches `batchSize`, an asynchronous flush is triggered
    /// automatically to avoid accumulating an unbounded backlog.
    ///
    /// - Parameters:
    ///   - eventType: The category of action or state change to record.
    ///   - deviceId: The server-assigned identifier of the device generating the event.
    ///   - userId: The SSO user ID associated with the event, if a session is active.
    ///     Pass `nil` for system-level events that are not tied to a specific user.
    ///   - metadata: Arbitrary key/value pairs providing event-specific context.
    func track(
        _ eventType: AdminAnalyticsEventType,
        deviceId: String,
        userId: String? = nil,
        metadata: [String: String] = [:]
    ) {
        let event = AdminAnalyticsEvent(
            deviceId: deviceId,
            userId: userId,
            eventType: eventType,
            metadata: metadata
        )

        lock.lock()
        pendingEvents.append(event)
        let shouldFlush = pendingEvents.count >= batchSize
        lock.unlock()

        logger.debug("Tracked event '\(eventType.rawValue)' for device '\(deviceId)'. Pending: \(self.pendingCount).")

        if shouldFlush {
            logger.info("Batch size threshold reached (\(self.batchSize)). Triggering async flush.")
            Task {
                do {
                    try await flush()
                } catch {
                    logger.error("Auto-flush after batch threshold failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Flushing

    /// Flushes all pending events to the admin console server.
    ///
    /// Pending events are atomically extracted from the in-memory queue before the
    /// network call so that new events may continue to be tracked concurrently. If
    /// submission fails, the events are re-inserted at the front of the queue on a
    /// best-effort basis, preserving their relative ordering for the next flush attempt.
    ///
    /// - Throws: `AdminError.networkError` on transport failure, or
    ///   `AdminError.serverError` if the server returns a non-success status code.
    func flush() async throws {
        lock.lock()
        guard !pendingEvents.isEmpty else {
            lock.unlock()
            logger.debug("Flush called with no pending events — skipping.")
            return
        }
        let eventsToSubmit = pendingEvents
        pendingEvents = []
        lock.unlock()

        logger.info("Flushing \(eventsToSubmit.count) analytics event(s) to admin console.")

        do {
            try await apiClient.submitAnalyticsEvents(eventsToSubmit)
            logger.info("Successfully submitted \(eventsToSubmit.count) analytics event(s).")
        } catch {
            logger.error("Failed to submit analytics events: \(error.localizedDescription). Re-queuing \(eventsToSubmit.count) event(s).")
            // Restore events to the front of the pending queue (best effort).
            lock.lock()
            pendingEvents = eventsToSubmit + pendingEvents
            lock.unlock()
            throw error
        }
    }

    // MARK: - Auto-Flush Timer

    /// Starts the periodic auto-flush timer on the main run loop.
    ///
    /// Any previously running timer is stopped before the new one is created.
    /// The timer fires every `flushInterval` seconds and submits all accumulated
    /// events to the admin console asynchronously.
    func startAutoFlush() {
        stopAutoFlush()
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.logger.debug("Auto-flush timer fired.")
            Task {
                do {
                    try await self.flush()
                } catch {
                    self.logger.error("Scheduled auto-flush failed: \(error.localizedDescription)")
                }
            }
        }
        logger.info("Auto-flush timer started with interval \(self.flushInterval)s.")
    }

    /// Stops the periodic auto-flush timer.
    ///
    /// After calling this method no further automatic flushes occur until
    /// `startAutoFlush()` is called again. In-flight flushes are not affected.
    func stopAutoFlush() {
        flushTimer?.invalidate()
        flushTimer = nil
        logger.debug("Auto-flush timer stopped.")
    }

    // MARK: - Accessors

    /// The number of events currently waiting to be flushed to the admin console.
    var pendingCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pendingEvents.count
    }
}
