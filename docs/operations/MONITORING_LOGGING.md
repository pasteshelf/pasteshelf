# Monitoring & Logging

> **Last Updated**: 2026-02-03 | **Reading Time**: 12 minutes

Guide for monitoring and logging in PasteShelf.

---

## Table of Contents

- [Logging System](#logging-system)
- [Metrics Collection](#metrics-collection)
- [Crash Reporting](#crash-reporting)
- [Performance Monitoring](#performance-monitoring)

---

## Logging System

### OSLog Integration

```swift
import os

extension Logger {
    static let clipboard = Logger(subsystem: "com.pasteshelf.PasteShelf", category: "clipboard")
    static let search = Logger(subsystem: "com.pasteshelf.PasteShelf", category: "search")
    static let sync = Logger(subsystem: "com.pasteshelf.PasteShelf", category: "sync")
    static let security = Logger(subsystem: "com.pasteshelf.PasteShelf", category: "security")
}

// Usage
Logger.clipboard.debug("Captured item: \(item.id)")
Logger.sync.error("Sync failed: \(error.localizedDescription)")
```

### Log Levels

| Level | Use Case |
|-------|----------|
| `.debug` | Development debugging |
| `.info` | General information |
| `.notice` | Notable events |
| `.error` | Errors |
| `.fault` | Critical failures |

### Viewing Logs

```bash
# Stream logs
log stream --predicate 'subsystem == "com.pasteshelf.PasteShelf"'

# Show last hour
log show --predicate 'subsystem == "com.pasteshelf.PasteShelf"' --last 1h

# Filter by category
log show --predicate 'subsystem == "com.pasteshelf.PasteShelf" AND category == "sync"'
```

---

## Metrics Collection

### MetricKit Integration

```swift
import MetricKit

class MetricsManager: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricsManager()

    func startCollecting() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            // Process CPU metrics
            if let cpuMetrics = payload.cpuMetrics {
                Logger.metrics.info("CPU time: \(cpuMetrics.cumulativeCPUTime)")
            }

            // Process memory metrics
            if let memoryMetrics = payload.memoryMetrics {
                Logger.metrics.info("Peak memory: \(memoryMetrics.peakMemoryUsage)")
            }
        }
    }
}
```

### Custom Metrics

```swift
struct ClipboardMetrics {
    static var captureCount: Int = 0
    static var searchCount: Int = 0
    static var pasteCount: Int = 0

    static func recordCapture() {
        captureCount += 1
        Logger.metrics.debug("Captures: \(captureCount)")
    }
}
```

---

## Crash Reporting

### Crash Log Location

```
~/Library/Logs/DiagnosticReports/PasteShelf_*.crash
```

### Symbolication

```bash
# Symbolicate crash log
atos -arch arm64 -o PasteShelf.app.dSYM/Contents/Resources/DWARF/PasteShelf \
    -l 0x100000000 0x1000012ab
```

---

## Performance Monitoring

### Instruments Profiling

- **Time Profiler**: CPU usage
- **Allocations**: Memory leaks
- **Core Data**: Database performance
- **Network**: Sync traffic

### Signposts

```swift
import os

let signposter = OSSignposter(subsystem: "com.pasteshelf.PasteShelf", category: "Performance")

func searchItems(query: String) {
    let signpostID = signposter.makeSignpostID()
    let state = signposter.beginInterval("Search", id: signpostID)

    // Perform search
    let results = performSearch(query)

    signposter.endInterval("Search", state)
}
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Maintenance](MAINTENANCE.md) | Regular maintenance |
| [Troubleshooting](TROUBLESHOOTING.md) | Common issues |

---

*Last updated: 2026-02-03*
