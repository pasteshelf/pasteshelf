# Quick Start Guide

> **Last Updated**: 2026-02-03 | **Reading Time**: 5 minutes

Get PasteShelf up and running in under 5 minutes.

---

## TL;DR

```bash
# Clone and build
git clone https://github.com/pasteshelf/pasteshelf.git
cd pasteshelf
open PasteShelf.xcodeproj
# Press ⌘R to build and run
```

---

## Table of Contents

- [System Requirements](#system-requirements)
- [Installation Options](#installation-options)
- [First Launch](#first-launch)
- [Essential Shortcuts](#essential-shortcuts)
- [Next Steps](#next-steps)

---

## System Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| macOS | 14.0 (Sonoma) | 14.0+ |
| Processor | Apple Silicon or Intel | Apple Silicon |
| RAM | 4 GB | 8 GB+ |
| Storage | 100 MB | 500 MB+ |
| Xcode (for building) | 15.0 | 15.0+ |

---

## Installation Options

### Option 1: Direct Download (Recommended)

1. Go to [GitHub Releases](https://github.com/pasteshelf/pasteshelf/releases)
2. Download `PasteShelf.dmg`
3. Open the DMG and drag PasteShelf to Applications
4. Launch from Applications folder

### Option 2: Homebrew (Coming Soon)

```bash
brew install --cask pasteshelf
```

### Option 3: Build from Source

```bash
# 1. Clone the repository
git clone https://github.com/pasteshelf/pasteshelf.git
cd pasteshelf

# 2. Open in Xcode
open PasteShelf.xcodeproj

# 3. Build and run (⌘R)
```

---

## First Launch

### 1. Grant Accessibility Permission

PasteShelf needs accessibility permission to monitor the clipboard.

```
System Settings → Privacy & Security → Accessibility → Enable PasteShelf
```

> ⚠️ **Warning**: PasteShelf cannot function without this permission.

### 2. Configure Global Hotkey

The default hotkey is `⌘⇧V`. You can customize this in Preferences.

### 3. Start Copying!

Copy anything (`⌘C`) and PasteShelf automatically saves it to your history.

---

## Essential Shortcuts

| Action | Shortcut |
|--------|----------|
| Open PasteShelf | `⌘⇧V` |
| Search History | Just start typing |
| Paste Selected | `↵` (Return) |
| Paste and Close | `⌘↵` |
| Delete Item | `⌘⌫` |
| Pin Item | `⌘P` |
| Close Panel | `Esc` |
| Navigate | `↑` / `↓` |
| Quick Paste 1-9 | `⌘1` - `⌘9` |

---

## Quick Configuration

### Menu Bar

PasteShelf lives in your menu bar. Click the 📋 icon to:
- View recent items
- Access preferences
- Check for updates

### Preferences (⌘,)

Key settings to configure:

| Setting | Default | Description |
|---------|---------|-------------|
| History Limit | 1000 items | Maximum items to store |
| Launch at Login | Off | Start with macOS |
| Sound Effects | On | Audio feedback |
| Show in Dock | Off | Dock icon visibility |

---

## Feature Tiers

| Feature | 🆓 CE | ⭐ Pro | 🏢 Enterprise |
|---------|-------|--------|---------------|
| Clipboard History | ✅ | ✅ | ✅ |
| Search | ✅ | ✅ | ✅ |
| Categories | ✅ | ✅ | ✅ |
| iCloud Sync | ❌ | ✅ | ✅ |
| AI Search | ❌ | ✅ | ✅ |
| Team Sharing | ❌ | ❌ | ✅ |
| Admin Console | ❌ | ❌ | ✅ |

---

## Troubleshooting Quick Fixes

### PasteShelf not capturing clipboard?

1. Check Accessibility permission is enabled
2. Restart PasteShelf
3. Restart your Mac if issue persists

### Hotkey not working?

1. Check for conflicts in System Settings → Keyboard → Shortcuts
2. Try a different hotkey combination

### High memory usage?

1. Reduce history limit in Preferences
2. Clear old items with "Clear History" option

---

## Next Steps

<table>
<tr>
<td>

**📖 Learn More**
- [Setup Guide](SETUP_GUIDE.md) - Detailed configuration
- [Development Guide](DEVELOPMENT_GUIDE.md) - Contributing to PasteShelf

</td>
<td>

**🏗️ Architecture**
- [Architecture Overview](../architecture/ARCHITECTURE.md)
- [Tech Stack](../architecture/TECH_STACK.md)

</td>
</tr>
<tr>
<td>

**🔧 Features**
- [Clipboard Engine](../features/CLIPBOARD_ENGINE.md)
- [Search Engine](../features/SEARCH_ENGINE.md)

</td>
<td>

**❓ Help**
- [FAQ](../reference/FAQ.md)
- [Troubleshooting](../operations/TROUBLESHOOTING.md)

</td>
</tr>
</table>

---

## Get Help

- **Documentation**: [docs.pasteshelf.app](https://docs.pasteshelf.app)
- **Issues**: [GitHub Issues](https://github.com/pasteshelf/pasteshelf/issues)
- **Discussions**: [GitHub Discussions](https://github.com/pasteshelf/pasteshelf/discussions)
- **Email**: support@pasteshelf.app

---

*Welcome to PasteShelf! 🎉*
