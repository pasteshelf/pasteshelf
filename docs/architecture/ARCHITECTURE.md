# Architecture Overview

> **Last Updated**: 2026-02-03 | **Reading Time**: 25 minutes

Comprehensive architecture documentation for PasteShelf.

---

## Table of Contents

- [System Overview](#system-overview)
- [Architecture Principles](#architecture-principles)
- [High-Level Architecture](#high-level-architecture)
- [Core Components](#core-components)
- [Data Architecture](#data-architecture)
- [Security Architecture](#security-architecture)
- [Scalability Considerations](#scalability-considerations)
- [Cross-Cutting Concerns](#cross-cutting-concerns)

---

## System Overview

PasteShelf is a privacy-first clipboard manager for macOS built with a modular, layered architecture that enables:

- **Clean separation** between UI, business logic, and data layers
- **Testability** through dependency injection and protocols
- **Extensibility** via plugin system
- **Scalability** from individual users to enterprise deployments

### Key Characteristics

| Aspect | Approach |
|--------|----------|
| **Platform** | Native macOS (AppKit/SwiftUI) |
| **Language** | Swift 5.9+ |
| **Persistence** | CoreData with CloudKit |
| **Concurrency** | Swift Concurrency (async/await) |
| **UI Framework** | SwiftUI with AppKit interop |
| **Architecture Pattern** | MVVM + Clean Architecture |

---

## Architecture Principles

### 1. Privacy by Design

```
┌─────────────────────────────────────────────────────────────┐
│  All sensitive operations happen LOCALLY                     │
│  ─────────────────────────────────────────────────────────   │
│  • Clipboard capture: Local NSPasteboard                     │
│  • Storage: Local CoreData with encryption                   │
│  • Search: Local index with optional on-device ML            │
│  • Sync: E2E encrypted CloudKit or self-hosted                │
└─────────────────────────────────────────────────────────────┘
```

### 2. Layered Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  SwiftUI Views, ViewModels, UI State Management              │
├─────────────────────────────────────────────────────────────┤
│                    DOMAIN LAYER                              │
│  Business Logic, Use Cases, Domain Models                    │
├─────────────────────────────────────────────────────────────┤
│                    DATA LAYER                                │
│  Repositories, CoreData, CloudKit, Keychain                  │
├─────────────────────────────────────────────────────────────┤
│                    INFRASTRUCTURE                            │
│  System APIs, NSPasteboard, Networking, File System          │
└─────────────────────────────────────────────────────────────┘
```

### 3. Dependency Rule

Dependencies flow inward only:
- Presentation depends on Domain
- Data implements Domain interfaces
- Domain has no external dependencies

### 4. Feature Modularity

Each feature is self-contained:

```
Feature/
├── View.swift           # SwiftUI View
├── ViewModel.swift      # Presentation logic
├── UseCase.swift        # Business logic
├── Repository.swift     # Data access
└── Tests/              # Feature tests
```

---

## High-Level Architecture

### System Context

```
┌─────────────────────────────────────────────────────────────────────┐
│                         macOS System                                 │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────────────┐   │
│  │  Applications │  │   System UI   │  │    System Services    │   │
│  │  (Copy/Paste) │  │  (Menu Bar)   │  │  (Keychain, CloudKit) │   │
│  └───────┬───────┘  └───────┬───────┘  └───────────┬───────────┘   │
│          │                  │                      │                │
│          ▼                  ▼                      ▼                │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                       PasteShelf                              │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────┐ │  │
│  │  │  Clipboard │  │   Search   │  │   Storage  │  │  Sync  │ │  │
│  │  │   Engine   │  │   Engine   │  │   Engine   │  │ Engine │ │  │
│  │  └────────────┘  └────────────┘  └────────────┘  └────────┘ │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │       CloudKit          │
                    │   (Apple's Servers)     │
                    │   E2E Encrypted         │
                    └─────────────────────────┘
```

### Component Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            PasteShelf App                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                     Presentation Layer                            │   │
│  │                                                                   │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌────────────┐ │   │
│  │  │  Floating   │ │    Main     │ │   Menu Bar  │ │ Preferences│ │   │
│  │  │   Panel     │ │   Window    │ │             │ │            │ │   │
│  │  │   ┌─────┐   │ │   ┌─────┐   │ │   ┌─────┐   │ │   ┌─────┐  │ │   │
│  │  │   │View │   │ │   │View │   │ │   │View │   │ │   │View │  │ │   │
│  │  │   └──┬──┘   │ │   └──┬──┘   │ │   └──┬──┘   │ │   └──┬──┘  │ │   │
│  │  │      │      │ │      │      │ │      │      │ │      │     │ │   │
│  │  │   ┌──┴──┐   │ │   ┌──┴──┐   │ │   ┌──┴──┐   │ │   ┌──┴──┐  │ │   │
│  │  │   │ VM  │   │ │   │ VM  │   │ │   │ VM  │   │ │   │ VM  │  │ │   │
│  │  │   └─────┘   │ │   └─────┘   │ │   └─────┘   │ │   └─────┘  │ │   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └────────────┘ │   │
│  │                                                                   │   │
│  └───────────────────────────────┬───────────────────────────────────┘   │
│                                  │                                       │
│  ┌───────────────────────────────┴───────────────────────────────────┐   │
│  │                        Domain Layer                                │   │
│  │                                                                    │   │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────────┐  │   │
│  │  │   Clipboard    │  │     Search     │  │      Storage       │  │   │
│  │  │   Use Cases    │  │   Use Cases    │  │    Use Cases       │  │   │
│  │  │                │  │                │  │                    │  │   │
│  │  │ • Capture      │  │ • Query        │  │ • Save Item        │  │   │
│  │  │ • Parse Type   │  │ • Filter       │  │ • Delete Item      │  │   │
│  │  │ • Detect Sens. │  │ • Rank Results │  │ • Export/Import    │  │   │
│  │  └────────────────┘  └────────────────┘  └────────────────────┘  │   │
│  │                                                                    │   │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────────┐  │   │
│  │  │    Security    │  │   Config       │  │      Sync          │  │   │
│  │  │   Use Cases    │  │   Use Cases    │  │    Use Cases       │  │   │
│  │  │                │  │                │  │                    │  │   │
│  │  │ • Encrypt      │  │ • App Settings │  │ • Push Changes     │  │   │
│  │  │ • Biometric    │  │ • Settings     │  │ • Pull Changes     │  │   │
│  │  │ • Audit Log    │  │ • Preferences  │  │ • Resolve Conflict │  │   │
│  │  └────────────────┘  └────────────────┘  └────────────────────┘  │   │
│  │                                                                    │   │
│  └───────────────────────────────┬────────────────────────────────────┘   │
│                                  │                                        │
│  ┌───────────────────────────────┴────────────────────────────────────┐  │
│  │                         Data Layer                                  │  │
│  │                                                                     │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────┐  ┌──────────┐ │  │
│  │  │   CoreData   │  │   CloudKit   │  │  Keychain  │  │  Files   │ │  │
│  │  │  Repository  │  │  Repository  │  │ Repository │  │Repository│ │  │
│  │  │              │  │              │  │            │  │          │ │  │
│  │  │ Local Store  │  │  Sync Store  │  │  Secrets   │  │  Images  │ │  │
│  │  │ Search Index │  │  E2E Encrypt │  │  Keys      │  │  Exports │ │  │
│  │  └──────────────┘  └──────────────┘  └────────────┘  └──────────┘ │  │
│  │                                                                     │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. Clipboard Engine

**Responsibility**: Monitor system clipboard and capture items.

```
┌───────────────────────────────────────────────────────────────┐
│                    Clipboard Engine                            │
├───────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────┐        ┌───────────────────────────┐   │
│  │  NSPasteboard    │◀──poll──│   ClipboardMonitor       │   │
│  │  (System)        │         │   ─────────────────       │   │
│  └──────────────────┘         │   • changeCount tracking │   │
│                               │   • Timer-based polling  │   │
│                               │   • 250ms interval       │   │
│                               └────────────┬──────────────┘   │
│                                            │                   │
│                                            ▼                   │
│                               ┌───────────────────────────┐   │
│                               │   ContentParser           │   │
│                               │   ─────────────            │   │
│                               │   • Text extraction       │   │
│                               │   • Image processing      │   │
│                               │   • File reference        │   │
│                               │   • Rich text (RTF/HTML)  │   │
│                               └────────────┬──────────────┘   │
│                                            │                   │
│                                            ▼                   │
│                               ┌───────────────────────────┐   │
│                               │   SensitiveDataDetector   │   │
│                               │   ───────────────────────  │   │
│                               │   • Password patterns     │   │
│                               │   • API keys              │   │
│                               │   • Credit card numbers   │   │
│                               │   • App exclusion rules   │   │
│                               └────────────┬──────────────┘   │
│                                            │                   │
│                                            ▼                   │
│                               ┌───────────────────────────┐   │
│                               │   ClipboardItem           │   │
│                               │   (Domain Model)          │   │
│                               └───────────────────────────┘   │
└───────────────────────────────────────────────────────────────┘
```

**Key Interfaces**:

```swift
protocol ClipboardMonitorProtocol {
    var isMonitoring: Bool { get }
    func startMonitoring()
    func stopMonitoring()
    var onItemCaptured: ((ClipboardItem) -> Void)? { get set }
}

protocol ContentParserProtocol {
    func parse(_ pasteboard: NSPasteboard) -> ClipboardContent?
}

protocol SensitiveDataDetectorProtocol {
    func isSensitive(_ content: String) -> Bool
    func shouldExcludeApp(_ bundleId: String) -> Bool
}
```

See [Clipboard Engine](../features/CLIPBOARD_ENGINE.md) for detailed documentation.

### 2. Search Engine

**Responsibility**: Index and search clipboard history.

```
┌───────────────────────────────────────────────────────────────┐
│                      Search Engine                             │
├───────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                    Search Pipeline                        │ │
│  │                                                           │ │
│  │   Query ──▶ Tokenize ──▶ Search Index ──▶ Rank ──▶ Results │
│  │                              │                            │ │
│  │                              ▼                            │ │
│  │                    ┌─────────────────┐                   │ │
│  │                    │  Search Modes   │                   │ │
│  │                    │  ─────────────  │                   │ │
│  │                    │  • Full-text    │                   │ │
│  │                    │  • Fuzzy       │                   │ │
│  │                    │  • Semantic    │                   │ │
│  │                    │  • OCR         │                   │ │
│  │                    └─────────────────┘                   │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                    Search Index                           │ │
│  │                                                           │ │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────┐ │ │
│  │  │ NSUserActivity │  │  Spotlight     │  │  In-Memory │ │ │
│  │  │    Index       │  │   Index        │  │    Cache   │ │ │
│  │  │                │  │                │  │            │ │ │
│  │  │  Searchable    │  │  System-wide   │  │  Hot items │ │ │
│  │  │  from Spotlight│  │  integration   │  │  Fast      │ │ │
│  │  └────────────────┘  └────────────────┘  └────────────┘ │ │
│  └──────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

See [Search Engine](../features/SEARCH_ENGINE.md) for detailed documentation.

### 3. Storage Engine

**Responsibility**: Persist clipboard items locally.

```
┌───────────────────────────────────────────────────────────────┐
│                     Storage Engine                             │
├───────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                    CoreData Stack                         │ │
│  │                                                           │ │
│  │   ┌─────────────────────────────────────────────────┐    │ │
│  │   │       NSPersistentCloudKitContainer             │    │ │
│  │   │       ──────────────────────────────            │    │ │
│  │   │       Unified local + cloud container           │    │ │
│  │   └─────────────────────┬───────────────────────────┘    │ │
│  │                         │                                 │ │
│  │   ┌─────────────────────┴───────────────────────────┐    │ │
│  │   │              Persistent Stores                   │    │ │
│  │   │                                                  │    │ │
│  │   │  ┌──────────────────┐  ┌──────────────────────┐ │    │ │
│  │   │  │   Local Store    │  │   CloudKit Store     │ │    │ │
│  │   │  │   ────────────   │  │   ─────────────────  │ │    │ │
│  │   │  │   SQLite DB      │  │   Private Database   │ │    │ │
│  │   │  │   ~/Library/     │  │   E2E Encrypted      │ │    │ │
│  │   │  │   Application    │  │   iCloud Account     │ │    │ │
│  │   │  │   Support/       │  │                      │ │    │ │
│  │   │  └──────────────────┘  └──────────────────────┘ │    │ │
│  │   └──────────────────────────────────────────────────┘    │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                    Data Management                        │ │
│  │                                                           │ │
│  │  • Automatic migration between schema versions            │ │
│  │  • Background context for write operations                │ │
│  │  • Main context for UI reads                              │ │
│  │  • Batch delete for history cleanup                       │ │
│  │  • Export/Import for backup                               │ │
│  └──────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

See [Database Schema](DATABASE_SCHEMA.md) for detailed documentation.

### 4. Sync Engine

**Responsibility**: Sync clipboard history across devices.

```
┌───────────────────────────────────────────────────────────────┐
│                      Sync Engine                               │
├───────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                CloudKit Integration                       │ │
│  │                                                           │ │
│  │  Device A          CloudKit            Device B           │ │
│  │  ────────          ────────            ────────           │ │
│  │                                                           │ │
│  │  ┌──────┐    Push   ┌──────┐   Push    ┌──────┐          │ │
│  │  │Local │ ────────▶ │Cloud │ ────────▶ │Local │          │ │
│  │  │Store │ ◀──────── │  DB  │ ◀──────── │Store │          │ │
│  │  └──────┘    Pull   └──────┘   Pull    └──────┘          │ │
│  │                         │                                 │ │
│  │                         │ E2E Encryption                  │ │
│  │                         ▼                                 │ │
│  │              ┌───────────────────┐                       │ │
│  │              │ Encryption Layer  │                       │ │
│  │              │ ─────────────────  │                       │ │
│  │              │ • Device key pair │                       │ │
│  │              │ • Symmetric key   │                       │ │
│  │              │ • Key rotation    │                       │ │
│  │              └───────────────────┘                       │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                Conflict Resolution                        │ │
│  │                                                           │ │
│  │  Strategy: Last-Write-Wins with timestamp                 │ │
│  │                                                           │ │
│  │  ┌─────────┐      ┌─────────┐      ┌─────────┐          │ │
│  │  │ Detect  │ ───▶ │ Compare │ ───▶ │ Resolve │          │ │
│  │  │Conflict │      │Timestamp│      │ & Merge │          │ │
│  │  └─────────┘      └─────────┘      └─────────┘          │ │
│  └──────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

See [Sync Engine](../features/SYNC_ENGINE.md) for detailed documentation.

### 5. Security Engine

**Responsibility**: Encryption, authentication, and privacy protection.

```
┌───────────────────────────────────────────────────────────────┐
│                     Security Engine                            │
├───────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                   Encryption Layer                        │ │
│  │                                                           │ │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────┐ │ │
│  │  │  At-Rest       │  │  In-Transit    │  │  In-Memory │ │ │
│  │  │  Encryption    │  │  Encryption    │  │  Protection│ │ │
│  │  │  ────────────  │  │  ────────────  │  │  ────────── │ │ │
│  │  │  AES-256-GCM   │  │  TLS 1.3       │  │  Secure    │ │ │
│  │  │  FileVault     │  │  Certificate   │  │  Enclave   │ │ │
│  │  │  integration   │  │  pinning       │  │            │ │ │
│  │  └────────────────┘  └────────────────┘  └────────────┘ │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                 Authentication Layer                      │ │
│  │                                                           │ │
│  │  ┌──────────────────┐    ┌──────────────────────────┐   │ │
│  │  │  Biometric Auth  │    │     SSO / Enterprise     │   │ │
│  │  │  ──────────────  │    │     ─────────────────    │   │ │
│  │  │  • Touch ID      │    │     • SAML 2.0           │   │ │
│  │  │  • Watch unlock  │    │     • OIDC               │   │ │
│  │  │  • Password      │    │     • Token management   │   │ │
│  │  └──────────────────┘    └──────────────────────────┘   │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                   Keychain Integration                    │ │
│  │                                                           │ │
│  │  Stored in Keychain:                                      │ │
│  │  • Encryption keys                                        │ │
│  │  • Sync credentials                                       │ │
│  │  • SSO tokens                                             │ │
│  │  • Sensitive preferences                                  │ │
│  └──────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

See [Security](../security/SECURITY.md) for detailed documentation.

---

## Data Architecture

### Data Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│                           Data Flow                                     │
├────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   CAPTURE                 PROCESS                 STORE                 │
│   ───────                 ───────                 ─────                 │
│                                                                         │
│   ┌─────────┐    ┌─────────────────┐    ┌───────────────────────────┐ │
│   │Clipboard│───▶│  Parse Content  │───▶│      CoreData Store       │ │
│   │ Event   │    │  Detect Type    │    │                           │ │
│   └─────────┘    │  Check Privacy  │    │  ClipboardItem            │ │
│                  └─────────────────┘    │  ├── id: UUID             │ │
│                                         │  ├── content: Data        │ │
│                                         │  ├── contentType: String  │ │
│                                         │  ├── timestamp: Date      │ │
│                                         │  ├── metadata: JSON       │ │
│                                         │  └── isSensitive: Bool    │ │
│                                         └────────────┬──────────────┘ │
│                                                      │                 │
│   RETRIEVE                SEARCH                     │                 │
│   ────────                ──────                     │                 │
│                                                      ▼                 │
│   ┌─────────┐    ┌─────────────────┐    ┌───────────────────────────┐ │
│   │  User   │◀───│  Search Index   │◀───│      Index Update         │ │
│   │  Query  │    │  Rank Results   │    │  (Background)             │ │
│   └─────────┘    └─────────────────┘    └───────────────────────────┘ │
│                                                                         │
│   SYNC                                                                 │
│   ──────────                                                           │
│                                                                         │
│   ┌───────────────┐    ┌──────────────┐    ┌────────────────────────┐ │
│   │ Local Change  │───▶│  Encrypt     │───▶│  CloudKit Push         │ │
│   └───────────────┘    │  (AES-256)   │    └────────────────────────┘ │
│                        └──────────────┘                                │
│                                                                         │
│   ┌───────────────┐    ┌──────────────┐    ┌────────────────────────┐ │
│   │  Merge Local  │◀───│  Decrypt     │◀───│  CloudKit Pull         │ │
│   └───────────────┘    │              │    └────────────────────────┘ │
│                        └──────────────┘                                │
└────────────────────────────────────────────────────────────────────────┘
```

### State Management

```
┌───────────────────────────────────────────────────────────────┐
│                    State Architecture                          │
├───────────────────────────────────────────────────────────────┤
│                                                                │
│   ┌────────────────────────────────────────────────────────┐  │
│   │                   App State                             │  │
│   │                                                         │  │
│   │  @MainActor                                             │  │
│   │  class AppState: ObservableObject {                     │  │
│   │      @Published var clipboardItems: [ClipboardItem]     │  │
│   │      @Published var searchQuery: String                 │  │
│   │      @Published var selectedItem: ClipboardItem?        │  │
│   │      @Published var isLoading: Bool                     │  │
│   │      @Published var syncStatus: SyncStatus              │  │
│   │  }                                                      │  │
│   └────────────────────────────────────────────────────────┘  │
│                             │                                  │
│                             ▼                                  │
│   ┌────────────────────────────────────────────────────────┐  │
│   │               View-Specific State                       │  │
│   │                                                         │  │
│   │  struct FloatingPanelState {                            │  │
│   │      var isVisible: Bool                                │  │
│   │      var position: CGPoint                              │  │
│   │      var filteredItems: [ClipboardItem]                 │  │
│   │  }                                                      │  │
│   └────────────────────────────────────────────────────────┘  │
│                                                                │
│   Data Flow: Unidirectional                                   │
│                                                                │
│   Action ──▶ State ──▶ View ──▶ Action                       │
│                                                                │
└───────────────────────────────────────────────────────────────┘
```

---

## Security Architecture

### Threat Model

```
┌───────────────────────────────────────────────────────────────┐
│                      Threat Model                              │
├───────────────────────────────────────────────────────────────┤
│                                                                │
│   THREAT                  MITIGATION                           │
│   ──────                  ──────────                           │
│                                                                │
│   Clipboard sniffing      • Secure app detection               │
│   (malware)               • Password manager exclusion         │
│                           • Sensitive data detection           │
│                                                                │
│   Data at rest            • CoreData encryption                │
│   (device theft)          • FileVault integration              │
│                           • Keychain for secrets               │
│                                                                │
│   Data in transit         • E2E encryption for sync            │
│   (network attack)        • Certificate pinning                │
│                           • TLS 1.3 only                       │
│                                                                │
│   Unauthorized access     • Biometric authentication           │
│   (physical access)       • Auto-lock timeout                  │
│                           • Require unlock for sensitive       │
│                                                                │
│   Memory attack           • Secure Enclave usage               │
│   (memory dump)           • Clear sensitive data promptly      │
│                           • No plaintext passwords in memory   │
│                                                                │
└───────────────────────────────────────────────────────────────┘
```

See [Security Documentation](../security/SECURITY.md) for complete threat model.

---

## Scalability Considerations

### Performance Targets

| Metric | Target | Measured |
|--------|--------|----------|
| Clipboard capture latency | < 50ms | TBD |
| Search response time | < 100ms | TBD |
| Memory usage (10K items) | < 200MB | TBD |
| Startup time | < 1s | TBD |
| Sync latency | < 2s | TBD |

### Optimization Strategies

1. **Lazy Loading**: Load items on demand
2. **Pagination**: Limit displayed items
3. **Background Indexing**: Index in background thread
4. **Thumbnail Caching**: Pre-generate image previews
5. **Batch Operations**: Batch CoreData writes

See [Performance Optimization](../reference/PERFORMANCE_OPTIMIZATION.md) for details.

---

## Cross-Cutting Concerns

### Logging

```swift
import os

let logger = Logger(subsystem: "com.pasteshelf.PasteShelf", category: "Category")

// Levels: debug, info, notice, error, fault
logger.debug("Debug message")
logger.info("Info message")
logger.error("Error: \(error.localizedDescription)")
```

### Error Handling

```swift
enum PasteShelfError: Error {
    case clipboardAccessDenied
    case storageFailure(underlying: Error)
    case syncConflict
}

// Usage
func captureItem() async throws {
    guard hasAccessibilityPermission else {
        throw PasteShelfError.clipboardAccessDenied
    }
    // ...
}
```

### User Settings

```swift
// Usage
@AppStorage("cloudSync") var isCloudSyncEnabled: Bool = false
@AppStorage("maxHistoryItems") var maxHistoryItems: Int = 1000
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Tech Stack](TECH_STACK.md) | Technology choices |
| [Database Schema](DATABASE_SCHEMA.md) | Data models |
| [Security](../security/SECURITY.md) | Security details |
| [Performance](../reference/PERFORMANCE_OPTIMIZATION.md) | Optimization |

---

*Last updated: 2026-02-03*
