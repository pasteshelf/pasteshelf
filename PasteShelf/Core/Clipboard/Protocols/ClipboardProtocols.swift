//
//  ClipboardProtocols.swift
//  PasteShelf
//
//  Protocol definitions for the clipboard engine components.
//  These protocols enable dependency injection and testability.
//

import AppKit
import Foundation

// MARK: - ClipboardMonitoring

/// Protocol for clipboard monitoring functionality
@MainActor
protocol ClipboardMonitoring: AnyObject {
    /// Whether monitoring is currently active
    var isMonitoring: Bool { get }

    /// Delegate to receive clipboard events
    var delegate: ClipboardMonitorDelegate? { get set }

    /// Start monitoring the clipboard for changes
    func startMonitoring()

    /// Stop monitoring the clipboard
    func stopMonitoring()
}

// MARK: - ClipboardMonitorDelegate

/// Delegate protocol for receiving clipboard events
@MainActor
protocol ClipboardMonitorDelegate: AnyObject {
    /// Called when new clipboard content is captured
    /// - Parameters:
    ///   - monitor: The monitor that captured the content
    ///   - content: The captured clipboard content
    ///   - sourceApp: The source application (if detected)
    func clipboardMonitor(
        _ monitor: ClipboardMonitoring,
        didCapture content: ClipboardContent,
        from sourceApp: SourceApp?
    )

    /// Called when clipboard content was excluded
    /// - Parameters:
    ///   - monitor: The monitor that excluded the content
    ///   - reason: The reason for exclusion
    func clipboardMonitor(
        _ monitor: ClipboardMonitoring,
        didExcludeContentWithReason reason: ExclusionReason
    )

    /// Called when an error occurs during monitoring
    /// - Parameters:
    ///   - monitor: The monitor that encountered the error
    ///   - error: The error that occurred
    func clipboardMonitor(
        _ monitor: ClipboardMonitoring,
        didEncounterError error: Error
    )
}

// MARK: - ExclusionReason

/// Reasons why clipboard content may be excluded
enum ExclusionReason {
    case excludedApp(bundleId: String)
    case ownPasteOperation
    case emptyContent
    case duplicate
    case userPaused
    case contentTypeDisabled
}

// MARK: - ContentParsing

/// Protocol for parsing clipboard content from NSPasteboard
protocol ContentParsing {
    /// Parse content from the pasteboard
    /// - Parameter pasteboard: The pasteboard to parse
    /// - Returns: Parsed clipboard content, or nil if no valid content
    func parse(_ pasteboard: NSPasteboard) -> ClipboardContent?

    /// Parse content for a specific type only
    /// - Parameters:
    ///   - pasteboard: The pasteboard to parse
    ///   - type: The specific content type to extract
    /// - Returns: Parsed content containing only the specified type
    func parse(_ pasteboard: NSPasteboard, forType type: ContentType) -> ClipboardContent?
}

// MARK: - SensitiveDataDetecting

/// Protocol for detecting sensitive data in clipboard content
protocol SensitiveDataDetecting {
    /// Analyze content for sensitive data
    /// - Parameter content: The content to analyze
    /// - Returns: Result of the analysis
    func analyze(_ content: ClipboardContent) -> SensitiveDataResult

    /// Analyze a string for sensitive data
    /// - Parameter text: The text to analyze
    /// - Returns: Result of the analysis
    func analyze(text: String) -> SensitiveDataResult
}

// MARK: - SensitiveDataResult

/// Result of sensitive data analysis
struct SensitiveDataResult {
    /// Empty result with no detections
    static let empty = SensitiveDataResult(
        isSensitive: false,
        detections: [],
        highestSeverity: .none
    )

    /// Whether any sensitive data was detected
    let isSensitive: Bool

    /// List of detected sensitive data items
    let detections: [SensitiveDetection]

    /// The highest severity level detected
    let highestSeverity: SensitiveSeverity
}

// MARK: - SensitiveDetection

/// Individual sensitive data detection
struct SensitiveDetection {
    /// The type of sensitive data detected
    let type: String

    /// Severity of this detection
    let severity: SensitiveSeverity

    /// Range in the original text where this was detected
    let range: Range<String.Index>?

    /// Redacted preview of the detected content
    let redactedPreview: String?
}

// MARK: - SensitiveSeverity

/// Severity levels for sensitive data
enum SensitiveSeverity: Int, Codable, Comparable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4

    // MARK: Internal

    static func < (lhs: SensitiveSeverity, rhs: SensitiveSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Deduplicating

/// Protocol for content deduplication
protocol Deduplicating {
    /// Compute a hash for the given content
    /// - Parameter content: The content to hash
    /// - Returns: A SHA256 hash string
    func computeHash(for content: ClipboardContent) -> String

    /// Compute a hash for text content
    /// - Parameter text: The text to hash
    /// - Returns: A SHA256 hash string
    func computeHash(forText text: String) -> String

    /// Check if content is a duplicate of recent items
    /// - Parameters:
    ///   - content: The content to check
    ///   - recentHashes: Hashes of recent items to compare against
    /// - Returns: True if content is a duplicate
    func isDuplicate(_ content: ClipboardContent, comparing recentHashes: [String]) -> Bool
}

// MARK: - ImageProcessing

/// Protocol for image processing operations
protocol ImageProcessing {
    /// Maximum size for stored images in bytes (default 10MB)
    var maxStorageSize: Int { get }

    /// Maximum dimension for thumbnails in pixels (default 256)
    var thumbnailSize: CGFloat { get }

    /// Process an image for storage
    /// - Parameter image: The image to process
    /// - Returns: Processed image result with thumbnail and compressed data
    func process(_ image: NSImage) -> ProcessedImage

    /// Generate a thumbnail for an image
    /// - Parameter image: The source image
    /// - Returns: Thumbnail image data (PNG)
    func generateThumbnail(_ image: NSImage) -> Data?

    /// Compress an image if it exceeds the max storage size
    /// - Parameter imageData: The original image data
    /// - Returns: Compressed image data (JPEG) or original if under limit
    func compressIfNeeded(_ imageData: Data) -> (data: Data, isCompressed: Bool)
}

// MARK: - ProcessedImage

/// Result of image processing
struct ProcessedImage {
    /// Processed image data (may be compressed)
    var data: Data?

    /// Thumbnail data (PNG, 256px max dimension)
    var thumbnail: Data?

    /// Original image width
    var width: Int = 0

    /// Original image height
    var height: Int = 0

    /// Whether the image was compressed for storage
    var isCompressed: Bool = false
}

// MARK: - AppExcluding

/// Protocol for managing app exclusions
protocol AppExcluding {
    /// Check if an app should be excluded from capture
    /// - Parameter bundleId: The bundle identifier to check
    /// - Returns: True if the app is excluded
    func isExcluded(bundleId: String) -> Bool

    /// Add an app to the exclusion list
    /// - Parameter bundleId: The bundle identifier to exclude
    func exclude(bundleId: String)

    /// Remove an app from the exclusion list
    /// - Parameter bundleId: The bundle identifier to include
    func include(bundleId: String)

    /// Get the list of excluded bundle identifiers
    var excludedBundleIds: [String] { get }

    /// Get the list of default excluded bundle identifiers (password managers, etc.)
    var defaultExcludedBundleIds: [String] { get }
}

// MARK: - ClipboardItemStoring

/// Protocol for storing clipboard items (to be implemented in Phase 1.3)
protocol ClipboardItemStoring: AnyObject {
    /// Save a clipboard item
    /// - Parameters:
    ///   - content: The content to save
    ///   - sourceApp: The source application
    /// - Returns: True if save was successful
    @MainActor
    func save(content: ClipboardContent, from sourceApp: SourceApp?) async -> Bool

    /// Fetch recent item hashes for deduplication
    /// - Parameter limit: Maximum number of hashes to return
    /// - Returns: Array of content hashes
    func fetchRecentHashes(limit: Int) async -> [String]
}

// MARK: - Mock Storage (Debug/Testing Only)

#if DEBUG
    /// In-memory mock storage for testing
    @MainActor
    final class MockClipboardItemStore: ClipboardItemStoring {
        // MARK: Lifecycle

        init(maxItems: Int = 100) {
            self.maxItems = maxItems
        }

        // MARK: Internal

        /// Access to stored items for testing
        var storedItems: [(content: ClipboardContent, sourceApp: SourceApp?)] {
            self.items
        }

        func save(content: ClipboardContent, from sourceApp: SourceApp?) async -> Bool {
            self.items.insert((content, sourceApp), at: 0)
            if self.items.count > self.maxItems {
                self.items.removeLast()
            }
            return true
        }

        func fetchRecentHashes(limit: Int) async -> [String] {
            self.items.prefix(limit).compactMap(\.content.contentHash)
        }

        /// Clear all stored items
        func clear() {
            self.items.removeAll()
        }

        // MARK: Private

        private var items: [(content: ClipboardContent, sourceApp: SourceApp?)] = []
        private let maxItems: Int
    }
#endif

// MARK: - Default Delegate Implementations

extension ClipboardMonitorDelegate {
    func clipboardMonitor(
        _ monitor: ClipboardMonitoring,
        didExcludeContentWithReason reason: ExclusionReason
    ) {
        // Optional - default empty implementation
    }

    func clipboardMonitor(
        _ monitor: ClipboardMonitoring,
        didEncounterError error: Error
    ) {
        // Optional - default empty implementation
    }
}
