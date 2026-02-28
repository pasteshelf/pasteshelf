# Development Guide

> **Last Updated**: 2026-02-03 | **Reading Time**: 20 minutes

Complete guide for contributing to PasteShelf development.

---

## Table of Contents

- [Development Environment](#development-environment)
- [Project Structure](#project-structure)
- [Architecture Overview](#architecture-overview)
- [Coding Standards](#coding-standards)
- [Building and Running](#building-and-running)
- [Testing](#testing)
- [Debugging](#debugging)
- [Feature Development](#feature-development)
- [Pull Request Process](#pull-request-process)

---

## Development Environment

### Required Tools

| Tool | Version | Installation |
|------|---------|--------------|
| Xcode | 15.0+ | Mac App Store |
| Swift | 5.9+ | Bundled with Xcode |
| Git | 2.30+ | `xcode-select --install` |
| Homebrew | Latest | [brew.sh](https://brew.sh) |
| SwiftLint | Latest | `brew install swiftlint` |
| SwiftFormat | Latest | `brew install swiftformat` |

### Environment Setup

```bash
# 1. Install Xcode from Mac App Store

# 2. Install Xcode Command Line Tools
xcode-select --install

# 3. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 4. Install development tools
brew install swiftlint swiftformat

# 5. Clone the repository
git clone https://github.com/pasteshelf/pasteshelf.git
cd pasteshelf

# 6. Open in Xcode
open PasteShelf.xcodeproj
```

### Xcode Configuration

#### Recommended Settings

```
Xcode → Settings → Text Editing:
  ✓ Show line numbers
  ✓ Page guide at column: 120
  ✓ Trim trailing whitespace
  Indentation: 4 spaces
```

#### Build Settings

```
Product → Scheme → Edit Scheme:
  Build Configuration: Debug
  Diagnostics:
    ✓ Address Sanitizer
    ✓ Thread Sanitizer (optional)
    ✓ Main Thread Checker
```

---

## Project Structure

```
PasteShelf/
├── PasteShelf/                    # Main application source
│   ├── PasteShelfApp.swift        # App entry point
│   ├── ContentView.swift          # Main view
│   ├── Persistence.swift          # CoreData controller
│   ├── PasteShelf.xcdatamodeld/   # CoreData model
│   │
│   ├── Core/                      # Core business logic
│   │   ├── Clipboard/             # Clipboard monitoring
│   │   │   ├── ClipboardMonitor.swift
│   │   │   ├── ClipboardItem.swift
│   │   │   └── ContentType.swift
│   │   ├── Search/                # Search engine
│   │   │   ├── SearchEngine.swift
│   │   │   ├── SearchIndex.swift
│   │   │   └── SearchResult.swift
│   │   ├── Storage/               # Data persistence
│   │   │   ├── StorageManager.swift
│   │   │   └── MigrationManager.swift
│   │   ├── Sync/                  # CloudKit sync (Pro)
│   │   │   ├── SyncEngine.swift
│   │   │   └── ConflictResolver.swift
│   │   ├── Security/              # Encryption & privacy
│   │   │   ├── EncryptionManager.swift
│   │   │   ├── SensitiveDataDetector.swift
│   │   │   └── BiometricAuth.swift
│   │   └── Plugins/               # Plugin system
│   │       ├── PluginManager.swift
│   │       └── PluginProtocol.swift
│   │
│   ├── UI/                        # User interface
│   │   ├── FloatingPanel/         # Quick access panel
│   │   │   ├── FloatingPanelView.swift
│   │   │   └── ClipboardRowView.swift
│   │   ├── MainWindow/            # Main application window
│   │   │   ├── MainWindowView.swift
│   │   │   └── SidebarView.swift
│   │   ├── MenuBar/               # Menu bar integration
│   │   │   └── MenuBarController.swift
│   │   ├── Preferences/           # Settings UI
│   │   │   └── PreferencesView.swift
│   │   ├── Onboarding/            # First-run experience
│   │   │   └── OnboardingView.swift
│   │   ├── Upgrade/               # Upgrade prompts (Pro)
│   │   │   └── UpgradeView.swift
│   │   └── Components/            # Shared UI components
│   │       ├── SearchField.swift
│   │       └── ItemPreview.swift
│   │
│   ├── Models/                    # Data models
│   │   └── Item+Extensions.swift
│   ├── Extensions/                # Swift extensions
│   │   └── String+Extensions.swift
│   ├── Utilities/                 # Helper utilities
│   │   └── Logger.swift
│   └── Resources/                 # Assets & localization
│       ├── Assets.xcassets/
│       └── Localizable.xcstrings
│
├── PasteShelfTests/               # Unit tests
│   └── PasteShelfTests.swift
├── PasteShelfUITests/             # UI tests
│   └── PasteShelfUITests.swift
│
├── .github/                       # GitHub configuration
│   ├── workflows/                 # CI/CD workflows
│   │   ├── ci.yml
│   │   └── release.yml
│   └── ISSUE_TEMPLATE/
│
├── docs/                          # Documentation
├── fastlane/                      # Automation scripts
└── Configuration files
    ├── .swiftlint.yml
    ├── .swiftformat
    └── .gitignore
```

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        PasteShelf                            │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    UI Layer                          │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │   │
│  │  │ Floating │ │   Main   │ │ Menu Bar │ │ Prefs  │ │   │
│  │  │  Panel   │ │  Window  │ │          │ │        │ │   │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └───┬────┘ │   │
│  └───────┼────────────┼────────────┼───────────┼───────┘   │
│          │            │            │           │            │
│  ┌───────┴────────────┴────────────┴───────────┴───────┐   │
│  │                  Core Layer                          │   │
│  │  ┌───────────┐ ┌────────┐ ┌─────────┐ ┌──────────┐ │   │
│  │  │ Clipboard │ │ Search │ │ Storage │ │ Security │ │   │
│  │  │  Monitor  │ │ Engine │ │ Manager │ │  Manager │ │   │
│  │  └─────┬─────┘ └───┬────┘ └────┬────┘ └────┬─────┘ │   │
│  │        │           │           │           │        │   │
│  │  ┌─────┴───────────┴───────────┴───────────┴─────┐ │   │
│  │  │              Sync Engine (Pro)                 │ │   │
│  │  └────────────────────┬───────────────────────────┘ │   │
│  └───────────────────────┼──────────────────────────────┘   │
│                          │                                   │
├──────────────────────────┼───────────────────────────────────┤
│  ┌───────────────────────┴───────────────────────────────┐  │
│  │                   Data Layer                           │  │
│  │  ┌──────────────┐  ┌───────────┐  ┌────────────────┐ │  │
│  │  │   CoreData   │  │  CloudKit │  │    Keychain    │ │  │
│  │  │   (Local)    │  │  (Sync)   │  │   (Secrets)    │ │  │
│  │  └──────────────┘  └───────────┘  └────────────────┘ │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

```
┌──────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Clipboard   │───▶│ ClipboardMonitor │───▶│  StorageManager │
│  (System)    │    │   - Poll/Observe │    │   - CoreData    │
└──────────────┘    │   - Parse types  │    │   - Index       │
                    └──────────────────┘    └────────┬────────┘
                                                     │
                                                     ▼
┌──────────────┐    ┌──────────────────┐    ┌─────────────────┐
│     User     │◀───│   UI Components  │◀───│  SearchEngine   │
│   Interface  │    │   - SwiftUI      │    │   - Full-text   │
└──────────────┘    │   - View Models  │    │   - Semantic    │
                    └──────────────────┘    └─────────────────┘
```

### Key Patterns

1. **MVVM Architecture**: Views bind to ViewModels
2. **Dependency Injection**: For testability
3. **Protocol-Oriented Design**: Interfaces over implementations
4. **Async/Await**: Modern concurrency
5. **Combine**: Reactive streams for data flow

See [Architecture Documentation](../architecture/ARCHITECTURE.md) for details.

---

## Coding Standards

### Swift Style Guide

We follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) with these additions:

#### Naming Conventions

```swift
// Types: UpperCamelCase
struct ClipboardItem { }
class SearchEngine { }
enum ContentType { }

// Properties/Methods: lowerCamelCase
let clipboardHistory: [ClipboardItem]
func searchItems(query: String) -> [ClipboardItem]

// Constants: lowerCamelCase
let maximumHistoryCount = 1000

// Abbreviations: treat as words
let urlString: String  // not: uRLString
let httpResponse: HTTPResponse  // type abbreviations OK
```

#### Code Organization

```swift
// MARK: - Protocol conformance order
// 1. Properties
// 2. Initialization
// 3. Public methods
// 4. Private methods
// 5. Protocol conformance (separate extensions)

final class ClipboardManager {
    // MARK: - Properties
    private let storage: StorageProtocol
    private let monitor: ClipboardMonitorProtocol

    // MARK: - Initialization
    init(storage: StorageProtocol, monitor: ClipboardMonitorProtocol) {
        self.storage = storage
        self.monitor = monitor
    }

    // MARK: - Public Methods
    func startMonitoring() {
        // ...
    }

    // MARK: - Private Methods
    private func processItem(_ item: ClipboardItem) {
        // ...
    }
}

// MARK: - ClipboardMonitorDelegate
extension ClipboardManager: ClipboardMonitorDelegate {
    func didCaptureItem(_ item: ClipboardItem) {
        // ...
    }
}
```

#### SwiftLint Rules

Key rules from `.swiftlint.yml`:

```yaml
line_length:
  warning: 120
  error: 150

type_body_length:
  warning: 300
  error: 400

function_body_length:
  warning: 40
  error: 60

nesting:
  type_level: 2
  function_level: 3
```

Run before committing:
```bash
swiftlint
swiftformat .
```

---

## Building and Running

### Debug Build

```bash
# Using xcodebuild
xcodebuild -scheme PasteShelf -configuration Debug build

# Or use Xcode: ⌘R
```

### Release Build

```bash
xcodebuild -scheme PasteShelf -configuration Release build
```

### Build for Testing

```bash
xcodebuild -scheme PasteShelf -configuration Debug \
    -destination 'platform=macOS' \
    build-for-testing
```

### Clean Build

```bash
# Clean build folder
xcodebuild clean -scheme PasteShelf

# Or: ⌘⇧K in Xcode
```

---

## Testing

### Unit Tests

```bash
# Run all unit tests
xcodebuild test -scheme PasteShelf -destination 'platform=macOS'

# Or: ⌘U in Xcode
```

Example test structure:

```swift
import XCTest
@testable import PasteShelf

final class SearchEngineTests: XCTestCase {
    var sut: SearchEngine!
    var mockStorage: MockStorageManager!

    override func setUp() {
        super.setUp()
        mockStorage = MockStorageManager()
        sut = SearchEngine(storage: mockStorage)
    }

    override func tearDown() {
        sut = nil
        mockStorage = nil
        super.tearDown()
    }

    func test_search_withEmptyQuery_returnsAllItems() {
        // Given
        mockStorage.items = [
            ClipboardItem(content: "Hello"),
            ClipboardItem(content: "World")
        ]

        // When
        let results = sut.search(query: "")

        // Then
        XCTAssertEqual(results.count, 2)
    }

    func test_search_withQuery_returnsMatchingItems() {
        // Given
        mockStorage.items = [
            ClipboardItem(content: "Hello World"),
            ClipboardItem(content: "Goodbye Moon")
        ]

        // When
        let results = sut.search(query: "Hello")

        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.content, "Hello World")
    }
}
```

### UI Tests

```swift
import XCTest

final class PasteShelfUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func test_openingApp_showsMainWindow() {
        XCTAssertTrue(app.windows["PasteShelf"].exists)
    }

    func test_globalHotkey_opensFloatingPanel() {
        // Simulate ⌘⇧V
        app.typeKey("v", modifierFlags: [.command, .shift])

        XCTAssertTrue(app.windows["FloatingPanel"].waitForExistence(timeout: 2))
    }
}
```

### Code Coverage

Target: **70% minimum** coverage

View coverage in Xcode:
```
Product → Scheme → Edit Scheme → Test → Options → Code Coverage ✓
```

---

## Debugging

### Console Logging

```swift
import os

private let logger = Logger(subsystem: "com.pasteshelf.PasteShelf", category: "Clipboard")

func captureItem() {
    logger.debug("Starting clipboard capture")
    logger.info("Captured item: \(item.id)")
    logger.error("Failed to save: \(error.localizedDescription)")
}
```

### Breakpoints

Common breakpoints to set:
- `ClipboardMonitor.captureItem()` - Debug capture issues
- `SearchEngine.search()` - Debug search results
- `StorageManager.save()` - Debug persistence

### Instruments

Profile with Instruments (`⌘I`):
- **Time Profiler**: CPU usage
- **Allocations**: Memory leaks
- **Core Data**: Database performance
- **Network**: CloudKit sync

---

## Feature Development

### Application Settings

User preferences are managed via `@AppStorage`:

```swift
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("cloudSyncEnabled") var isCloudSyncEnabled = false
    @AppStorage("maxHistoryItems") var maxHistoryItems = 1000
    @AppStorage("autoDeleteAfterDays") var autoDeleteAfterDays = 30
}
```

### Adding a New Feature

1. **Create feature branch**
   ```bash
   git checkout -b feature/smart-folders
   ```

2. **Implement the feature**
   - Add Core logic in `Core/`
   - Add UI in `UI/`
   - Add tests

3. **Check settings if needed**
   ```swift
   if AppSettings.shared.isSmartFoldersEnabled {
       // Show smart folders UI
   }
   ```

4. **Update documentation**
   - Add to relevant docs
   - Update CHANGELOG.md

5. **Submit PR**
   - Follow PR template
   - Request review

---

## Pull Request Process

### Before Submitting

```bash
# 1. Ensure code compiles
xcodebuild -scheme PasteShelf build

# 2. Run linter
swiftlint

# 3. Format code
swiftformat .

# 4. Run tests
xcodebuild test -scheme PasteShelf -destination 'platform=macOS'

# 5. Commit changes
git add .
git commit -m "feat(clipboard): add smart folders support"
```

### PR Requirements

- [ ] Code builds without warnings
- [ ] All tests pass
- [ ] Code coverage maintained (≥70%)
- [ ] SwiftLint passes
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Follows commit message convention

### Review Process

1. Create PR from feature branch to `develop`
2. CI runs automatically
3. Request review from maintainers
4. Address feedback
5. Maintainer approves and merges

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Contributing Guide](../../CONTRIBUTING.md) | Contribution guidelines |
| [Architecture](../architecture/ARCHITECTURE.md) | System architecture |
| [Testing Guide](../testing/TESTING.md) | Testing best practices |
| [CI/CD](../deployment/CI_CD.md) | Continuous integration |

---

*Last updated: 2026-02-03*
