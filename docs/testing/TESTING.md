# Testing Guide

> **Last Updated**: 2026-02-03 | **Reading Time**: 15 minutes

Testing strategy and best practices for PasteShelf.

---

## Table of Contents

- [Testing Strategy](#testing-strategy)
- [Unit Testing](#unit-testing)
- [Integration Testing](#integration-testing)
- [UI Testing](#ui-testing)
- [Performance Testing](#performance-testing)
- [Test Coverage](#test-coverage)

---

## Testing Strategy

### Testing Pyramid

```
        ┌─────────┐
        │  E2E    │  Few, slow, comprehensive
        │  Tests  │
       ─┴─────────┴─
      ┌─────────────┐
      │ Integration │  Moderate, API/DB tests
      │   Tests     │
     ─┴─────────────┴─
    ┌─────────────────┐
    │   Unit Tests    │  Many, fast, isolated
    │                 │
    └─────────────────┘
```

### Coverage Targets

| Layer | Target | Current |
|-------|--------|---------|
| Unit Tests | 80% | TBD |
| Integration | 60% | TBD |
| UI Tests | 40% | TBD |
| **Overall** | **70%** | TBD |

---

## Unit Testing

### Structure

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

    // MARK: - Search Tests

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

    func test_search_isCaseInsensitive() {
        // Given
        mockStorage.items = [ClipboardItem(content: "HELLO")]

        // When
        let results = sut.search(query: "hello")

        // Then
        XCTAssertEqual(results.count, 1)
    }
}
```

### Mocking

```swift
// Mock storage
class MockStorageManager: StorageManagerProtocol {
    var items: [ClipboardItem] = []
    var saveCallCount = 0

    func fetchAll() -> [ClipboardItem] {
        return items
    }

    func save(_ item: ClipboardItem) {
        items.append(item)
        saveCallCount += 1
    }
}

// Mock clipboard
class MockClipboardMonitor: ClipboardMonitorProtocol {
    var isMonitoring = false
    var capturedItems: [ClipboardItem] = []

    func startMonitoring() {
        isMonitoring = true
    }

    func stopMonitoring() {
        isMonitoring = false
    }
}
```

---

## Integration Testing

### CoreData Tests

```swift
final class StorageManagerTests: XCTestCase {
    var sut: StorageManager!
    var container: NSPersistentContainer!

    override func setUp() {
        super.setUp()
        container = NSPersistentContainer(name: "PasteShelf")
        container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        sut = StorageManager(container: container)
    }

    func test_save_persistsItem() async throws {
        // Given
        let item = ClipboardItem(content: "Test content")

        // When
        try await sut.save(item)

        // Then
        let fetched = try await sut.fetch(id: item.id)
        XCTAssertEqual(fetched?.content, "Test content")
    }

    func test_delete_removesItem() async throws {
        // Given
        let item = ClipboardItem(content: "Test")
        try await sut.save(item)

        // When
        try await sut.delete(id: item.id)

        // Then
        let fetched = try await sut.fetch(id: item.id)
        XCTAssertNil(fetched)
    }
}
```

---

## UI Testing

### XCUITest

```swift
import XCTest

final class PasteShelfUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func test_mainWindow_showsClipboardHistory() {
        // Given app is launched

        // Then
        XCTAssertTrue(app.windows["PasteShelf"].exists)
        XCTAssertTrue(app.tables["ClipboardList"].exists)
    }

    func test_search_filtersResults() {
        // Given
        let searchField = app.searchFields["SearchField"]

        // When
        searchField.tap()
        searchField.typeText("test")

        // Then
        let results = app.tables["ClipboardList"].cells
        // Verify filtered results
    }

    func test_globalHotkey_opensPanel() {
        // Given panel is closed
        let panel = app.windows["FloatingPanel"]
        XCTAssertFalse(panel.exists)

        // When pressing global hotkey
        app.typeKey("v", modifierFlags: [.command, .shift])

        // Then
        XCTAssertTrue(panel.waitForExistence(timeout: 2))
    }
}
```

---

## Performance Testing

### Measure Blocks

```swift
func test_search_performance() {
    // Given large dataset
    mockStorage.items = (0..<10000).map { i in
        ClipboardItem(content: "Item \(i)")
    }

    measure {
        // When
        _ = sut.search(query: "Item 5000")
    }
}

func test_startup_performance() {
    measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
        // Measure app initialization
        let _ = AppState()
    }
}
```

---

## Test Coverage

### Running with Coverage

```bash
# Xcode
xcodebuild test \
    -scheme PasteShelf \
    -enableCodeCoverage YES \
    -resultBundlePath TestResults.xcresult

# View report
xcrun xccov view --report TestResults.xcresult
```

### CI Coverage

```yaml
# .github/workflows/ci.yml
- name: Test with coverage
  run: |
    xcodebuild test \
      -scheme PasteShelf \
      -enableCodeCoverage YES \
      -resultBundlePath TestResults.xcresult

- name: Upload coverage
  uses: codecov/codecov-action@v3
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Development Guide](../getting-started/DEVELOPMENT_GUIDE.md) | Dev setup |
| [CI/CD](../deployment/CI_CD.md) | Automation |

---

*Last updated: 2026-02-03*
