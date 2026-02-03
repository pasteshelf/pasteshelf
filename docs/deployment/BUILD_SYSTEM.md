# Build System

> **Last Updated**: 2026-02-03 | **Reading Time**: 12 minutes

Xcode build configuration and automation for PasteShelf.

---

## Table of Contents

- [Project Structure](#project-structure)
- [Build Configurations](#build-configurations)
- [Schemes](#schemes)
- [Signing](#signing)
- [Fastlane](#fastlane)

---

## Project Structure

```
PasteShelf.xcodeproj/
├── project.pbxproj
├── xcshareddata/
│   └── xcschemes/
│       ├── PasteShelf.xcscheme
│       └── PasteShelfTests.xcscheme
└── xcuserdata/
```

---

## Build Configurations

| Configuration | Use Case |
|---------------|----------|
| Debug | Development and debugging |
| Release | Production builds |

### Debug Configuration

```xcconfig
// Debug.xcconfig
SWIFT_OPTIMIZATION_LEVEL = -Onone
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
ENABLE_TESTABILITY = YES
GCC_PREPROCESSOR_DEFINITIONS = DEBUG=1
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG
```

### Release Configuration

```xcconfig
// Release.xcconfig
SWIFT_OPTIMIZATION_LEVEL = -O
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
ENABLE_TESTABILITY = NO
SWIFT_COMPILATION_MODE = wholemodule
```

---

## Schemes

### PasteShelf (Development)

- Build: Debug
- Test: All test targets
- Run: Debug build

### PasteShelf-Release

- Build: Release
- Archive: For distribution

---

## Signing

### Development

```
Team: Personal Team
Signing Certificate: Apple Development
Provisioning: Automatic
```

### Distribution

```
Team: PasteShelf Inc (TEAMID)
Signing Certificate: Apple Distribution (App Store)
                    or Developer ID Application (Direct)
Provisioning: Manual
```

---

## Fastlane

```ruby
# Fastfile
default_platform(:mac)

platform :mac do
  desc "Build for development"
  lane :build do
    build_app(
      scheme: "PasteShelf",
      configuration: "Debug",
      skip_archive: true
    )
  end

  desc "Build and archive for release"
  lane :release do
    build_app(
      scheme: "PasteShelf-Release",
      configuration: "Release",
      export_method: "app-store"
    )
  end

  desc "Upload to App Store Connect"
  lane :upload do
    upload_to_app_store(
      skip_metadata: false,
      skip_screenshots: true
    )
  end

  desc "Run tests"
  lane :test do
    run_tests(
      scheme: "PasteShelf",
      device: "Mac"
    )
  end
end
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [CI/CD](CI_CD.md) | Continuous integration |
| [Deployment Guide](DEPLOYMENT_GUIDE.md) | Distribution |

---

*Last updated: 2026-02-03*
