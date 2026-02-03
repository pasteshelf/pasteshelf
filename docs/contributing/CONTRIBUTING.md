# Contributing to PasteShelf

> **Last Updated**: 2026-02-03 | **Reading Time**: 10 minutes

Welcome to PasteShelf! We appreciate your interest in contributing.

---

## Table of Contents

- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Guidelines](#development-guidelines)
- [Pull Request Process](#pull-request-process)
- [Community](#community)

---

## Getting Started

### Prerequisites

- macOS 14.0+
- Xcode 15.0+
- Git
- Homebrew

### Setup

```bash
# Clone repository
git clone https://github.com/pasteshelf/pasteshelf.git
cd pasteshelf

# Install tools
brew install swiftlint swiftformat

# Open project
open PasteShelf.xcodeproj
```

---

## How to Contribute

### Reporting Bugs

1. Search existing issues
2. Use bug report template
3. Include:
   - macOS version
   - PasteShelf version
   - Steps to reproduce
   - Expected vs actual behavior

### Suggesting Features

1. Check roadmap and existing requests
2. Use feature request template
3. Describe use case clearly
4. Tag appropriately (tier/community, tier/pro)

### Code Contributions

1. Fork the repository
2. Create feature branch
3. Make changes
4. Submit pull request

---

## Development Guidelines

### Coding Standards

- Follow Swift API Design Guidelines
- Run SwiftLint before committing
- Run SwiftFormat before committing
- Maximum line length: 120 characters

### Commit Messages

Follow Conventional Commits:

```
type(scope): description

[optional body]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

Examples:
```
feat(clipboard): add image preview support
fix(search): resolve memory leak in indexer
docs(readme): update installation instructions
```

### Branch Naming

- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation
- `refactor/` - Code refactoring

---

## Pull Request Process

### Before Submitting

```bash
# Run linter
swiftlint

# Format code
swiftformat .

# Run tests
xcodebuild test -scheme PasteShelf
```

### PR Requirements

- [ ] Code builds without warnings
- [ ] All tests pass
- [ ] SwiftLint passes
- [ ] Documentation updated
- [ ] Follows commit conventions

### Review Process

1. Create PR to `develop` branch
2. CI runs automatically
3. Request review
4. Address feedback
5. Merge after approval

---

## Community

- **Discussions**: GitHub Discussions
- **Issues**: GitHub Issues
- **Email**: support@pasteshelf.app

### Code of Conduct

We are committed to providing a welcoming and inclusive environment. Please be respectful and constructive in all interactions.

---

## License

By contributing, you agree that your contributions will be licensed under AGPL-3.0.

---

*Thank you for contributing to PasteShelf!*

---

*Last updated: 2026-02-03*
