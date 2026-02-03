# Repository Structure

> **Last Updated**: 2026-02-03 | **Reading Time**: 10 minutes

Organization of PasteShelf's public and private repositories.

---

## Table of Contents

- [Overview](#overview)
- [Public Repository](#public-repository)
- [Private Repository](#private-repository)
- [Build Integration](#build-integration)
- [Contribution Flow](#contribution-flow)

---

## Overview

PasteShelf uses a split repository model for open-core development:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     Repository Architecture                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                   PUBLIC REPOSITORY                              │   │
│   │                   github.com/pasteshelf/pasteshelf               │   │
│   │                                                                  │   │
│   │   License: AGPL-3.0                                              │   │
│   │   Content: Community Edition features                            │   │
│   │   Access:  Open to everyone                                      │   │
│   │                                                                  │   │
│   │   ┌─────────────────────────────────────────────────────────┐   │   │
│   │   │  • Core clipboard engine                                 │   │   │
│   │   │  • Basic search                                          │   │   │
│   │   │  • Local storage                                         │   │   │
│   │   │  • UI components                                         │   │   │
│   │   │  • Documentation                                         │   │   │
│   │   │  • Community contributions                               │   │   │
│   │   └─────────────────────────────────────────────────────────┘   │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                      │                                   │
│                                      │ git submodule                     │
│                                      ▼                                   │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                   PRIVATE REPOSITORY                             │   │
│   │                   github.com/pasteshelf/pasteshelf-pro           │   │
│   │                                                                  │   │
│   │   License: Proprietary                                           │   │
│   │   Content: Pro & Enterprise features                             │   │
│   │   Access:  PasteShelf team only                                  │   │
│   │                                                                  │   │
│   │   ┌─────────────────────────────────────────────────────────┐   │   │
│   │   │  • CloudKit sync engine                                  │   │   │
│   │   │  • AI/ML models & semantic search                        │   │   │
│   │   │  • OCR processing                                        │   │   │
│   │   │  • Automation engine                                     │   │   │
│   │   │  • Plugin system                                         │   │   │
│   │   │  • Enterprise features (SSO, admin, etc.)               │   │   │
│   │   │  • License validation                                    │   │   │
│   │   └─────────────────────────────────────────────────────────┘   │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Public Repository

### Repository: `github.com/pasteshelf/pasteshelf`

```
pasteshelf/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml              # Continuous integration
│   │   ├── release.yml         # Release automation
│   │   └── codeql.yml          # Security scanning
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml
│   │   ├── feature_request.yml
│   │   └── config.yml
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── CODEOWNERS
│   └── FUNDING.yml
│
├── PasteShelf/                  # Main application
│   ├── PasteShelfApp.swift     # App entry point
│   ├── ContentView.swift       # Main view
│   ├── Persistence.swift       # CoreData controller
│   │
│   ├── Core/                   # 🆓 Core functionality
│   │   ├── Clipboard/
│   │   │   ├── ClipboardMonitor.swift
│   │   │   ├── ClipboardItem.swift
│   │   │   ├── ContentParser.swift
│   │   │   └── ContentType.swift
│   │   ├── Search/
│   │   │   ├── SearchEngine.swift
│   │   │   ├── FullTextSearch.swift
│   │   │   └── FuzzySearch.swift
│   │   ├── Storage/
│   │   │   ├── StorageManager.swift
│   │   │   └── MigrationManager.swift
│   │   └── Security/
│   │       ├── SensitiveDataDetector.swift
│   │       ├── BiometricAuth.swift
│   │       └── EncryptionManager.swift
│   │
│   ├── UI/                     # 🆓 User interface
│   │   ├── FloatingPanel/
│   │   ├── MainWindow/
│   │   ├── MenuBar/
│   │   ├── Preferences/
│   │   └── Components/
│   │
│   ├── Models/                 # 🆓 Data models
│   ├── Extensions/             # 🆓 Swift extensions
│   ├── Utilities/              # 🆓 Utilities
│   │
│   ├── Pro/                    # ⭐ Pro stubs (interface only)
│   │   ├── ProFeatures.swift   # Protocol definitions
│   │   └── ProStubs.swift      # Placeholder implementations
│   │
│   └── Resources/
│       ├── Assets.xcassets/
│       ├── Localizable.xcstrings
│       └── PasteShelf.xcdatamodeld/
│
├── PasteShelfTests/            # Unit tests
├── PasteShelfUITests/          # UI tests
│
├── docs/                       # Documentation
│   ├── getting-started/
│   ├── architecture/
│   ├── features/
│   └── ...
│
├── fastlane/                   # Build automation
│
├── .swiftlint.yml
├── .swiftformat
├── .gitignore
├── LICENSE                     # AGPL-3.0
├── README.md
├── CONTRIBUTING.md
├── CHANGELOG.md
└── PasteShelf.xcodeproj
```

### What's Public

| Component | Location | Description |
|-----------|----------|-------------|
| Core clipboard | `Core/Clipboard/` | Monitoring, capture, parsing |
| Basic search | `Core/Search/` | Full-text, fuzzy search |
| Local storage | `Core/Storage/` | CoreData persistence |
| Basic security | `Core/Security/` | Biometrics, encryption |
| All UI | `UI/` | Complete user interface |
| Documentation | `docs/` | All documentation |
| Tests | `*Tests/` | Unit and UI tests |
| CI/CD | `.github/workflows/` | Build automation |

---

## Private Repository

### Repository: `github.com/pasteshelf/pasteshelf-pro`

```
pasteshelf-pro/
├── ProFeatures/                # ⭐ Pro features
│   ├── Sync/
│   │   ├── SyncEngine.swift
│   │   ├── CloudKitProvider.swift
│   │   ├── ConflictResolver.swift
│   │   └── SyncEncryption.swift
│   │
│   ├── AISearch/
│   │   ├── SemanticSearch.swift
│   │   ├── EmbeddingManager.swift
│   │   └── Models/
│   │       └── SearchModel.mlmodel
│   │
│   ├── OCR/
│   │   ├── OCREngine.swift
│   │   └── OCRIndexer.swift
│   │
│   ├── Automation/
│   │   ├── RuleEngine.swift
│   │   ├── ActionExecutor.swift
│   │   └── JSRuntime.swift
│   │
│   ├── Plugins/
│   │   ├── PluginManager.swift
│   │   ├── PluginLoader.swift
│   │   └── PluginSandbox.swift
│   │
│   └── Licensing/
│       ├── LicenseManager.swift
│       ├── LicenseValidator.swift
│       └── FeatureFlags.swift
│
├── EnterpriseFeatures/         # 🏢 Enterprise features
│   ├── Team/
│   │   ├── TeamSync.swift
│   │   └── SharedSnippets.swift
│   │
│   ├── Admin/
│   │   ├── AdminConsole.swift
│   │   ├── PolicyManager.swift
│   │   └── AuditLogger.swift
│   │
│   ├── SSO/
│   │   ├── SSOManager.swift
│   │   ├── SAMLProvider.swift
│   │   └── OIDCProvider.swift
│   │
│   ├── MDM/
│   │   └── MDMConfiguration.swift
│   │
│   └── Compliance/
│       ├── DLPEngine.swift
│       └── RetentionManager.swift
│
├── LicenseServer/              # License server (separate deployment)
│   ├── src/
│   ├── migrations/
│   └── Dockerfile
│
├── Tests/
│   ├── ProTests/
│   └── EnterpriseTests/
│
└── Package.swift               # Swift package definition
```

### What's Private

| Component | Location | Description |
|-----------|----------|-------------|
| CloudKit sync | `ProFeatures/Sync/` | Cross-device sync |
| AI search | `ProFeatures/AISearch/` | Semantic search, ML models |
| OCR | `ProFeatures/OCR/` | Image text extraction |
| Automation | `ProFeatures/Automation/` | Rules, actions, JS runtime |
| Plugins | `ProFeatures/Plugins/` | Plugin system |
| Licensing | `ProFeatures/Licensing/` | License validation |
| Team features | `EnterpriseFeatures/Team/` | Team sync, sharing |
| Admin | `EnterpriseFeatures/Admin/` | Admin console |
| SSO | `EnterpriseFeatures/SSO/` | SAML/OIDC |
| Compliance | `EnterpriseFeatures/Compliance/` | DLP, retention |
| License server | `LicenseServer/` | Server components |

---

## Build Integration

### Swift Package Integration

```swift
// Package.swift (private repo)
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PasteShelfPro",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ProFeatures", targets: ["ProFeatures"]),
        .library(name: "EnterpriseFeatures", targets: ["EnterpriseFeatures"])
    ],
    dependencies: [
        // Public repo as dependency
        .package(url: "https://github.com/pasteshelf/pasteshelf.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "ProFeatures",
            dependencies: [
                .product(name: "PasteShelfCore", package: "pasteshelf")
            ]
        ),
        .target(
            name: "EnterpriseFeatures",
            dependencies: ["ProFeatures"]
        )
    ]
)
```

### Build Configurations

```ruby
# Fastlane configuration
lane :build_community do
  # Build with only public code
  build_app(
    scheme: "PasteShelf-Community",
    configuration: "Release",
    export_method: "app-store"
  )
end

lane :build_pro do
  # Include private Pro features
  sh("git submodule update --init --recursive")
  build_app(
    scheme: "PasteShelf-Pro",
    configuration: "Release",
    export_method: "app-store"
  )
end

lane :build_enterprise do
  # Include all features
  sh("git submodule update --init --recursive")
  build_app(
    scheme: "PasteShelf-Enterprise",
    configuration: "Release",
    export_method: "enterprise"
  )
end
```

### Conditional Compilation

```swift
// In public repo - Pro stubs
#if PASTESHELF_PRO
import ProFeatures
let syncEngine = SyncEngine()
#else
let syncEngine: SyncEngineProtocol? = nil
#endif

// Protocol in public repo
protocol SyncEngineProtocol {
    func startSync() async throws
    func stopSync()
    var syncStatus: SyncStatus { get }
}

// Implementation in private repo
final class SyncEngine: SyncEngineProtocol {
    // Full implementation
}
```

---

## Contribution Flow

### Community Contributions

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Community Contribution Flow                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   1. Fork public repo                                                    │
│      github.com/pasteshelf/pasteshelf → github.com/user/pasteshelf      │
│                                                                          │
│   2. Create feature branch                                               │
│      git checkout -b feature/my-feature                                  │
│                                                                          │
│   3. Make changes (Community features only)                              │
│      • Core functionality improvements                                   │
│      • UI enhancements                                                   │
│      • Bug fixes                                                         │
│      • Documentation                                                     │
│                                                                          │
│   4. Submit PR to public repo                                            │
│      pasteshelf/pasteshelf ← user/pasteshelf                            │
│                                                                          │
│   5. Review and merge                                                    │
│      • Code review                                                       │
│      • CI passes                                                         │
│      • CLA signed                                                        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Internal Development

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Internal Development Flow                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   Feature Type          Repository           Branch                      │
│   ────────────          ──────────           ──────                      │
│                                                                          │
│   🆓 Community          pasteshelf           feature/xxx                 │
│      feature            (public)             └── PR to develop           │
│                                                                          │
│   ⭐ Pro                pasteshelf-pro       feature/xxx                 │
│      feature            (private)            └── PR to develop           │
│                                              └── Update public interface │
│                                                                          │
│   🏢 Enterprise         pasteshelf-pro       feature/xxx                 │
│      feature            (private)            └── PR to develop           │
│                                                                          │
│   Release:                                                               │
│   1. Tag public repo                                                     │
│   2. Tag private repo (same version)                                     │
│   3. Build all editions                                                  │
│   4. Publish                                                             │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Open-Core Model](OPEN_CORE_MODEL.md) | Business model |
| [Contributing](../../CONTRIBUTING.md) | Contribution guide |
| [CI/CD](../deployment/CI_CD.md) | Build automation |

---

*Last updated: 2026-02-03*
