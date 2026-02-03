# PasteShelf

[![Build](https://github.com/pasteshelf/pasteshelf/actions/workflows/ci.yml/badge.svg)](https://github.com/pasteshelf/pasteshelf/actions/workflows/ci.yml)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-brightgreen)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)

Privacy-first, AI-powered clipboard manager for macOS. Open source. Free forever.

## Features

### Community Edition (Free & Open Source)
- **Unlimited Clipboard History** - Never lose copied content again
- **Instant Search** - Find anything you've copied with lightning-fast search
- **Smart Categories** - Auto-organize by content type (text, images, files, code)
- **Quick Access** - Global hotkey for instant clipboard access
- **Privacy First** - All data stored locally, no cloud sync required
- **Keyboard Driven** - Full keyboard navigation support

### Pro Edition
- **AI-Powered Search** - Natural language search across your clipboard
- **Smart Suggestions** - Context-aware paste suggestions
- **Advanced Sync** - Secure iCloud sync across devices
- **Custom Actions** - Automate workflows with clipboard content
- **Priority Support** - Direct access to the development team

### Enterprise Edition
- **Team Sharing** - Share clipboard items securely with your team
- **Admin Controls** - Centralized management and policies
- **Audit Logs** - Complete visibility into clipboard usage
- **SSO Integration** - SAML/OIDC authentication support
- **On-Premise Option** - Self-hosted deployment available

## Installation

### Direct Download
Download the latest release from [GitHub Releases](https://github.com/pasteshelf/pasteshelf/releases).

### Homebrew (Coming Soon)
```bash
brew install --cask pasteshelf
```

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac

## Building from Source

### Prerequisites
- Xcode 15.0+
- Swift 5.9+

### Build
```bash
git clone https://github.com/pasteshelf/pasteshelf.git
cd pasteshelf
open PasteShelf.xcodeproj
```

Build and run using Xcode (⌘R).

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup
```bash
# Install development tools
brew install swiftlint swiftformat

# Run linter
swiftlint

# Format code
swiftformat .
```

## Architecture

PasteShelf follows a modular architecture:

```
PasteShelf/
├── Core/           # Core functionality
│   ├── Clipboard/  # Clipboard monitoring & management
│   ├── Search/     # Search engine & indexing
│   ├── Storage/    # Data persistence
│   ├── Sync/       # Cloud sync (Pro)
│   ├── Security/   # Encryption & privacy
│   ├── Licensing/  # License validation
│   └── Plugins/    # Plugin system
├── UI/             # User interface
│   ├── FloatingPanel/   # Quick access panel
│   ├── MainWindow/      # Main application window
│   ├── MenuBar/         # Menu bar integration
│   ├── Preferences/     # Settings UI
│   ├── Onboarding/      # First-run experience
│   ├── Upgrade/         # Upgrade prompts
│   └── Components/      # Shared UI components
├── Models/         # Data models
├── Extensions/     # Swift extensions
├── Utilities/      # Helper utilities
└── Resources/      # Assets & localization
```

## License

PasteShelf Community Edition is licensed under the [GNU Affero General Public License v3.0](LICENSE).

Pro and Enterprise features are available under a commercial license. See [pasteshelf.com](https://pasteshelf.com) for details.

## Support

- **Documentation**: [docs.pasteshelf.com](https://docs.pasteshelf.com)
- **Issues**: [GitHub Issues](https://github.com/pasteshelf/pasteshelf/issues)
- **Discussions**: [GitHub Discussions](https://github.com/pasteshelf/pasteshelf/discussions)
- **Email**: support@pasteshelf.com

## Acknowledgments

Built with love using:
- [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- [Swift](https://swift.org)

---

Made with ❤️ by the PasteShelf team
