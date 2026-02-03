# Clipboard Engine

> **Last Updated**: 2026-02-03 | **Reading Time**: 20 minutes

Deep dive into PasteShelf's clipboard monitoring and capture system.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Content Types](#content-types)
- [Monitoring System](#monitoring-system)
- [Content Processing](#content-processing)
- [Deduplication](#deduplication)
- [Performance](#performance)
- [Troubleshooting](#troubleshooting)

---

## Overview

The Clipboard Engine is the core component responsible for monitoring macOS clipboard changes and capturing content efficiently.

### Key Features 🆓

| Feature | Description |
|---------|-------------|
| Real-time monitoring | Captures clipboard changes within 250ms |
| Multi-type support | Text, images, files, RTF, HTML, and more |
| Smart deduplication | Prevents duplicate entries |
| Sensitive detection | Identifies passwords, keys, and PII |
| App awareness | Tracks source application |
| Memory efficient | Handles large content gracefully |

---

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Clipboard Engine                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                    System Layer                                  │   │
│   │                                                                  │   │
│   │   ┌──────────────────────────────────────────────────────────┐  │   │
│   │   │                  NSPasteboard.general                     │  │   │
│   │   │              (macOS Clipboard System)                     │  │   │
│   │   └────────────────────────┬─────────────────────────────────┘  │   │
│   │                            │                                     │   │
│   └────────────────────────────┼─────────────────────────────────────┘   │
│                                │                                         │
│   ┌────────────────────────────┼─────────────────────────────────────┐   │
│   │                    Monitor Layer                                  │   │
│   │                            │                                      │   │
│   │   ┌────────────────────────▼─────────────────────────────────┐   │   │
│   │   │              ClipboardMonitor                             │   │   │
│   │   │              ─────────────────                            │   │   │
│   │   │                                                           │   │   │
│   │   │   ┌─────────────┐    ┌─────────────┐    ┌────────────┐  │   │   │
│   │   │   │   Timer     │    │ Change Count│    │   Source   │  │   │   │
│   │   │   │  (250ms)    │───▶│   Tracker   │───▶│  Detector  │  │   │   │
│   │   │   └─────────────┘    └─────────────┘    └────────────┘  │   │   │
│   │   └──────────────────────────────┬───────────────────────────┘   │   │
│   │                                  │                                │   │
│   └──────────────────────────────────┼────────────────────────────────┘   │
│                                      │                                    │
│   ┌──────────────────────────────────┼────────────────────────────────┐   │
│   │                    Processing Layer                                │   │
│   │                                  │                                 │   │
│   │   ┌──────────────────────────────▼───────────────────────────┐    │   │
│   │   │                   ContentParser                           │    │   │
│   │   │                   ─────────────                           │    │   │
│   │   │                                                           │    │   │
│   │   │   ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────────┐   │    │   │
│   │   │   │  Text   │ │  Image  │ │  File   │ │   Rich      │   │    │   │
│   │   │   │ Parser  │ │ Parser  │ │ Parser  │ │   Parser    │   │    │   │
│   │   │   └────┬────┘ └────┬────┘ └────┬────┘ └──────┬──────┘   │    │   │
│   │   │        │           │           │             │          │    │   │
│   │   │        └───────────┴─────┬─────┴─────────────┘          │    │   │
│   │   └──────────────────────────┼───────────────────────────────┘    │   │
│   │                              │                                     │   │
│   │   ┌──────────────────────────▼───────────────────────────┐        │   │
│   │   │              SensitiveDataDetector                    │        │   │
│   │   └──────────────────────────┬───────────────────────────┘        │   │
│   │                              │                                     │   │
│   │   ┌──────────────────────────▼───────────────────────────┐        │   │
│   │   │                 Deduplicator                          │        │   │
│   │   └──────────────────────────┬───────────────────────────┘        │   │
│   │                              │                                     │   │
│   └──────────────────────────────┼─────────────────────────────────────┘   │
│                                  │                                         │
│   ┌──────────────────────────────┼─────────────────────────────────────┐   │
│   │                    Storage Layer                                    │   │
│   │                              │                                      │   │
│   │   ┌──────────────────────────▼───────────────────────────┐         │   │
│   │   │                  StorageManager                       │         │   │
│   │   │                  ──────────────                       │         │   │
│   │   │   • CoreData persistence                              │         │   │
│   │   │   • Search index update                               │         │   │
│   │   │   • CloudKit sync trigger ⭐                          │         │   │
│   │   └──────────────────────────────────────────────────────┘         │   │
│   │                                                                     │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  Copy    │────▶│  Detect  │────▶│  Parse   │────▶│  Filter  │────▶│  Store   │
│  Event   │     │  Change  │     │ Content  │     │  & Check │     │  Item    │
└──────────┘     └──────────┘     └──────────┘     └──────────┘     └──────────┘
     │                │                │                │                │
     │           changeCount      NSPasteboard     Exclusions        CoreData
     │              check            types          Sensitive        CloudKit
     │               250ms                          Duplicate
```

---

## Content Types

### Supported Types 🆓

| Type | UTI | Description |
|------|-----|-------------|
| Plain Text | `public.utf8-plain-text` | Basic text content |
| Rich Text | `public.rtf` | Formatted text (RTF) |
| HTML | `public.html` | Web content |
| PNG Image | `public.png` | PNG images |
| TIFF Image | `public.tiff` | TIFF images |
| JPEG Image | `public.jpeg` | JPEG images |
| PDF | `com.adobe.pdf` | PDF documents |
| File URL | `public.file-url` | File references |
| URL | `public.url` | Web URLs |

### Type Detection

```swift
enum ContentType: String, CaseIterable {
    case plainText = "public.utf8-plain-text"
    case richText = "public.rtf"
    case html = "public.html"
    case png = "public.png"
    case tiff = "public.tiff"
    case jpeg = "public.jpeg"
    case pdf = "com.adobe.pdf"
    case fileURL = "public.file-url"
    case url = "public.url"

    /// Priority for type selection (lower = higher priority)
    var priority: Int {
        switch self {
        case .richText: return 1
        case .html: return 2
        case .plainText: return 3
        case .png: return 4
        case .jpeg: return 5
        case .tiff: return 6
        case .pdf: return 7
        case .url: return 8
        case .fileURL: return 9
        }
    }

    /// Icon for display
    var icon: String {
        switch self {
        case .plainText: return "doc.text"
        case .richText: return "doc.richtext"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .png, .jpeg, .tiff: return "photo"
        case .pdf: return "doc.fill"
        case .fileURL: return "folder"
        case .url: return "link"
        }
    }
}
```

### Multi-Type Handling

When clipboard contains multiple representations:

```swift
class ContentParser {
    /// Parse clipboard content, preferring richest representation
    func parse(_ pasteboard: NSPasteboard) -> ClipboardContent? {
        var content = ClipboardContent()

        // Get all available types sorted by priority
        let availableTypes = pasteboard.types?
            .compactMap { ContentType(rawValue: $0.rawValue) }
            .sorted { $0.priority < $1.priority } ?? []

        guard !availableTypes.isEmpty else { return nil }

        // Primary type is highest priority available
        content.primaryType = availableTypes.first!

        // Extract all representations
        for type in availableTypes {
            switch type {
            case .plainText:
                content.plainText = pasteboard.string(forType: .string)

            case .richText:
                content.rtfData = pasteboard.data(forType: .rtf)

            case .html:
                content.html = pasteboard.string(forType: .html)

            case .png, .jpeg, .tiff:
                if let image = NSImage(pasteboard: pasteboard) {
                    content.image = image
                    content.imageData = image.tiffRepresentation
                }

            case .fileURL:
                content.fileURLs = pasteboard.readObjects(
                    forClasses: [NSURL.self],
                    options: [.urlReadingFileURLsOnly: true]
                ) as? [URL]

            case .url:
                content.url = URL(string: pasteboard.string(forType: .URL) ?? "")

            case .pdf:
                content.pdfData = pasteboard.data(forType: .pdf)
            }
        }

        return content
    }
}
```

---

## Monitoring System

### Timer-Based Polling

```swift
@MainActor
final class ClipboardMonitor: ObservableObject {
    @Published private(set) var isMonitoring = false

    private var changeCount: Int = 0
    private var timer: Timer?
    private let pollInterval: TimeInterval = 0.25 // 250ms

    // Callbacks
    var onItemCaptured: ((ClipboardItem) -> Void)?

    func startMonitoring() {
        guard !isMonitoring else { return }

        // Initialize with current count
        changeCount = NSPasteboard.general.changeCount

        // Start polling timer
        timer = Timer.scheduledTimer(
            withTimeInterval: pollInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkForChanges()
            }
        }

        // Ensure timer runs in common modes (even during UI interaction)
        RunLoop.main.add(timer!, forMode: .common)

        isMonitoring = true
        Logger.clipboard.info("Clipboard monitoring started")
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        Logger.clipboard.info("Clipboard monitoring stopped")
    }

    private func checkForChanges() {
        let currentCount = NSPasteboard.general.changeCount

        if currentCount != changeCount {
            changeCount = currentCount
            captureCurrentContent()
        }
    }

    private func captureCurrentContent() {
        let pasteboard = NSPasteboard.general

        // Check for exclusions first
        if shouldExcludeCurrentCapture() {
            Logger.clipboard.debug("Clipboard capture excluded")
            return
        }

        // Parse content
        guard let content = ContentParser().parse(pasteboard) else {
            Logger.clipboard.debug("No parseable content")
            return
        }

        // Detect sensitive data
        let sensitiveResult = SensitiveDataDetector().analyze(content)

        // Check for duplicates
        if isDuplicate(content) {
            Logger.clipboard.debug("Duplicate content, updating access time")
            return
        }

        // Create clipboard item
        let item = ClipboardItem(
            content: content,
            sourceApp: getSourceApp(),
            isSensitive: sensitiveResult.isSensitive
        )

        onItemCaptured?(item)
        Logger.clipboard.info("Captured clipboard item: \(item.id)")
    }
}
```

### Source App Detection

```swift
extension ClipboardMonitor {
    private func getSourceApp() -> SourceApp? {
        // Get frontmost application
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        return SourceApp(
            bundleId: frontApp.bundleIdentifier ?? "unknown",
            name: frontApp.localizedName ?? "Unknown",
            icon: frontApp.icon
        )
    }
}

struct SourceApp {
    let bundleId: String
    let name: String
    let icon: NSImage?
}
```

### Exclusion Logic

```swift
extension ClipboardMonitor {
    private func shouldExcludeCurrentCapture() -> Bool {
        let frontApp = NSWorkspace.shared.frontmostApplication

        // Check excluded apps
        if let bundleId = frontApp?.bundleIdentifier,
           ExclusionManager.shared.isExcluded(bundleId: bundleId) {
            return true
        }

        // Check if it's our own paste operation
        if frontApp?.bundleIdentifier == Bundle.main.bundleIdentifier {
            return true
        }

        // Check for private browsing
        if isPrivateBrowsingActive() {
            return true
        }

        return false
    }

    private func isPrivateBrowsingActive() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        // Safari private window detection
        if frontApp.bundleIdentifier == "com.apple.Safari" {
            // Use Accessibility API to check window title
            if let windowTitle = getActiveWindowTitle(),
               windowTitle.contains("Private") {
                return true
            }
        }

        // Chrome incognito detection
        if frontApp.bundleIdentifier == "com.google.Chrome" {
            if let windowTitle = getActiveWindowTitle(),
               windowTitle.contains("Incognito") {
                return true
            }
        }

        return false
    }
}
```

---

## Content Processing

### Processing Pipeline

```
┌────────────────────────────────────────────────────────────────────────────┐
│                         Content Processing Pipeline                         │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Raw NSPasteboard                                                          │
│         │                                                                   │
│         ▼                                                                   │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │  1. Type Detection                                                   │  │
│   │     • Enumerate available UTI types                                  │  │
│   │     • Select primary type by priority                                │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│         │                                                                   │
│         ▼                                                                   │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │  2. Content Extraction                                               │  │
│   │     • Extract data for each type                                     │  │
│   │     • Convert to internal representations                            │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│         │                                                                   │
│         ▼                                                                   │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │  3. Normalization                                                    │  │
│   │     • Standardize text encoding (UTF-8)                              │  │
│   │     • Trim whitespace                                                │  │
│   │     • Extract plain text from rich formats                           │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│         │                                                                   │
│         ▼                                                                   │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │  4. Metadata Extraction                                              │  │
│   │     • Source app info                                                │  │
│   │     • URL from web content                                           │  │
│   │     • File info (size, type, path)                                   │  │
│   │     • Character/word count                                           │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│         │                                                                   │
│         ▼                                                                   │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │  5. Preview Generation                                               │  │
│   │     • Text preview (first 500 chars)                                 │  │
│   │     • Image thumbnail (256px)                                        │  │
│   │     • File icon                                                      │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│         │                                                                   │
│         ▼                                                                   │
│   ClipboardContent (ready for storage)                                      │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

### Image Processing

```swift
class ImageProcessor {
    private let maxStorageSize: Int = 10_000_000 // 10MB
    private let thumbnailSize: CGFloat = 256

    func process(_ image: NSImage) -> ProcessedImage {
        var processed = ProcessedImage()

        // Generate thumbnail
        processed.thumbnail = generateThumbnail(image)

        // Get original data
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData) {

            // Compress if too large
            if tiffData.count > maxStorageSize {
                processed.data = compressImage(bitmap)
                processed.isCompressed = true
            } else {
                processed.data = bitmap.representation(
                    using: .png,
                    properties: [:]
                )
            }
        }

        // Extract dimensions
        processed.width = Int(image.size.width)
        processed.height = Int(image.size.height)

        return processed
    }

    private func generateThumbnail(_ image: NSImage) -> Data? {
        let targetSize = CGSize(width: thumbnailSize, height: thumbnailSize)

        // Calculate aspect-fit size
        let ratio = min(
            targetSize.width / image.size.width,
            targetSize.height / image.size.height
        )
        let newSize = CGSize(
            width: image.size.width * ratio,
            height: image.size.height * ratio
        )

        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        thumbnail.unlockFocus()

        return thumbnail.tiffRepresentation
    }

    private func compressImage(_ bitmap: NSBitmapImageRep) -> Data? {
        // Use JPEG compression
        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.8]
        )
    }
}
```

---

## Deduplication

### Hash-Based Deduplication

```swift
class Deduplicator {
    private let storage: StorageManager

    /// Check if content is duplicate of recent item
    func isDuplicate(_ content: ClipboardContent) -> Bool {
        let hash = computeHash(content)

        // Check recent items (last 100)
        let recentItems = storage.fetchRecent(limit: 100)
        return recentItems.contains { $0.contentHash == hash }
    }

    /// Compute content hash for deduplication
    func computeHash(_ content: ClipboardContent) -> String {
        var hasher = SHA256()

        // Hash based on primary type
        switch content.primaryType {
        case .plainText:
            if let text = content.plainText {
                hasher.update(data: Data(text.utf8))
            }

        case .richText:
            // Hash plain text extraction for RTF
            if let rtfData = content.rtfData,
               let attrString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                hasher.update(data: Data(attrString.string.utf8))
            }

        case .png, .jpeg, .tiff:
            // Hash image data
            if let imageData = content.imageData {
                hasher.update(data: imageData)
            }

        case .fileURL:
            // Hash file paths
            if let urls = content.fileURLs {
                let paths = urls.map(\.path).joined(separator: "\n")
                hasher.update(data: Data(paths.utf8))
            }

        default:
            // Generic hash
            if let plainText = content.plainText {
                hasher.update(data: Data(plainText.utf8))
            }
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
```

### Duplicate Handling Options

```
┌─────────────────────────────────────────────────────────────┐
│               Duplicate Handling Options                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Preferences → Behavior → Duplicates:                        │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  When duplicate content is copied:                   │    │
│  │                                                      │    │
│  │  ● Move existing to top (update timestamp)          │    │
│  │  ○ Create new entry (allow duplicates)              │    │
│  │  ○ Ignore (keep original position)                  │    │
│  │                                                      │    │
│  │  ─────────────────────────────────────────────────  │    │
│  │                                                      │    │
│  │  ☑ Consider whitespace differences as unique        │    │
│  │  ☑ Consider case differences as unique              │    │
│  │  ☐ Consider formatting differences as unique        │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Performance

### Memory Management

```swift
class ClipboardMonitor {
    // Limit in-memory content size
    private let maxInMemorySize: Int = 50_000_000 // 50MB

    private func captureCurrentContent() {
        // Check total pasteboard size first
        let pasteboardSize = estimatePasteboardSize()

        if pasteboardSize > maxInMemorySize {
            Logger.clipboard.warning("Clipboard content too large: \(pasteboardSize) bytes")
            // Stream to disk instead
            captureToFile()
            return
        }

        // Normal capture
        // ...
    }

    private func estimatePasteboardSize() -> Int {
        let pasteboard = NSPasteboard.general
        var totalSize = 0

        for type in pasteboard.types ?? [] {
            if let data = pasteboard.data(forType: type) {
                totalSize += data.count
            }
        }

        return totalSize
    }
}
```

### Performance Metrics

| Metric | Target | Notes |
|--------|--------|-------|
| Capture latency | < 50ms | Time from copy to capture |
| Memory overhead | < 50MB | For monitoring |
| CPU usage (idle) | < 1% | When not capturing |
| CPU usage (capture) | < 5% | During content processing |
| Timer accuracy | ±50ms | Polling interval consistency |

### Monitoring Dashboard

```swift
struct ClipboardEngineMetrics {
    var captureCount: Int = 0
    var duplicateCount: Int = 0
    var excludedCount: Int = 0
    var errorCount: Int = 0

    var averageCaptureTime: TimeInterval = 0
    var averageContentSize: Int = 0

    var lastCaptureTime: Date?
    var lastError: Error?
}
```

---

## Troubleshooting

### Common Issues

#### Clipboard Not Being Captured

```
Problem: Copy operations not appearing in history

Checklist:
1. ✅ Accessibility permission granted?
   System Settings → Privacy & Security → Accessibility → PasteShelf ✓

2. ✅ App not excluded?
   Preferences → Privacy → Excluded Apps

3. ✅ Monitoring enabled?
   Check menu bar icon is active (not grayed out)

4. ✅ Content type supported?
   Some custom clipboard formats may not be supported

5. ✅ Not a private browsing window?
   Private/Incognito windows are excluded by default
```

#### High CPU Usage

```
Problem: PasteShelf using excessive CPU

Solutions:
1. Check for runaway loop
   - Restart PasteShelf

2. Large clipboard content
   - Clear the system clipboard

3. Reduce history limit
   - Preferences → History → Maximum Items

4. Disable image previews
   - Preferences → Display → Show Thumbnails ✗
```

#### Memory Issues

```
Problem: High memory usage

Solutions:
1. Clear old history
   - Preferences → Privacy → Clear History

2. Reduce image storage
   - Preferences → Storage → Image Quality → Lower

3. Enable auto-cleanup
   - Preferences → Privacy → Auto-delete after: 30 days
```

### Debug Mode

```bash
# Enable debug logging
defaults write com.pasteshelf.PasteShelf DebugLogging -bool true

# View logs
log stream --predicate 'subsystem == "com.pasteshelf.PasteShelf"' --level debug

# Disable debug logging
defaults delete com.pasteshelf.PasteShelf DebugLogging
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Architecture](../architecture/ARCHITECTURE.md) | System overview |
| [Search Engine](SEARCH_ENGINE.md) | Search system |
| [Privacy & Security](PRIVACY_SECURITY_FEATURES.md) | Data protection |
| [Performance](../reference/PERFORMANCE_OPTIMIZATION.md) | Optimization |

---

*Last updated: 2026-02-03*
