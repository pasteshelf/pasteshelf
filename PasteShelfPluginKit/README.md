# PasteShelfPluginKit

The official SDK for creating PasteShelf plugins. This Swift package provides all the public protocols and types needed to build third-party plugins that integrate with PasteShelf.

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9 or later
- Xcode 15.0 or later

## Installation

### Swift Package Manager

Add PasteShelfPluginKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/pasteshelf/PasteShelfPluginKit.git", from: "1.0.0")
]
```

Or in Xcode: File > Add Package Dependencies, then enter the repository URL.

### Manual

Copy the `Sources/PasteShelfPluginKit` folder into your project.

## Quick Start

### 1. Create a Plugin Class

```swift
import PasteShelfPluginKit

@objc(MyPlugin)
public final class MyPlugin: NSObject, PasteShelfPlugin {
    private var context: (any PluginContext)?

    public func didLoad(with context: any PluginContext) {
        self.context = context
        context.logger.info("MyPlugin loaded!")
    }

    public func willUnload() {
        context?.logger.info("MyPlugin unloading")
    }

    public func menuItems() -> [PluginMenuItem] {
        [
            PluginMenuItem(
                title: "My Action",
                iconName: "star.fill",
                shortcutKey: "M+command+shift"
            ) { content in
                // Transform content here
                return content
            }
        ]
    }
}
```

### 2. Configure Info.plist

```xml
<key>NSPrincipalClass</key>
<string>MyPlugin</string>

<key>PSPluginIdentifier</key>
<string>com.example.myplugin</string>

<key>PSPluginName</key>
<string>My Plugin</string>

<key>PSPluginVersion</key>
<string>1.0.0</string>

<key>PSMinimumVersion</key>
<string>1.3.0</string>

<key>PSPluginPermissions</key>
<array>
    <string>storage</string>
</array>
```

### 3. Build as Bundle

Build your plugin as a macOS Bundle target with the `.pasteshelfplugin` extension.

### 4. Install

Copy the built bundle to:

```
~/Library/Application Support/PasteShelf/Plugins/
```

## Core Protocols

### PasteShelfPlugin

The main protocol all plugins must implement:

```swift
@objc public protocol PasteShelfPlugin: NSObjectProtocol {
    func didLoad(with context: any PluginContext)
    optional func willUnload()
    optional func menuItems() -> [PluginMenuItem]
}
```

### PasteShelfPluginExtended

For plugins that transform content:

```swift
public protocol PasteShelfPluginExtended: PasteShelfPlugin {
    func transform(content: PluginClipboardContent) async throws -> PluginClipboardContent?
    func supports(contentType: ContentType) -> Bool
}
```

### PasteShelfPluginWithSettings

For plugins with configurable settings:

```swift
public protocol PasteShelfPluginWithSettings: PasteShelfPlugin {
    func settingsView() -> AnyView?
}
```

### PluginContext

Access to host APIs:

```swift
@objc public protocol PluginContext: NSObjectProtocol {
    var storage: any PluginStorage { get }
    var logger: PluginLogger { get }
    var hostVersion: String { get }
    var network: (any PluginNetwork)? { get }
    var clipboard: (any PluginClipboardAccess)? { get }

    func requestPermission(_ permission: String) async -> Bool
    func hasPermission(_ permission: String) -> Bool
}
```

## Permissions

Plugins must declare required permissions in Info.plist:

| Permission | Description |
|------------|-------------|
| `storage` | Persistent storage (always granted) |
| `clipboard.read` | Read clipboard history |
| `clipboard.write` | Write to clipboard |
| `network` | HTTP network access |
| `notifications` | Show notifications |
| `automation` | Automation integration |

## Content Types

Supported clipboard content types:

```swift
public enum ContentType: String {
    case plainText = "public.utf8-plain-text"
    case richText = "public.rtf"
    case html = "public.html"
    case png = "public.png"
    case jpeg = "public.jpeg"
    case tiff = "public.tiff"
    case pdf = "com.adobe.pdf"
    case fileURL = "public.file-url"
    case url = "public.url"
}
```

## Examples

See the `Examples/` directory for complete plugin implementations:

- **ExamplePlugin** - Text reversal with settings UI

## API Reference

### PluginStorage

```swift
// Read values
storage.string(forKey: "key")
storage.bool(forKey: "key")
storage.integer(forKey: "key")
storage.data(forKey: "key")
storage.get("key") as MyType?  // Codable

// Write values
storage.setString("value", forKey: "key")
storage.setBool(true, forKey: "key")
storage.setInteger(42, forKey: "key")
storage.setData(data, forKey: "key")
storage.set("key", value: myValue)  // Codable

// Clear
storage.removeObject(forKey: "key")
storage.clear()
```

### PluginNetwork

```swift
// GET request
let data = try await network.get(url)

// POST request
let response = try await network.post(url, body: jsonData)

// Custom request
let (data, response) = try await network.request(urlRequest)
```

### PluginClipboardAccess

```swift
// Read clipboard
let current = clipboard.currentContent()
let recent = await clipboard.recentItems(limit: 10)

// Write to clipboard
clipboard.writeToClipboard(content)
```

### PluginLogger

```swift
context.logger.debug("Debug message")
context.logger.info("Info message")
context.logger.warning("Warning message")
context.logger.error("Error message")
```

## Best Practices

1. **Store context reference** - Save the context in `didLoad` for later use
2. **Handle errors gracefully** - Use proper error types with localized descriptions
3. **Clean up in willUnload** - Cancel operations and release resources
4. **Minimize permissions** - Only request what you need
5. **Use async/await** - All network and clipboard operations are async
6. **Add metadata** - Include transformation metadata for debugging

## License

Copyright © 2026 PasteShelf. All rights reserved.

See the [PasteShelf License](https://pasteshelf.com/license) for details.
