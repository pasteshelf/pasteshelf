# PasteShelf

[![Build](https://github.com/pasteshelf/pasteshelf/actions/workflows/ci.yml/badge.svg)](https://github.com/pasteshelf/pasteshelf/actions/workflows/ci.yml)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-brightgreen)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](docs/contributing/CONTRIBUTING.md)

**Privacy-first clipboard manager for macOS.** Open-core model with a free Community Edition and paid Pro/Enterprise tiers.

```
┌─────────────────────────────────────────────────────────────┐
│  Your clipboard history, your data, your control.           │
│                                                             │
│  • Local-first: Data stays on your device                   │
│  • Open source: Audit the code yourself                     │
│  • Extensible: Plugins, automation, integrations            │
└─────────────────────────────────────────────────────────────┘
```

---

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Documentation](#documentation)
- [Building from Source](#building-from-source)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [License](#license)
- [Support](#support)

---

## Features

### 🆓 Community Edition (Free & Open Source)

| Feature | Description |
|---------|-------------|
| **Unlimited History** | Never lose copied content again |
| **Instant Search** | Full-text search across all clipboard items |
| **Smart Categories** | Auto-organize by content type (text, images, files, code) |
| **Global Hotkey** | `⌘⇧V` for instant clipboard access |
| **App Exclusions** | Exclude password managers and sensitive apps |
| **Keyboard Driven** | Full keyboard navigation support |
| **Privacy First** | All data stored locally, no telemetry |

### ⭐ Pro Edition ($29/year)

Everything in Community, plus:

| Feature | Description |
|---------|-------------|
| **iCloud Sync** | Encrypted sync across all your Macs |
| **Semantic Search** | Natural language queries ("that email from last week") |
| **OCR Search** | Find text within images |
| **Smart Collections** | Auto-organize with rules |
| **Advanced Automation** | Shortcuts, AppleScript, webhooks |
| **Plugin System** | Extend with community plugins |
| **Priority Support** | Direct email support |

### 🏢 Enterprise Edition (Custom pricing)

Everything in Pro, plus:

| Feature | Description |
|---------|-------------|
| **SSO Integration** | SAML 2.0 / OIDC authentication |
| **MDM Deployment** | Jamf, Kandji, Intune support |
| **Centralized Management** | Admin console for policies |
| **Audit Logging** | Complete activity trail |
| **DLP Policies** | Data loss prevention rules |
| **Self-Hosted Sync** | On-premise deployment option |
| **Dedicated Support** | SLA-backed enterprise support |

---

## Installation

### Direct Download

Download the latest release from [GitHub Releases](https://github.com/pasteshelf/pasteshelf/releases).

### Homebrew (Coming Soon)

```bash
brew install --cask pasteshelf
```

### Mac App Store (Coming Soon)

[![Download on the Mac App Store](https://developer.apple.com/assets/elements/badges/download-on-the-mac-app-store.svg)](https://apps.apple.com/app/pasteshelf)

### Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac

---

## Quick Start

1. **Install PasteShelf** and grant Accessibility permission when prompted
2. **Copy anything** - PasteShelf automatically captures it
3. **Press `⌘⇧V`** to open the floating panel
4. **Search or navigate** to find your item
5. **Press Enter** to paste

```
┌─────────────────────────────────────────────┐
│  ⌘⇧V     Open PasteShelf                   │
│  ⌘F      Focus search                       │
│  ↑↓      Navigate items                     │
│  ⏎       Paste selected item               │
│  ⌘1-9    Quick paste items 1-9             │
│  ⌘,      Open preferences                   │
└─────────────────────────────────────────────┘
```

📖 **[Full Quick Start Guide →](docs/getting-started/QUICK_START.md)**

---

## Documentation

### Getting Started

| Document | Description |
|----------|-------------|
| [Quick Start](docs/getting-started/QUICK_START.md) | Get up and running in 5 minutes |
| [Setup Guide](docs/getting-started/SETUP_GUIDE.md) | Detailed installation and configuration |
| [Development Guide](docs/getting-started/DEVELOPMENT_GUIDE.md) | Contributing and development setup |

### Architecture

| Document | Description |
|----------|-------------|
| [Architecture Overview](docs/architecture/ARCHITECTURE.md) | System design and components |
| [Tech Stack](docs/architecture/TECH_STACK.md) | Technologies and frameworks |
| [Database Schema](docs/architecture/DATABASE_SCHEMA.md) | CoreData model documentation |

### Features

| Document | Description |
|----------|-------------|
| [Privacy & Security](docs/features/PRIVACY_SECURITY_FEATURES.md) | Encryption, sensitive data handling |
| [Clipboard Engine](docs/features/CLIPBOARD_ENGINE.md) | How clipboard monitoring works |
| [Search Engine](docs/features/SEARCH_ENGINE.md) | Full-text, semantic, OCR search |
| [Sync Engine](docs/features/SYNC_ENGINE.md) | iCloud sync architecture ⭐ |
| [Automation](docs/features/AUTOMATION_ENGINE.md) | Rules, Shortcuts, AppleScript ⭐ |
| [Plugins](docs/features/PLUGIN_SYSTEM.md) | Plugin development ⭐ |

### Business Model

| Document | Description |
|----------|-------------|
| [Open-Core Model](docs/open-core/OPEN_CORE_MODEL.md) | Edition comparison and philosophy |
| [License System](docs/open-core/LICENSE_SYSTEM.md) | License validation architecture |
| [Repository Structure](docs/open-core/REPOSITORY_STRUCTURE.md) | Public vs private code |

### Enterprise

| Document | Description |
|----------|-------------|
| [Admin Guide](docs/enterprise/ENTERPRISE_ADMIN_GUIDE.md) | SSO, MDM, policies 🏢 |
| [Deployment Guide](docs/enterprise/ENTERPRISE_DEPLOYMENT.md) | Enterprise deployment 🏢 |

### Reference

| Document | Description |
|----------|-------------|
| [FAQ](docs/reference/FAQ.md) | Frequently asked questions |
| [Roadmap](docs/reference/ROADMAP.md) | Development timeline |
| [API Documentation](docs/api/API_DOCUMENTATION.md) | Plugin API, scripting |
| [Troubleshooting](docs/operations/TROUBLESHOOTING.md) | Common issues and solutions |

---

## Building from Source

### Prerequisites

- Xcode 15.0+
- Swift 5.9+
- macOS 14.0+

### Build

```bash
# Clone repository
git clone https://github.com/pasteshelf/pasteshelf.git
cd pasteshelf

# Install development tools
brew install swiftlint swiftformat

# Open in Xcode
open PasteShelf.xcodeproj

# Build and run (⌘R)
```

### Project Structure

```
PasteShelf/
├── PasteShelf/              # Main application
│   ├── App/                 # App entry point
│   ├── Core/                # Core functionality
│   │   ├── Clipboard/       # Clipboard monitoring
│   │   ├── Search/          # Search engine
│   │   ├── Storage/         # CoreData persistence
│   │   ├── Sync/            # CloudKit sync ⭐
│   │   └── Security/        # Encryption
│   ├── UI/                  # SwiftUI views
│   ├── Models/              # Data models
│   └── Resources/           # Assets, localization
├── PasteShelfTests/         # Unit tests
├── PasteShelfUITests/       # UI tests
└── docs/                    # Documentation
```

📖 **[Full Development Guide →](docs/getting-started/DEVELOPMENT_GUIDE.md)**

---

## Contributing

We welcome contributions! Here's how to get started:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes using [Conventional Commits](https://www.conventionalcommits.org/)
4. **Push** to your branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Commands

```bash
# Run linter
swiftlint

# Format code
swiftformat .

# Run tests
xcodebuild test -scheme PasteShelf
```

### Areas We Need Help

- 🌍 **Translations** - Help us localize PasteShelf
- 📖 **Documentation** - Improve guides and tutorials
- 🐛 **Bug Reports** - Find and report issues
- ✨ **Features** - Implement roadmap items
- 🧪 **Testing** - Improve test coverage

📖 **[Full Contributing Guide →](docs/contributing/CONTRIBUTING.md)**

---

## Roadmap

| Version | Target | Focus |
|---------|--------|-------|
| 0.1.0 | Q1 2026 | Core clipboard functionality |
| 0.2.0 | Q2 2026 | Search and organization |
| 1.0.0 | Q3 2026 | Community Edition release |
| 1.1.0 | Q4 2026 | Pro Edition launch |
| 2.0.0 | Q1 2027 | Enterprise Edition |

📖 **[Full Roadmap →](docs/reference/ROADMAP.md)**

---

## License

**Community Edition**: [GNU Affero General Public License v3.0](LICENSE)

**Pro & Enterprise**: Commercial license. See [pasteshelf.app/pricing](https://pasteshelf.app/pricing) for details.

The open-core model means:
- Core clipboard functionality is free and open source forever
- Advanced features (sync, AI search, enterprise) require a paid license
- Your contributions to the open source core benefit everyone

---

## Support

| Channel | For |
|---------|-----|
| [GitHub Issues](https://github.com/pasteshelf/pasteshelf/issues) | Bug reports |
| [GitHub Discussions](https://github.com/pasteshelf/pasteshelf/discussions) | Questions, ideas |
| [Documentation](docs/) | Guides and references |
| support@pasteshelf.app | Pro support ⭐ |
| enterprise@pasteshelf.app | Enterprise inquiries 🏢 |

---

## Acknowledgments

Built with:
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - Modern declarative UI
- [CoreData](https://developer.apple.com/documentation/coredata) - Local persistence
- [CloudKit](https://developer.apple.com/icloud/cloudkit/) - Secure cloud sync
- [CryptoKit](https://developer.apple.com/documentation/cryptokit) - Encryption

Special thanks to all [contributors](https://github.com/pasteshelf/pasteshelf/graphs/contributors)!

---

<p align="center">
  Made with care by the PasteShelf team
  <br>
  <a href="https://pasteshelf.app">Website</a> •
  <a href="https://twitter.com/pasteshelf">Twitter</a> •
  <a href="docs/">Documentation</a>
</p>
