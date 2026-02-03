# API Documentation

> **Last Updated**: 2026-02-03 | **Reading Time**: 25 minutes

Complete API reference for PasteShelf integrations and automation.

---

## Table of Contents

- [Overview](#overview)
- [Plugin API](#plugin-api)
- [AppleScript API](#applescript-api)
- [Shortcuts Integration](#shortcuts-integration)
- [URL Scheme](#url-scheme)
- [Webhooks](#webhooks)
- [JavaScript Actions](#javascript-actions)
- [CLI Interface](#cli-interface)

---

## Overview

PasteShelf provides multiple integration points for automation and extensibility:

| API | Tier | Use Case |
|-----|------|----------|
| Plugin API | ⭐ Pro | Custom transformations and integrations |
| AppleScript | ⭐ Pro | System automation |
| Shortcuts | ⭐ Pro | Visual automation |
| URL Scheme | 🆓 CE | Deep linking |
| Webhooks | 🏢 Enterprise | External integrations |
| JavaScript Actions | ⭐ Pro | In-app transformations |
| CLI | 🆓 CE | Terminal access |

---

## Plugin API ⭐

### Plugin Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Plugin Architecture                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌─────────────────────────────────────────────────────┐   │
│   │                   PasteShelf Host                    │   │
│   │                                                      │   │
│   │   ┌───────────────────────────────────────────────┐ │   │
│   │   │              Plugin Manager                    │ │   │
│   │   │                                                │ │   │
│   │   │   ┌──────────┐ ┌──────────┐ ┌──────────┐     │ │   │
│   │   │   │ Plugin A │ │ Plugin B │ │ Plugin C │     │ │   │
│   │   │   │ (Bundle) │ │ (Bundle) │ │ (Bundle) │     │ │   │
│   │   │   └────┬─────┘ └────┬─────┘ └────┬─────┘     │ │   │
│   │   │        │            │            │            │ │   │
│   │   │   ┌────┴────────────┴────────────┴─────────┐ │ │   │
│   │   │   │           Plugin Protocol               │ │ │   │
│   │   │   │  • transform(content:) -> Content      │ │ │   │
│   │   │   │  • supports(contentType:) -> Bool      │ │ │   │
│   │   │   │  • menuItems() -> [MenuItem]           │ │ │   │
│   │   │   └────────────────────────────────────────┘ │ │   │
│   │   └───────────────────────────────────────────────┘ │   │
│   └─────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Plugin Protocol

```swift
/// Protocol that all PasteShelf plugins must conform to
public protocol PasteShelfPlugin {
    /// Unique identifier for the plugin
    static var identifier: String { get }

    /// Human-readable name
    static var name: String { get }

    /// Plugin version
    static var version: String { get }

    /// Supported content types
    static var supportedTypes: [ContentType] { get }

    /// Initialize the plugin
    init()

    /// Transform clipboard content
    /// - Parameter content: The content to transform
    /// - Returns: Transformed content or nil if transformation fails
    func transform(content: ClipboardContent) async throws -> ClipboardContent?

    /// Check if plugin supports a specific content type
    /// - Parameter type: The content type to check
    /// - Returns: true if the plugin can handle this type
    func supports(contentType: ContentType) -> Bool

    /// Menu items to display in context menu
    /// - Returns: Array of menu items
    func menuItems() -> [PluginMenuItem]

    /// Called when plugin is loaded
    func didLoad()

    /// Called when plugin is unloaded
    func willUnload()
}

/// Default implementations
public extension PasteShelfPlugin {
    func supports(contentType: ContentType) -> Bool {
        Self.supportedTypes.contains(contentType)
    }

    func didLoad() {}
    func willUnload() {}
}
```

### Creating a Plugin

#### 1. Create Plugin Bundle

```
MyPlugin.pasteshelfplugin/
├── Contents/
│   ├── Info.plist
│   ├── MacOS/
│   │   └── MyPlugin
│   └── Resources/
│       └── icon.png
```

#### 2. Info.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.example.myplugin</string>
    <key>CFBundleName</key>
    <string>My Plugin</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>PSPluginClass</key>
    <string>MyPlugin.MyPlugin</string>
    <key>PSSupportedContentTypes</key>
    <array>
        <string>public.plain-text</string>
        <string>public.utf8-plain-text</string>
    </array>
</dict>
</plist>
```

#### 3. Plugin Implementation

```swift
import Foundation
import PasteShelfPluginKit

@objc(MyPlugin)
public final class MyPlugin: NSObject, PasteShelfPlugin {
    public static let identifier = "com.example.myplugin"
    public static let name = "My Plugin"
    public static let version = "1.0.0"
    public static let supportedTypes: [ContentType] = [.plainText, .richText]

    public override init() {
        super.init()
    }

    public func transform(content: ClipboardContent) async throws -> ClipboardContent? {
        guard let text = content.text else { return nil }

        // Transform the text
        let transformed = text.uppercased()

        return ClipboardContent(text: transformed)
    }

    public func menuItems() -> [PluginMenuItem] {
        return [
            PluginMenuItem(
                title: "Uppercase",
                icon: "textformat.abc.dottedunderline",
                action: { [weak self] content in
                    try await self?.transform(content: content)
                }
            )
        ]
    }
}
```

### Plugin Installation

Plugins are installed to:
```
~/Library/Application Support/PasteShelf/Plugins/
```

```swift
// Programmatic installation
let pluginManager = PluginManager.shared

do {
    try await pluginManager.install(from: pluginURL)
    print("Plugin installed successfully")
} catch {
    print("Installation failed: \(error)")
}
```

### Plugin API Reference

#### ClipboardContent

```swift
public struct ClipboardContent {
    /// Text content (if applicable)
    public var text: String?

    /// RTF data (if applicable)
    public var rtfData: Data?

    /// HTML content (if applicable)
    public var html: String?

    /// Image data (if applicable)
    public var imageData: Data?

    /// File URLs (if applicable)
    public var fileURLs: [URL]?

    /// Raw data with UTI type
    public var rawData: [String: Data]

    /// Content type
    public var contentType: ContentType

    /// Metadata
    public var metadata: [String: Any]
}
```

#### PluginMenuItem

```swift
public struct PluginMenuItem {
    /// Menu item title
    public let title: String

    /// SF Symbol icon name
    public let icon: String?

    /// Keyboard shortcut
    public let shortcut: KeyboardShortcut?

    /// Action to perform
    public let action: (ClipboardContent) async throws -> ClipboardContent?

    /// Submenu items (optional)
    public let submenu: [PluginMenuItem]?
}
```

---

## AppleScript API ⭐

### AppleScript Dictionary

```applescript
-- PasteShelf AppleScript Suite

-- Application
application "PasteShelf"
    -- Properties
    clipboard history : list of clipboard items
    current item : clipboard item
    is monitoring : boolean

    -- Commands
    search for : search clipboard history
    paste item : paste a clipboard item
    delete item : delete a clipboard item
    clear history : clear all history
```

### Examples

#### Get Recent Items

```applescript
tell application "PasteShelf"
    set recentItems to clipboard history

    repeat with item in recentItems
        log "Content: " & (text content of item)
        log "Date: " & (created date of item)
    end repeat
end tell
```

#### Search Clipboard

```applescript
tell application "PasteShelf"
    set results to search for "important" with limit 10

    if (count of results) > 0 then
        set firstResult to item 1 of results
        paste item firstResult
    end if
end tell
```

#### Add Custom Content

```applescript
tell application "PasteShelf"
    set newItem to make new clipboard item with properties {
        text content: "Custom content",
        is favorite: true
    }
end tell
```

#### Monitor Clipboard Changes

```applescript
tell application "PasteShelf"
    -- Enable monitoring
    set is monitoring to true

    -- Wait for new item
    repeat
        set currentContent to text content of current item
        if currentContent contains "trigger" then
            -- Do something
            display notification "Trigger detected!"
        end if
        delay 1
    end repeat
end tell
```

---

## Shortcuts Integration ⭐

### Available Actions

| Action | Description | Parameters |
|--------|-------------|------------|
| Get Clipboard History | Retrieve recent items | limit: Int |
| Search Clipboard | Search by query | query: String, limit: Int |
| Paste Item | Paste specific item | item: ClipboardItem |
| Add to Clipboard | Add new item | content: String/Image |
| Transform Content | Apply transformation | action: String |
| Get Current Item | Get most recent | - |

### Example Shortcuts

#### "Save to PasteShelf" Shortcut

```
┌─────────────────────────────────────────────────────────────┐
│  Shortcut: Save to PasteShelf                               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Get Clipboard                                            │
│     └── Output: Clipboard Content                            │
│                                                              │
│  2. Add to Clipboard (PasteShelf)                           │
│     ├── Content: [Clipboard Content]                         │
│     ├── Favorite: Yes                                        │
│     └── Tags: "shortcut", "important"                        │
│                                                              │
│  3. Show Notification                                        │
│     └── "Saved to PasteShelf"                               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

#### "Smart Paste" Shortcut

```
┌─────────────────────────────────────────────────────────────┐
│  Shortcut: Smart Paste                                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Search Clipboard (PasteShelf)                           │
│     ├── Query: [Ask for Input]                               │
│     └── Limit: 5                                             │
│                                                              │
│  2. Choose from List                                         │
│     └── [Search Results]                                     │
│                                                              │
│  3. Paste Item (PasteShelf)                                 │
│     └── [Chosen Item]                                        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### AppIntents Implementation

```swift
import AppIntents

struct SearchClipboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Clipboard"
    static var description = IntentDescription("Search PasteShelf clipboard history")

    @Parameter(title: "Search Query")
    var query: String

    @Parameter(title: "Maximum Results", default: 10)
    var limit: Int

    func perform() async throws -> some IntentResult & ReturnsValue<[ClipboardItemEntity]> {
        let items = try await ClipboardManager.shared.search(query: query, limit: limit)
        let entities = items.map { ClipboardItemEntity(item: $0) }
        return .result(value: entities)
    }
}
```

---

## URL Scheme 🆓

### Base URL

```
pasteshelf://
```

### Supported Actions

| URL | Action | Parameters |
|-----|--------|------------|
| `pasteshelf://open` | Open main window | - |
| `pasteshelf://search?q=` | Search clipboard | q: query |
| `pasteshelf://paste?id=` | Paste specific item | id: UUID |
| `pasteshelf://add?text=` | Add text to clipboard | text: String |
| `pasteshelf://preferences` | Open preferences | - |
| `pasteshelf://upgrade` | Open upgrade dialog | - |

### Examples

```bash
# Open PasteShelf
open "pasteshelf://open"

# Search for "email"
open "pasteshelf://search?q=email"

# Add text
open "pasteshelf://add?text=Hello%20World"

# Paste by ID
open "pasteshelf://paste?id=550e8400-e29b-41d4-a716-446655440000"
```

### URL Handling

```swift
// In AppDelegate or Scene
func handleURL(_ url: URL) {
    guard url.scheme == "pasteshelf" else { return }

    switch url.host {
    case "open":
        windowManager.showMainWindow()

    case "search":
        if let query = url.queryParameters["q"] {
            searchManager.search(query: query)
        }

    case "paste":
        if let idString = url.queryParameters["id"],
           let id = UUID(uuidString: idString) {
            clipboardManager.paste(itemWithId: id)
        }

    case "add":
        if let text = url.queryParameters["text"]?.removingPercentEncoding {
            clipboardManager.add(text: text)
        }

    default:
        break
    }
}
```

---

## Webhooks 🏢

### Configuration

```
Admin Console → Integrations → Webhooks → Add Webhook
```

### Webhook Events

| Event | Description | Payload |
|-------|-------------|---------|
| `clipboard.created` | New item captured | Item data |
| `clipboard.deleted` | Item deleted | Item ID |
| `clipboard.synced` | Sync completed | Sync status |
| `user.activated` | License activated | User info |
| `team.member.joined` | Team member added | Member info |

### Payload Format

```json
{
    "event": "clipboard.created",
    "timestamp": "2026-02-03T12:00:00Z",
    "data": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "contentType": "public.plain-text",
        "preview": "Hello World...",
        "sourceApp": "com.apple.Safari",
        "createdAt": "2026-02-03T12:00:00Z"
    },
    "user": {
        "id": "user_123",
        "email": "user@company.com"
    },
    "signature": "sha256=..."
}
```

### Webhook Security

```swift
// Verify webhook signature
func verifySignature(payload: Data, signature: String, secret: String) -> Bool {
    let hmac = HMAC<SHA256>.authenticationCode(
        for: payload,
        using: SymmetricKey(data: Data(secret.utf8))
    )
    let expectedSignature = "sha256=" + Data(hmac).hexString
    return signature == expectedSignature
}
```

### Example: Slack Integration

```json
{
    "url": "https://hooks.slack.com/services/xxx",
    "events": ["clipboard.created"],
    "filters": {
        "contentTypes": ["public.plain-text"],
        "sourceApps": ["com.apple.Safari"]
    },
    "transform": {
        "text": "New clipboard item from {sourceApp}: {preview}"
    }
}
```

---

## JavaScript Actions ⭐

### Action Structure

```javascript
// action.js
(function() {
    return {
        // Action metadata
        name: "Format JSON",
        description: "Pretty-print JSON content",
        icon: "curlybraces",
        supportedTypes: ["public.json", "public.plain-text"],

        // Transform function
        transform: function(content) {
            try {
                const parsed = JSON.parse(content.text);
                return {
                    text: JSON.stringify(parsed, null, 2),
                    contentType: "public.json"
                };
            } catch (e) {
                return { error: "Invalid JSON: " + e.message };
            }
        }
    };
})();
```

### Built-in Functions

```javascript
// Available in action context
const PasteShelf = {
    // Clipboard operations
    clipboard: {
        getText: () => String,
        setText: (text) => void,
        getHTML: () => String,
        setHTML: (html) => void
    },

    // HTTP requests
    http: {
        get: async (url, options) => Response,
        post: async (url, body, options) => Response
    },

    // Storage (per-action)
    storage: {
        get: (key) => Any,
        set: (key, value) => void,
        remove: (key) => void
    },

    // UI
    ui: {
        alert: (message) => void,
        prompt: (message, defaultValue) => String,
        confirm: (message) => Boolean,
        notify: (title, body) => void
    },

    // Utilities
    utils: {
        base64Encode: (text) => String,
        base64Decode: (text) => String,
        urlEncode: (text) => String,
        urlDecode: (text) => String,
        md5: (text) => String,
        sha256: (text) => String
    }
};
```

### Example Actions

#### URL Shortener

```javascript
(function() {
    return {
        name: "Shorten URL",
        description: "Shorten URL using TinyURL",
        icon: "link",
        supportedTypes: ["public.url", "public.plain-text"],

        transform: async function(content) {
            const url = content.text;
            if (!url.match(/^https?:\/\//)) {
                return { error: "Not a valid URL" };
            }

            const response = await PasteShelf.http.get(
                `https://tinyurl.com/api-create.php?url=${encodeURIComponent(url)}`
            );

            return { text: response.text };
        }
    };
})();
```

#### Markdown to HTML

```javascript
(function() {
    return {
        name: "Markdown to HTML",
        description: "Convert Markdown to HTML",
        icon: "text.badge.checkmark",
        supportedTypes: ["public.plain-text"],

        transform: function(content) {
            // Simple markdown conversion
            let html = content.text
                .replace(/^### (.*$)/gim, '<h3>$1</h3>')
                .replace(/^## (.*$)/gim, '<h2>$1</h2>')
                .replace(/^# (.*$)/gim, '<h1>$1</h1>')
                .replace(/\*\*(.*)\*\*/gim, '<strong>$1</strong>')
                .replace(/\*(.*)\*/gim, '<em>$1</em>')
                .replace(/\n/gim, '<br>');

            return {
                text: html,
                html: html,
                contentType: "public.html"
            };
        }
    };
})();
```

---

## CLI Interface 🆓

### Installation

```bash
# Symlink CLI tool
sudo ln -s /Applications/PasteShelf.app/Contents/MacOS/pasteshelf-cli /usr/local/bin/pasteshelf
```

### Commands

```bash
# Help
pasteshelf --help

# List recent items
pasteshelf list [--limit N] [--type TYPE]

# Search
pasteshelf search "query" [--limit N]

# Get item by ID
pasteshelf get <id> [--format json|text|raw]

# Add content
pasteshelf add "content" [--type text|image|file]
pasteshelf add --file /path/to/file

# Paste item
pasteshelf paste <id>

# Delete item
pasteshelf delete <id> [--force]

# Clear history
pasteshelf clear [--before DATE] [--confirm]

# Export
pasteshelf export --output /path/to/backup.json [--format json|csv]

# Import
pasteshelf import /path/to/backup.json

# Status
pasteshelf status

# Version
pasteshelf --version
```

### Examples

```bash
# List last 5 text items
pasteshelf list --limit 5 --type text

# Search and paste first result
ID=$(pasteshelf search "email" --limit 1 --format json | jq -r '.[0].id')
pasteshelf paste $ID

# Export history
pasteshelf export --output ~/Desktop/clipboard-backup.json

# Pipe content
echo "Hello World" | pasteshelf add --stdin
cat file.txt | pasteshelf add --stdin

# Watch for changes
pasteshelf watch --on-change 'echo "New item: $PASTESHELF_PREVIEW"'
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Item not found |
| 4 | Permission denied |
| 5 | Not authenticated |

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Plugin System](../features/PLUGIN_SYSTEM.md) | Plugin development |
| [Automation Engine](../features/AUTOMATION_ENGINE.md) | Automation details |
| [Enterprise Admin](../enterprise/ENTERPRISE_ADMIN_GUIDE.md) | Webhook setup |

---

*Last updated: 2026-02-03*
