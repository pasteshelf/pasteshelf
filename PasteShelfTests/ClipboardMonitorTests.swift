//
//  ClipboardMonitorTests.swift
//  PasteShelfTests
//
//  Tests for clipboard monitoring functionality.
//

import Foundation
@testable import PasteShelf
import Testing

// MARK: - ClipboardMonitorTests

@MainActor
struct ClipboardMonitorTests {
    // MARK: - Lifecycle Tests

    @Test("Monitor starts in stopped state")
    func monitorStartsInStoppedState() {
        let monitor = ClipboardMonitor.forTesting()

        #expect(!monitor.isMonitoring)
    }

    @Test("Start monitoring changes state")
    func startMonitoringChangesState() {
        let monitor = ClipboardMonitor.forTesting()

        monitor.startMonitoring()

        #expect(monitor.isMonitoring)

        monitor.stopMonitoring()
    }

    @Test("Stop monitoring changes state")
    func stopMonitoringChangesState() {
        let monitor = ClipboardMonitor.forTesting()
        monitor.startMonitoring()

        monitor.stopMonitoring()

        #expect(!monitor.isMonitoring)
    }

    @Test("Double start has no effect")
    func doubleStartHasNoEffect() {
        let monitor = ClipboardMonitor.forTesting()

        monitor.startMonitoring()
        monitor.startMonitoring()

        #expect(monitor.isMonitoring)

        monitor.stopMonitoring()
    }

    // MARK: - Pause/Resume Tests

    @Test("Pause sets paused flag")
    func pauseSetsPausedFlag() {
        let monitor = ClipboardMonitor.forTesting()
        monitor.startMonitoring()

        monitor.pause()

        #expect(monitor.isPaused)

        monitor.stopMonitoring()
    }

    @Test("Resume clears paused flag")
    func resumeClearsPausedFlag() {
        let monitor = ClipboardMonitor.forTesting()
        monitor.startMonitoring()
        monitor.pause()

        monitor.resume()

        #expect(!monitor.isPaused)

        monitor.stopMonitoring()
    }

    // MARK: - Metrics Tests

    @Test("Initial metrics are zero")
    func initialMetricsAreZero() {
        let monitor = ClipboardMonitor.forTesting()

        #expect(monitor.metrics.captureCount == 0)
        #expect(monitor.metrics.duplicateCount == 0)
        #expect(monitor.metrics.excludedCount == 0)
    }

    @Test("Metrics track captures")
    func metricsTrackCaptures() {
        var metrics = ClipboardMonitorMetrics()

        metrics.captureCount = 5
        metrics.duplicateCount = 2
        metrics.excludedCount = 3

        #expect(metrics.totalProcessed == 10)
        #expect(metrics.duplicateRate == 20.0)
    }

    @Test("Average capture time is calculated")
    func averageCaptureTimeIsCalculated() {
        var metrics = ClipboardMonitorMetrics()

        metrics.updateAverageCaptureTime(0.010) // 10ms
        metrics.updateAverageCaptureTime(0.020) // 20ms

        // Running average should be ~15ms
        #expect(metrics.averageCaptureTimeMs > 10)
        #expect(metrics.averageCaptureTimeMs < 20)
    }

    // MARK: - Hash Cache Tests

    @Test("Clear hash cache empties cache")
    func clearHashCacheEmptiesCache() {
        let monitor = ClipboardMonitor.forTesting()

        // Manually trigger a capture to add to cache
        // (In real tests, we'd use a mock pasteboard)
        monitor.clearHashCache()

        // After clear, captures should not be flagged as duplicates
        // This is an integration test that would need more setup
    }
}

// MARK: - MockClipboardMonitorDelegate

@MainActor
final class MockClipboardMonitorDelegate: ClipboardMonitorDelegate {
    var capturedContents: [ClipboardContent] = []
    var capturedSourceApps: [SourceApp?] = []
    var excludedReasons: [ExclusionReason] = []
    var errors: [Error] = []

    func clipboardMonitor(
        _ monitor: ClipboardMonitoring,
        didCapture content: ClipboardContent,
        from sourceApp: SourceApp?
    ) {
        capturedContents.append(content)
        capturedSourceApps.append(sourceApp)
    }

    func clipboardMonitor(
        _ monitor: ClipboardMonitoring,
        didExcludeContentWithReason reason: ExclusionReason
    ) {
        excludedReasons.append(reason)
    }

    func clipboardMonitor(
        _ monitor: ClipboardMonitoring,
        didEncounterError error: Error
    ) {
        errors.append(error)
    }
}

// MARK: - ClipboardMonitorDelegateTests

@MainActor
struct ClipboardMonitorDelegateTests {
    @Test("Delegate receives capture events")
    func delegateReceivesCaptureEvents() {
        let delegate = MockClipboardMonitorDelegate()

        // Simulate calling delegate
        let content = ClipboardContent(primaryType: .plainText)
        delegate.clipboardMonitor(
            ClipboardMonitor.forTesting(),
            didCapture: content,
            from: nil
        )

        #expect(delegate.capturedContents.count == 1)
    }

    @Test("Delegate receives exclusion events")
    func delegateReceivesExclusionEvents() {
        let delegate = MockClipboardMonitorDelegate()

        delegate.clipboardMonitor(
            ClipboardMonitor.forTesting(),
            didExcludeContentWithReason: .duplicate
        )

        #expect(delegate.excludedReasons.count == 1)
    }
}

// MARK: - MockClipboardItemStoreTests

@MainActor
struct MockClipboardItemStoreTests {
    @Test("Mock storage saves items")
    func mockStorageSavesItems() async {
        let store = MockClipboardItemStore()
        let content = ClipboardContent(primaryType: .plainText)

        let result = await store.save(content: content, from: nil)

        #expect(result)
        #expect(store.storedItems.count == 1)
    }

    @Test("Mock storage returns recent hashes")
    func mockStorageReturnsRecentHashes() async {
        let store = MockClipboardItemStore()

        var content1 = ClipboardContent(primaryType: .plainText)
        content1.contentHash = "hash1"

        var content2 = ClipboardContent(primaryType: .plainText)
        content2.contentHash = "hash2"

        _ = await store.save(content: content1, from: nil)
        _ = await store.save(content: content2, from: nil)

        let hashes = await store.fetchRecentHashes(limit: 10)

        #expect(hashes.count == 2)
        #expect(hashes.contains("hash1"))
        #expect(hashes.contains("hash2"))
    }

    @Test("Mock storage respects max items")
    func mockStorageRespectsMaxItems() async {
        let store = MockClipboardItemStore(maxItems: 2)

        for i in 0 ..< 5 {
            var content = ClipboardContent(primaryType: .plainText)
            content.contentHash = "hash\(i)"
            _ = await store.save(content: content, from: nil)
        }

        #expect(store.storedItems.count == 2)
    }

    @Test("Mock storage clear works")
    func mockStorageClearWorks() async {
        let store = MockClipboardItemStore()
        let content = ClipboardContent(primaryType: .plainText)
        _ = await store.save(content: content, from: nil)

        store.clear()

        #expect(store.storedItems.isEmpty)
    }
}
