# Setup Guide

> **Last Updated**: 2026-02-03 | **Reading Time**: 15 minutes

Complete guide to setting up PasteShelf for users and developers.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Initial Configuration](#initial-configuration)
- [System Permissions](#system-permissions)
- [User Preferences](#user-preferences)
- [Advanced Features Setup](#advanced-features-setup)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### For Users

| Requirement | Details |
|-------------|---------|
| **macOS** | 14.0 (Sonoma) or later |
| **Processor** | Apple Silicon (M1/M2/M3) or Intel x86_64 |
| **RAM** | 4 GB minimum, 8 GB recommended |
| **Storage** | 100 MB for app, 500 MB+ for clipboard history |
| **Apple ID** | Required for iCloud sync |

### For Developers

| Requirement | Details |
|-------------|---------|
| **Xcode** | 15.0 or later |
| **Swift** | 5.9 or later |
| **Homebrew** | Latest version |
| **Git** | 2.30 or later |
| **Apple Developer Account** | For code signing and CloudKit |

---

## Installation

### Method 1: Direct Download

1. **Download the latest release**
   ```
   https://github.com/pasteshelf/pasteshelf/releases/latest
   ```

2. **Mount the DMG**
   - Double-click `PasteShelf-x.x.x.dmg`

3. **Install the application**
   - Drag `PasteShelf.app` to the `Applications` folder

4. **First launch**
   - Open from Applications
   - macOS may show a security prompt - click "Open"

> 💡 **Tip**: Right-click and select "Open" if macOS blocks the app on first launch.

### Method 2: Homebrew (Coming Soon)

```bash
# Install via Homebrew Cask
brew install --cask pasteshelf

# Verify installation
ls /Applications/PasteShelf.app
```

### Method 3: Build from Source

```bash
# Clone the repository
git clone https://github.com/pasteshelf/pasteshelf.git
cd pasteshelf

# Install development dependencies
brew install swiftlint swiftformat

# Open in Xcode
open PasteShelf.xcodeproj

# Build and run
# Press ⌘R or Product → Run
```

#### Build Configuration

| Configuration | Use Case |
|---------------|----------|
| **Debug** | Development and testing |
| **Release** | Production builds |

---

## Initial Configuration

### Step 1: Launch PasteShelf

After installation, launch PasteShelf from:
- Applications folder
- Spotlight (`⌘Space` → "PasteShelf")
- Launchpad

### Step 2: Complete Onboarding

The onboarding wizard guides you through:

1. **Welcome Screen** - Overview of features
2. **Permissions** - Grant required system permissions
3. **Hotkey Setup** - Configure global shortcut
4. **Preferences** - Basic settings
5. **Ready!** - Start using PasteShelf

### Step 3: Verify Installation

```
┌─────────────────────────────────────────┐
│  ✅ PasteShelf installed               │
│  ✅ Accessibility permission granted    │
│  ✅ Global hotkey configured (⌘⇧V)     │
│  ✅ Menu bar icon visible (📋)         │
│  ✅ First clipboard item captured      │
└─────────────────────────────────────────┘
```

---

## System Permissions

PasteShelf requires specific permissions to function correctly.

### Accessibility (Required)

**Why needed**: Monitor clipboard changes and respond to global hotkeys.

**How to enable**:
```
System Settings → Privacy & Security → Accessibility → PasteShelf ✓
```

```
┌──────────────────────────────────────────────────────────┐
│  Privacy & Security                                       │
│  ─────────────────                                        │
│  Accessibility                                            │
│                                                           │
│  Allow the apps below to control your computer.           │
│                                                           │
│  ┌────────────────────────────────────────────┐          │
│  │ 📋 PasteShelf              [✓]            │          │
│  └────────────────────────────────────────────┘          │
└──────────────────────────────────────────────────────────┘
```

> ⚠️ **Warning**: PasteShelf will not capture clipboard items without this permission.

### Full Disk Access (Optional)

**Why needed**: Access files from clipboard to generate previews.

**How to enable**:
```
System Settings → Privacy & Security → Full Disk Access → PasteShelf ✓
```

### Automation (Optional)

**Why needed**: AppleScript integration and custom actions.

**How to enable**: Granted automatically when first using automation features.

---

## User Preferences

Access Preferences with `⌘,` or from the menu bar icon.

### General Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Launch at Login | Off | Start PasteShelf when macOS boots |
| Show in Dock | Off | Display dock icon |
| Show in Menu Bar | On | Display menu bar icon |
| Sound Effects | On | Play sounds on actions |
| Haptic Feedback | On | Trackpad feedback (MacBooks) |

### History Settings

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| Maximum Items | 1000 | 100-10000 | Total items to store |
| Text Preview Length | 500 | 100-2000 | Characters to preview |
| Image Preview Size | 256px | 64-512px | Thumbnail dimensions |
| Auto-clear After | Never | 1h-1y | Automatic cleanup |

### Privacy Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Exclude Password Managers | On | Don't capture 1Password, etc. |
| Exclude Private Browsing | On | Skip Safari/Chrome private windows |
| Sensitive Content Detection | On | Auto-detect passwords, keys |
| Clear on Quit | Off | Wipe history when closing |

### Appearance Settings

| Setting | Options | Default |
|---------|---------|---------|
| Theme | System / Light / Dark | System |
| Accent Color | System default or custom | System |
| Panel Size | Compact / Standard / Large | Standard |
| Panel Position | Cursor / Center / Custom | Cursor |

### Keyboard Shortcuts

| Action | Default | Customizable |
|--------|---------|--------------|
| Open Panel | `⌘⇧V` | Yes |
| Paste Plain Text | `⌘⇧⌥V` | Yes |
| Open Preferences | `⌘,` | No |
| Quick Paste 1-9 | `⌘1` - `⌘9` | Yes |

---

## Advanced Features Setup

All features are included in PasteShelf. Here is how to enable the advanced features.

### iCloud Sync Setup

```
Preferences → Sync → Enable iCloud Sync ✓
```

Requirements:
- Signed into iCloud on Mac
- iCloud Drive enabled
- Sufficient iCloud storage

### AI-Powered Search

```
Preferences → Search → Enable AI Search ✓
```

> AI processing happens on-device using Core ML. No data leaves your Mac.

### Custom Actions

```
Preferences → Actions → Create New Action
```

Example action: "Uppercase Text"
```swift
// Action Script (JavaScript)
function transform(text) {
    return text.toUpperCase();
}
```

### MDM Deployment

Supported MDM solutions:
- Jamf Pro
- Kandji
- Mosyle
- Microsoft Intune

Example Jamf deployment:
```xml
<dict>
    <key>BundleIdentifier</key>
    <string>com.pasteshelf.PasteShelf</string>
    <key>Version</key>
    <string>1.0.0</string>
    <key>InstallPath</key>
    <string>/Applications/PasteShelf.app</string>
</dict>
```

### SSO Integration

```
Preferences → Authentication → Configure SSO
```

Supported providers:
- Okta
- Azure AD
- Google Workspace
- OneLogin
- Custom SAML 2.0

### Compliance Settings

```
Preferences → Compliance → Configure Policies
```

Available policies:
- Data retention periods
- Content filtering rules
- Audit log settings
- Export restrictions

See [Enterprise Admin Guide](../enterprise/ENTERPRISE_ADMIN_GUIDE.md) for detailed setup.

---

## Troubleshooting

### Common Issues

#### "PasteShelf can't be opened because it is from an unidentified developer"

**Solution**:
```bash
# Remove quarantine attribute
xattr -dr com.apple.quarantine /Applications/PasteShelf.app
```

Or: Right-click → Open → Open

#### Clipboard not being captured

**Checklist**:
1. ✅ Accessibility permission enabled?
2. ✅ PasteShelf running (check menu bar)?
3. ✅ App not in excluded list?
4. ✅ Not a password manager field?

#### High CPU/Memory usage

**Solutions**:
1. Reduce history limit (`Preferences → History → Maximum Items`)
2. Disable image previews
3. Clear old history items

#### iCloud sync not working

**Checklist**:
1. ✅ Signed into iCloud?
2. ✅ iCloud Drive enabled?
3. ✅ Internet connection active?

### Getting Help

- **Documentation**: [docs.pasteshelf.app](https://docs.pasteshelf.app)
- **FAQ**: [Reference FAQ](../reference/FAQ.md)
- **Issues**: [GitHub Issues](https://github.com/pasteshelf/pasteshelf/issues)
- **Support**: support@pasteshelf.app

---

## Next Steps

| Document | Description |
|----------|-------------|
| [Development Guide](DEVELOPMENT_GUIDE.md) | For contributors |
| [Architecture](../architecture/ARCHITECTURE.md) | System overview |
| [Features](../features/CLIPBOARD_ENGINE.md) | Feature deep-dives |
| [Troubleshooting](../operations/TROUBLESHOOTING.md) | Detailed solutions |

---

*Last updated: 2026-02-03*
