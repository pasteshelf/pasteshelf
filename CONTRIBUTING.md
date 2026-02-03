# Contributing to PasteShelf

Thank you for your interest in contributing to PasteShelf! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## How to Contribute

### Reporting Bugs

1. **Search existing issues** to avoid duplicates
2. **Use the bug report template** when creating a new issue
3. **Include detailed information**:
   - macOS version
   - PasteShelf version
   - Steps to reproduce
   - Expected vs actual behavior
   - Screenshots if applicable

### Suggesting Features

1. **Check the roadmap** and existing feature requests
2. **Use the feature request template**
3. **Describe the use case** and why it would benefit users
4. **Tag appropriately** (tier/community, tier/pro, tier/enterprise)

### Pull Requests

1. **Fork the repository** and create your branch from `develop`
2. **Follow the coding standards** (see below)
3. **Write tests** for new functionality
4. **Update documentation** as needed
5. **Create a pull request** using the PR template

## Development Setup

### Prerequisites

- macOS 14.0+
- Xcode 15.0+
- Homebrew

### Getting Started

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/pasteshelf.git
cd pasteshelf

# Install development tools
brew install swiftlint swiftformat

# Open in Xcode
open PasteShelf.xcodeproj
```

### Branch Naming

- `feature/` - New features (e.g., `feature/smart-search`)
- `fix/` - Bug fixes (e.g., `fix/memory-leak`)
- `docs/` - Documentation changes
- `refactor/` - Code refactoring
- `test/` - Test additions or fixes

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation
- `style` - Formatting
- `refactor` - Code refactoring
- `test` - Tests
- `chore` - Maintenance

Examples:
```
feat(clipboard): add image preview support
fix(search): resolve memory leak in indexer
docs(readme): update installation instructions
```

## Coding Standards

### Swift Style Guide

We follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) with some additions:

1. **Use SwiftLint** - Run `swiftlint` before committing
2. **Use SwiftFormat** - Run `swiftformat .` before committing
3. **Maximum line length** - 120 characters
4. **Indentation** - 4 spaces

### Code Organization

```swift
// MARK: - Properties

// MARK: - Initialization

// MARK: - Public Methods

// MARK: - Private Methods

// MARK: - Protocol Conformance
```

### Documentation

- Add documentation comments for public APIs
- Use `///` for documentation comments
- Include parameter descriptions and return values

```swift
/// Searches the clipboard history for items matching the query.
/// - Parameters:
///   - query: The search query string
///   - limit: Maximum number of results (default: 50)
/// - Returns: Array of matching clipboard items
func search(query: String, limit: Int = 50) -> [ClipboardItem]
```

### Testing

- Write unit tests for new functionality
- Maintain test coverage above 70%
- Use descriptive test names

```swift
func test_search_withEmptyQuery_returnsAllItems() {
    // Given
    let sut = SearchEngine()

    // When
    let results = sut.search(query: "")

    // Then
    XCTAssertEqual(results.count, expectedCount)
}
```

## Architecture Guidelines

### Dependency Injection

Use dependency injection for testability:

```swift
final class ClipboardManager {
    private let storage: StorageProtocol
    private let monitor: ClipboardMonitorProtocol

    init(storage: StorageProtocol, monitor: ClipboardMonitorProtocol) {
        self.storage = storage
        self.monitor = monitor
    }
}
```

### Error Handling

Use typed errors:

```swift
enum ClipboardError: Error {
    case accessDenied
    case invalidContent
    case storageFull
}
```

### Async/Await

Prefer async/await over callbacks:

```swift
func fetchItems() async throws -> [ClipboardItem] {
    // Implementation
}
```

## Review Process

1. All PRs require at least one approval
2. CI must pass (build, lint, tests)
3. Code coverage must not decrease
4. Documentation must be updated

## Community

- **Discussions**: Use GitHub Discussions for questions
- **Discord**: Join our community (link coming soon)

## License

By contributing, you agree that your contributions will be licensed under the AGPL-3.0 License.

---

Thank you for contributing to PasteShelf!
