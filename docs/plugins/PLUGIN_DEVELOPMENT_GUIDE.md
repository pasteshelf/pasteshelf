# PasteShelf Plugin Development Guide

This guide explains how to create plugins for PasteShelf using the PasteShelfPluginKit SDK.

## Table of Contents

1. [Overview](#overview)
2. [Getting Started](#getting-started)
3. [Plugin Structure](#plugin-structure)
4. [Creating Your First Plugin](#creating-your-first-plugin)
5. [Plugin Protocols](#plugin-protocols)
6. [Working with Context](#working-with-context)
7. [Permissions](#permissions)
8. [Best Practices](#best-practices)
9. [Debugging](#debugging)
10. [Distribution](#distribution)

---

## Overview

PasteShelf plugins extend the clipboard manager with custom functionality:

- **Content Transformers**: Modify clipboard content (format JSON, shorten URLs, etc.)
- **Integrations**: Send content to external services (Notion, GitHub Gist, etc.)
- **UI Extensions**: Add menu items and context actions

Plugins are Swift bundles (`.pasteshelfplugin`) that implement the `PasteShelfPlugin` protocol.

### Requirements

- macOS 14.0+ (Sonoma)
- Swift 5.9+
- Xcode 15+
- PasteShelf Pro license (plugins are a Pro feature)

---

## Getting Started

### 1. Add the SDK to Your Project

Add PasteShelfPluginKit as a Swift Package dependency:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/pasteshelf/PasteShelfPluginKit.git", from: "1.0.0")
]
```

Or in Xcode: File > Add Package Dependencies > Enter the repository URL.

### 2. Create a Bundle Target

1. In Xcode, create a new target: File > New > Target
2. Select "Bundle" under macOS
3. Name it with `.pasteshelfplugin` extension
4. Set the principal class in Info.plist

### 3. Configure Info.plist

Every plugin requires an Info.plist with these keys:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Required: Unique reverse-DNS identifier -->
    <key>PSPluginIdentifier</key>
    <string>com.yourcompany.plugins.myplugin</string>

    <!-- Required: Display name -->
    <key>PSPluginName</key>
    <string>My Plugin</string>

    <!-- Required: Semantic version -->
    <key>PSPluginVersion</key>
    <string>1.0.0</string>

    <!-- Required: Principal class name (must match @objc attribute) -->
    <key>NSPrincipalClass</key>
    <string>MyPlugin</string>

    <!-- Optional: Author name -->
    <key>PSPluginAuthor</key>
    <string>Your Name</string>

    <!-- Optional: Author website -->
    <key>PSPluginWebsite</key>
    <string>https://yourwebsite.com</string>

    <!-- Optional: Plugin description -->
    <key>PSPluginDescription</key>
    <string>A brief description of what your plugin does.</string>

    <!-- Required: Minimum PasteShelf version -->
    <key>PSMinimumVersion</key>
    <string>1.3.0</string>

    <!-- Required: Permissions your plugin needs -->
    <key>PSPluginPermissions</key>
    <array>
        <string>clipboard.read</string>
        <string>storage</string>
    </array>

    <!-- Optional: Content types your plugin handles -->
    <key>PSPluginSupportedTypes</key>
    <array>
        <string>public.utf8-plain-text</string>
        <string>public.url</string>
    </array>
</dict>
</plist>
```

---

## Plugin Structure

A typical plugin bundle structure:

```
MyPlugin.pasteshelfplugin/
├── Contents/
│   ├── Info.plist          # Plugin manifest
│   ├── MacOS/
│   │   └── MyPlugin        # Compiled binary
│   └── Resources/
│       ├── icon.png        # Plugin icon (optional)
│       └── Localizable.strings  # Localization (optional)
```

---

## Creating Your First Plugin

Here's a complete example of a simple text transformer plugin:

```swift
import Foundation
import PasteShelfPluginKit

/// A plugin that converts text to uppercase.
@objc(UppercasePlugin)
public final class UppercasePlugin: NSObject, PasteShelfPlugin, PasteShelfPluginExtended {

    // MARK: - Properties

    private var context: (any PluginContext)?

    // MARK: - PasteShelfPlugin

    public func didLoad(with context: any PluginContext) {
        self.context = context
        context.logger.info("Uppercase plugin loaded!")
    }

    public func willUnload() {
        context?.logger.info("Uppercase plugin unloading")
    }

    public func menuItems() -> [PluginMenuItem] {
        [
            PluginMenuItem(
                title: "Convert to Uppercase",
                iconName: "textformat.size.larger",
                shortcutKey: "U+command+shift"
            ) { [weak self] content in
                try await self?.transform(content: content)
            }
        ]
    }

    // MARK: - PasteShelfPluginExtended

    public func transform(content: PluginClipboardContent) async throws -> PluginClipboardContent? {
        guard let text = content.text else {
            return nil
        }

        let result = PluginClipboardContent(text: text.uppercased())
        result.metadata["transformedBy"] = "UppercasePlugin"
        return result
    }

    public func supports(contentType: ContentType) -> Bool {
        contentType == .plainText
    }
}
```

**Key points:**

1. **`@objc(UppercasePlugin)`**: Required for runtime loading. The name must match `NSPrincipalClass` in Info.plist.

2. **`NSObject` inheritance**: Required for Objective-C runtime compatibility.

3. **`didLoad(with:)`**: Store the context reference here. It provides access to storage, logging, and other APIs.

4. **`willUnload()`**: Clean up resources before the plugin is unloaded.

5. **`menuItems()`**: Return menu items that appear in the PasteShelf UI.

---

## Plugin Protocols

### PasteShelfPlugin (Required)

The base protocol all plugins must implement:

```swift
@objc public protocol PasteShelfPlugin: NSObjectProtocol {
    /// Called when the plugin is loaded
    @objc func didLoad(with context: any PluginContext)

    /// Called before the plugin is unloaded (optional)
    @objc optional func willUnload()

    /// Returns menu items for the UI (optional)
    @objc optional func menuItems() -> [PluginMenuItem]
}
```

### PasteShelfPluginExtended (Optional)

For plugins that transform clipboard content:

```swift
public protocol PasteShelfPluginExtended: PasteShelfPlugin {
    /// Transforms clipboard content
    func transform(content: PluginClipboardContent) async throws -> PluginClipboardContent?

    /// Checks if the plugin supports a content type
    func supports(contentType: ContentType) -> Bool
}
```

### PasteShelfPluginWithSettings (Optional)

For plugins that have a settings UI:

```swift
public protocol PasteShelfPluginWithSettings: PasteShelfPlugin {
    /// Returns a SwiftUI view for plugin settings
    func settingsView() -> AnyView?
}
```

---

## Working with Context

The `PluginContext` provides access to PasteShelf APIs:

### Storage

Persistent key-value storage isolated to your plugin:

```swift
// Store values
context.storage.setString("api-key-here", forKey: "apiKey")
context.storage.setBool(true, forKey: "enabled")
context.storage.setInteger(5, forKey: "retryCount")

// Retrieve values
let apiKey = context.storage.string(forKey: "apiKey")
let enabled = context.storage.bool(forKey: "enabled")
let retries = context.storage.integer(forKey: "retryCount")

// Store Codable objects
struct Settings: Codable {
    var theme: String
    var fontSize: Int
}
let settings = Settings(theme: "dark", fontSize: 14)
context.storage.set("settings", value: settings)
let loaded: Settings? = context.storage.get("settings")
```

### Logger

Logging for debugging and diagnostics:

```swift
context.logger.debug("Debug message")
context.logger.info("Info message")
context.logger.warning("Warning message")
context.logger.error("Error message")
```

### Network (Requires Permission)

Make HTTP requests:

```swift
guard let network = context.network else {
    throw MyError.networkPermissionRequired
}

// Simple GET
let data = try await network.get(URL(string: "https://api.example.com/data")!)

// POST with JSON
let responseData = try await network.post(
    URL(string: "https://api.example.com/submit")!,
    body: jsonData,
    contentType: "application/json"
)

// Custom request
var request = URLRequest(url: url)
request.httpMethod = "PATCH"
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
let (data, response) = try await network.request(request)
```

### Clipboard (Requires Permission)

Access clipboard content:

```swift
guard let clipboard = context.clipboard else {
    throw MyError.clipboardPermissionRequired
}

// Get current content
if let content = clipboard.currentContent() {
    print("Current text: \(content.text ?? "none")")
}

// Get recent items
let recentItems = await clipboard.recentItems(limit: 10)

// Write to clipboard
let newContent = PluginClipboardContent(text: "Modified text")
clipboard.writeToClipboard(newContent)
```

---

## Permissions

Plugins must declare required permissions in Info.plist. Users approve permissions when installing/enabling the plugin.

| Permission | Key | Description |
|------------|-----|-------------|
| Read Clipboard | `clipboard.read` | Read clipboard history and current content |
| Write Clipboard | `clipboard.write` | Write content to the clipboard |
| Network | `network` | Make HTTP requests |
| Notifications | `notifications` | Show system notifications |
| Storage | `storage` | Persist data (always granted) |
| Automation | `automation` | Integrate with automation rules |

### Requesting Permissions at Runtime

For permissions declared but not yet granted:

```swift
// Check if permission is granted
if !context.hasPermission(.network) {
    // Request it
    let granted = await context.requestPermission(.network)
    if !granted {
        throw MyError.networkPermissionDenied
    }
}
```

---

## Best Practices

### 1. Handle Missing Permissions Gracefully

```swift
public func transform(content: PluginClipboardContent) async throws -> PluginClipboardContent? {
    guard let network = context?.network else {
        // Provide clear error message
        throw PluginError.permissionRequired("Network access is required. Enable it in plugin settings.")
    }
    // ... use network
}
```

### 2. Use Weak Self in Closures

```swift
PluginMenuItem(title: "Action") { [weak self] content in
    try await self?.performAction(content)
}
```

### 3. Validate Input

```swift
public func transform(content: PluginClipboardContent) async throws -> PluginClipboardContent? {
    guard let text = content.text, !text.isEmpty else {
        return nil  // Nothing to transform
    }
    // ... process text
}
```

### 4. Provide Meaningful Metadata

```swift
let result = PluginClipboardContent(text: transformed)
result.metadata["originalLength"] = text.count
result.metadata["transformedBy"] = Self.identifier
result.metadata["timestamp"] = ISO8601DateFormatter().string(from: Date())
return result
```

### 5. Keep Operations Fast

Plugins run in-process. Long operations block the UI. For slow operations:

```swift
// Show progress if available
context?.logger.info("Starting long operation...")

// Consider breaking into smaller chunks
for chunk in chunks {
    // Process chunk
    try Task.checkCancellation()  // Allow cancellation
}
```

### 6. Clean Up Resources

```swift
public func willUnload() {
    // Cancel any pending operations
    pendingTask?.cancel()

    // Release resources
    cachedData = nil

    context?.logger.info("Plugin unloaded cleanly")
}
```

---

## Debugging

### View Plugin Logs

Plugin logs appear in Console.app under the `PasteShelf` process. Filter by your plugin ID.

### Common Issues

**Plugin doesn't load:**
- Verify `NSPrincipalClass` matches your `@objc(ClassName)` attribute exactly
- Ensure the class inherits from `NSObject`
- Check code signature (unsigned plugins are rejected by default)

**Permission errors:**
- Verify permissions are declared in Info.plist
- Check if user has granted the permission in settings

**Network requests fail:**
- Ensure `network` permission is declared and granted
- Verify URLs use HTTPS (HTTP is blocked)

**Storage not persisting:**
- Storage uses UserDefaults scoped to your plugin ID
- Data persists across app restarts but not plugin reinstalls

---

## Distribution

### Code Signing

Plugins should be code-signed for security:

```bash
codesign --sign "Developer ID Application: Your Name" \
    --options runtime \
    --timestamp \
    MyPlugin.pasteshelfplugin
```

### Notarization (Recommended)

For distribution outside the App Store:

```bash
# Create a ZIP for notarization
zip -r MyPlugin.zip MyPlugin.pasteshelfplugin

# Submit for notarization
xcrun notarytool submit MyPlugin.zip \
    --apple-id "your@email.com" \
    --team-id "TEAMID" \
    --password "@keychain:AC_PASSWORD" \
    --wait

# Staple the ticket
xcrun stapler staple MyPlugin.pasteshelfplugin
```

### Installation Directory

Users install plugins to:
```
~/Library/Application Support/PasteShelf/Plugins/
```

Bundled plugins (included with PasteShelf) are in the app bundle's Resources folder.

---

## Example Plugins

PasteShelf includes several built-in plugins as references:

| Plugin | Description | Permissions |
|--------|-------------|-------------|
| JSON Beautifier | Format/minify JSON | storage |
| Markdown Formatter | HTML to Markdown conversion | storage |
| URL Shortener | Shorten URLs via public APIs | network, storage |
| GitHub Gist | Create gists from clipboard | network, storage |
| Notion | Send content to Notion pages | network, storage |

View the source code in `PasteShelf/Core/Plugins/BuiltIn/` for implementation patterns.

---

## API Reference

For complete API documentation, see the [PasteShelfPluginKit API Reference](API_REFERENCE.md).

---

## Support

- **GitHub Issues**: Report bugs and request features
- **Documentation**: https://pasteshelf.com/docs/plugins
- **Community**: https://github.com/pasteshelf/discussions

---

*PasteShelf Plugin SDK v1.0.0*
