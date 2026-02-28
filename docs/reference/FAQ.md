# Frequently Asked Questions

> **Last Updated**: 2026-02-03 | **Reading Time**: 12 minutes

Answers to common questions about PasteShelf.

---

## Table of Contents

- [General Questions](#general-questions)
- [Features](#features)
- [Privacy & Security](#privacy--security)
- [Technical](#technical)
- [Troubleshooting](#troubleshooting)

---

## General Questions

### What is PasteShelf?

PasteShelf is a privacy-first clipboard manager for macOS that stores your clipboard history locally, with optional encrypted cloud sync. All features are free and open source under AGPL-3.0.

### What macOS versions are supported?

PasteShelf requires **macOS 14.0 (Sonoma)** or later. This requirement enables modern APIs including:
- SwiftData compatibility
- Advanced SwiftUI features
- Enhanced privacy controls

### Is PasteShelf free?

**Yes!** PasteShelf is completely free and open source (AGPL-3.0). All features are included:
- Unlimited clipboard history
- Full-text, semantic, and OCR search
- iCloud sync with E2E encryption
- Keyboard shortcuts and automation
- Plugin system
- Enterprise features (SSO, MDM, audit logs, DLP)

### How does PasteShelf compare to other clipboard managers?

| Feature | PasteShelf | Paste | Maccy | Alfred |
|---------|------------|-------|-------|--------|
| Free | ✅ All features | ❌ | ✅ | ❌ |
| Open source | ✅ Fully | ❌ | ✅ | ❌ |
| E2E sync | ✅ | ✅ | ❌ | ❌ |
| Semantic search | ✅ | ❌ | ❌ | ❌ |
| Enterprise MDM | ✅ | ❌ | ❌ | ❌ |

---

## Features

### What content types are supported?

- Plain text
- Rich text (RTF)
- Images (PNG, JPEG, GIF, TIFF)
- File references
- URLs
- Code snippets with syntax highlighting
- Colors
- Files (with preview)

### How many items can I store?

Unlimited (recommended: 10,000 for optimal performance). Administrators can configure limits via MDM.

### Can I organize my clipboard items?

**Yes!** PasteShelf supports:
- Favorites/pinning
- Tags
- Smart collections
- Folders
- Shared collections (team)

### Does PasteShelf support keyboard shortcuts?

**Yes!** Default shortcuts:

| Action | Shortcut |
|--------|----------|
| Open panel | `⌘⇧V` |
| Search | `⌘F` |
| Paste item 1-9 | `⌘1` - `⌘9` |
| Clear history | `⌘⇧⌫` |

All shortcuts are customizable in Preferences.

### Can I sync across devices?

**Yes!** Sync features:
- iCloud sync via CloudKit
- End-to-end encryption
- Selective sync (choose what syncs)
- Conflict resolution
- Offline support with automatic reconciliation

---

## Privacy & Security

### Is my clipboard data private?

**Absolutely.** Privacy principles:

1. **Local-first**: All data stored on your device by default
2. **No telemetry**: Zero data collection
3. **E2E encryption**: Sync data encrypted before leaving device
4. **Open source**: Core code auditable by anyone

### Does PasteShelf send my data anywhere?

**By default**: No. Everything stays on your device.

**With sync enabled**: Data is encrypted on your device before upload to iCloud or your self-hosted server. We cannot read your clipboard contents.

### How is sensitive data protected?

PasteShelf automatically detects and handles:
- Passwords (excluded by default)
- API keys and tokens
- Credit card numbers
- Social Security Numbers
- Private keys

Options:
- Auto-exclude from history
- Mask in UI
- Never sync
- Auto-delete after time

### Which apps are excluded by default?

Password managers are automatically excluded:
- 1Password
- Bitwarden
- LastPass
- Dashlane
- Keychain Access
- KeePassXC

You can customize exclusions in Preferences → Privacy.

### Is PasteShelf GDPR compliant?

**Yes.** We support:
- Data export (JSON format)
- Data deletion (complete wipe)
- Data portability
- No tracking
- Opt-in analytics only

### Is PasteShelf HIPAA compliant?

PasteShelf can be configured for HIPAA compliance:
- BAA available
- Full audit logging
- PHI auto-detection
- Encryption enforcement
- Access controls

Contact: legal@pasteshelf.app

---

## Technical

### Where is my data stored?

```
~/Library/Application Support/PasteShelf/
├── PasteShelf.sqlite       # Main database
├── PasteShelf.sqlite-shm   # Shared memory
├── PasteShelf.sqlite-wal   # Write-ahead log
├── Attachments/            # Image/file storage
└── Preferences.plist       # Settings
```

### Can I backup my data?

**Yes!** Options:

1. **Time Machine**: Automatic
2. **Manual export**: File → Export History
3. **iCloud sync**: Automatic backup

### Does PasteShelf work offline?

**Yes!** PasteShelf is fully functional offline. Sync occurs when connectivity returns.

### How much disk space does PasteShelf use?

Typical usage:
- App: ~25 MB
- Database (10K items): ~50 MB
- With images: Varies (thumbnails compressed)

### Can I import from other clipboard managers?

**Yes!** Supported imports:
- Paste (JSON export)
- Maccy (SQLite)
- Alfred clipboard history
- Plain text/CSV

File → Import → Select format

### Does PasteShelf support Apple Silicon?

**Yes!** PasteShelf is a Universal Binary running natively on:
- Apple Silicon (M1, M2, M3, M4)
- Intel Macs

---

## Troubleshooting

### PasteShelf isn't capturing my clipboard

1. Check Accessibility permission:
   ```
   System Settings → Privacy & Security → Accessibility → PasteShelf ✓
   ```
2. Verify PasteShelf is running (menu bar icon)
3. Check if source app is excluded
4. Restart PasteShelf

### Search isn't finding my items

1. Try simpler search terms
2. Check active filters
3. Rebuild search index:
   ```
   Preferences → Advanced → Rebuild Index
   ```

### Sync isn't working

1. Check iCloud sign-in status
3. Ensure iCloud Drive is enabled
4. Check internet connection
5. Reset sync state:
   ```
   Preferences → Sync → Reset Sync
   ```

### PasteShelf is using too much memory

1. Reduce history limit (Preferences → General)
2. Clear old items
3. Disable image previews
4. Check for corrupt items

### How do I completely uninstall PasteShelf?

```bash
# Quit PasteShelf first, then:

# Remove app
rm -rf /Applications/PasteShelf.app

# Remove data
rm -rf ~/Library/Application\ Support/PasteShelf
rm -rf ~/Library/Caches/com.pasteshelf.PasteShelf
rm -rf ~/Library/Preferences/com.pasteshelf.PasteShelf.plist

# Remove from login items (manual)
# System Settings → General → Login Items → Remove PasteShelf
```

---

## Still Have Questions?

### Community Support
- [GitHub Discussions](https://github.com/pasteshelf/pasteshelf/discussions)
- [GitHub Issues](https://github.com/pasteshelf/pasteshelf/issues)

### Email Support
- Email: support@pasteshelf.app
- Enterprise inquiries: enterprise@pasteshelf.app

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Quick Start](../getting-started/QUICK_START.md) | Get started quickly |
| [Troubleshooting](../operations/TROUBLESHOOTING.md) | Detailed solutions |

---

*Last updated: 2026-02-03*
