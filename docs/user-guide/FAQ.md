# PasteShelf FAQ

Frequently asked questions about PasteShelf, your privacy-first clipboard manager for macOS.

---

## Table of Contents

- [Installation & Setup](#installation--setup)
- [Usage](#usage)
- [Privacy & Security](#privacy--security)
- [Troubleshooting](#troubleshooting)
- [Features](#features)
- [Performance](#performance)
- [License](#license)

---

## Installation & Setup

### What are the system requirements for PasteShelf?

PasteShelf requires:
- **macOS 14.0 (Sonoma)** or later
- **Apple Silicon** (M1/M2/M3) or Intel Mac
- ~50 MB of disk space

### Why does PasteShelf need Accessibility permission?

Accessibility permission allows PasteShelf to:
- Simulate the paste keystroke (⌘V) to paste items into other apps
- Detect when you're in a private browsing window

Without this permission, PasteShelf can only copy items to your clipboard, but cannot automatically paste them.

### How do I grant Accessibility permission?

1. Go to **System Settings > Privacy & Security > Accessibility**
2. Click the lock icon and authenticate
3. Find PasteShelf and enable the checkbox
4. If PasteShelf isn't listed, click the "+" button and add it from Applications

### Can I use PasteShelf without Accessibility permission?

Yes, but with limited functionality:
- You can browse clipboard history
- You can copy items back to clipboard
- Automatic pasting won't work - you'll need to manually press ⌘V after selecting an item

### How do I change the global hotkey?

1. Open **Preferences** (⌘,)
2. Go to the **Shortcuts** tab
3. Click the hotkey recorder field
4. Press your desired key combination
5. The new hotkey is saved automatically

---

## Usage

### How many clipboard items can PasteShelf store?

You can choose from several limits in Settings > General:
- **100 items** - Minimal footprint
- **500 items** - Balanced (default)
- **1,000 items** - Extended history
- **Unlimited** - No automatic limit

### Are images and files saved?

Yes, PasteShelf saves:
- **Images**: Thumbnails are generated for preview, full images are stored
- **Files**: File references are stored (not the actual files)
- **Rich text**: RTF formatting is preserved
- **URLs**: Web links with favicons

### How do I paste without closing the panel?

Hold **⌘ (Command)** while pressing Enter to paste without closing the panel. This is useful for pasting multiple items.

### Can I edit clipboard items?

Currently, PasteShelf doesn't support editing items. You can:
1. Copy the item to your clipboard
2. Paste it somewhere
3. Edit it there
4. Copy the edited version

### How do I delete all my clipboard history?

1. Open **Preferences** (⌘,)
2. Go to the **Privacy** tab
3. Click **Clear History**
4. Confirm the action

Note: This cannot be undone.

### Why aren't my recent copies showing up?

Check these common causes:
1. **Monitoring paused**: Look for the paused indicator in the menu bar
2. **App excluded**: The source app may be in your excluded apps list
3. **Private browsing**: Content from private browser windows is excluded by default
4. **Password content**: Content from password managers is excluded by default

---

## Privacy & Security

### Where is my data stored?

All data is stored locally on your Mac in:
```
~/Library/Application Support/PasteShelf/
```

This includes:
- Clipboard history database
- Settings
- Image cache

### Does PasteShelf send data to the cloud?

**No.** By default, PasteShelf is 100% local. No data ever leaves your Mac.

If you enable iCloud sync, your data is protected with end-to-end encryption.

### How does PasteShelf detect sensitive data?

PasteShelf uses pattern matching to detect:
- Credit card numbers (Visa, MasterCard, etc.)
- Social Security Numbers
- API keys and tokens
- Password patterns
- Content from password manager apps

Detected sensitive content is flagged and can be automatically excluded.

### Can I see which apps have been excluded?

Yes, go to **Preferences > Privacy > Excluded Apps** to see and manage the list.

### Is my clipboard history encrypted?

By default, data is stored unencrypted (but only accessible to your user account).

You can enable database encryption using your device keychain in Preferences.

### What happens when I delete PasteShelf?

When you uninstall PasteShelf:
1. The app is removed from Applications
2. Clipboard data remains in `~/Library/Application Support/PasteShelf/`
3. To fully remove data, delete this folder manually

---

## Troubleshooting

### PasteShelf won't open the clipboard panel

1. **Check accessibility permission** - The most common cause
2. **Check the hotkey** - Make sure it's not conflicting with another app
3. **Restart PasteShelf** - Quit and relaunch from Applications
4. **Check menu bar** - Try opening via the menu bar icon

### Items aren't being saved

1. **Check if monitoring is paused** - Resume from menu bar
2. **Check excluded apps** - The source app might be excluded
3. **Check private browsing setting** - Disable if needed
4. **Restart PasteShelf** - Some apps require a restart

### The paste action isn't working

1. **Verify accessibility permission** is granted and active
2. **Check the target app** - Some apps don't accept programmatic paste
3. **Try manual paste** - Select item, then press ⌘V manually
4. **Restart the target app** - Some apps need a restart

### PasteShelf is using too much memory

1. **Reduce history limit** - Lower the maximum items in Settings
2. **Clear old history** - Delete items you no longer need
3. **Enable auto-cleanup** - Set auto-delete after X days
4. **Check for large images** - Large images use more memory

### The search is slow

1. **Reduce history size** - Fewer items = faster search
2. **Update macOS** - Latest system updates improve performance
3. **Restart PasteShelf** - Clears temporary caches

### I can't find an item I copied

1. **Check if monitoring was paused** at that time
2. **Check auto-delete settings** - Item may have been cleaned up
3. **Check the source app** - It might be excluded
4. **Try searching** - Use the search field to find it

---

## Features

### What features does PasteShelf include?

All features are included for free:
- Clipboard history (unlimited)
- Full-text, semantic, and OCR search
- Favorites, tags, and smart collections
- Customizable hotkey and keyboard shortcuts
- iCloud sync with end-to-end encryption
- Plugin system
- Enterprise features (SSO, MDM, audit logs, DLP)

### Does PasteShelf work with multiple monitors?

Yes! The floating panel appears on the screen where your cursor is located.

### Can I use PasteShelf with multiple macOS user accounts?

Yes. Each user account has its own separate clipboard history and settings.

### Does PasteShelf sync between Macs?

Yes, PasteShelf supports optional iCloud sync with end-to-end encryption. Enable it in Preferences.

### Can I export my clipboard history?

Yes, PasteShelf supports data export. Use File > Export History to export your clipboard data.

---

## Performance

### Does PasteShelf slow down my Mac?

PasteShelf is designed to be lightweight:
- **CPU**: Minimal usage (checks clipboard every 250ms)
- **Memory**: ~30-50 MB typically, depends on history size
- **Disk**: Small SQLite database

### How much disk space does PasteShelf use?

Depends on your usage:
- **Text-heavy**: ~10-50 MB
- **Image-heavy**: ~100-500 MB
- **Heavy usage**: ~500 MB - 1 GB

### Does PasteShelf affect battery life?

Minimally. The clipboard polling is very efficient and doesn't significantly impact battery life.

---

## License

### Is PasteShelf free?

**Yes!** PasteShelf is completely free and open source under the AGPL-3.0 license. All features are included -- there are no paid tiers or subscriptions.

---

## Still Have Questions?

- **Documentation**: [docs.pasteshelf.com](https://docs.pasteshelf.com)
- **Support**: support@pasteshelf.com
- **Community**: [github.com/pasteshelf/pasteshelf/discussions](https://github.com/pasteshelf/pasteshelf/discussions)
- **Report bugs**: [github.com/pasteshelf/pasteshelf/issues](https://github.com/pasteshelf/pasteshelf/issues)

---

*Last updated: February 2026*
