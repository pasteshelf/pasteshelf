# CI/CD Pipeline

> **Last Updated**: 2026-02-03 | **Reading Time**: 15 minutes

Continuous Integration and Deployment for PasteShelf.

---

## Table of Contents

- [Overview](#overview)
- [GitHub Actions](#github-actions)
- [Workflows](#workflows)
- [Secrets Management](#secrets-management)
- [Deployment Automation](#deployment-automation)

---

## Overview

PasteShelf uses GitHub Actions for CI/CD automation.

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| CI | Push, PR | Build, lint, test |
| Release | Tag | Build and distribute |
| CodeQL | Schedule | Security scanning |

---

## GitHub Actions

### CI Workflow

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.0.app

      - name: Install dependencies
        run: |
          brew install swiftlint swiftformat

      - name: Lint
        run: swiftlint --strict

      - name: Format check
        run: swiftformat --lint .

      - name: Build
        run: |
          xcodebuild -scheme PasteShelf \
            -configuration Debug \
            -destination 'platform=macOS' \
            build

      - name: Test
        run: |
          xcodebuild -scheme PasteShelf \
            -configuration Debug \
            -destination 'platform=macOS' \
            test

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.lcov
```

### Release Workflow

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Setup signing
        env:
          CERTIFICATE: ${{ secrets.DEVELOPER_ID_CERTIFICATE }}
          CERTIFICATE_PASSWORD: ${{ secrets.CERTIFICATE_PASSWORD }}
        run: |
          echo $CERTIFICATE | base64 --decode > certificate.p12
          security create-keychain -p "" build.keychain
          security import certificate.p12 -k build.keychain \
            -P $CERTIFICATE_PASSWORD -T /usr/bin/codesign
          security set-keychain-settings build.keychain
          security unlock-keychain -p "" build.keychain

      - name: Build
        run: |
          xcodebuild -scheme PasteShelf-Release \
            -configuration Release \
            -archivePath PasteShelf.xcarchive \
            archive

      - name: Export
        run: |
          xcodebuild -exportArchive \
            -archivePath PasteShelf.xcarchive \
            -exportPath export \
            -exportOptionsPlist ExportOptions.plist

      - name: Notarize
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_PASSWORD: ${{ secrets.APPLE_APP_PASSWORD }}
          TEAM_ID: ${{ secrets.TEAM_ID }}
        run: |
          xcrun notarytool submit export/PasteShelf.app \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_PASSWORD" \
            --team-id "$TEAM_ID" \
            --wait

      - name: Create DMG
        run: |
          hdiutil create -volname "PasteShelf" \
            -srcfolder export/PasteShelf.app \
            -ov -format UDZO \
            PasteShelf-${{ github.ref_name }}.dmg

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: PasteShelf-${{ github.ref_name }}.dmg
          generate_release_notes: true
```

### Security Scanning

```yaml
# .github/workflows/codeql.yml
name: CodeQL

on:
  schedule:
    - cron: '0 0 * * 1'
  push:
    branches: [main]

jobs:
  analyze:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v2
        with:
          languages: swift

      - name: Build
        run: |
          xcodebuild -scheme PasteShelf build

      - name: Perform Analysis
        uses: github/codeql-action/analyze@v2
```

---

## Secrets Management

| Secret | Purpose |
|--------|---------|
| `DEVELOPER_ID_CERTIFICATE` | Code signing certificate (base64) |
| `CERTIFICATE_PASSWORD` | Certificate password |
| `APPLE_ID` | Apple ID for notarization |
| `APPLE_APP_PASSWORD` | App-specific password |
| `TEAM_ID` | Apple Developer Team ID |
| `MATCH_PASSWORD` | Fastlane match password |

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Build System](BUILD_SYSTEM.md) | Build configuration |
| [Deployment Guide](DEPLOYMENT_GUIDE.md) | Distribution |

---

*Last updated: 2026-02-03*
