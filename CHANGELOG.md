# Changelog

All notable changes to PasteShelf will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure with SwiftUI and CoreData
- Basic clipboard history storage with CloudKit container
- Project documentation suite

### Changed
- None

### Deprecated
- None

### Removed
- None

### Fixed
- None

### Security
- None

---

## Version History

### [0.1.0] - 2026-02-03

#### Added
- 🎉 Initial release
- Basic SwiftUI application structure
- CoreData persistence layer with CloudKit support
- Project scaffolding and development tools configuration
- SwiftLint and SwiftFormat configuration
- GitHub Actions CI/CD workflows
- Issue and PR templates
- AGPL-3.0 license for Community Edition
- Basic README and CONTRIBUTING documentation

#### Technical Details
- **Platform**: macOS 14.0+ (Sonoma)
- **Language**: Swift 5.9+
- **Framework**: SwiftUI with CoreData
- **Sync**: CloudKit container prepared

---

## Release Types

| Type | Description |
|------|-------------|
| 🆓 **Community Edition** | Free, open-source features under AGPL-3.0 |
| ⭐ **Pro Edition** | Premium features for individual power users |
| 🏢 **Enterprise Edition** | Team features with admin controls and compliance |

## Versioning Scheme

PasteShelf follows [Semantic Versioning](https://semver.org/):

- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions
- **PATCH** version for backwards-compatible bug fixes

### Pre-release Versions
- `alpha` - Early development, unstable
- `beta` - Feature complete, testing phase
- `rc` - Release candidate, final testing

### Examples
- `1.0.0-alpha.1` - First alpha of version 1.0.0
- `1.0.0-beta.2` - Second beta of version 1.0.0
- `1.0.0-rc.1` - First release candidate
- `1.0.0` - Stable release

---

## Upgrade Notes

### Upgrading to 1.0.0 (Future)

When upgrading to version 1.0.0, please note:

1. **Database Migration**: Automatic migration will be performed on first launch
2. **Settings**: Some preferences may reset to defaults
3. **Backup**: We recommend exporting your clipboard history before upgrading

---

## Links

- [Latest Release](https://github.com/pasteshelf/pasteshelf/releases/latest)
- [All Releases](https://github.com/pasteshelf/pasteshelf/releases)
- [Release Notes](https://docs.pasteshelf.app/releases)
- [Migration Guides](https://docs.pasteshelf.app/migration)

---

*Last updated: 2026-02-03*
