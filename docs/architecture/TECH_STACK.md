# Technology Stack

> **Last Updated**: 2026-02-03 | **Reading Time**: 15 minutes

Comprehensive overview of technologies powering PasteShelf.

---

## Table of Contents

- [Overview](#overview)
- [Core Technologies](#core-technologies)
- [Apple Frameworks](#apple-frameworks)
- [Third-Party Dependencies](#third-party-dependencies)
- [Development Tools](#development-tools)
- [Infrastructure](#infrastructure)
- [Technology Decisions](#technology-decisions)

---

## Overview

PasteShelf is built as a native macOS application using Apple's latest technologies, prioritizing performance, privacy, and seamless system integration.

### Tech Stack Summary

```
┌─────────────────────────────────────────────────────────────┐
│                    PasteShelf Tech Stack                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  LANGUAGE            Swift 5.9+                              │
│  UI FRAMEWORK        SwiftUI + AppKit                        │
│  DATA PERSISTENCE    CoreData + CloudKit                     │
│  CONCURRENCY         Swift Concurrency (async/await)         │
│  SECURITY            Keychain + CryptoKit                    │
│  PLATFORM            macOS 14.0+ (Sonoma)                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Core Technologies

### Swift 5.9+

**Role**: Primary programming language

**Why Swift?**
- Type safety and modern syntax
- Excellent macOS integration
- Strong concurrency model
- Active development by Apple

**Key Features Used**:

```swift
// Swift Concurrency
func fetchItems() async throws -> [ClipboardItem] {
    try await withThrowingTaskGroup(of: ClipboardItem.self) { group in
        // Parallel processing
    }
}

// Property Wrappers
@MainActor
class ViewModel: ObservableObject {
    @Published var items: [ClipboardItem] = []
}

// Result Builders (SwiftUI)
var body: some View {
    VStack {
        ForEach(items) { item in
            ItemRow(item: item)
        }
    }
}

// Macros (Swift 5.9+)
@Observable
class AppState {
    var clipboardItems: [ClipboardItem] = []
}
```

### SwiftUI

**Role**: Primary UI framework

**Why SwiftUI?**
- Declarative, reactive UI
- Native macOS look and feel
- Automatic dark mode support
- Built-in accessibility

**Architecture**:

```
┌─────────────────────────────────────────────────────────────┐
│                     SwiftUI Architecture                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   View                    ViewModel               Model      │
│   ────                    ─────────               ─────      │
│                                                              │
│   ┌──────────┐     ┌───────────────┐     ┌──────────────┐  │
│   │ SwiftUI  │────▶│ ObservableObj │────▶│   CoreData   │  │
│   │   View   │     │   @Published  │     │    Entity    │  │
│   └──────────┘     └───────────────┘     └──────────────┘  │
│        │                   │                                 │
│        │    @StateObject   │    @FetchRequest               │
│        │    @EnvironmentObj│                                 │
│        ▼                   ▼                                 │
│   ┌─────────────────────────────────────────────────────┐   │
│   │              Combine Publishers                      │   │
│   │         (Reactive data flow)                         │   │
│   └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**Key Components**:

| Component | Usage |
|-----------|-------|
| `@State` | Local view state |
| `@Binding` | Two-way data binding |
| `@StateObject` | ViewModel ownership |
| `@EnvironmentObject` | Shared state |
| `@FetchRequest` | CoreData integration |
| `@AppStorage` | UserDefaults binding |

### CoreData

**Role**: Local data persistence

**Why CoreData?**
- Native Apple framework
- CloudKit integration built-in
- Efficient for large datasets
- Automatic migration support

**Configuration**:

```swift
// NSPersistentCloudKitContainer for sync support
let container = NSPersistentCloudKitContainer(name: "PasteShelf")

// Multiple store configuration
let localStoreDescription = NSPersistentStoreDescription(url: localURL)
localStoreDescription.configuration = "Local"

let cloudStoreDescription = NSPersistentStoreDescription(url: cloudURL)
cloudStoreDescription.configuration = "Cloud"
cloudStoreDescription.cloudKitContainerOptions = CKContainerOptions(
    containerIdentifier: "iCloud.com.pasteshelf.PasteShelf"
)
```

See [Database Schema](DATABASE_SCHEMA.md) for data model details.

### CloudKit ⭐

**Role**: Cross-device synchronization

**Why CloudKit?**
- Native Apple integration
- End-to-end encryption
- No server maintenance
- Generous free tier

**Architecture**:

```
┌─────────────────────────────────────────────────────────────┐
│                    CloudKit Architecture                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌───────────────────────────────────────────────────────┐ │
│   │                  Private Database                      │ │
│   │            (User's iCloud Account)                     │ │
│   │                                                        │ │
│   │  ┌────────────────────────────────────────────────┐   │ │
│   │  │              Custom Zone                        │   │ │
│   │  │     "com.pasteshelf.clipboardHistory"          │   │ │
│   │  │                                                 │   │ │
│   │  │  Record Types:                                  │   │ │
│   │  │  • ClipboardItem                               │   │ │
│   │  │  • ClipboardContent (asset)                    │   │ │
│   │  │  • UserPreferences                             │   │ │
│   │  └────────────────────────────────────────────────┘   │ │
│   └───────────────────────────────────────────────────────┘ │
│                                                              │
│   Sync Features:                                             │
│   • Automatic background sync                                │
│   • Conflict resolution (last-write-wins)                    │
│   • Incremental changes via CKFetchRecordZoneChangesOperation│
│   • Push notifications for real-time updates                 │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Apple Frameworks

### System Integration

| Framework | Purpose | Tier |
|-----------|---------|------|
| **AppKit** | Menu bar, floating panel | 🆓 |
| **Foundation** | Core utilities | 🆓 |
| **Combine** | Reactive programming | 🆓 |
| **OSLog** | Unified logging | 🆓 |
| **MetricKit** | Performance metrics | 🆓 |
| **LocalAuthentication** | Biometric auth | 🆓 |
| **CryptoKit** | Encryption | 🆓 |
| **NaturalLanguage** | Text analysis | ⭐ |
| **CreateML** | On-device ML | ⭐ |
| **Vision** | OCR for images | ⭐ |

### NSPasteboard (Clipboard)

**Core clipboard monitoring**:

```swift
import AppKit

class ClipboardMonitor {
    private var changeCount: Int = 0
    private var timer: Timer?

    func startMonitoring() {
        changeCount = NSPasteboard.general.changeCount

        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
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

        // Supported types
        let types: [NSPasteboard.PasteboardType] = [
            .string,
            .rtf,
            .html,
            .png,
            .tiff,
            .fileURL
        ]

        for type in types {
            if let data = pasteboard.data(forType: type) {
                // Process content
            }
        }
    }
}
```

### Security Framework

**Keychain integration**:

```swift
import Security

class KeychainManager {
    func save(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.pasteshelf.PasteShelf",
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
}
```

### CryptoKit

**End-to-end encryption**:

```swift
import CryptoKit

class EncryptionManager {
    private let key: SymmetricKey

    init() {
        // Generate or retrieve from Keychain
        key = SymmetricKey(size: .bits256)
    }

    func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }

    func decrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
}
```

### LocalAuthentication

**Biometric authentication**:

```swift
import LocalAuthentication

class BiometricAuth {
    func authenticate() async throws -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw BiometricError.notAvailable
        }

        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock PasteShelf"
        )
    }
}
```

### Vision Framework ⭐

**OCR for image search**:

```swift
import Vision

class OCREngine {
    func extractText(from image: CGImage) async throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results else {
            return ""
        }

        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}
```

### NaturalLanguage Framework ⭐

**Semantic search**:

```swift
import NaturalLanguage

class SemanticSearch {
    private let embedding = NLEmbedding.wordEmbedding(for: .english)

    func findSimilar(to query: String, in items: [ClipboardItem]) -> [ClipboardItem] {
        guard let queryVector = embedding?.vector(for: query) else {
            return []
        }

        return items
            .map { item in
                let similarity = cosineSimilarity(queryVector, item.embedding)
                return (item, similarity)
            }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }
}
```

---

## Third-Party Dependencies

### Dependency Philosophy

PasteShelf minimizes third-party dependencies to:
- Reduce attack surface
- Avoid licensing complications
- Ensure long-term maintainability
- Keep app size small

### Current Dependencies

| Dependency | Purpose | License |
|------------|---------|---------|
| **None** | Pure Apple frameworks | N/A |

### Potential Future Dependencies

| Dependency | Purpose | Consideration |
|------------|---------|---------------|
| SQLite.swift | Direct SQLite access | If CoreData limitations hit |
| KeychainAccess | Simplified Keychain | If Security API too complex |
| Sparkle | Auto-updates (non-App Store) | Direct distribution only |

---

## Development Tools

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| **Xcode** | 15.0+ | IDE and build system |
| **Swift** | 5.9+ | Compiler |
| **Git** | 2.30+ | Version control |
| **SwiftLint** | Latest | Code linting |
| **SwiftFormat** | Latest | Code formatting |

### CI/CD Tools

| Tool | Purpose |
|------|---------|
| **GitHub Actions** | CI/CD automation |
| **Fastlane** | Build and release automation |
| **xcpretty** | Prettier Xcode output |

### Testing Tools

| Tool | Purpose |
|------|---------|
| **XCTest** | Unit and UI testing |
| **XCUITest** | UI automation |
| **Instruments** | Performance profiling |

### Documentation Tools

| Tool | Purpose |
|------|---------|
| **DocC** | API documentation |
| **Markdown** | General documentation |

---

## Infrastructure

### Distribution Channels

```
┌─────────────────────────────────────────────────────────────┐
│                  Distribution Architecture                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌─────────────────┐      ┌─────────────────────────────┐  │
│   │   App Store     │      │    Direct Distribution      │  │
│   │   (Primary)     │      │    (Secondary)              │  │
│   │   ─────────     │      │    ──────────────           │  │
│   │                 │      │                             │  │
│   │   • Sandboxed   │      │   • DMG download            │  │
│   │   • Review      │      │   • Sparkle updates         │  │
│   │   • Auto-update │      │   • Notarized               │  │
│   │   • Payment     │      │   • Direct licensing        │  │
│   └─────────────────┘      └─────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Backend Services 🏢

For Enterprise features:

| Service | Provider | Purpose |
|---------|----------|---------|
| Sync Server | Self-hosted option | Air-gapped sync |
| Analytics | Privacy-respecting | Usage metrics |

---

## Technology Decisions

### Decision Records

#### ADR-001: SwiftUI vs AppKit

**Context**: Choose primary UI framework.

**Decision**: SwiftUI with AppKit interop.

**Rationale**:
- SwiftUI for main views (modern, declarative)
- AppKit for menu bar and floating panel (better control)
- Future-proof as SwiftUI matures

#### ADR-002: CoreData vs SQLite

**Context**: Choose persistence layer.

**Decision**: CoreData with NSPersistentCloudKitContainer.

**Rationale**:
- Built-in CloudKit sync
- Automatic migration
- Apple's strategic direction
- Good enough performance for clipboard data

#### ADR-003: CloudKit vs Custom Backend

**Context**: Choose sync infrastructure.

**Decision**: CloudKit for Pro, self-hosted option for Enterprise.

**Rationale**:
- CloudKit: Zero infrastructure, E2E encryption, Apple integration
- Self-hosted: Enterprise compliance requirements

#### ADR-004: On-Device ML vs Cloud AI

**Context**: Choose AI/ML strategy for semantic search.

**Decision**: On-device ML using CreateML/CoreML.

**Rationale**:
- Privacy: No data leaves device
- Performance: Low latency
- Offline: Works without internet
- Cost: No API fees

---

## Version Compatibility

### Minimum Requirements

| Component | Version | Release Date |
|-----------|---------|--------------|
| macOS | 14.0 (Sonoma) | Sep 2023 |
| Swift | 5.9 | Sep 2023 |
| Xcode | 15.0 | Sep 2023 |

### Target Versions

| Component | Version | Notes |
|-----------|---------|-------|
| macOS | 14.0 - 15.x | Sonoma and later |
| Swift | 5.9+ | Latest stable |
| Xcode | 15.0+ | Latest stable |

### Deprecated Support

| Version | Deprecation Date | EOL Date |
|---------|------------------|----------|
| macOS 13 | N/A (never supported) | N/A |

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Architecture](ARCHITECTURE.md) | System architecture |
| [Database Schema](DATABASE_SCHEMA.md) | Data models |
| [Build System](../deployment/BUILD_SYSTEM.md) | Build configuration |
| [Performance](../reference/PERFORMANCE_OPTIMIZATION.md) | Optimization |

---

*Last updated: 2026-02-03*
