# Performance Optimization Guide

> **Last Updated**: 2026-02-03 | **Reading Time**: 15 minutes

Performance best practices and optimization techniques for PasteShelf.

---

## Table of Contents

- [Performance Goals](#performance-goals)
- [SwiftUI Optimization](#swiftui-optimization)
- [CoreData Optimization](#coredata-optimization)
- [Memory Management](#memory-management)
- [Search Optimization](#search-optimization)
- [Profiling & Monitoring](#profiling--monitoring)

---

## Performance Goals

### Target Metrics

| Metric | Target | Critical |
|--------|--------|----------|
| App launch | <500ms | <1s |
| Panel open | <100ms | <200ms |
| Search (10K items) | <50ms | <100ms |
| Clipboard capture | <10ms | <50ms |
| Memory (idle) | <50MB | <100MB |
| CPU (idle) | <1% | <5% |

### User Experience Principles

1. **Instant feedback**: UI responds immediately
2. **Non-blocking**: Heavy work on background threads
3. **Progressive loading**: Show data as it loads
4. **Graceful degradation**: Handle large datasets smoothly

---

## SwiftUI Optimization

### View Performance

#### Minimize View Updates

```swift
// ❌ Bad: Entire view rebuilds on any change
struct ClipboardListView: View {
    @ObservedObject var viewModel: ClipboardViewModel

    var body: some View {
        List(viewModel.items) { item in
            ClipboardRow(item: item)
        }
    }
}

// ✅ Good: Only affected rows rebuild
struct ClipboardListView: View {
    @StateObject private var viewModel = ClipboardViewModel()

    var body: some View {
        List(viewModel.items) { item in
            ClipboardRow(item: item)
                .equatable() // Only rebuild if item changes
        }
    }
}

struct ClipboardRow: View, Equatable {
    let item: ClipboardItem

    static func == (lhs: ClipboardRow, rhs: ClipboardRow) -> Bool {
        lhs.item.id == rhs.item.id &&
        lhs.item.modifiedDate == rhs.item.modifiedDate
    }

    var body: some View {
        // Row content
    }
}
```

#### Lazy Loading

```swift
// ❌ Bad: Loads all items at once
ForEach(items) { item in
    ClipboardRow(item: item)
}

// ✅ Good: Only loads visible items
LazyVStack {
    ForEach(items) { item in
        ClipboardRow(item: item)
    }
}
```

#### Image Optimization

```swift
struct ThumbnailView: View {
    let imageData: Data

    var body: some View {
        // ✅ Use AsyncImage for large images
        AsyncImage(url: thumbnailURL) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .failure:
                Image(systemName: "photo")
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: 60, height: 60)
    }
}

// ✅ Generate thumbnails off main thread
class ThumbnailGenerator {
    private let queue = DispatchQueue(label: "thumbnail", qos: .utility)
    private let cache = NSCache<NSString, NSImage>()

    func thumbnail(for data: Data, size: CGSize) async -> NSImage? {
        let key = NSString(string: data.hashValue.description)

        if let cached = cache.object(forKey: key) {
            return cached
        }

        return await withCheckedContinuation { continuation in
            queue.async {
                guard let image = NSImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }

                let thumbnail = image.resized(to: size)
                self.cache.setObject(thumbnail, forKey: key)
                continuation.resume(returning: thumbnail)
            }
        }
    }
}
```

### State Management

```swift
// ✅ Use appropriate property wrappers
struct ClipboardView: View {
    // Local state - use @State
    @State private var searchText = ""

    // Shared observable - use @StateObject for ownership
    @StateObject private var viewModel = ClipboardViewModel()

    // Passed observable - use @ObservedObject
    @ObservedObject var settings: SettingsManager

    // Environment values - use @Environment
    @Environment(\.colorScheme) var colorScheme
}
```

---

## CoreData Optimization

### Fetch Requests

#### Batch Fetching

```swift
// ✅ Fetch in batches
func fetchItems(batchSize: Int = 50) -> NSFetchRequest<ClipboardItemEntity> {
    let request = ClipboardItemEntity.fetchRequest()
    request.fetchBatchSize = batchSize
    request.returnsObjectsAsFaults = true // Lazy load properties
    request.propertiesToFetch = ["id", "content", "createdDate"] // Only needed properties
    return request
}
```

#### Efficient Predicates

```swift
// ❌ Bad: Fetches all, filters in memory
let allItems = try context.fetch(ClipboardItemEntity.fetchRequest())
let filtered = allItems.filter { $0.content?.contains(searchText) == true }

// ✅ Good: Filter in database
let request = ClipboardItemEntity.fetchRequest()
request.predicate = NSPredicate(
    format: "content CONTAINS[cd] %@",
    searchText
)
let filtered = try context.fetch(request)
```

#### Fetch Limits

```swift
// ✅ Limit results when possible
let request = ClipboardItemEntity.fetchRequest()
request.fetchLimit = 100 // Only need first 100
request.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
```

### Background Processing

```swift
class StorageManager {
    let container: NSPersistentContainer

    // ✅ Use background context for writes
    func save(_ item: ClipboardItem) async throws {
        try await container.performBackgroundTask { context in
            let entity = ClipboardItemEntity(context: context)
            entity.populate(from: item)
            try context.save()
        }
    }

    // ✅ Batch delete
    func deleteOldItems(before date: Date) async throws {
        try await container.performBackgroundTask { context in
            let request = NSBatchDeleteRequest(
                fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: "ClipboardItemEntity")
            )
            request.predicate = NSPredicate(format: "createdDate < %@", date as NSDate)
            try context.execute(request)
        }
    }
}
```

### Indexing

```swift
// In CoreData model, mark frequently searched attributes as indexed:
// - content: Indexed for text search
// - createdDate: Indexed for sorting
// - sourceApp: Indexed for filtering

// Or programmatically:
let entity = NSEntityDescription()
entity.name = "ClipboardItemEntity"

let contentAttribute = NSAttributeDescription()
contentAttribute.name = "content"
contentAttribute.attributeType = .stringAttributeType
contentAttribute.isIndexed = true // ✅ Enable indexing
```

---

## Memory Management

### Large Data Handling

```swift
// ✅ Use external storage for large blobs
// In CoreData model: "Allows External Storage" = YES for imageData

// ✅ Clear caches when memory pressure
class CacheManager {
    static let shared = CacheManager()

    let imageCache = NSCache<NSString, NSImage>()
    let thumbnailCache = NSCache<NSString, NSImage>()

    init() {
        // Set cache limits
        imageCache.totalCostLimit = 50_000_000 // 50MB
        thumbnailCache.countLimit = 500

        // Respond to memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCaches),
            name: NSApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc func clearCaches() {
        imageCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
    }
}
```

### Autorelease Pool

```swift
// ✅ Use autorelease pools for batch processing
func processLargeDataset(_ items: [Data]) {
    for chunk in items.chunked(into: 100) {
        autoreleasepool {
            for data in chunk {
                processItem(data)
            }
        }
    }
}
```

### Weak References

```swift
// ✅ Use weak references to avoid retain cycles
class ClipboardMonitor {
    weak var delegate: ClipboardMonitorDelegate?

    private var timer: Timer?

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
}
```

---

## Search Optimization

### Full-Text Search

```swift
// ✅ Use Spotlight-style indexing for fast search
import CoreSpotlight

class SearchIndexer {
    private let index = CSSearchableIndex.default()

    func indexItem(_ item: ClipboardItem) {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = item.preview
        attributes.textContent = item.content
        attributes.contentCreationDate = item.createdDate

        let searchableItem = CSSearchableItem(
            uniqueIdentifier: item.id.uuidString,
            domainIdentifier: "clipboard",
            attributeSet: attributes
        )

        index.indexSearchableItems([searchableItem])
    }

    func search(query: String) async throws -> [String] {
        let queryString = "textContent == \"*\(query)*\"cd"
        let query = CSSearchQuery(queryString: queryString, attributes: ["textContent"])

        return try await withCheckedThrowingContinuation { continuation in
            var results: [String] = []

            query.foundItemsHandler = { items in
                results.append(contentsOf: items.map { $0.uniqueIdentifier })
            }

            query.completionHandler = { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results)
                }
            }

            query.start()
        }
    }
}
```

### Debouncing

```swift
// ✅ Debounce search input
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var results: [ClipboardItem] = []

    private var searchTask: Task<Void, Never>?

    init() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                self?.performSearch(text)
            }
            .store(in: &cancellables)
    }

    private func performSearch(_ query: String) {
        searchTask?.cancel()

        searchTask = Task {
            let results = await searchEngine.search(query: query)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.results = results
            }
        }
    }
}
```

---

## Profiling & Monitoring

### Instruments

```swift
// Profile with Instruments:
// 1. Product → Profile (⌘I)
// 2. Choose template:
//    - Time Profiler: CPU usage
//    - Allocations: Memory usage
//    - Core Data: Fetch performance
//    - SwiftUI: View updates
```

### Signposts

```swift
import os.signpost

class PerformanceMonitor {
    static let log = OSLog(subsystem: "com.pasteshelf.PasteShelf", category: "Performance")

    static func measure<T>(_ name: StaticString, block: () throws -> T) rethrows -> T {
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: signpostID)
        defer { os_signpost(.end, log: log, name: name, signpostID: signpostID) }
        return try block()
    }
}

// Usage
let results = PerformanceMonitor.measure("Search") {
    searchEngine.search(query: text)
}
```

### MetricKit

```swift
import MetricKit

class MetricsManager: NSObject, MXMetricManagerSubscriber {
    override init() {
        super.init()
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            // Log performance metrics
            if let cpuMetrics = payload.cpuMetrics {
                print("CPU time: \(cpuMetrics.cumulativeCPUTime)")
            }

            if let memoryMetrics = payload.memoryMetrics {
                print("Peak memory: \(memoryMetrics.peakMemoryUsage)")
            }

            if let launchMetrics = payload.applicationLaunchMetrics {
                print("Launch time: \(launchMetrics.histogrammedTimeToFirstDraw)")
            }
        }
    }
}
```

### Performance Logging

```swift
// ✅ Log performance in debug builds
#if DEBUG
func logPerformance(_ operation: String, duration: TimeInterval) {
    if duration > 0.1 { // Log slow operations
        print("⚠️ Slow operation: \(operation) took \(duration * 1000)ms")
    }
}
#endif
```

---

## Performance Checklist

### Before Release

- [ ] Profile with Time Profiler
- [ ] Check memory with Allocations
- [ ] Test with 10,000+ clipboard items
- [ ] Verify launch time <500ms
- [ ] Confirm idle CPU <1%
- [ ] Test on oldest supported hardware

### Ongoing

- [ ] Monitor MetricKit reports
- [ ] Track user-reported performance issues
- [ ] A/B test optimizations
- [ ] Review after major changes

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Architecture](../architecture/ARCHITECTURE.md) | System design |
| [Testing](../testing/TESTING.md) | Performance testing |
| [Monitoring](../operations/MONITORING_LOGGING.md) | Production monitoring |

---

*Last updated: 2026-02-03*
