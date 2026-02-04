# PasteShelf User Guide

Welcome to PasteShelf, your privacy-first clipboard manager for macOS. This guide will help you get the most out of PasteShelf.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [The Floating Panel](#the-floating-panel)
3. [Search and Filters](#search-and-filters)
4. [Keyboard Shortcuts](#keyboard-shortcuts)
5. [Favorites](#favorites)
6. [Settings](#settings)
7. [Privacy & Security](#privacy--security)
8. [Tips & Tricks](#tips--tricks)

---

## Getting Started

### Installation

1. Download PasteShelf from the Mac App Store or the official website
2. Open the downloaded `.dmg` file and drag PasteShelf to your Applications folder
3. Launch PasteShelf from your Applications folder

### First Launch

When you first launch PasteShelf, you'll be guided through a brief onboarding process:

1. **Welcome Screen**: Overview of PasteShelf's key features
2. **Accessibility Permission**: Required for pasting into other apps
3. **Quick Tutorial**: Learn the basics of using PasteShelf
4. **Hotkey Setup**: Configure your preferred keyboard shortcut

### Granting Accessibility Permission

PasteShelf requires accessibility permission to paste items into other applications. Here's how to enable it:

1. Click "Open System Settings" during onboarding, or go to **System Settings > Privacy & Security > Accessibility**
2. Click the lock icon and enter your password
3. Find PasteShelf in the list and enable the checkbox
4. The permission will be verified automatically

---

## The Floating Panel

The floating panel is your main interface for browsing and selecting clipboard items.

### Opening the Panel

- **Keyboard shortcut**: Press `⌘⇧V` (or your custom hotkey)
- **Menu bar**: Click the PasteShelf icon in the menu bar and select "Show Clipboard Panel"

### Panel Features

- **Header**: Shows "Clipboard History" and the current item count
- **Search field**: Type to filter your clipboard history
- **Filter chips**: Quick filters for content types and favorites
- **Item list**: Your clipboard history, organized by date

### Navigating Items

- Use **↑** and **↓** arrow keys to navigate between items
- Press **Enter** to paste the selected item
- Press **Delete** to remove the selected item
- Press **Escape** to close the panel

### Understanding Item Types

PasteShelf displays different icons for different content types:

| Icon | Content Type |
|------|-------------|
| 📄 | Plain text |
| 🎨 | Rich text (RTF) |
| 🌐 | Web content (HTML) |
| 🖼️ | Image |
| 📁 | File |
| 🔗 | URL/Link |

---

## Search and Filters

### Searching Your Clipboard

1. Open the floating panel
2. Start typing in the search field (or press `⌘F` to focus it)
3. Results update in real-time as you type
4. Press **Escape** to clear the search

### Using Filters

Filter chips let you quickly narrow down your clipboard history:

- **All**: Show all items
- **Text**: Text content only
- **Images**: Images only
- **Links**: URLs and web links
- **Files**: File references
- **⭐ Favorites**: Only favorited items

Click a filter chip to toggle it. Active filters are highlighted.

### Combining Search and Filters

You can use search and filters together. For example:
- Search for "email" + filter by "Text" to find only text items containing "email"

---

## Keyboard Shortcuts

### Global Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘⇧V` | Open/close clipboard panel (customizable) |

### Panel Shortcuts

| Shortcut | Action |
|----------|--------|
| `↑` / `↓` | Navigate items |
| `Enter` | Paste selected item |
| `Delete` | Delete selected item |
| `⌘S` | Toggle favorite |
| `⌘F` | Focus search field |
| `⌘1-9` | Quick paste (items 1-9) |
| `Escape` | Clear search / Close panel |

### Quick Paste

With Quick Paste enabled (Settings > Shortcuts), you can paste recent items directly:
- `⌘1` pastes the most recent item
- `⌘2` pastes the second most recent
- And so on up to `⌘9`

---

## Favorites

Favorites help you keep important items from being automatically deleted.

### Adding Favorites

1. Select an item in the floating panel
2. Press `⌘S` to toggle favorite status
3. The star icon ⭐ indicates a favorited item

### Viewing Favorites

Click the **Favorites** filter chip to show only favorited items.

### Why Use Favorites?

- Favorites are **never automatically deleted**, even when auto-cleanup runs
- Keep frequently-used text snippets, links, or images easily accessible
- Organize your most important clipboard content

---

## Settings

Access Settings via:
- Menu bar icon > Preferences
- Keyboard shortcut: `⌘,` (when PasteShelf is active)

### General Settings

| Setting | Description |
|---------|-------------|
| Launch at Login | Start PasteShelf automatically when you log in |
| Show in Dock | Display PasteShelf icon in the macOS Dock |
| Check for Updates | Automatically check for new versions |
| History Limit | Maximum number of items to keep (100/500/1000/Unlimited) |

### Privacy Settings

| Setting | Description |
|---------|-------------|
| Excluded Apps | Apps whose clipboard content won't be saved |
| Clear History | Delete all clipboard history |
| Auto-delete after X days | Automatically remove old items |
| Pause Monitoring | Temporarily stop capturing clipboard content |
| Exclude Private Browsing | Don't capture content from private browser windows |

### Appearance Settings

| Setting | Description |
|---------|-------------|
| Theme | System/Light/Dark appearance |
| Panel Width | Narrow/Normal/Wide panel size |
| Preview Lines | Number of text lines shown in previews (1-5) |
| Show Thumbnails | Display image thumbnails |
| Compact Mode | Smaller item rows for more items on screen |

### Shortcuts Settings

| Setting | Description |
|---------|-------------|
| Global Hotkey | Keyboard shortcut to open PasteShelf |
| Quick Paste | Enable ⌘1-9 shortcuts for recent items |

---

## Privacy & Security

PasteShelf is designed with privacy as a core principle.

### Local-Only Storage

- All clipboard data is stored locally on your Mac
- No data is ever sent to external servers
- No telemetry or analytics collected

### Sensitive Data Detection

PasteShelf automatically detects and protects sensitive content:
- Passwords (from password managers)
- Credit card numbers
- API keys and tokens
- Social Security Numbers

Sensitive items are:
- Marked with a warning indicator
- Hidden by default (click to reveal)
- Can be automatically excluded via Settings

### Excluded Apps

By default, PasteShelf excludes content from password managers:
- 1Password
- Bitwarden
- LastPass
- Dashlane
- KeePassXC
- And others

Add additional excluded apps in Settings > Privacy > Excluded Apps.

### Private Browsing

When "Exclude Private Browsing" is enabled, PasteShelf won't capture content from:
- Safari Private Browsing windows
- Chrome Incognito windows
- Firefox Private windows
- Other browsers' private modes

---

## Tips & Tricks

### Quick Actions

1. **Double-click** an item to paste it immediately
2. **Right-click** for context menu options (copy, delete, favorite)
3. Use **date headers** to find items by when they were copied

### Managing Large Histories

- Set a reasonable history limit to keep performance smooth
- Use favorites to preserve important items
- Enable auto-delete to automatically clean old items

### Workflow Tips

1. **Code Snippets**: Copy frequently-used code and favorite it
2. **Templates**: Store email templates or boilerplate text
3. **Research**: Collect links and quotes while researching
4. **Quick Reference**: Keep important information handy

### Troubleshooting Quick Fixes

- **Panel won't open**: Check that accessibility permission is granted
- **Items not saving**: Ensure monitoring isn't paused (check menu bar)
- **Slow performance**: Reduce history limit or enable compact mode

---

## Need Help?

- **In-app help**: Press `⌘?` or go to Help menu
- **Support**: Visit [pasteshelf.com/support](https://pasteshelf.com/support)
- **Report issues**: [github.com/pasteshelf/pasteshelf/issues](https://github.com/pasteshelf/pasteshelf/issues)

---

*PasteShelf v1.0.0 - Privacy-First Clipboard Manager for macOS*
