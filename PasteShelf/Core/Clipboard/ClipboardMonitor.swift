//
//  ClipboardMonitor.swift
//  PasteShelf
//
//  Central orchestrator for clipboard monitoring. Uses timer-based polling
//  to detect changes and coordinates parsing, filtering, and storage.
//

import AppKit
import Combine
import Foundation
import os.log

/// Monitors the system clipboard for changes and captures content
@MainActor
final class ClipboardMonitor: ObservableObject, ClipboardMonitoring {
    // MARK: - Published Properties

    /// Whether monitoring is currently active
    @Published private(set) var isMonitoring = false

    /// Whether monitoring is paused by user
    @Published var isPaused = false

    /// Metrics for monitoring health
    @Published private(set) var metrics = ClipboardMonitorMetrics()

    // MARK: - Dependencies

    /// Delegate to receive clipboard events
    weak var delegate: ClipboardMonitorDelegate?

    /// Content parser
    private let contentParser: ContentParsing

    /// Sensitive data detector
    private let sensitiveDetector: SensitiveDataDetecting

    /// Exclusion manager
    private let exclusionManager: ExclusionManager

    /// Storage for persistence (optional, can be nil during Phase 1.2)
    private let storage: ClipboardItemStoring?

    // MARK: - Configuration

    /// Polling interval in seconds
    private let pollInterval: TimeInterval

    /// Number of recent hashes to check for duplicates
    private let duplicateCheckLimit: Int

    // MARK: - Internal State

    /// Last known change count
    private var lastChangeCount: Int = 0

    /// Polling timer
    private var timer: Timer?

    /// Recent content hashes for deduplication
    private var recentHashes: [String] = []

    /// Pasteboard instance
    private let pasteboard: NSPasteboard

    // MARK: - Initialization

    /// Creates a ClipboardMonitor with default dependencies
    init(
        contentParser: ContentParsing = ContentParser(),
        sensitiveDetector: SensitiveDataDetecting = SensitiveDataDetector(),
        exclusionManager: ExclusionManager = .shared,
        storage: ClipboardItemStoring? = nil,
        pollInterval: TimeInterval = 0.25,
        duplicateCheckLimit: Int = 100,
        pasteboard: NSPasteboard = .general
    ) {
        self.contentParser = contentParser
        self.sensitiveDetector = sensitiveDetector
        self.exclusionManager = exclusionManager
        self.storage = storage
        self.pollInterval = pollInterval
        self.duplicateCheckLimit = duplicateCheckLimit
        self.pasteboard = pasteboard
    }

    deinit {
        // Timer cleanup handled by stopMonitoring
    }

    // MARK: - ClipboardMonitoring

    func startMonitoring() {
        guard !isMonitoring else {
            Logger.clipboard.debug("Monitoring already active")
            return
        }

        // Initialize with current change count
        lastChangeCount = pasteboard.changeCount

        // Load recent hashes for deduplication, then start timer
        Task {
            if let storage = storage {
                recentHashes = await storage.fetchRecentHashes(limit: duplicateCheckLimit)
            }

            // Start polling timer after hashes are loaded
            self.startPollingTimer()
        }

        isMonitoring = true
        Logger.clipboard.info("Clipboard monitoring started (interval: \(self.pollInterval)s)")
    }

    /// Starts the polling timer (called after hash cache is loaded)
    private func startPollingTimer() {
        timer = Timer.scheduledTimer(
            withTimeInterval: pollInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkForChanges()
            }
        }

        // Ensure timer runs during UI interactions
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        Logger.clipboard.info("Clipboard monitoring stopped")
    }

    // MARK: - Change Detection

    /// Checks for clipboard changes (called by timer)
    private func checkForChanges() {
        guard !isPaused else { return }

        let currentCount = pasteboard.changeCount

        if currentCount != lastChangeCount {
            lastChangeCount = currentCount
            captureCurrentContent()
        }
    }

    /// Captures and processes current clipboard content
    private func captureCurrentContent() {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Check exclusions first
        if handleExclusions() { return }

        // Parse and validate content
        guard let content = parseAndValidateContent() else { return }

        // Process the content
        let (mutableContent, sourceApp) = processContent(content)

        // Finalize capture
        finalizeCapture(mutableContent, sourceApp: sourceApp, startTime: startTime)
    }

    private func handleExclusions() -> Bool {
        let (shouldExclude, reason) = exclusionManager.shouldExcludeCurrentCapture()
        if shouldExclude, let reason = reason {
            metrics.excludedCount += 1
            delegate?.clipboardMonitor(self, didExcludeContentWithReason: reason)
            Logger.clipboard.debug("Capture excluded: \(String(describing: reason))")
            return true
        }
        return false
    }

    private func parseAndValidateContent() -> ClipboardContent? {
        guard let content = contentParser.parse(pasteboard) else {
            metrics.excludedCount += 1
            delegate?.clipboardMonitor(self, didExcludeContentWithReason: .emptyContent)
            return nil
        }

        if let hash = content.contentHash, recentHashes.contains(hash) {
            metrics.duplicateCount += 1
            delegate?.clipboardMonitor(self, didExcludeContentWithReason: .duplicate)
            Logger.clipboard.debug("Duplicate content detected")
            return nil
        }

        return content
    }

    private func processContent(_ content: ClipboardContent) -> (ClipboardContent, SourceApp?) {
        var mutableContent = content
        let sensitiveResult = sensitiveDetector.analyze(content)
        mutableContent.isSensitive = sensitiveResult.isSensitive
        mutableContent.sensitiveTypes = sensitiveResult.detectedTypes

        if sensitiveResult.isSensitive {
            Logger.security.info(
                "Sensitive data detected: \(sensitiveResult.uniqueTypes.joined(separator: ", "))"
            )
        }

        let sourceApp = SourceApp.frontmost()
        mutableContent.sourceApp = sourceApp

        return (mutableContent, sourceApp)
    }

    private func finalizeCapture(_ content: ClipboardContent, sourceApp: SourceApp?, startTime: CFAbsoluteTime) {
        let captureTime = CFAbsoluteTimeGetCurrent() - startTime
        metrics.updateAverageCaptureTime(captureTime)
        metrics.lastCaptureTime = Date()

        // Save first, then update metrics and hash cache only after successful persistence.
        // This prevents orphaned hashes from permanently deduplicating content that was never stored.
        Task {
            let saved = await saveToStorageAsync(content, sourceApp: sourceApp)
            if saved {
                metrics.captureCount += 1
                updateRecentHashes(with: content.contentHash)
                delegate?.clipboardMonitor(self, didCapture: content, from: sourceApp)
            } else {
                metrics.errorCount += 1
                Logger.clipboard.error("Failed to save clipboard content to storage")
            }
        }

        let timeMs = String(format: "%.2fms", captureTime * 1_000)
        Logger.clipboard.info("Captured: \(content.primaryType.displayName), sensitive=\(content.isSensitive), time=\(timeMs)")
    }

    private func updateRecentHashes(with hash: String?) {
        guard let hash = hash else { return }
        recentHashes.insert(hash, at: 0)
        if recentHashes.count > duplicateCheckLimit {
            recentHashes.removeLast()
        }
    }

    private func saveToStorageAsync(_ content: ClipboardContent, sourceApp: SourceApp?) async -> Bool {
        guard let storage = storage else { return false }
        return await storage.save(content: content, from: sourceApp)
    }

    // MARK: - Control Methods

    /// Pauses monitoring temporarily
    func pause() {
        isPaused = true
        Logger.clipboard.info("Clipboard monitoring paused")
    }

    /// Resumes monitoring after pause
    func resume() {
        isPaused = false
        // Reset change count to avoid capturing changes made while paused
        lastChangeCount = pasteboard.changeCount
        Logger.clipboard.info("Clipboard monitoring resumed")
    }

    /// Triggers a manual capture (for testing)
    func captureNow() {
        captureCurrentContent()
    }

    /// Clears the recent hashes cache
    func clearHashCache() {
        recentHashes.removeAll()
    }

    /// Reloads recent hashes from storage
    func reloadHashCache() async {
        guard let storage = storage else { return }
        recentHashes = await storage.fetchRecentHashes(limit: duplicateCheckLimit)
    }
}

// MARK: - Metrics

/// Metrics for clipboard monitoring health
struct ClipboardMonitorMetrics {
    /// Total items captured
    var captureCount: Int = 0

    /// Items detected as duplicates
    var duplicateCount: Int = 0

    /// Items excluded (apps, private browsing, etc.)
    var excludedCount: Int = 0

    /// Errors encountered
    var errorCount: Int = 0

    /// Average capture time in seconds
    private(set) var averageCaptureTime: TimeInterval = 0

    /// Number of samples for average calculation
    private var sampleCount: Int = 0

    /// Last capture timestamp
    var lastCaptureTime: Date?

    /// Last error encountered
    var lastError: Error?

    /// Updates the running average capture time
    mutating func updateAverageCaptureTime(_ time: TimeInterval) {
        sampleCount += 1
        averageCaptureTime += (time - averageCaptureTime) / Double(sampleCount)
    }

    /// Average capture time in milliseconds
    var averageCaptureTimeMs: Double {
        averageCaptureTime * 1_000
    }

    /// Total items processed (captures + duplicates + excluded)
    var totalProcessed: Int {
        captureCount + duplicateCount + excludedCount
    }

    /// Duplicate rate as percentage
    var duplicateRate: Double {
        guard totalProcessed > 0 else { return 0 }
        return Double(duplicateCount) / Double(totalProcessed) * 100
    }
}

// MARK: - Convenience Factory Methods

#if DEBUG
    @MainActor
    extension ClipboardMonitor {
        /// Creates a monitor with mock storage for testing
        static func forTesting(
            storage: ClipboardItemStoring? = nil
        ) -> ClipboardMonitor {
            ClipboardMonitor(storage: storage ?? MockClipboardItemStore(), pollInterval: 0.1)
        }
    }
#endif
