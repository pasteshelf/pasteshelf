# PasteShelf Privacy Policy

**Effective Date**: February 2026
**Last Updated**: February 4, 2026

---

## Introduction

PasteShelf ("we", "our", or "the app") is a privacy-first clipboard manager for macOS. This Privacy Policy explains how we collect, use, and protect your information.

**Our Core Principle**: Your clipboard data belongs to you. We designed PasteShelf to keep your data local and private by default.

---

## Summary

| Aspect | Details |
|--------|---------|
| Data Storage | Local only (optional iCloud sync) |
| Data Collection | None |
| Analytics | None |
| Third-party Services | Apple iCloud (optional, for sync) |
| Encryption | At rest + in transit (when sync enabled) |

---

## Data We Collect

**We collect NO data.** Zero. None.

- No analytics or telemetry
- No crash reports sent to us
- No usage statistics
- No personal information
- No clipboard content transmitted anywhere

### iCloud Sync (Optional)

If you enable iCloud sync, the following applies:
- Your encrypted clipboard data syncs through Apple's iCloud
- Data is end-to-end encrypted before leaving your device
- We cannot read your synced data
- Apple's privacy policy applies to iCloud services

---

## Data Stored on Your Device

### What is Stored

PasteShelf stores the following data locally on your Mac:

| Data Type | Purpose | Location |
|-----------|---------|----------|
| Clipboard History | Core functionality | `~/Library/Application Support/PasteShelf/` |
| Settings/Preferences | App configuration | `~/Library/Preferences/com.pasteshelf.PasteShelf.plist` |
| Image Thumbnails | Preview display | `~/Library/Application Support/PasteShelf/` |
| Search Index | Fast search | `~/Library/Application Support/PasteShelf/` |

### How Long Data is Stored

- **History Limit**: You control how many items are stored (100/500/1000/unlimited)
- **Auto-cleanup**: You can configure automatic deletion after X days
- **Manual Deletion**: You can delete individual items or clear all history anytime

### Data Security

- Data stored locally, protected by macOS file permissions
- Only accessible to your user account
- Optional database encryption using macOS Keychain
- iCloud data (if sync enabled) encrypted with end-to-end encryption

---

## Sensitive Data Handling

### Automatic Detection

PasteShelf automatically detects potentially sensitive content:
- Passwords (from password managers)
- Credit card numbers
- API keys and tokens
- Social Security Numbers

### Default Exclusions

By default, PasteShelf does NOT capture content from:
- 1Password
- Bitwarden
- LastPass
- Dashlane
- KeePassXC
- Other password managers
- Private browsing windows (Safari, Chrome, Firefox)

You can customize these exclusions in Settings.

---

## Third-Party Services

PasteShelf has no third-party service integrations by default. If you enable iCloud sync:

| Service | Purpose | Data Shared |
|---------|---------|-------------|
| Apple iCloud | Optional sync | Encrypted clipboard data |

We do NOT use:
- Analytics services (Google Analytics, Mixpanel, etc.)
- Crash reporting services (Crashlytics, Sentry, etc.)
- Advertising networks
- Data brokers

---

## Your Rights

### Access Your Data

All your data is stored locally. You can:
- View it in the app at any time
- Access the raw database at `~/Library/Application Support/PasteShelf/`

### Export Your Data

PasteShelf includes data export functionality.

### Delete Your Data

You can delete your data anytime:
1. **Individual items**: Select and delete in the app
2. **All history**: Settings → Privacy → Clear History
3. **Complete removal**: Delete `~/Library/Application Support/PasteShelf/`

### Control Your Data

You control:
- What apps are excluded from capture
- How long history is kept
- Whether to use iCloud sync
- Whether to enable encryption

---

## Children's Privacy

PasteShelf is not intended for use by children under 13. We do not knowingly collect information from children.

---

## International Users

Your data stays on your device, or within Apple's iCloud infrastructure if you enable sync. We do not transfer data internationally.

---

## Changes to This Policy

We will post any privacy policy changes on this page. Significant changes will be communicated through:
- In-app notification
- Release notes
- Our website

---

## Enterprise Features

PasteShelf includes enterprise features that may involve additional data processing when enabled:
- SSO authentication (through your identity provider)
- Audit logging (stored per your administrator's configuration)
- Centralized management (if enabled by your organization)

Contact your IT administrator for your organization's specific privacy policies.

---

## Open Source

PasteShelf is free and open source (AGPL-3.0). You can:
- Audit our code on GitHub
- Verify our privacy claims
- Build the app yourself

Repository: [github.com/pasteshelf/pasteshelf](https://github.com/pasteshelf/pasteshelf)

---

## Contact Us

For privacy-related questions:

- **Email**: privacy@pasteshelf.com
- **GitHub**: [github.com/pasteshelf/pasteshelf/issues](https://github.com/pasteshelf/pasteshelf/issues)

---

## Summary

1. **100% local by default**, zero data collection
2. **Optional iCloud sync** with end-to-end encryption
3. **No analytics, no telemetry, no ads**
4. **You control your data**
5. **Open source** (AGPL-3.0) for full transparency

---

*PasteShelf - Privacy-First Clipboard Manager for macOS*
